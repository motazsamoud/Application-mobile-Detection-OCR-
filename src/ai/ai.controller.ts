import {Body, Controller, Get, Post, Query, Res} from '@nestjs/common';
import { Response } from 'express';
import { AiService } from './ai.service';

@Controller('ai/opportunities')
export class AiController {
    constructor(private readonly ai: AiService) {}

    @Post('insights')
    async insights(@Body() body: { from?: string; to?: string; limit?: number }) {
        return this.ai.generateInsights(body.from, body.to, body.limit ?? 300);
    }
    @Get('report')
    async report(
        @Query('from') from?: string,
        @Query('to') to?: string,
        @Query('limit') limitStr?: string,
    ) {
        const limit = Number(limitStr ?? 300) || 300;
        return this.ai.generateInsights(from, to, limit);
    }

    // GET /ai/report.csv?from=...&to=...&limit=...
    @Get('report.csv')
    async reportCsv(
        @Query('from') from: string | undefined,
        @Query('to') to: string | undefined,
        @Query('limit') limitStr: string | undefined,
        @Res() res: Response,
    ) {
        const limit = Number(limitStr ?? 300) || 300;
        const { csv } = await this.ai.generateInsights(from, to, limit);
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', 'attachment; filename="opportunities.csv"');
        res.send(csv);
    }
}
