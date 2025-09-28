import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type OpportunityDocument = Opportunity & Document;

export enum PipelinePosition {
    NEW = 'new',
    CONTACTED = 'contacted',
    QUALIFIED = 'qualified',
    WON = 'won',
    LOST = 'lost',
}

@Schema({ _id: true, timestamps: true, versionKey: false })
export class Opportunity {
    _id: Types.ObjectId;

    @Prop({ type: Types.ObjectId, ref: 'OcrDetection', required: false, index: true })
    ocrDetectionId?: Types.ObjectId;

    @Prop({ type: String, required: true, trim: true })
    title: string;

    @Prop({
        type: String,
        enum: Object.values(PipelinePosition),
        default: PipelinePosition.NEW,
        index: true,
    })
    position: PipelinePosition;

    @Prop({ type: Number, min: 0, required: false })
    amount?: number;

    @Prop({ type: String, default: 'TND' })
    currency: string;

    // Contact
    @Prop({ type: String, trim: true })
    fullName?: string;

    @Prop({ type: String, trim: true })
    company?: string;

    @Prop({ type: String, trim: true, lowercase: true })
    email?: string;

    @Prop({ type: String, trim: true })
    phone?: string;

    @Prop({ type: String, trim: true })
    jobTitle?: string; // poste de la personne

    @Prop({ type: String, trim: true })
    address?: string;

    @Prop({ type: String, trim: true })
    website?: string;

    @Prop({ type: Date, required: false })
    dueDate?: Date;

    @Prop({ type: [String], default: [], index: true })
    tags: string[];

    @Prop({ type: Date })
    createdAt: Date;

    @Prop({ type: Date })
    updatedAt: Date;
}

export const OpportunitySchema = SchemaFactory.createForClass(Opportunity);

// ➜ L'index doit être DÉHORS de la classe, après la création du schema :
OpportunitySchema.index({ title: 'text', company: 'text', fullName: 'text' });
