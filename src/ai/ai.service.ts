import { Injectable } from '@nestjs/common';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { OpportunitiesService } from '../opportunities/opportunities.service';

function toNum(v: any): number | null {
    if (v == null) return null;
    if (typeof v === 'number') return v;
    const n = Number(String(v).replace(',', '.'));
    return isNaN(n) ? null : n;
}
function toDateStr(v: any): string {
    try { return new Date(v).toISOString(); } catch { return ''; }
}

@Injectable()
export class AiService {
    private readonly model = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!)
        .getGenerativeModel({ model: 'gemini-2.0-flash' });

    constructor(private readonly opps: OpportunitiesService) {}

    async generateInsights(from?: string, to?: string, limit = 300) {
        // ✅ n’envoie plus from/to au service (DTO ne les connaît pas)
        const data = await this.opps.findAll({ page: 1, limit });

        // support des deux formats possibles: {data:[...]} ou [...]
        const rows: any[] = Array.isArray((data as any)?.data) ? (data as any).data : (data as any) ?? [];

        // ✅ filtre date en mémoire si from/to fournis
        const fromD = from ? new Date(from) : null;
        const toD   = to   ? new Date(to)   : null;
        const filtered = rows.filter((m: any) => {
            const d = new Date(m?.createdAt ?? m?.updatedAt ?? Date.now());
            if (fromD && d < fromD) return false;
            if (toD && d > toD)     return false;
            return true;
        });

        const items = filtered.map((m: any) => ({
            id: String(m._id ?? m.id ?? ''),
            title: String(m.title ?? ''),
            company: String(m.company ?? ''),
            fullName: String(m.fullName ?? ''),
            email: String(m.email ?? ''),
            position: String(m.position ?? 'new'),
            amount: toNum(m.amount),
            currency: String(m.currency ?? 'TND'),
            createdAt: toDateStr(m.createdAt),
            updatedAt: toDateStr(m.updatedAt),
        }));

        // Prompt JSON strict
        const sys = `Tu es un analyste CRM. Retourne UNIQUEMENT du JSON valide avec ce schema:
{
  "summary": "string",
  "kpis": {"total": number, "sumAmount": number, "winRate": number},
  "insightsByStage": [{"stage":"new|contacted|qualified|won|lost","note":"string"}],
  "actions": ["string", ...],
  "risks": ["string", ...]
}`;
        const user = `Données (JSON) des opportunités: ${JSON.stringify(items).slice(0, 50000)}
Consigne: calcule KPIs, déduis tendances par étape, top sociétés, 5 actions concrètes et 5 risques.
Réponds STRICTEMENT le JSON demandé, sans texte autour.`;

        const res = await this.model.generateContent([{ text: sys }, { text: user }]);
        const raw = res.response.text() ?? '{}';

        // CSV (côté serveur)
        const header = ['id','title','company','fullName','email','position','amount','currency','createdAt','updatedAt'];
        const csvRows = [header.join(',')].concat(
            items.map((r) => header.map((h) => {
                const cell = (r[h] ?? '').toString().replace(/\n/g,' ').replace(/"/g,'""');
                return `"${cell}"`;
            }).join(','))
        );
        const csv = csvRows.join('\n');

        // Parse robuste du JSON
        let json: any;
        try {
            const start = raw.indexOf('{'); const end = raw.lastIndexOf('}');
            json = JSON.parse(raw.slice(start, end + 1));
        } catch {
            json = {
                summary: 'Analyse indisponible',
                kpis: { total: items.length, sumAmount: items.reduce((s, m)=> s + (m.amount ?? 0), 0), winRate: 0 },
                insightsByStage: [], topCompanies: [], actions: [], risks: [],
            };
        }

        return { ai: json, csv, count: items.length, from, to };
    }
}
