# Nexus

Nexus is a Flutter recipe app that turns available ingredients into recipes,
recognizes ingredients from camera images, and syncs saved recipes with
Firebase.

## Requirements

- Flutter SDK and Dart
- Node.js 20 or newer for the AI server
- Android Studio and an Android device or emulator
- A Firebase project with Authentication and Firestore enabled
- A Gemini API key for recipe generation and camera recognition

## Run The App

From the repository root:

```powershell
flutter pub get
flutter run
```

Without an AI endpoint, the app uses its built-in offline recipe generator.

## Local AI Server

The server keeps `GEMINI_API_KEY` out of the Flutter app. Create the local
environment file and set the key directly in it:

```powershell
cd server
Copy-Item .env.example .env
# Edit .env and set GEMINI_API_KEY
npm install
$env:PORT = '8081'
$env:HOST = '0.0.0.0'
npm start
```

The server exposes `GET /health`, `POST /recipes`, and `POST /recognize`.

## Camera AI Over USB

With the local server running on port `8081`, connect an Android phone with USB
debugging enabled:

```powershell
adb devices
adb reverse tcp:8081 tcp:8081
flutter run -d <android-device-id> `
  --dart-define=AI_RECIPE_ENDPOINT=http://127.0.0.1:8081/recipes `
  --dart-define=AI_RECOGNIZE_ENDPOINT=http://127.0.0.1:8081/recognize
```

`adb reverse` lets the phone reach the development computer through
`127.0.0.1`. In VS Code, use **Nexus local development (USB)** after starting
the server and running the reverse command.

For Wi-Fi development, replace `127.0.0.1` with the computer's local IPv4
address:

```powershell
flutter run `
  --dart-define=AI_RECIPE_ENDPOINT=http://192.168.1.10:8081/recipes `
  --dart-define=AI_RECOGNIZE_ENDPOINT=http://192.168.1.10:8081/recognize
```

## Firebase

Firebase Authentication and Firestore store accounts and saved recipes. Each
user's recipes are stored at:

```text
users/{firebase-auth-uid}/recipes/{recipe-id}
```

Email/password and Google sign-in use the Firebase Auth UID, so Google users'
recipes are stored in the same secure per-user collection. The app repairs a
missing user profile when a session is restored or a recipe is read or saved.

Enable these Firebase Authentication providers:

- Email/Password
- Google

For Android Google sign-in, add debug and release SHA-1/SHA-256 certificates
to the Firebase Android app. Deploy Firestore rules with:

```powershell
npx firebase-tools login
npx firebase-tools deploy --only firestore:rules --project leftoverlab-76ed0
```

The admin dashboard uses a Firestore collection-group query for all recipe
subcollections. Admin access requires the Firebase custom claim `admin: true`
or `role: admin` and the deployed rules in `firestore.rules`.

## Firebase AI Function

`functions/index.js` provides the same `/recipes` and `/recognize` routes as the
local server. Deployment requires the Blaze plan, an active billing account,
and the `GEMINI_API_KEY` Firebase secret:

```powershell
npm --prefix functions install
npx firebase-tools functions:secrets:set GEMINI_API_KEY --project leftoverlab-76ed0
npx firebase-tools deploy --only functions:api --project leftoverlab-76ed0
```

The deployed API base URL is:

```text
https://us-central1-leftoverlab-76ed0.cloudfunctions.net/api
```

Launch against Firebase with:

```powershell
flutter run `
  --dart-define=AI_RECIPE_ENDPOINT=https://us-central1-leftoverlab-76ed0.cloudfunctions.net/api/recipes `
  --dart-define=AI_RECOGNIZE_ENDPOINT=https://us-central1-leftoverlab-76ed0.cloudfunctions.net/api/recognize
```

Never commit `.env` files, Gemini keys, or other credentials.

## Tests And Analysis

```powershell
dart analyze
flutter test
```
