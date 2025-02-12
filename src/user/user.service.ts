/* eslint-disable prettier/prettier */
import {
  Injectable,
  NotFoundException,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { InjectModel ,  } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { LoginDto } from './dto/login.dto';
import { JwtService } from '@nestjs/jwt';
import { Token, TokenDocument } from './entities/Token.entity';
import { Response } from 'express';
import { Types, isValidObjectId } from 'mongoose';
import * as bcrypt from 'bcrypt';
import axios from 'axios';

@Injectable()
export class UserService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Token.name) private readonly tokenModel: Model<TokenDocument>,

    private readonly jwtService: JwtService,
  ) {}

  async create(createUserDto: any): Promise<User> {
    const existingUser = await this.userModel.findOne({ email: createUserDto.email }).exec();
    if (existingUser) {
      throw new BadRequestException('Email is already taken');
    }

    const hashedPassword = await bcrypt.hash(createUserDto.password, 10);
    const createdUser = new this.userModel({
      ...createUserDto,
      password: hashedPassword,
      dateOfBirth: new Date(createUserDto.dateOfBirth),
      role: createUserDto.role,  // Assurez-vous d'inclure le rôle ici
    });
    return createdUser.save();
  }


  async login(loginDto: LoginDto): Promise<{ access_token?: string; user?: Partial<User> }> {
    const { email, password } = loginDto;
    const user = await this.userModel.findOne({ $or: [{ email }, { username: email }] }).exec();
    console.log('Email:', email);
    console.log('Password:', password);
    
    if (!user || !(await bcrypt.compare(password, user.password))) {
      console.log('User not found');
      throw new BadRequestException('Invalid credentials');
    }
    const payload = {
      email: user.email,
      id: user._id,
      username: user.username,
      dateOfBirth: user.dateOfBirth,
      role: user.role  // Inclure le rôle dans les détails de l'utilisateur retournés

    };
    const access_token = this.jwtService.sign(payload, {
      expiresIn: '1h', // Set token expiration (1 hour in this example)
    });
  
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 1); // Token expires in 1 hour
  
    // Save the token to the database
    await this.tokenModel.create({
      userId: user._id,
      token: access_token,
      expiresAt,
    });
  
    // Return token and essential user details
    return { 
      access_token, 
      user: { 
        id: user._id, 
        username: user.username, 
        email: user.email,
        role: user.role  // Inclure le rôle dans les détails de l'utilisateur retournés
      } 

    };
  }
  

  async findAll(): Promise<User[]> {
    return this.userModel.find().exec();
  }

  async findOne(id: string): Promise<User> {
    if (!Types.ObjectId.isValid(id)) {
      throw new BadRequestException('Invalid user ID format');
    }
  
    const user = await this.userModel.findById(id).exec();
    if (!user) {
      throw new NotFoundException('User with this ID not found');
    }
    return user;
  }

  async findOneBy(username: string): Promise<{ id: string }> {
    const user = await this.userModel.findOne({ username }).exec();
    if (!user) {
      throw new NotFoundException('User with this username not found');
    }
    return { id: user.id.toString() };
  }

  async update(id: string, updateUserDto: any): Promise<any> {
    console.log('[UserService] Updating user with ID:', id);
    console.log('[UserService] Update Data:', updateUserDto);

    const existingUser = await this.userModel.findById(id).exec();
    if (!existingUser) {
        throw new NotFoundException('User not found');
    }

    // Si le champ `password` est absent ou vide, conserver l'ancien mot de passe
    if (!updateUserDto.password || updateUserDto.password.trim() === '') {
        delete updateUserDto.password; // Supprimez le champ pour éviter toute mise à jour
    } else {
        // Si le champ `password` est fourni, vérifiez qu'il s'agit d'une chaîne valide
        if (typeof updateUserDto.password !== 'string') {
            throw new BadRequestException('Password must be a string');
        }
        // Hachez le nouveau mot de passe
        updateUserDto.password = await bcrypt.hash(updateUserDto.password, 10);
    }

    // Si le champ `username` est vide, conservez l'ancien nom d'utilisateur
    if (!updateUserDto.username || updateUserDto.username.trim() === '') {
        updateUserDto.username = existingUser.username;
    }

    // Si le champ `preferences` est vide ou absent, conservez les préférences existantes
    
    const updatedUser = await this.userModel.findByIdAndUpdate(
      id,
      { $set: updateUserDto },
      { new: true, runValidators: true } // Retourne l'utilisateur mis à jour
  ).exec();
  if (!updatedUser) {
    throw new NotFoundException('User not found');
}
 // Email notification
 const emailData = {
  sender: { name: 'Esprit', email: 'amira.gharbi2505@gmail.com' },
  to: [{ email: updatedUser.email }],
  subject: 'Your Account Information Has Been Updated',
  htmlContent: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px; background-color: #f4f4f8;">
          <div style="text-align: center; margin-bottom: 20px;">
              <h1 style="color: #6a1b9a; font-size: 24px;">Account Update Successful</h1>
              <p style="color: #555;">Your account information has been successfully updated. If you did not make this change, please contact our support team immediately.</p>
          </div>
          
          <footer style="margin-top: 30px; text-align: center; color: #999; font-size: 12px;">
              <p>© 2024 Sante.</p>
              <p>123 Cosmic Avenue, Galaxy City</p>
          </footer>
      </div>
  `,
};

try {
  const response = await axios.post(
      'https://api.brevo.com/v3/smtp/email',
      emailData,
      {
          headers: {
              'Content-Type': 'application/json',
              'api-key': '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',
          },
      }
  );
  console.log(
      `[UserService] Notification email sent successfully to: ${updatedUser.email}`,
      JSON.stringify(response.data, null, 2)
  );
} catch (error) {
  console.error(
      '[UserService] Failed to send notification email:',
      error.response?.data || error.message
  );
}

    if (!updatedUser) {
        console.log('[UserService] User not found for ID:', id);
        throw new NotFoundException('User not found');
    }

    console.log('[UserService] Successfully updated user:', updatedUser);
    return updatedUser;
}


  

  async remove(id: string): Promise<User> {
    const deletedUser = await this.userModel.findByIdAndDelete(id).exec();
    if (!deletedUser) {
      throw new NotFoundException('User not found');
    }
    return deletedUser;
  }


  async forgetPassword(email: string): Promise<void> {
    const user = await this.userModel.findOne({ email }).exec();
    if (!user) {
        throw new NotFoundException('User not found');
    }

    // Generate a strong 20-character password
    const tempPassword = this.generateStrongPassword(10);
    const hashedTempPassword = await bcrypt.hash(tempPassword, 10);

    // Update user's password in the database
    user.password = hashedTempPassword;
    await user.save();

    // Prepare and send the email
    const brevoUrl = 'https://api.brevo.com/v3/smtp/email';
    const emailData = {
      sender: { name: 'Esprit', email: 'amira.gharbi2505@gmail.com' },
      to: [{ email }],
        subject: 'Your Sante Temporary Password',
        htmlContent: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px; background-color: #f4f4f8;">
                <div style="text-align: center; margin-bottom: 20px;">
                    <h1 style="color: #6a1b9a; font-size: 24px;">Your Sante Temporary Password</h1>
                    <p style="color: #555;">You requested to reset your password. Use the temporary password below to log in and reset your password immediately.</p>
                </div>
                <div style="text-align: center; margin-bottom: 20px;">
                    <h2 style="color: #6a1b9a; font-size: 20px;">Temporary Password:</h2>
                    <p style="font-size: 18px; font-weight: bold; color: #333;">${tempPassword}</p>
                    <p style="color: #555;">This password is temporary. Please change it after logging in.</p>
                </div>
                <div style="margin-top: 20px;">
                    <p style="color: #555; font-size: 14px; text-align: center;">If you did not request this email, please contact our support team immediately.</p>
                </div>
                
                <footer style="margin-top: 30px; text-align: center; color: #999; font-size: 12px;">
                    <p>© 2024 Sante.</p>
                    <p>123 Cosmic Avenue, Galaxy City</p>
                </footer>
            </div>
        `,
    };

    await axios.post(brevoUrl, emailData, {
        headers: {
            'Content-Type': 'application/json',
            'api-key': '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',
          },
    });

    console.log(`Temporary password sent to ${email}`);
}

