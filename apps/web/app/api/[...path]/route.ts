import { NextRequest } from 'next/server';
export const dynamic = 'force-dynamic';
async function proxy(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  if (!['GET', 'HEAD'].includes(request.method)) {
    const origin = request.headers.get('origin');
    if (origin && origin !== request.nextUrl.origin) return Response.json({ detail: 'Origine de requête refusée.' }, { status: 403 });
  }
  const target = new URL('/api/' + path.map(encodeURIComponent).join('/'), process.env.API_URL || 'http://127.0.0.1:8010');
  target.search = request.nextUrl.search;
  const headers = new Headers();
  for (const name of ['content-type', 'cookie', 'authorization', 'idempotency-key', 'x-csrf-token']) {
    const value = request.headers.get(name); if (value) headers.set(name, value);
  }
  try {
    const upstream = await fetch(target, { method: request.method, headers, body: ['GET', 'HEAD'].includes(request.method) ? undefined : await request.arrayBuffer(), cache: 'no-store', redirect: 'manual' });
    const responseHeaders = new Headers({ 'cache-control': 'no-store' });
    for (const name of ['content-type', 'content-disposition', 'x-request-id']) { const value = upstream.headers.get(name); if (value) responseHeaders.set(name, value); }
    for (const cookie of upstream.headers.getSetCookie()) responseHeaders.append('set-cookie', cookie);
    return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
  } catch { return Response.json({ detail: 'Le serveur scolaire est momentanément indisponible. Réessayez dans un instant.' }, { status: 503 }); }
}
export { proxy as GET, proxy as POST, proxy as PUT, proxy as PATCH, proxy as DELETE };
