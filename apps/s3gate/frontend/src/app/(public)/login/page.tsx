'use client';

import { signIn } from 'next-auth/react';

export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-sm space-y-6 text-center">
        <h1 className="text-3xl font-bold">s3gate</h1>
        <p className="text-gray-500">Microsoft 계정으로 로그인하세요</p>
        <button
          onClick={() => signIn('azure-ad', { callbackUrl: '/' })}
          className="w-full rounded-lg bg-blue-600 px-6 py-3 text-white font-medium hover:bg-blue-700"
        >
          Microsoft 계정으로 로그인
        </button>
      </div>
    </div>
  );
}
