import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { OpportunitiesController } from './opportunities.controller';
import { OpportunitiesService } from './opportunities.service';
import { Opportunity, OpportunitySchema } from './schemas/opportunity.schema';
import { OcrDetectionsModule } from '../ocr-detections/ocr-detections.module';  // Assurez-vous que ce module est importé ici

@Module({
    imports: [
        MongooseModule.forFeature([
            { name: Opportunity.name, schema: OpportunitySchema },
        ]),
        OcrDetectionsModule,  // Important : Assurez-vous que OcrDetectionsModule est bien importé
    ],
    controllers: [OpportunitiesController],
    providers: [OpportunitiesService],
    exports: [OpportunitiesService], // ✅ important

})
export class OpportunitiesModule {}
