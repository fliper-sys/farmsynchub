# Making "Ask AI", photo review and AI summaries work (free)

FarmSyncHub tries these routes in order and uses the first that answers:

1. **Firebase AI Logic** (Gemini through your Firebase project).
2. **Gemini API key** (direct call to Google, no Firebase/App Check involved).
3. **Free OpenAI-compatible route** (OpenRouter free models by default).
4. **Offline farm guidance** (built in; used only if all of the above fail).

Routes 1 to 3 cover the AI Advisor chat, the **photo/image review** (a photo
attached in the advisor), farm insight summaries and the finance AI recap.

If "Ask AI" shows offline guidance, no live route is working. The quickest
fix is a free Gemini key (route 2), optionally with a free backup (route 3).

## Route 2: free Gemini key (recommended, understands photos)

1. Open <https://aistudio.google.com/apikey> and create a key (no card needed).
2. Restrict the key in Google Cloud Console: *APIs & Services → Credentials →
   your key → API restrictions → Generative Language API*, and add an
   application restriction (Android package + SHA-1, or HTTP referrers for web).
3. Build or run with the key:

   ```
   flutter run --dart-define=GEMINI_API_KEY=your-key
   flutter build apk --dart-define=GEMINI_API_KEY=your-key
   flutter build web --dart-define=GEMINI_API_KEY=your-key
   ```

Optional: `--dart-define=FIREBASE_AI_MODEL=gemini-flash-latest` (the default).

## Route 3: free backup (OpenRouter)

1. Create a free key at <https://openrouter.ai/keys> (no card needed).
2. Add it to the build:

   ```
   --dart-define=AI_FREE_API_KEY=your-openrouter-key
   ```

   Defaults: `AI_FREE_MODEL=openrouter/free` and
   `AI_FREE_BASE_URL=https://openrouter.ai/api/v1`.
3. For photo review on this route, pick a free model that accepts images from
   the OpenRouter model list (filter by "free" and "image input") and pass it:

   ```
   --dart-define=AI_FREE_VISION_MODEL=<model-id>
   ```

   If you do not set it, photos are sent to `AI_FREE_MODEL`; if that model
   cannot read images the call fails and the app falls back to offline advice.

Any other OpenAI-compatible service also works (for example Groq): set
`AI_FREE_BASE_URL`, `AI_FREE_API_KEY` and `AI_FREE_MODEL` to its values.

Combine both: `--dart-define=GEMINI_API_KEY=... --dart-define=AI_FREE_API_KEY=...`

## Route 1: Firebase AI Logic checklist

- In the Firebase console open *Build → AI Logic* and enable the **Gemini
  Developer API** for the project.
- Make sure App Check is registered for each platform (Play Integrity on
  Android, DeviceCheck/App Attest on iOS, reCAPTCHA on web) or its enforcement
  for AI Logic is off while testing.
- Check the model name still exists (`gemini-flash-latest` is an alias).

## Things to know

- **Free tiers have limits.** They change over time, so check each provider's
  current limits (as reported in late 2026: OpenRouter `:free` models about 20
  requests per minute and 50 per day without credits; Gemini and Groq free
  limits are shown in their dashboards). When a limit is hit the app tries the
  next route, then falls back to offline advice.
- **Privacy.** On free tiers providers may use prompts to improve their
  products. The finance recap and farm insight send farm names, crops and
  transaction summaries. Do not use free routes if that is not acceptable, or
  switch to a paid plan.
- **Keys inside an app can be extracted.** A `--dart-define` key is compiled
  into the app, so restrict it (see above) and rotate it if it leaks. Never
  commit a key. The safest design is a small server (for example a Firebase
  Cloud Function, which needs the paid Blaze plan) that holds the key and
  calls the AI for the app.
