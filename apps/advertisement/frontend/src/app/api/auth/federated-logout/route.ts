import { NextRequest, NextResponse } from 'next/server';
import { signOut } from '@/lib/auth';

export const dynamic = 'force-dynamic';

/**
 * 로그아웃 / 세션 만료 → 앱(NextAuth) 세션 쿠키 삭제 후 /login(SSO 로그인 페이지)으로 이동.
 *
 * NOTE: IdP(Entra) 세션까지 끊는 federated logout(.../oauth2/v2.0/logout) 은
 *   post_logout_redirect_uri 가 Entra App Registration 에 등록돼 있어야 /login 으로 되돌아온다.
 *   미등록 시 MS 로그아웃 화면에 머물러 "로그인 페이지로 안 넘어가는" 문제가 생기므로,
 *   여기서는 앱 세션만 종료하고 확실히 /login 으로 보낸다.
 *   (IdP 세션은 남아 다음 로그인 시 자격증명을 다시 안 물을 수 있음 — 필요 시 Entra 에
 *    Front-channel logout URL 로 {origin}/login 을 등록하고 end-session redirect 로 복원 가능.)
 */
export async function GET(request: NextRequest): Promise<Response> {
  await signOut({ redirect: false });
  const appBaseUrl = process.env.NEXTAUTH_URL || process.env.AUTH_URL || request.nextUrl.origin;
  const loginUrl = `${appBaseUrl.replace(/\/$/, '')}/login`;
  return NextResponse.redirect(loginUrl);
}