// Private method to generate a strong password
private generateStrongPassword(length: number): string 
{
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const allChars = upper + lower + digits;

    let password = '';
    password += this.getRandomCharacter(upper);
    password += this.getRandomCharacter(lower);
    password += this.getRandomCharacter(digits);

    for (let i = 3; i < length; i++) {
        password += this.getRandomCharacter(allChars);
    }

    return this.shuffle(password);
}

// Helper method to get a random character from a string
private getRandomCharacter(chars: string): string {
    return chars[Math.floor(Math.random() * chars.length)];
}

// Helper method to shuffle the generated password
private shuffle(password: string): string {
    return password.split('').sort(() => Math.random() - 0.5).join('');
}

async validateToken(token: string): Promise<boolean> {
  const storedToken = await this.tokenModel.findOne({ token }).exec();
  if (!storedToken) {
    throw new NotFoundException('Token not found');
  }

  if (storedToken.expiresAt < new Date()) {
    throw new BadRequestException('Token expired');
  }

  return true;
}

async logout(token: string): Promise<void> {
  const result = await this.tokenModel.findOneAndDelete({ token }).exec();
  if (!result) {
    throw new NotFoundException('Token not found or already invalidated');
  }
  console.log(`Token invalidated for user: ${result.userId}`);
}
async fetchUserDetails(userId: string): Promise<User> {
  if (!isValidObjectId(userId)) {
    throw new BadRequestException('Invalid user ID');
  }

  const user = await this.userModel.findById(userId).exec();
  if (!user) {
    throw new NotFoundException('User not found');
  }

  return user;
}


