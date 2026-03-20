# Nutri-Sense

A Flutter app that uses AI to analyze food photos and show dish name, nutrition (calories, protein, carbs, fat, fiber), and how to make the dish.

## API keys (`assets/.env`)

The app reads secrets from **`assets/.env`** (loaded in `lib/main.dart`). That file is **gitignored** — do not commit real keys.

1. Copy `assets/.env.example` to **`assets/.env`** (or copy from `.env.example` in the repo root — same variables).
2. Add your keys as `KEY=value` lines (no quotes).

### Food scan (Google Gemini)

1. Get a key: [Google AI Studio](https://aistudio.google.com/apikey)
2. In `assets/.env`, set: `GEMINI_API_KEY=your_key_here`
3. Run the app and use Camera or Gallery to scan a meal.

Without a key, the scan will show an error asking you to add `GEMINI_API_KEY`.

### Find nutritionists (Google Places API)

The “Find nutritionists near you” feature uses the **Google Places API** (Web Service). Your Google Cloud “Maps” API key usually works if **Places API** is enabled on the same project.

1. Open [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Library** → enable **Places API**.
2. **Credentials** → **Create credentials** → **API key** (optionally restrict it to Places).
3. In `assets/.env`, set: `GOOGLE_PLACES_API_KEY=your_key_here`
4. Restart the app (hot restart may be enough after changing `.env`).

Without this key, the app falls back to free OpenStreetMap data, which may not match Google Maps results.

### Location search (OpenCage Geocoder)

The nutritionist screen can use **[OpenCage](https://opencagedata.com/)** for address autocomplete (similar to the `fetch(\`...opencagedata.com...\`)` web snippet): type **3+ characters**, debounced requests, results biased toward **Pakistan** (`countrycode=pk`).

1. Create an API key in your OpenCage account.
2. In `assets/.env`, set: `OPENCAGE_API_KEY=your_key_here`
3. Optional: `OPENCAGE_GEOCODE_BIAS=Lahore, Pakistan` (default in code) or e.g. `Pakistan` for a wider bias.
4. Restart the app.

**Security:** never commit real keys. If a key was shared in chat or checked into git, **rotate it** in the OpenCage dashboard.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
