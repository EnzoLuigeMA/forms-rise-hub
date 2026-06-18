// Proxy server-side para a Meta Conversions API (CAPI).
// Mantém o META_ACCESS_TOKEN FORA do código client — ele é lido de variáveis
// de ambiente na Vercel. O client (index/lp/lp-trafego) faz POST aqui com o
// mesmo corpo `{ data: [ ... ] }` que antes ia direto pra Graph API.
//
// Env vars exigidas (Vercel → Settings → Environment Variables):
//   META_PIXEL_ID      ex: 2238173290034845
//   META_ACCESS_TOKEN  token da CAPI (de preferência um NOVO, após rotacionar o antigo)

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const PIXEL_ID = process.env.META_PIXEL_ID;
  const TOKEN = process.env.META_ACCESS_TOKEN;
  if (!PIXEL_ID || !TOKEN) {
    res.status(500).json({ error: 'Server not configured (missing META_PIXEL_ID / META_ACCESS_TOKEN)' });
    return;
  }

  try {
    // req.body já vem parseado quando Content-Type é application/json; aceita string também.
    const payload = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});

    const fbRes = await fetch(
      `https://graph.facebook.com/v21.0/${PIXEL_ID}/events?access_token=${TOKEN}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: payload }
    );

    const data = await fbRes.json().catch(() => ({}));
    res.status(fbRes.status).json(data);
  } catch (err) {
    res.status(502).json({ error: 'CAPI proxy failed', detail: err.message });
  }
};
