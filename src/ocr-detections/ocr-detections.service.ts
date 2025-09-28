// src/ocr-detections/ocr-detections.service.ts
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { OcrDetection } from './schemas/ocr-detection.schema';

@Injectable()
export class OcrDetectionsService {
    constructor(@InjectModel(OcrDetection.name) private model: Model<OcrDetection>) {}

    async create(payload: Partial<OcrDetection>) {
        return this.model.create(payload);
    }

    async findOne(id: string) {
        return this.model.findById(id).lean();
    }

    async list(limit = 50) {
        return this.model.find().sort({ createdAt: -1 }).limit(limit).lean();
    }

    async updateStatus(id: string, status: 'draft'|'confirmed'|'rejected') {
        return this.model.findByIdAndUpdate(id, { status }, { new: true }).lean();
    }
}
