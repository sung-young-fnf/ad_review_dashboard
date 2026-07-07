import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/lib/auth';

export const dynamic = 'force-dynamic';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8000';
const BODY_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

type RouteContext = { params: Promise<{ path: string[] }> };

/**
 * BFF Catch-All Proxy
 *
 * Browser → /api/v1/{path} → Next.js Proxy → Backend (BACKEND_URL)
 *
 * - 모든 HTTP 메서드 (GET/POST/PUT/PATCH/DELETE)
 * - SSE 스트리밍 ReadableStream 직접 전달
 * - 서버사이드 인증: session.accessToken → Bearer 토큰
 * - Query params 그대로 전달
 */
async function proxyRequest(
  request: NextRequest,
  context: RouteContext,
  method: string,
): Promise<Response> {
  try {
    const session = await auth();

    if (session?.error === 'RefreshAccessTokenError') {
      return NextResponse.json(
        { error: 'Session expired. Please re-login.', code: 'TOKEN_REFRESH_FAILED' },
        { status: 401 },
      );
    }

    if (!session?.accessToken) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { path } = await context.params;
    const pathStr = path.join('/');
    const query = request.nextUrl.searchParams.toString();
    const url = `${BACKEND_URL}/api/${pathStr}${query ? `?${query}` : ''}`;

    const headers = new Headers();
    headers.set('Authorization', `Bearer ${session.accessToken}`);
    // SSO email 흐름: session.user.email → X-Auth-Email 헤더로 backend 전달.
    // (NextAuth jwt/session callback 에서 Entra email(preferred_username/upn fallback)을
    //  token.email→session.user.email 로 매핑해야 여기서 값이 채워진다. 누락 시 backend 가
    //  사용자를 'unknown' 으로 잡으므로, backend 는 빈 값/unknown 이면 거부하도록 구현할 것.)
    if (session.user?.email) headers.set('X-Auth-Email', session.user.email);

    const contentType = request.headers.get('content-type');
    if (contentType) headers.set('Content-Type', contentType);

    const accept = request.headers.get('accept');
    if (accept) headers.set('Accept', accept);

    let body: ArrayBuffer | undefined;
    if (BODY_METHODS.has(method)) {
      body = await request.arrayBuffer();
    }

    const response = await fetch(url, { method, headers, body });

    // SSE 스트리밍: ReadableStream 직접 전달
    if (response.headers.get('content-type')?.includes('text/event-stream') && response.body) {
      return new Response(response.body, {
        status: response.status,
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      });
    }

    // JSON 응답
    const data = await response.arrayBuffer();
    return new NextResponse(data, {
      status: response.status,
      headers: { 'Content-Type': response.headers.get('content-type') || 'application/json' },
    });
  } catch (error) {
    console.error(`[BFF Proxy] ${method} /${(await context.params).path.join('/')}:`, error);
    return NextResponse.json({ error: 'Backend unavailable' }, { status: 502 });
  }
}

export const GET = (req: NextRequest, ctx: RouteContext) => proxyRequest(req, ctx, 'GET');
export const POST = (req: NextRequest, ctx: RouteContext) => proxyRequest(req, ctx, 'POST');
export const PUT = (req: NextRequest, ctx: RouteContext) => proxyRequest(req, ctx, 'PUT');
export const PATCH = (req: NextRequest, ctx: RouteContext) => proxyRequest(req, ctx, 'PATCH');
export const DELETE = (req: NextRequest, ctx: RouteContext) => proxyRequest(req, ctx, 'DELETE');
