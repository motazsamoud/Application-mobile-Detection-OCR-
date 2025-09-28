// src/ocr-detections/schemas/ocr-detection.schema.ts
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class OcrDetection extends Document {
    // Image source info (optionnel)
    @Prop() source?: 'mobile' | 'web';
    @Prop() fileName?: string;
    @Prop() mimeType?: string;
    @Prop() fileSize?: number;

    // Champs extraits
    @Prop() fullName?: string;
    @Prop() company?: string;
    @Prop() email?: string;
    @Prop() phone?: string;
    @Prop() position?: string;
    @Prop() address?: string;
    @Prop() website?: string;

    // Scores & meta OCR
    @Prop() status?: 'draft' | 'confirmed' | 'rejected'; // draft par défaut
    @Prop({ default: 0 }) confidence?: number;
    @Prop({ type: Object }) fieldScores?: Record<string, number>;
    @Prop() rawText?: string;
}

export const OcrDetectionSchema = SchemaFactory.createForClass(OcrDetection);
export const OcrDetectionModel = 'OcrDetection';  // Nom pour l'injection
