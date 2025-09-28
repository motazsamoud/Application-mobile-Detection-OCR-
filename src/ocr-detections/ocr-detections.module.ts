import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { OcrDetection, OcrDetectionSchema } from './schemas/ocr-detection.schema';
import { OcrDetectionsService } from './ocr-detections.service';
import { OcrDetectionsController } from './ocr-detections.controller';

@Module({
    imports: [
        MongooseModule.forFeature([{ name: OcrDetection.name, schema: OcrDetectionSchema }]),
    ],
    controllers: [OcrDetectionsController],
    providers: [OcrDetectionsService],
    exports: [MongooseModule,
        OcrDetectionsService],  // Assurez-vous que le service est exporté
})
export class OcrDetectionsModule {}
