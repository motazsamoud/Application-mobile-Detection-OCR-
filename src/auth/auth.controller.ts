import { Controller, Post, Body, HttpException, HttpStatus } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,

  ) {}

  @Post('google-login')
  async googleLogin(@Body() body: any) {
    const { idToken, accessToken } = body;

    if (!idToken || !accessToken) {
      throw new HttpException('idToken ou accessToken manquant', HttpStatus.BAD_REQUEST);
    }

    // 1. Authentifie l’utilisateur avec le idToken
    const { token, user } = await this.authService.verifyGoogleToken(idToken);

    // 2. Récupère les données Google Fit avec accessToken


    return {
      token,
      user,
    };
  }
}
