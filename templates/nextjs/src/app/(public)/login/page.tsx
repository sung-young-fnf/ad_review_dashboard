'use client';

import { signIn } from 'next-auth/react';

export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="w-full max-w-sm space-y-8 text-center">
        <div className="space-y-2">
          <h1 className="text-3xl font-bold tracking-tight">{{APP_NAME}}</h1>
          <p className="text-muted-foreground">Microsoft 계정으로 로그인하세요</p>
        </div>
        <button
          onClick={() => signIn('microsoft-entra-id', { callbackUrl: '/' })}
          className="w-full rounded-lg bg-primary px-6 py-3 text-primary-foreground font-medium hover:bg-primary/90 transition-colors"
        >
          Microsoft 계정으로 로그인
        </button>
      </div>
    </div>
  );
}