async updatePassword(userId: string, newPassword: string): Promise<{ message: string }> {
  console.log('[UserService] Update Password called for User ID:', userId);

  const user = await this.userModel.findById(userId);
  if (!user) {
      console.log('[UserService] User not found.');
      throw new BadRequestException('User not found.');
  }

  const hashedNewPassword = await bcrypt.hash(newPassword, 10);
  console.log('[UserService] New password hashed.');

  user.password = hashedNewPassword;
  await user.save();
  console.log('[UserService] Password updated successfully.');

  const emailData = {
    sender: { name: 'Esprit', email: 'amira.gharbi2505@gmail.com' },
    to: [{ email: user.email }],
      subject: 'Password Updated Successfully',
      htmlContent: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px; background-color: #f4f4f8;">
              <div style="text-align: center; margin-bottom: 20px;">
                  <h1 style="color: #6a1b9a; font-size: 24px;">Your Password Has Been Updated</h1>
                  <p style="color: #555;">This is a confirmation that your password has been successfully updated.</p>
              </div>
              
              <footer style="margin-top: 30px; text-align: center; color: #999; font-size: 12px;">
                  <p>© 2024 sante.</p>
                  <p>123 Cosmic Avenue, Galaxy City</p>
              </footer>
          </div>
      `,
  };

  try {
      const response = await axios.post(
          'https://api.brevo.com/v3/smtp/email',
          emailData,
          {
              headers: {
                  'Content-Type': 'application/json',
                  'api-key': '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',
                },
          }
      );
      console.log(
          `[UserService] Notification email sent successfully to: ${user.email}`,
          response.data
      );
  } catch (error) {
      console.error(
          '[UserService] Failed to send notification email:',
          error.response?.data || error.message
      );
  }

  return { message: 'Password updated successfully.' };
}

async findByEmail(email: string): Promise<User | null> {
  return this.userModel.findOne({ email }).exec();  // Ensure this method returns the correct type
}



private isValidObjectId(id: string): boolean {
  const ObjectId = require('mongoose').Types.ObjectId;
  return ObjectId.isValid(id);
}


public async sendOtpToUser(email: string): Promise<void> {
  const user = await this.userModel.findOne({ email }).exec();
  if (!user) {
    throw new NotFoundException('User not found');
  }

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  user.otp = otp;
  user.otpExpires = new Date(Date.now() + 10 * 60 * 1000);
  await user.save();

  const brevoUrl = 'https://api.brevo.com/v3/smtp/email';
  const emailData = {
    sender: { name: 'Esprit', email: 'amira.gharbi2505@gmail.com' },
    to: [{ email }],
    subject: 'Your OTP for Verification',
    htmlContent: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px; background-color: #f4f4f8;">
        <div style="text-align: center; margin-bottom: 20px;">
          <h1 style="color: #6a1b9a; font-size: 24px;">Welcome </h1>
          <p style="color: #555;">Unlock the universe with us!</p>
        </div>
        <div style="text-align: center; margin-bottom: 20px;">
          <h2 style="color: #6a1b9a; font-size: 20px;">Your One-Time Password (OTP)</h2>
          <p style="font-size: 18px; font-weight: bold; color: #333;">${otp}</p>
          <p style="color: #555;">This code is valid for <strong>10 minutes</strong>.</p>
        </div>
        <div style="margin-top: 20px;">
          <p style="color: #555; font-size: 14px; text-align: center;">If you did not request this OTP, please ignore this email or contact our support team.</p>
        </div>
        
        <footer style="margin-top: 30px; text-align: center; color: #999; font-size: 12px;">
          <p>© 2024 sante.</p>
          <p>123 Cosmic Avenue, Galaxy City</p>
        </footer>
      </div>
    `,
  };

  try {
    const response = await axios.post(brevoUrl, emailData, {
      headers: {
        'Content-Type': 'application/json',
        'api-key': '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', // Remplacez par votre clé API Brevo
      },
    });
    console.log('Email sent successfully:', response.data);
  } catch (error) {
    console.error('Failed to send email:', error.response?.data || error.message);
    throw new Error('Email sending failed');
  }

}

