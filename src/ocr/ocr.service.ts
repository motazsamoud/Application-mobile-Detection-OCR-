// src/ocr/ocr.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { createWorker, OEM, PSM } from 'tesseract.js';
import { join } from 'path';
import sharp from 'sharp';
import { promises as fs } from 'fs';

type FieldScore<T> = { value: T | null; confidence: number };

function titleCase(s: string) {
    return s
        .toLowerCase()
        .split(/[\s_-]+/)
        .map(w => (w ? w[0].toUpperCase() + w.slice(1) : w))
        .join(' ');
}

@Injectable()
export class OcrService {
    private readonly logger = new Logger(OcrService.name);

    // ---------- Prétraitement image ----------
    private async preprocess(inputPath: string): Promise<string> {
        const out = inputPath.replace(/(\.[a-z]+)$/i, '_prep.png');
        await sharp(inputPath)
            .rotate()
            .resize({ width: 2000 })
            .sharpen()
            .grayscale()
            .normalize()
            .toFormat('png')
            .toFile(out);
        return out;
    }

    // ---------- Normalisation texte OCR ----------
    private normalizeText(raw: string) {
        let t = (raw || '').replace(/\r/g, '\n');

        // Répare les points autour des TLD / sous-domaines
        t = t.replace(/\s*\.\s*/g, '.'); // "name . com" -> "name.com"
        t = t.replace(/(www\.[a-z0-9-]+)\s+(com|fr|net|org|io|co|tn|ma|dz)\b/gi, '$1.$2');
        // Petites confusions fréquentes
        t = t.replace(/[|]/g, 'I'); // confond '|' et 'I'
        t = t.replace(/@\s+/g, '@'); // "@ domain.com" -> "@domain.com"
        t = t.replace(/\s{2,}/g, ' ');

        return t.trim();
    }

    // ---------- Extracteurs simples ----------
    private extractEmail(text: string): FieldScore<string> {
        // 1) Détection stricte
        const strict = text.match(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i);
        if (strict) {
            return { value: strict[0].toLowerCase(), confidence: 0.96 };
        }

        // 2) Réparation si le point avant TLD a sauté (avec ou sans espace)
        const TLD = '(com|fr|net|org|io|co|tn|ma|dz|de|uk|es|it|edu|gov|info|biz)';

        // "name@domain com"
        let m = text.match(new RegExp(`\\b([A-Z0-9._%+-]+)@([A-Z0-9.-]+)\\s+${TLD}\\b`, 'i'));
        if (m) {
            const repaired = `${m[1]}@${m[2].replace(/\.$/, '')}.${m[3]}`.toLowerCase();
            return { value: repaired, confidence: 0.85 };
        }

        // "name@domaincom"
        m = text.match(new RegExp(`\\b([A-Z0-9._%+-]+)@([A-Z0-9.-]+)${TLD}\\b`, 'i'));
        if (m) {
            const repaired = `${m[1]}@${m[2]}.${m[3]}`.toLowerCase();
            return { value: repaired, confidence: 0.80 };
        }

        return { value: null, confidence: 0 };
    }


    private extractPhone(text: string): FieldScore<string> {
        // autorise +, espaces, -, (), points
        const m = text.replace(/[|]/g, 'I').match(/(\+?\d[\d ().\-]{7,})/);
        return { value: m?.[0]?.replace(/\s{2,}/g, ' ').trim() ?? null, confidence: m ? 0.9 : 0 };
    }

    private extractWebsite(text: string): FieldScore<string> {
        // 1) Détection stricte avec point déjà présent
        let m = text.match(/\b((https?:\/\/)?(www\.)?[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,})(\/[^\s]*)?\b/i);
        if (m) return { value: m[1].toLowerCase(), confidence: 0.92 };

        // 2) Fallback : "www accurate com" (sans point)
        const m2 = text.match(/\bwww\s+([a-z0-9-]+)\s+(com|fr|net|org|io|co|tn|ma|dz|de|uk|es|it|edu|gov|info|biz)\b/i);
        if (m2) return { value: `www.${m2[1].toLowerCase()}.${m2[2].toLowerCase()}`, confidence: 0.86 };

        return { value: null, confidence: 0 };
    }


