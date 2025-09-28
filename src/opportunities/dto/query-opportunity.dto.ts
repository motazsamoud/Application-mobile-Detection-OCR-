import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { PipelinePosition } from '../schemas/opportunity.schema';


export class QueryOpportunityDto {
    @ApiPropertyOptional({ enum: PipelinePosition })
    @IsOptional()
    @IsEnum(PipelinePosition)
    position?: PipelinePosition;


    @ApiPropertyOptional({ description: 'Recherche texte: title/company/fullName' })
    @IsOptional()
    @IsString()
    search?: string;


    @ApiPropertyOptional({ description: 'Tri, ex: -createdAt ou createdAt' })
    @IsOptional()
    @IsString()
    sort?: string;


    @ApiPropertyOptional({ default: 1 })
    @IsOptional()
    @IsInt()
    @Min(1)
    page?: number = 1;


    @ApiPropertyOptional({ default: 20 })
    @IsOptional()
    @IsInt()
    @Min(1)
    limit?: number = 20;
}