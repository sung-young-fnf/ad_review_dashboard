import NextAuth from 'next-auth';
import AzureAD from 'next-auth/providers/azure-ad';
import type { JWT } from 'next-auth/jwt';

// TypeScript 타입 확장
declare module 'next-auth' {
  interface Session {
    accessToken?: string;
    error?: string;
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    accessToken?: string;
    refreshToken?: string;
    accessTokenExpires?: number;
    error?: string;
  }
}

/**
 * Azure AD 토큰 갱신
 */
async function refreshAccessToken(token: JWT): Promise<JWT> {
  const tenantId = process.env.AZURE_AD_TENANT_ID;
  const url = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: process.env.AZURE_AD_CLIENT_ID!,
        client_secret: process.env.AZURE_AD_CLIENT_SECRET!,
        grant_type: 'refresh_token',
        refresh_token: token.refreshToken!,
        scope: 'openid profile email User.Read offline_access',
      }),
    });

    const tokens = await response.json();

    if (!response.ok) {
      console.error('Token refresh failed:', tokens.error_description);
      return { ...token, error: 'RefreshAccessTokenError' };
    }

    return {
      ...token,
      accessToken: tokens.id_token,
      refreshToken: tokens.refresh_token ?? token.refreshToken,
      accessTokenExpires: Date.now() + tokens.expires_in * 1000,
      error: undefined,
    };
  } catch (error) {
    console.error('Token refresh error:', error);
    return { ...token, error: 'RefreshAccessTokenError' };
  }
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  // ALB 등 리버스 프록시 뒤 host 신뢰 (signOut redirect /undefined 방지)
  trustHost: true,
  providers: [
    AzureAD({
      clientId: process.env.AZURE_AD_CLIENT_ID!,
      clientSecret: process.env.AZURE_AD_CLIENT_SECRET!,
      tenantId: process.env.AZURE_AD_TENANT_ID!,
      authorization: {
        params: {
          scope: 'openid profile email User.Read offline_access',
        },
      },
    }),
  ],
  callbacks: {
    // ALB(리버스 프록시) 뒤 — host 신뢰 (없으면 signOut redirect /undefined). SSO 모드 공통
    async redirect({ url, baseUrl }) {
      if (url.startsWith('/')) return `${baseUrl}${url}`;
      try { if (new URL(url).origin === baseUrl) return url; } catch { /* */ }
      return baseUrl;
    },
    // ── SSO email 흐름 (필독) ───────────────────────────────────────────
    // NextAuth(token.email) → session.user.email → BFF X-Auth-Email 헤더 → backend user
    // Entra(Azure AD) 는 표준 email claim 이 비어있는 경우가 많아(profile.email=null)
    // preferred_username / upn 을 fallback 으로 써야 email 이 backend 까지 흐른다.
    // 이 매핑을 빠뜨리면 backend 에서 사용자가 'unknown' 으로 잡힌다.
    async jwt({ token, account, profile }) {
      // 최초 로그인: account에서 토큰 추출 + 이메일 캡처
      if (account) {
        const p = (profile ?? {}) as { email?: string; preferred_username?: string; upn?: string };
        const email = p.email ?? p.preferred_username ?? p.upn ?? token.email ?? null;
        return {
          ...token,
          email,
          accessToken: account.id_token,
          refreshToken: account.refresh_token,
          accessTokenExpires: account.expires_at ? account.expires_at * 1000 : Date.now() + 3600000,
        };
      }

      // 토큰 만료 전: 기존 토큰 반환
      if (token.accessTokenExpires && Date.now() < token.accessTokenExpires - 60000) {
        return token;
      }

      // 토큰 만료: 리프레시
      return refreshAccessToken(token);
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken;
      session.error = token.error;
      // token.email → session.user.email (BFF 가 X-Auth-Email 로 backend 에 전달)
      if (session.user && token.email) {
        session.user.email = token.email as string;
      }
      return session;
    },
  },
  pages: {
    signIn: '/login',
  },
});