    private extractAddress(lines: string[]): FieldScore<string> {
        // Un "token email" = tout segment sans espace contenant '@' (même sans .tld)
        const tokenAtRe = /[^\s,;]*@[^\s,;]*/g;       // supprime nameofyourcomany@domaincom, foo@bar, etc.
        const urlRe     = /\b(https?:\/\/|www\.)[^\s,;]+/gi;

        // utilitaire: nettoie une ligne d'email/url + normalise
        const stripComm = (s: string) => s
            .replace(tokenAtRe, ' ')
            .replace(urlRe, ' ')
            .replace(/\s{2,}/g, ' ')
            .replace(/\s*,\s*,+/g, ', ')
            .replace(/(^\s*,\s*)|(\s*,\s*$)/g, '') // virgules en tête/fin
            .trim();

        // cas OCR: lettre isolée avant l’adresse (ex: "Q Street ...")
        const stripOCRHead = (s: string) => s.replace(/^[A-Za-z]\s+(?=[A-Z])/, '');

        const prepared = lines
            .map(l => stripOCRHead(stripComm(l)))
            .filter(Boolean);

        // 1) Règle forte: ligne avec ≥ 2 virgules => candidate adresse
        let candidate = prepared.find(l => (l.match(/,/g) || []).length >= 2) || null;
        if (candidate) {
            // re-strip au cas où (idempotent) puis vérifs
            candidate = stripComm(candidate);
            if ((candidate.match(/,/g) || []).length >= 2 && /[A-Za-z]/.test(candidate)) {
                return { value: candidate, confidence: 0.9 };
            }
        }

        // Heuristiques d’adresse classiques
        const addrRegex =
            /(street|st\.?|avenue|ave\.?|road|rd\.?|boulevard|blvd\.?|rue|route|state|country|zip|postal|bp|city|ville)/i;

        // 2) Mot-clé d’adresse (et fusion éventuelle avec la suivante)
        for (let i = 0; i < prepared.length; i++) {
            const line = prepared[i];
            if (addrRegex.test(line) || /^[0-9]{1,5}[^,]*[, ]/.test(line)) {
                const next = prepared[i + 1];
                const merged = [line, next]
                    .filter(s => s && (addrRegex.test(s) || /[0-9A-Za-z].*,.*[0-9A-Za-z]/.test(s)))
                    .join(', ');
                const clean = stripComm(merged || line);
                if (clean) return { value: clean, confidence: 0.84 };
            }
        }

        // 3) Fallback: chiffres + virgules (ex: "12 Something, City, Country")
        const numericComma = prepared.find(l => /[0-9].*,.*[A-Za-z]/.test(l));
        if (numericComma) return { value: stripComm(numericComma), confidence: 0.78 };

        // 4) Dernier recours: première ligne longue avec une virgule
        const simpleComma = prepared.find(l => l.includes(',') && l.length >= 12) || null;
        return { value: simpleComma ? stripComm(simpleComma) : null, confidence: simpleComma ? 0.7 : 0 };
    }




