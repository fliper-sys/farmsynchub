# FarmSync AI - free setup

AI chat, image review, farm briefing and finance recap all go through
`lib/core/services/gemini_service.dart`. A request tries these routes in order
and uses the first that returns text; if all fail the app shows offline guidance.

1. **Firebase AI Logic** (Gemini Developer API, free on the Spark plan). Needs
   the "Gemini Developer API" enabled for the Firebase project and App Check
   correctly set up.
2. **Gemini API key, main model**, then **lite model** (`GEMINI_API_KEY`).
   Free quotas are per model and per project, so the lite model often still
   works when the main one is rate limited.
3. **Optional OpenAI-compatible provider** (`AI_FALLBACK_*`), e.g. Groq,
   OpenRouter or Cloudflare Workers AI. Skipped when no key is set.

## Steps

1. Create a free key at https://aistudio.google.com/apikey (use a *new* Google
   Cloud project, not the Firebase one, so it has its own quota).
2. (Optional) Create a free key with Groq or OpenRouter. Pick a vision-capable
   model so photo review works. Model IDs change - check the provider's list.
3. Run or build with:

```
flutter run \
  --dart-define=GEMINI_API_KEY=your-aistudio-key \
  --dart-define=AI_FALLBACK_API_KEY=your-groq-or-openrouter-key \
  --dart-define=AI_FALLBACK_BASE_URL=https://api.groq.com/openai/v1 \
  --dart-define=AI_FALLBACK_MODEL=<vision model id>
```

Optional: `FIREBASE_AI_MODEL`, `GEMINI_LITE_MODEL`.

## Keys and security

Never commit a key (an earlier one was scraped and revoked). Keys passed with
`--dart-define` are still extractable from a shipped app. For a public release,
put the key in a small proxy (for example a free Cloudflare Worker) and set
`AI_FALLBACK_BASE_URL` to the proxy.

## Free-tier caveats

Limits change and are not guaranteed. Free tiers of Gemini, OpenRouter and
Mistral may use prompts to improve their products, so avoid sending private
farm finances through them if that matters to you.
