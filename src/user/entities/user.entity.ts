/* eslint-disable prettier/prettier */
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { Role } from './Role.enum';  // Assurez-vous d'importer l'énumération Role

export type UserDocument = User & Document;

@Schema()
export class User extends Document {
  @Prop({ required: true, unique: true })
  email: string;

  @Prop({ required: true })
  password: string;

  @Prop({ required: true })
  username: string;

  @Prop({ required: true, type: Date })
  dateOfBirth: Date;

  @Prop({ default: 'not verified' })
  status: string;

  @Prop({ type: String, required: false }) // Optional OTP field
  otp: string | null; // Permet de gérer les valeurs null

  // Ajouter explicitement le type `Date` pour otpExpires
  @Prop({ type: Date, required: false }) // OTP expiration
  otpExpires: Date | null; // Permet de gérer les valeurs null

  @Prop({ enum: Role, required: true })
  role: Role;  // Utilisation de l'énumération Role pour le type

}

export const UserSchema = SchemaFactory.createForClass(User);
