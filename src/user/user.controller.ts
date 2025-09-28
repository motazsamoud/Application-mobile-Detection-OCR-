import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  BadRequestException,
  Req,
  UseGuards,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { UserService } from './user.service';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './jwt-auth/jwt-auth.guard';
import { User } from './entities/user.entity';
import { Request } from 'express';
import { Types } from 'mongoose';

@Controller('user')
export class UserController {

  constructor(private readonly userService: UserService) {}
  @Get('get')
  async findAllUsers() {
    return this.userService.findAllUsers();
  }

  @Post('signup')
  create(@Body() createUserDto: CreateUserDto) {
    return this.userService.create(createUserDto);
  }

  @Get('find-by-email/:email')
  async findByEmail(@Param('email') email: string) {
    const user = await this.userService.findByEmaill(email);
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    return this.userService.login(loginDto);
  }



  // ⚠️ À garder EN DERNIER
  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.userService.findOne(id);
  }
  @Post('send-otp')
  async sendOtp(@Body('email') email: string) {
    await this.userService.sendOtpToUser(email);
    return { message: 'OTP sent successfully' };
  }

  @Post('verify-otp')
  async verifyOtp(@Body() body: { identifier: string; otp: string; sendTemporaryPassword?: boolean }) {
    const { identifier, otp, sendTemporaryPassword = false } = body;
    const result = await this.userService.verifyOtp(identifier, otp, sendTemporaryPassword);
    if (!result.success) throw new BadRequestException(result.message);
    return { message: result.message };
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  async logout(@Req() req: Request) {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) throw new BadRequestException('Token is required');
    await this.userService.logout(token);
    return { message: 'Logged out successfully' };
  }

  @Post('resend-otp')
  async resendOtp(@Body('email') email: string) {
    await this.userService.resendOtp(email);
    return { message: 'OTP resent successfully' };
  }


  @Patch('update')
  update(@Body('id') id: string, @Body() updateUserDto: any) {
    if (!id) throw new BadRequestException('ID is required');
    return this.userService.update(id, updateUserDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.userService.remove(id);
  }

  @Post('status')
  async checkStatus(@Body('identifier') identifier: string) {
    return this.userService.checkStatus(identifier);
  }

  @Post('forget-password')
  async forgetPassword(@Body('email') email: string) {
    await this.userService.forgetPassword(email);
    return { message: '✅ Temporary password sent to email.' };
  }

  @Post('verify-temp-password')
  async verifyTempPassword(@Body('email') email: string, @Body('tempPassword') tempPassword: string) {
    const isValid = await this.userService.verifyTempPassword(email, tempPassword);
    if (!isValid) throw new BadRequestException('Invalid temporary password');
    return { success: true, message: 'Temporary password is valid.' };
  }

  // Remplace l'endpoint actuel update-password par :

  @Patch('update-password')
  async updatePassword(@Body('id') idOrEmail: string, @Body('password') password: string) {
    if (!idOrEmail || !password) {
      throw new BadRequestException('User ID/Email and Password are required.');
    }
    return this.userService.updatePassword(idOrEmail, password);
  }


  @Post('verify-diploma')
  async verifyDiploma(@Body() body: { imageBase64: string; lang: string }) {
    return this.userService.verifyDiploma(body.imageBase64, body.lang);
  }














  @Post(':id')
  async findById(@Param('id') id: string): Promise<User> {
    return this.userService.findByIdOrThrow(id);
  }


}
