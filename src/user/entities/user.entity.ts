/* eslint-disable prettier/prettier */
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Role } from './Role.enum';

export type UserDocument = User & Document;

@Schema()
export class User extends Document {
  @Prop({ required: true })
  email: string;

  @Prop({ required: true })
  password: string;

  @Prop({ required: true })
  username: string;

  @Prop({ required: true, type: Date })
  dateOfBirth: Date;

  @Prop({ default: 'not verified' })
  status: string;

  @Prop({ type: String, required: false })
  otp: string | null;

  @Prop({ type: Date, required: false })
  otpExpires: Date | null;

  @Prop({ enum: Role, required: true })
  role: Role;

  @Prop()
  tempPassword?: string;

  @Prop()
  tempPasswordExpires?: Date;




}

export const UserSchema = SchemaFactory.createForClass(User);
