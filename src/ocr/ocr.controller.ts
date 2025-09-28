// src/ocr/ocr.controller.ts
import {
    Controller, Post, UploadedFile, UseInterceptors,
    BadRequestException, Query, Req
} from '@nestjs/common';
import { Request } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { OcrService } from './ocr.service';
import { OcrDetectionsService } from '../ocr-detections/ocr-detections.service';

// helper: string | null | '' -> undefined
const s = (v: unknown): string | undefined =>
    (typeof v === 'string' && v.trim().length > 0) ? v.trim() : undefined;

@Controller('ocr')
export class OcrController {
    constructor(
        private readonly ocrService: OcrService,
        private readonly detections: OcrDetectionsService,
    ) {}

    @Post('scan')
    @UseInterceptors(
        FileInterceptor('file', {
            storage: diskStorage({
                destination: './uploads',
                filename: (_req, file, cb) => {
                    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
                    cb(null, unique + extname(file.originalname || '.png'));
                },
            }),
            limits: { fileSize: 5 * 1024 * 1024 },
            fileFilter: (_req, file, cb) => {
                if (!file.mimetype.startsWith('image/')) {
                    return cb(new BadRequestException('Seules les images sont acceptées'), false);
                }
                cb(null, true);
            },
        }),
    )
    async scanImage(
        @UploadedFile() file: Express.Multer.File,
        @Req() req: Request,                                    // <-- requis AVANT
        @Query('source') source?: 'mobile' | 'web',             // <-- optionnel APRÈS
    ) {
        if (!file) throw new BadRequestException('Aucun fichier');

        // 1) OCR
        const result = await this.ocrService.processImage(file.path);
        const { status: extractionStatus, ...r } = result;

        // 2) Construire l’URL publique du fichier SAUVÉ
        const storedName = file.filename; // nom réel sauvegardé par Multer
        const host =
            (process.env.PUBLIC_BASE_URL?.replace(/\/$/, '')) ||
            `${req.protocol}://${req.get('host')}`;
        const imageUrl = `${host}/uploads/${encodeURIComponent(storedName)}`;

        // 3) Payload DB: on stocke le NOM SAUVÉ
        const payload = {
            source: source ?? 'web',
            fileName: storedName,
            originalFileName: file.originalname,
            mimeType: file.mimetype,
            fileSize: file.size,
            status: 'draft' as const,

            fullName: s(r.fullName),
            company:  s(r.company),
            email:    s(r.email),
            phone:    s(r.phone),
            position: s(r.position),
            address:  s(r.address),
            website:  s(r.website),

            confidence: typeof r.confidence === 'number' ? r.confidence : undefined,
            fieldScores: (r.fieldScores ?? undefined) as Record<string, number> | undefined,
            rawText: s(r.rawText),
        };

        const saved = await this.detections.create(payload);

        // 4) Réponse front enrichie
        return {
            id: saved._id,
            detectionStatus: saved.status,
            extractionStatus,
            fileName: storedName,
            imageUrl, // <— le front l’utilise en priorité
            fullName: payload.fullName,
            company: payload.company,
            email: payload.email,
            phone: payload.phone,
            position: payload.position,
            address: payload.address,
            website: payload.website,
            confidence: payload.confidence,
            fieldScores: payload.fieldScores,
            rawText: payload.rawText,
        };
    }
}
