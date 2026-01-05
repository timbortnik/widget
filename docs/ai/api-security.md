# API Security for Commercial Use

## Current Setup (Non-Commercial)

Direct calls to Open-Meteo API from the app. No API key needed.

```
App → Open-Meteo API (free tier)
```

## Commercial Setup (Recommended)

Use a serverless proxy with Firebase App Check to protect API credentials.

```
App → Firebase App Check → Cloud Function → Open-Meteo API
                              (key here)
```

## Implementation Steps

### 1. Firebase Project Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize project
firebase init functions
```

### 2. Cloud Function (Proxy)

```javascript
// functions/index.js
const functions = require('firebase-functions');
const fetch = require('node-fetch');

exports.weather = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set('Access-Control-Allow-Origin', '*');

  const { lat, lon } = req.query;

  if (!lat || !lon) {
    return res.status(400).json({ error: 'Missing lat/lon' });
  }

  const API_KEY = process.env.OPENMETEO_KEY;
  const url = `https://customer-api.open-meteo.com/v1/forecast?apikey=${API_KEY}&latitude=${lat}&longitude=${lon}&hourly=temperature_2m,precipitation,cloud_cover&timezone=auto&past_hours=6&forecast_days=2`;

  try {
    const response = await fetch(url);
    const data = await response.json();

    // Cache for 15 minutes
    res.set('Cache-Control', 'public, max-age=900');
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch weather' });
  }
});
```

### 3. Store API Key as Secret

```bash
firebase functions:secrets:set OPENMETEO_KEY
# Enter your Open-Meteo API key when prompted
```

Update `functions/index.js`:
```javascript
exports.weather = functions
  .runWith({ secrets: ['OPENMETEO_KEY'] })
  .https.onRequest(async (req, res) => {
    // ...
  });
```

### 4. Deploy

```bash
firebase deploy --only functions
```

### 5. Enable App Check

**Firebase Console:**
1. Go to App Check section
2. Register app with Play Integrity (Android) / DeviceCheck (iOS)
3. Enforce App Check on the Cloud Function

**Flutter app:**
```dart
// pubspec.yaml
dependencies:
  firebase_core: ^latest
  firebase_app_check: ^latest

// main.dart
await Firebase.initializeApp();
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);
```

### 6. Update Weather Service

```dart
// lib/services/weather_service.dart
class WeatherService {
  static const String _baseUrl =
    'https://us-central1-YOUR_PROJECT.cloudfunctions.net/weather';

  Future<WeatherData> fetchWeather(double latitude, double longitude) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
    });

    final response = await http.get(uri);
    // ... rest unchanged
  }
}
```

## Rate Limiting (Optional)

Add to Cloud Function:

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 requests per minute per IP
  message: { error: 'Too many requests' },
});

// Apply to function
app.use(limiter);
```

## Cost Estimate

| Component | Free Tier | Paid |
|-----------|-----------|------|
| Firebase Functions | 2M calls/mo | $0.40/million |
| Open-Meteo Standard | - | $29/mo (1M calls) |
| Firebase App Check | Unlimited | Free |

**Break-even:** ~14 premium users/month at $2.99 covers $29 API cost.

## Security Layers

| Layer | Purpose |
|-------|---------|
| App Check | Verify requests from legitimate app |
| Rate limiting | Prevent abuse per IP |
| API key in secrets | Never exposed to client |
| HTTPS | Encrypted transport |

## Migration Checklist

- [ ] Create Firebase project
- [ ] Write and deploy Cloud Function
- [ ] Store Open-Meteo API key as secret
- [ ] Enable App Check in Firebase Console
- [ ] Add firebase_app_check to Flutter app
- [ ] Update weather_service.dart to use proxy
- [ ] Test on device
- [ ] Monitor usage in Firebase Console