async verifyOtp(identifier: string, otp: string): Promise<{ success: boolean; message: string }> {
  const user = await this.userModel.findOne({ email: identifier }).exec();

  if (!user) {
      console.warn('User not found during OTP verification');
      throw new NotFoundException('User not found');
  }

  if (user.otp !== otp || (user.otpExpires && user.otpExpires < new Date())) {
    console.warn(`Failed OTP verification for user: ${identifier}`);
    return { success: false, message: 'Invalid or expired OTP' };
  }

  user.status = 'verified';
  user.otp = null; // Assignez null au lieu de undefined
  user.otpExpires = null; // Assignez null au lieu de undefined  await user.save();

  console.log(`User ${identifier} successfully verified`);
  return { success: true, message: 'OTP verified successfully' };
}




async checkStatus(identifier: string): Promise<{ status: string }> {
  const user = await this.userModel.findOne({ email: identifier }).exec();

  if (!user) {
    throw new NotFoundException('User not found');
  }

  return { status: user.status };
}




  async resendOtp(email: string): Promise<void> {
    const user = await this.userModel.findOne({ email }).exec();
    if (!user) {
      throw new NotFoundException('User with this email not found');
    }

    const lastOtpSent = user.otpExpires
      ? new Date(user.otpExpires.getTime() - 10 * 60 * 1000)
      : null;
    if (lastOtpSent && new Date() < new Date(lastOtpSent.getTime() + 60 * 1000)) {
      throw new BadRequestException('You can only resend OTP after 60 seconds');
    }

    await this.sendOtpToUser(email);
  }

}
