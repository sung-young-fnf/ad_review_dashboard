import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Module({
  providers: [
    // 글로벌 인증 가드 — 모든 엔드포인트에 적용
    // @Public()으로 제외 가능
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
  exports: [],
})
export class AuthModule {}
