import { Controller, Get, Post, Body, Patch, Param, Delete , BadRequestException , Req , UseGuards, HttpException, HttpStatus} from '@nestjs/common';
import { UserService } from './user.service';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './jwt-auth/jwt-auth.guard';

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('signup')
  create(@Body() createUserDto: CreateUserDto) {
    return this.userService.create(createUserDto);
  }

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    return this.userService.login(loginDto);
  }

  @Post('send-otp')
  async sendOtp(@Body('email') email: string) {
    await this.userService.sendOtpToUser(email);
    return { message: 'OTP sent successfully' };
  }

  @Post('verify-otp')
async verifyOtp(@Body() body: { identifier: string; otp: string }) {
    const result = await this.userService.verifyOtp(body.identifier, body.otp);
    
    if (!result.success) {
        throw new BadRequestException(result.message);
    }

    return { message: result.message };
}

@UseGuards(JwtAuthGuard)
  @Post('logout')
  async logout(@Req() req: Request) {
    const token = req.headers['authorization']?.split(' ')[1]; // Correctly access authorization
    if (!token) {
      throw new BadRequestException('Token is required');
    }
    await this.userService.logout(token);
    return { message: 'Logged out successfully' };
  }

  @Post('resend-otp')
  async resendOtp(@Body('email') email: string) {
    await this.userService.resendOtp(email);
    return { message: 'OTP resent successfully' };
  }

  @Get('get')
  findAll() {
    return this.userService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.userService.findOne(id);
  }
  

  @Patch('update')
  update(@Body('id') id: string, @Body() updateUserDto: any) {
      console.log('[Update Controller] Received ID:', id);
      console.log('[Update Controller] Received Data:', updateUserDto);
      if (!id) {
        throw new BadRequestException('ID is required');
    }

      
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
async forgetPassword(@Body('email') email: string): Promise<{ message: string }> {
    await this.userService.forgetPassword(email);
    return { message: 'Password has been sent to your email.' };
}



  @Patch('update-password')
  async updatePassword(
    @Body('id') id: string,
    @Body('password') password: string,
  ) {
    console.log('[UserController] Received update-password request.');
    console.log('[UserController] User ID:', id);
    console.log('[UserController] New Password:', password);

    if (!id || !password) {
      console.log('[UserController] Missing required fields.');
      throw new BadRequestException('User ID and Password are required.');
    }

    return this.userService.updatePassword(id, password);
  }



}
