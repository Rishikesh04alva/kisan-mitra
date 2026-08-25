# AI Chatbot — Free API Setup for Kisan Mitra

Your app already has a full AI chatbot built in (`llm_service.dart`).
It supports 3 free providers — pick **one** and follow the steps.

---

## Recommended: Google Gemini (FREE, best for Indian languages)

### Why Gemini
- **Completely free** — 15 requests/minute, 1 million tokens/day (more than enough)
- **No credit card** required
- Supports Hindi, Marathi, Kannada, Tamil, Telugu, Malayalam natively
- Fast responses (~1–2 seconds)

### Step 1: Get your free API key
1. Go to **https://aistudio.google.com/apikey**
2. Sign in with any Google account
3. Click **"Create API Key"**
4. Copy the key (starts with `AIza...`)

### Step 2: Build the APK with your key

```bash
flutter build apk --release \
  --dart-define=AI_PROVIDER=gemini \
  --dart-define=AI_API_KEY=AIzaSyD_YOUR_ACTUAL_KEY_HERE
```

That's it. The APK will have the AI chatbot working out of the box.

### Step 3: Or let users enter their own key
If you don't want to hardcode the key, skip the `--dart-define=AI_API_KEY` step.
The app has a **settings sheet** in the chatbot screen where users can paste
their own Gemini key. It's saved locally on their phone.

```bash
# Build without hardcoded key — users enter it in-app
flutter build apk --release
```

---

## Alternative 1: Groq (FREE, fastest)

- Free tier: 30 requests/minute, very fast (Llama 3.3 70B)
- Get key: https://console.groq.com/keys (no credit card)
- Model: `llama-3.3-70b-versatile`

```bash
flutter build apk --release \
  --dart-define=AI_PROVIDER=groq \
  --dart-define=AI_API_KEY=gsk_your_groq_key_here
```

## Alternative 2: OpenRouter (FREE tier available)

- Some free models available (Llama 3.1, Mistral)
- Get key: https://openrouter.ai/keys
- Model: `google/gemini-2.5-flash` (or any model you prefer)

```bash
flutter build apk --release \
  --dart-define=AI_PROVIDER=openrouter \
  --dart-define=AI_API_KEY=sk-or-v1_your_key_here
```

---

## Production: Use a Backend Proxy (recommended for public release)

If you ship this to thousands of users, don't embed API keys in the APK.
Instead, deploy a small Cloudflare Worker / Vercel Edge Function that holds
the key server-side. Your app calls the proxy, the proxy calls Gemini.

```bash
flutter build apk --release \
  --dart-define=AI_PROVIDER=proxy \
  --dart-define=PROXY_URL=https://your-worker.workers.dev \
  --dart-define=API_SECRET=your_secret_string
```

The proxy endpoint should:
1. Receive `POST /v1/chat` with `{model, messages, temperature, max_tokens}`
2. Validate `X-Api-Secret` header
3. Forward to Gemini/Groq API
4. Return `{reply: "..."}`

---

## How the chatbot works in the app

```
User types question
        ↓
Local intent engine matches (greeting, fertilizer, weather, etc.)
        ↓
  Match found?  → Yes → Localized reply (works offline)
        ↓ No
  AI key set?   → Yes → Call Gemini/Groq API → AI reply
        ↓ No
  "Sorry, I can't help with that yet. Set up an AI key in settings."
```

The AI gets context about the farmer's:
- Planted crops (from tracker)
- Current weather (from weather API)
- Latest leaf scan result (from scanner)

This makes replies much more relevant than a generic chatbot.

---

## Quick start (copy-paste)

```bash
# 1. Get free key from https://aistudio.google.com/apikey

# 2. Build
cd C:\kisan-mitra
flutter build apk --release --split-per-abi \
  --dart-define=AI_PROVIDER=gemini \
  --dart-define=AI_API_KEY=PASTE_YOUR_KEY_HERE

# 3. APKs are in build/app/outputs/flutter-apk/
```