    private guessName(lines: string[]): FieldScore<string> {
        // Cherche dans les 5 premières lignes un "Prénom Nom" (ou ALL CAPS)
        const firsts = lines.slice(0, 5);
        for (const l of firsts) {
            const clean = l.replace(/[^A-Za-zÀ-ÖØ-öø-ÿ' -]/g, '').trim();
            if (!clean) continue;
            const twoWords = clean.match(/^([A-Z][A-Za-zÀ-ÖØ-öø-ÿ'-]{2,})\s+([A-Z][A-Za-zÀ-ÖØ-öø-ÿ'-]{2,})$/);
            if (twoWords) {
                return { value: clean, confidence: 0.9 };
            }
            // ALL CAPS -> convertir
            const capsTwo = clean.match(/^([A-Z]{2,})\s+([A-Z]{2,})$/);
            if (capsTwo) {
                return { value: titleCase(clean), confidence: 0.85 };
            }
        }
        return { value: null, confidence: 0 };
    }

    private extractJobTitle(lines: string[]): FieldScore<string> {
        const roleRe =
            /(CEO|Chief\s+\w+|CTO|CFO|COO|Founder|Co-?Founder|General\s+Manager|Manager|Director|Engineer|Developer|Designer|Sales|Marketing|Product\s+Manager|Project\s+Manager)/i;
        const line = lines.find(l => roleRe.test(l)) ?? null;
        return { value: line ?? null, confidence: line ? 0.88 : 0 };
    }

    private extractCompany(lines: string[], website?: string | null, email?: string | null): FieldScore<string> {
        // 1) ligne avec mots "Company|Corp|Inc|SARL|SAS|LTD|GmbH|SA|SPA"
        const line =
            lines.find(l => /\b(company|corp|corporation|inc\.?|sarl|sas|ltd|gmbh|sa|spa)\b/i.test(l)) ?? null;

        if (line) {
            return { value: titleCase(line.replace(/\b(www|\.com|\.fr).*/i, '').trim()), confidence: 0.8 };
        }

        // 2) déduire du site
        const from = (domain?: string | null) => {
            if (!domain) return null;
            const m = domain.toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, '');
            const sld = m.split('/')[0].split('.')[0];
            if (sld && sld.length >= 3) return titleCase(sld);
            return null;
        };

        const fromWeb = from(website);
        if (fromWeb) return { value: fromWeb, confidence: 0.7 };

        // 3) déduire de l’email
        const fromEmail = from(email?.split('@')[1] || undefined);
        if (fromEmail) return { value: fromEmail, confidence: 0.65 };

        return { value: null, confidence: 0 };
    }

    private computeGlobalConfidence(fields: Array<FieldScore<any>>, ocrConfidence: number) {
        const present = fields.filter(f => f.value !== null);
        const avgFields = present.length ? present.reduce((s, f) => s + f.confidence, 0) / present.length : 0;
        return Math.round((avgFields * 0.6 + (ocrConfidence / 100) * 0.4) * 100);
    }

    // ---------- Pipeline principal ----------
    async processImage(filePath: string) {
        const preprocessed = await this.preprocess(filePath);

        // Tesseract v5
        const worker = await createWorker(['eng', 'fra'], OEM.LSTM_ONLY, {
            logger: m => this.logger.debug(JSON.stringify(m)),
            langPath: join(process.cwd(), 'tessdata'),
            gzip: false,
        });

        try {
            await worker.setParameters({
                tessedit_pageseg_mode: PSM.SINGLE_BLOCK,
                user_defined_dpi: '300',
                preserve_interword_spaces: '1',
            });

            const { data } = await worker.recognize(preprocessed);

            const rawText = this.normalizeText(data.text || '');
            const lines = rawText.split('\n').map(s => s.trim()).filter(Boolean);

            const email = this.extractEmail(rawText);
            const phone = this.extractPhone(rawText);
            const website = this.extractWebsite(rawText);
            const address = this.extractAddress(lines);
            const fullName = this.guessName(lines);
            const position = this.extractJobTitle(lines);
            const company = this.extractCompany(lines, website.value, email.value);

            const confidence = this.computeGlobalConfidence(
                [fullName, position, company, email, phone, website, address],
                data.confidence ?? 0,
            );

            return {
                fullName: fullName.value,
                company: company.value,
                email: email.value,
                phone: phone.value,
                position: position.value, // ex: "CEO & FOUNDER"
                address: address.value,   // ex: "Street Name, State, Country"
                website: website.value,
                status: 'new',
                confidence,
                fieldScores: {
                    fullName: fullName.confidence,
                    company: company.confidence,
                    position: position.confidence,
                    address: address.confidence,
                    email: email.confidence,
                    phone: phone.confidence,
                    website: website.confidence,
                    ocr: Math.round(data.confidence ?? 0),
                },
                rawText,
            };
        } finally {
            await worker.terminate();
            try { await fs.unlink(filePath); } catch {}
            try { await fs.unlink(preprocessed); } catch {}
        }
    }
}
