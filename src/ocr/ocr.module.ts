import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { OcrController } from './ocr.controller';
import { OcrService } from './ocr.service';
import { OcrDetectionsModule } from '../ocr-detections/ocr-detections.module';

@Module({
    imports: [
        MulterModule.register({ dest: './uploads' }),
        OcrDetectionsModule, // pour injecter OcrDetectionsService dans le controller
    ],
    controllers: [OcrController],
    providers: [OcrService],
    exports: [OcrService],
})
export class OcrModule {}
