// MS Entra ID SSO — BFF Auth Route
// next-auth 또는 authlib 기반 구현 필요
// Browser → /api/auth/login → Entra ID → /api/auth/callback → JWT 세션

export async function GET() {
  return Response.json({ message: 'Auth route placeholder — implement SSO here' });
}
