// src/ocr-detections/ocr-detections.controller.ts
import { Controller, Get, Param, Post, Body, Query, Req } from '@nestjs/common';
import { Request } from 'express';
import { OcrDetectionsService } from './ocr-detections.service';

@Controller('ocr/detections')
export class OcrDetectionsController {
    constructor(private readonly svc: OcrDetectionsService) {}

    @Get()
    async list(@Req() req: Request, @Query('limit') limit?: string) {
        const host =
            (process.env.PUBLIC_BASE_URL?.replace(/\/$/, '')) ||
            `${req.protocol}://${req.get('host')}`;

        const items = await this.svc.list(Number(limit) || 50);
        return items.map((doc: any) => ({
            ...doc,
            imageUrl: doc?.fileName ? `${host}/uploads/${encodeURIComponent(doc.fileName)}` : null,
        }));
    }

    @Get(':id')
    async get(@Req() req: Request, @Param('id') id: string) {
        const host =
            (process.env.PUBLIC_BASE_URL?.replace(/\/$/, '')) ||
            `${req.protocol}://${req.get('host')}`;

        const doc: any = await this.svc.findOne(id);
        if (!doc) return null;
        return {
            ...doc,
            imageUrl: doc?.fileName ? `${host}/uploads/${encodeURIComponent(doc.fileName)}` : null,
        };
    }

    @Post(':id/status')
    updateStatus(@Param('id') id: string, @Body() body: { status: 'draft'|'confirmed'|'rejected' }) {
        return this.svc.updateStatus(id, body.status);
    }
}
