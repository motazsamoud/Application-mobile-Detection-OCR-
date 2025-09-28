import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiTags, ApiOkResponse, ApiCreatedResponse, ApiQuery } from '@nestjs/swagger';
import { OpportunitiesService } from './opportunities.service';
import { CreateOpportunityDto } from './dto/create-opportunity.dto';
import { UpdateOpportunityDto } from './dto/update-opportunity.dto';
import { QueryOpportunityDto } from './dto/query-opportunity.dto';


@ApiTags('opportunities')
@Controller('opportunities')
export class OpportunitiesController {
    constructor(private readonly service: OpportunitiesService) {}


    @Post()
    @ApiCreatedResponse({ description: 'Opportunity created' })
    create(@Body() dto: CreateOpportunityDto) {
        return this.service.create(dto);
    }


    @Get()
    @ApiOkResponse({ description: 'Paginated opportunities list' })
    @ApiQuery({ name: 'position', required: false, enum: ['new','contacted','qualified','won','lost'] })
    @ApiQuery({ name: 'search', required: false })
    @ApiQuery({ name: 'sort', required: false, description: 'ex: -createdAt' })
    @ApiQuery({ name: 'page', required: false, schema: { default: 1 } })
    @ApiQuery({ name: 'limit', required: false, schema: { default: 20 } })
    findAll(@Query() q: QueryOpportunityDto) {
        return this.service.findAll(q);
    }


    @Get(':id')
    @ApiOkResponse({ description: 'Opportunity detail' })
    findOne(@Param('id') id: string) {
        return this.service.findOne(id);
    }


    @Patch(':id')
    @ApiOkResponse({ description: 'Opportunity updated' })
    update(@Param('id') id: string, @Body() dto: UpdateOpportunityDto) {
        return this.service.update(id, dto);
    }


    @Delete(':id')
    @ApiOkResponse({ description: 'Opportunity deleted' })
    remove(@Param('id') id: string) {
        return this.service.remove(id);
    }
}