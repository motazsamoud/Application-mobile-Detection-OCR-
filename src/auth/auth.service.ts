import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UserService } from 'src/user/user.service';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';

@Injectable()
export class AuthService {
  private oauthClient: OAuth2Client;

  constructor(
    private readonly userService: UserService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {
    // ✅ Initialise correctement ici
    this.oauthClient = new OAuth2Client(this.configService.get<string>('GOOGLE_CLIENT_ID'));
  }

  async verifyGoogleToken(idToken: string) {
    // ✅ Assure-toi que le client est bien initialisé
    if (!this.oauthClient) {
      throw new Error('OAuth2 client not initialized');
    }

    const ticket = await this.oauthClient.verifyIdToken({
      idToken,
      audience: this.configService.get<string>('GOOGLE_CLIENT_ID'),
    });

    const payload = ticket.getPayload();
    if (!payload || !payload.email) {
      throw new Error('Invalid Google token');
    }

    const email = payload.email;
    const username = payload.name || email.split('@')[0];

    let user = await this.userService.findByEmail(email);
    if (!user) {
      user = await this.userService.create({
        email,
        username,
        role: 'user',
        status: 'not verified',
      });
    }

    const token = this.jwtService.sign({ id: user._id });

    return { token, user };
  }
}