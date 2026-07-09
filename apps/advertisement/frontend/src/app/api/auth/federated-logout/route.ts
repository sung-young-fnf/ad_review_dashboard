import { NextRequest, NextResponse } from 'next/server';
import { signOut } from '@/lib/auth';

export const dynamic = 'force-dynamic';

/**
 * Federated Logout (MS Entra SSO)
 *
 * WHY: NextAuth signOut() 은 앱(NextAuth) 세션 쿠키만 지운다. Entra(IdP) 의 SSO 세션은
 * 그대로 남아 있어서, 로그아웃 후 다시 로그인 버튼을 누르면 IdP 가 자격증명을 묻지 않고
 * 곧바로 재로그인되어 버린다("로그아웃이 안 되는 것처럼" 보임). 이를 막으려면 앱 세션 종료 +
 * IdP 의 end-session endpoint(.../oauth2/v2.0/logout) 로 redirect 해서 IdP 세션까지 끊어야 한다.
 *
 * 흐름: 사이드바 로그아웃 → GET /api/auth/federated-logout
 *   1) signOut({ redirect: false }) 로 NextAuth 세션 쿠키 삭제
 *   2) Entra logout endpoint 로 302 redirect (post_logout_redirect_uri = appBaseUrl + /login)
 *
 * 주의:
 * - tenantId 는 기존 env(AZURE_AD_TENANT_ID) 재사용 — 하드코딩 금지.
 * - post_logout_redirect_uri 는 Entra App Registration 의 "Front-channel logout URL" 또는
 *   허용된 redirect 목록에 등록돼 있어야 IdP 가 그 주소로 되돌려준다. (미등록 시 IdP 기본 화면에 머무름)
 * - auth-none 모드의 signOut 은 no-op 이므로 이 route 가 호출될 일이 없다(SSO 전용 UI 흐름).
 *   혹시 호출돼도 tenantId 미설정이면 그냥 /login 으로 보낸다.
 */
export async function GET(request: NextRequest): Promise<Response> {
  // 1) 앱(NextAuth) 세션 종료 — 쿠키 삭제. redirect 는 우리가 직접 한다.
  await signOut({ redirect: false });

  // appBaseUrl: 프록시(ALB) 뒤에서도 정확한 외부 origin 을 쓰도록 env 우선, 없으면 요청 origin.
  const appBaseUrl =
    process.env.NEXTAUTH_URL || process.env.AUTH_URL || request.nextUrl.origin;
  const loginUrl = `${appBaseUrl.replace(/\/$/, '')}/login`;

  const tenantId = process.env.AZURE_AD_TENANT_ID;
  if (!tenantId) {
    // SSO 미구성 — IdP 로그아웃 생략하고 앱 로그인 페이지로.
    return NextResponse.redirect(loginUrl);
  }

  // 2) Entra end-session endpoint 로 redirect → IdP SSO 세션까지 종료.
  const entraLogout = new URL(
    `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/logout`,
  );
  entraLogout.searchParams.set('post_logout_redirect_uri', loginUrl);

  return NextResponse.redirect(entraLogout.toString());
}
