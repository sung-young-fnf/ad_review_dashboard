export { auth as middleware } from '@/lib/auth';

export const config = {
  matcher: [
    // 인증 필요 경로 (admin, 기타 authenticated 페이지)
    '/((?!api|_next/static|_next/image|favicon.ico|login|auth).*)',
  ],
};
