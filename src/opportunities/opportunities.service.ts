import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Opportunity, OpportunityDocument, PipelinePosition } from './schemas/opportunity.schema';
import { CreateOpportunityDto } from './dto/create-opportunity.dto';
import { UpdateOpportunityDto } from './dto/update-opportunity.dto';
import { QueryOpportunityDto } from './dto/query-opportunity.dto';  // Importer correctement le DTO de requête
import { OcrDetection } from '../ocr-detections/schemas/ocr-detection.schema';  // Importer le modèle OcrDetection

@Injectable()
export class OpportunitiesService {
    constructor(
        @InjectModel(Opportunity.name) private readonly oppModel: Model<OpportunityDocument>,
        @InjectModel('OcrDetection') private readonly ocrModel: Model<OcrDetection>,  // Utiliser 'OcrDetection' comme modèle
    ) {}

    private extractEmailFallback(text?: string): string | undefined {
        if (!text) return undefined;
        const match = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
        return match ? match[0].toLowerCase() : undefined;
    }

    private extractWebsiteFallback(text?: string): string | undefined {
        if (!text) return undefined;
        const match = text.match(/(https?:\/\/)?(www\.)?[a-z0-9.-]+\.[a-z]{2,}(\/[\w.-]*)?/i);
        return match ? match[0] : undefined;
    }

    private async buildFromOcr(dto: CreateOpportunityDto): Promise<Partial<Opportunity>> {
        if (!dto.ocrDetectionId) return {};

        // Force le typage pour det._id en tant que Types.ObjectId
        const det = await this.ocrModel.findById(dto.ocrDetectionId).lean() as OcrDetection | null;

        if (!det) throw new NotFoundException('OCR detection not found');

        const email = dto.email ?? det.email ?? this.extractEmailFallback(det.address ?? det.rawText);
        const website = dto.website ?? det.website ?? this.extractWebsiteFallback(det.address ?? det.rawText);

        return {
            ocrDetectionId: det._id as Types.ObjectId,  // Ici, on force le typage en Types.ObjectId
            fullName: dto.fullName ?? det.fullName,
            company: dto.company ?? det.company,
            email,
            phone: dto.phone ?? det.phone,
            jobTitle: dto.jobTitle ?? det.position,
            address: dto.address ?? det.address,
            website,
            title: dto.title ?? (det.fullName ? `Carte ${det.fullName}` : 'Opportunity'),
        };
    }

    async create(dto: CreateOpportunityDto) {
        const fromOcr = await this.buildFromOcr(dto);

        const doc: Partial<Opportunity> = {
            title: dto.title ?? fromOcr.title ?? 'Opportunity',
            position: dto.position ?? PipelinePosition.NEW,
            amount: dto.amount,
            currency: dto.currency ?? 'TND',

            fullName: fromOcr.fullName ?? dto.fullName,
            company: fromOcr.company ?? dto.company,
            email: fromOcr.email ?? dto.email,
            phone: fromOcr.phone ?? dto.phone,
            jobTitle: fromOcr.jobTitle ?? dto.jobTitle,
            address: fromOcr.address ?? dto.address,
            website: fromOcr.website ?? dto.website,

            dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
            tags: dto.tags ?? [],
            ocrDetectionId: fromOcr.ocrDetectionId,
        };

        const created = new this.oppModel(doc);
        return created.save();
    }

    async findAll(q: QueryOpportunityDto) {
        const filter: any = {};
        if (q.position) filter.position = q.position;

        if (q.search) {
            filter.$text = { $search: q.search };
        }

        const sortKey = q.sort || '-createdAt';
        const sort: Record<string, 1 | -1> = {};
        if (sortKey.startsWith('-')) sort[sortKey.substring(1)] = -1;
        else sort[sortKey] = 1;

        const page = q.page ?? 1;
        const limit = q.limit ?? 20;
        const skip = (page - 1) * limit;

        const [data, total] = await Promise.all([
            this.oppModel.find(filter).sort(sort).skip(skip).limit(limit).lean(),
            this.oppModel.countDocuments(filter),
        ]);

        return { data, total, page, limit };
    }

    async findOne(id: string): Promise<Opportunity> {
        const doc = await this.oppModel.findById(id).lean();
        if (!doc) throw new NotFoundException('Opportunity not found');
        return doc as any;
    }

    async update(id: string, dto: UpdateOpportunityDto): Promise<Opportunity> {
        const patch: any = { ...dto };
        if (dto.dueDate) patch.dueDate = new Date(dto.dueDate);
        const updated = await this.oppModel.findByIdAndUpdate(id, patch, { new: true, lean: true });
        if (!updated) throw new NotFoundException('Opportunity not found');
        return updated as any;
    }

    async remove(id: string): Promise<{ deleted: boolean }> {
        const res = await this.oppModel.findByIdAndDelete(id);
        if (!res) throw new NotFoundException('Opportunity not found');
        return { deleted: true };
    }
}
