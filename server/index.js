/**
 * Kisan Mitra — AI Chatbot Proxy Server
 *
 * Hides the OpenRouter API key server-side so users never need their own key.
 * Deploy on Render / Railway / Fly.io / any Node host.
 *
 * Environment variables:
 *   AI_PROVIDER     — 'gemini', 'openrouter', or 'groq' (default: gemini)
 *   AI_API_KEY      — your API key for the chosen provider (required)
 *   PORT            — server port (default 3000)
 *   ALLOWED_ORIGINS — comma-separated allowed origins (optional, for CORS)
 *   API_SECRET      — shared secret the Flutter app must send (optional but recommended)
 */

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const https = require('https');

const app = express();

// ─── Security ──────────────────────────────────────────────────────────────
app.use(helmet());
app.use(express.json({ limit: '50kb' }));

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((s) => s.trim())
  : [];

app.use(
  cors({
    origin: allowedOrigins.length > 0 ? allowedOrigins : true,
    methods: ['POST'],
  }),
);

// ─── Rate limiting ─────────────────────────────────────────────────────────
// Per-IP: max 20 requests per minute (enough for a farmer, blocks bots)
const chatLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_requests', retryAfterSeconds: 60 },
});

// Global: max 500 requests per 15 minutes across all users (budget guard)
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'server_busy', retryAfterSeconds: 900 },
});

// ─── Health check ──────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// ─── Chat endpoint ─────────────────────────────────────────────────────────
app.post('/v1/chat', globalLimiter, chatLimiter, async (req, res) => {
  const AI_PROVIDER = process.env.AI_PROVIDER || 'gemini';
  const AI_API_KEY = process.env.AI_API_KEY;
  if (!AI_API_KEY) {
    console.error('AI_API_KEY not set');
    return res.status(500).json({ error: 'server_config_error' });
  }

  // Optional shared-secret check
  const API_SECRET = process.env.API_SECRET;
  if (API_SECRET) {
    const provided = req.headers['x-api-secret'] || req.body?.secret;
    if (provided !== API_SECRET) {
      return res.status(403).json({ error: 'forbidden' });
    }
  }

  const { messages, model, temperature, max_tokens, top_p } = req.body;

  // Validate payload
  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'messages_required' });
  }

  // Provider config
  const providers = {
    gemini: {
      hostname: 'generativelanguage.googleapis.com',
      path: `/v1beta/openai/?key=${AI_API_KEY}`,
      defaultModel: 'gemini-2.0-flash',
      authStyle: 'query',
    },
    openrouter: {
      hostname: 'openrouter.ai',
      path: '/api/v1/chat/completions',
      defaultModel: 'google/gemini-2.5-flash',
      authStyle: 'bearer',
      extraHeaders: { 'X-Title': 'Kisan Mitra', 'HTTP-Referer': 'https://kisanmitra.app' },
    },
    groq: {
      hostname: 'api.groq.com',
      path: '/openai/v1/chat/completions',
      defaultModel: 'llama-3.3-70b-versatile',
      authStyle: 'bearer',
    },
  };

  const provider = providers[AI_PROVIDER];
  if (!provider) {
    return res.status(400).json({ error: 'unknown_provider', valid: Object.keys(providers) });
  }

  const payload = JSON.stringify({
    model: model || provider.defaultModel,
    messages,
    temperature: temperature ?? 0.4,
    max_tokens: Math.min(max_tokens ?? 300, 500),
    top_p: top_p ?? 0.9,
    stream: false,
  });

  const headers = { 'Content-Type': 'application/json' };
  if (provider.authStyle === 'bearer') {
    headers['Authorization'] = `Bearer ${AI_API_KEY}`;
  }
  if (provider.extraHeaders) {
    Object.assign(headers, provider.extraHeaders);
  }

  const options = {
    hostname: provider.hostname,
    path: provider.path,
    method: 'POST',
    headers,
  };

  try {
    const result = await proxyRequest(options, payload);

    if (result.statusCode !== 200) {
      console.error(`Provider returned ${result.statusCode}: ${result.body}`);
      return res.status(502).json({ error: 'upstream_error', status: result.statusCode });
    }

    const data = JSON.parse(result.body);
    const choices = data.choices;
    if (!choices || choices.length === 0) {
      return res.status(502).json({ error: 'no_choices' });
    }

    const content = choices[0]?.message?.content;
    if (!content || content.trim().length === 0) {
      return res.status(502).json({ error: 'empty_response' });
    }

    // Return only what the app needs — strip billing/usage metadata
    res.json({
      reply: content.trim(),
      model: data.model || 'unknown',
    });
  } catch (err) {
    console.error('Proxy error:', err.message);
    res.status(502).json({ error: 'proxy_error' });
  }
});

// ─── Simple HTTPS helper (no extra dependency) ─────────────────────────────
function proxyRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          body: Buffer.concat(chunks).toString(),
        });
      });
    });
    req.on('error', reject);
    req.setTimeout(30000, () => {
      req.destroy();
      reject(new Error('upstream_timeout'));
    });
    req.write(body);
    req.end();
  });
}

// ─── Start ─────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Kisan Mitra proxy running on port ${PORT}`);
});
