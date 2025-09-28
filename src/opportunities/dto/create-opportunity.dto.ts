import { ApiPropertyOptional } from '@nestjs/swagger';
import {
    IsArray,
    ArrayMaxSize,
    IsDateString,
    IsEnum,
    IsMongoId,
    IsNumber,
    IsOptional,
    IsString,
} from 'class-validator';
import { PipelinePosition } from '../schemas/opportunity.schema';

export class CreateOpportunityDto {
    @ApiPropertyOptional({ description: 'Si fourni, pré-remplit depuis la détection OCR' })
    @IsOptional()
    @IsMongoId()
    ocrDetectionId?: string;

    @ApiPropertyOptional({ description: 'Titre explicite, sinon auto depuis OCR' })
    @IsOptional()
    @IsString()
    title?: string;

    @ApiPropertyOptional({ enum: PipelinePosition, default: PipelinePosition.NEW })
    @IsOptional()
    @IsEnum(PipelinePosition)
    position?: PipelinePosition;

    @ApiPropertyOptional({ example: 1200 })
    @IsOptional()
    @IsNumber()
    amount?: number;

    @ApiPropertyOptional({ example: 'TND' })
    @IsOptional()
    @IsString()
    currency?: string;

    // Contact
    @ApiPropertyOptional({ example: 'John Doe' })
    @IsOptional()
    @IsString()
    fullName?: string;

    @ApiPropertyOptional({ example: 'Companyname' })
    @IsOptional()
    @IsString()
    company?: string;

    @ApiPropertyOptional({ example: 'john@company.com' })
    @IsOptional()
    @IsString()
    email?: string;

    @ApiPropertyOptional({ example: '+216 55 555 555' })
    @IsOptional()
    @IsString()
    phone?: string;

    @ApiPropertyOptional({ example: 'CEO & Founder' })
    @IsOptional()
    @IsString()
    jobTitle?: string;

    @ApiPropertyOptional({ example: 'Q Street, City, Country' })
    @IsOptional()
    @IsString()
    address?: string;

    @ApiPropertyOptional({ example: 'www.company.com' })
    @IsOptional()
    @IsString()
    website?: string;

    @ApiPropertyOptional({ example: '2025-10-01' })
    @IsOptional()
    @IsDateString()
    dueDate?: string;

    @ApiPropertyOptional({ type: [String], example: ['priority', 'expo'] })
    @IsOptional()
    @IsArray()
    @ArrayMaxSize(20)
    tags?: string[];
}
