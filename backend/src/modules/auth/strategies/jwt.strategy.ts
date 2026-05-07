import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from '../auth.service';
import { AuthenticatedRequestUser } from '../interfaces/authenticated-request-user.interface';
import { JwtPayload } from '../interfaces/jwt-payload.interface';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly authService: AuthService
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET') ?? 'change-me-for-production'
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedRequestUser> {
    const session = await this.authService.getActiveSession(payload.sid);
    if (!session || session.userId !== payload.sub) {
      throw new UnauthorizedException('Session is no longer active');
    }

    await this.authService.touchSession(payload.sid);

    return {
      userId: payload.sub,
      sessionId: payload.sid,
      role: payload.role
    };
  }
}
