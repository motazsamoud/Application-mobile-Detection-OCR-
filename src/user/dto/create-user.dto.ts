/* eslint-disable prettier/prettier */
import {
  IsArray,
  IsNotEmpty,
  IsEmail,
  MinLength,
  IsString,
  IsDateString,
  IsOptional,
  IsEnum,

} from 'class-validator';
import { Role } from '../entities/Role.enum';
export class CreateUserDto {
  @IsEmail({}, { message: 'Please provide a valid email address' })
  @IsNotEmpty({ message: 'Email is required' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Password is required' })
  @MinLength(8, { message: 'Password must be at least 8 characters long' })
  password: string;

  @IsString()
  @IsNotEmpty({ message: 'Name is required' })
  username: string;

  @IsDateString({}, { message: 'Birthdate must be a valid date in ISO 8601 format' })
  @IsNotEmpty({ message: 'Birthdate is required' })
  dateOfBirth: string;

  @IsEnum(Role, { message: 'Invalid role selected' })
  @IsNotEmpty({ message: 'Role is required' })
  role: Role;
}
