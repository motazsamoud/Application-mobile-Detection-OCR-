import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { User } from './user.entity'; // Assurez-vous que ce chemin est correct
import { Role } from './Role.enum';

export type TokenDocument = Token & Document;

@Schema()
export class Token {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  user: Types.ObjectId;

  @Prop({ required: true })
  token: string;

  @Prop({ enum: Role, required: true })
    role: Role;
  
  @Prop({ required: true })
  expiresAt: Date;
}

export const TokenSchema = SchemaFactory.createForClass(Token);
