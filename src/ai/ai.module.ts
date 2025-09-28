import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { OpportunitiesModule } from '../opportunities/opportunities.module'; // déjà existant

@Module({
    imports: [OpportunitiesModule],
    controllers: [AiController],
    providers: [AiService],
})
export class AiModule {}
