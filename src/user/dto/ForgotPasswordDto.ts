/* eslint-disable prettier/prettier */
// src/user/dto/forgot-password.dto.ts
import { IsNotEmpty } from 'class-validator';

export class ForgotPasswordDto {
  // @IsEmail({}, { message: 'Please provide a valid email address' })
  @IsNotEmpty({ message: 'Email is required' })
  email: string;
}
