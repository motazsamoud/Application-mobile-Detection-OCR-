import { PartialType } from '@nestjs/mapped-types';
import { CreateUserDto } from './create-user.dto';
import { IsNumber, IsOptional, IsString, IsDateString } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateUserDto extends PartialType(CreateUserDto) {
  @IsOptional()
  @IsString()
  username?: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({}, { message: 'Phone number must be a number' })
  numeroTelephone?: number;

  @IsOptional()
  @IsDateString({}, { message: 'Date must be in ISO 8601 format' })
  dateOfBirth?: string;
}
