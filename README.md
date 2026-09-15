# nexus

## Cloud AI recipes

The app calls a backend endpoint when `AI_RECIPE_ENDPOINT` is supplied. Keep
the model API key on that backend, never in the Flutter application.

The endpoint accepts:

```json
{"ingredients":["Rice","Eggs","Spinach"]}
```

and returns:

```json
{
	"title":"Green Egg Rice",
	"subtitle":"A quick bowl built from your pantry.",
	"time":"15 min",
	"steps":["...", "...", "...", "..."]
}
```

Ingredient recognition uses the same backend and Gemini key. If the recipe URL
ends in `/recipes`, the app automatically uses its sibling `/recognize` route.
An explicit recognition URL can also be supplied:

```powershell
flutter run `
	--dart-define=AI_RECIPE_ENDPOINT=http://192.168.1.10:8081/recipes `
	--dart-define=AI_RECOGNIZE_ENDPOINT=http://192.168.1.10:8081/recognize
```

The camera sends a compressed image to `/recognize`; the backend returns
`{"ingredients":["Tomatoes","Onion"]}`. Those items are added to the
selected ingredient list and are used by the normal recipe generator.

### Use the cloud backend on a physical Android phone

The repository includes a Firebase HTTPS deployment as well as the optional
Cloud Run deployment below. Firebase is the simplest route for this project:

The Firebase project must be upgraded to the Blaze plan first because HTTPS
Functions and Secret Manager are not available on the Spark plan. Upgrade it
at the Firebase usage page, then run:

```powershell
npx firebase-tools functions:secrets:set GEMINI_API_KEY --project leftoverlab-76ed0
npx firebase-tools deploy --only functions --project leftoverlab-76ed0
```

Type the Gemini key directly into the secret prompt. The deployed API URL is:
`https://us-central1-leftoverlab-76ed0.cloudfunctions.net/api`. Set that URL in
`NEXUS_AI_ENDPOINT` only when launching manually; the checked-in cloud Android
launch profile already points to this URL.

Deploy the `server/` folder to Cloud Run. The Gemini key stays in Cloud Run and
is never included in the Android app. From the repository root, install and
authenticate the Google Cloud CLI, then run:

```powershell
gcloud auth login
gcloud config set project leftoverlab-76ed0
gcloud run deploy nexus-recipe-api `
	--source server `
	--region us-central1 `
	--allow-unauthenticated `
	--set-env-vars GEMINI_MODEL=gemini-2.5-flash `
	--set-env-vars GEMINI_API_KEY=YOUR_GEMINI_KEY
```

Copy the HTTPS URL printed by Cloud Run and set it once in PowerShell:

```powershell
$env:NEXUS_AI_ENDPOINT = "https://YOUR_SERVICE_URL.run.app"
```

Then connect the Android phone normally with Flutter or use the VS Code
profile **Nexus Android phone + Cloud AI**. No USB port forwarding is needed;
the phone calls the cloud `/recipes` and `/recognize` endpoints directly.

For a release APK, pass the same cloud URL when building:

```powershell
flutter build apk --release `
	--dart-define=AI_RECIPE_ENDPOINT=https://YOUR_SERVICE_URL.run.app/recipes
```

The app automatically derives `/recognize` from the `/recipes` URL. You can
override it with `AI_RECOGNIZE_ENDPOINT` if the routes are hosted separately.

Run the app against any already deployed function or service with:

```powershell
flutter run --dart-define=AI_RECIPE_ENDPOINT=https://your-service.example.com/recipes
```

If the endpoint is omitted or unavailable, the app generates an offline recipe
instead.

### Deploy the included backend

The `server/` folder contains a Node.js API that keeps `GEMINI_API_KEY` on the
server. For local testing:

```powershell
cd server
Copy-Item .env.example .env
# Edit .env and set GEMINI_API_KEY to your Gemini key
npm install
npm start
```

In a second terminal:

```powershell
flutter run --dart-define=AI_RECIPE_ENDPOINT=http://localhost:8081/recipes
```

For local USB development only, reverse the API port before launching. The
phone can then use `127.0.0.1` because Android forwards that port to this
computer:

```powershell
adb reverse tcp:8081 tcp:8081
flutter run -d <android-device-id> `
	--dart-define=AI_RECIPE_ENDPOINT=http://127.0.0.1:8081/recipes
```

In VS Code, use **Nexus Flutter + local AI server** after running `adb reverse`.
For Wi-Fi, use the computer's IPv4 address instead of `127.0.0.1`; the checked-
in launch profile uses the current development address `10.84.237.96`.

For a physical Android phone connected to the same Wi-Fi, find this PC's IPv4
address with `ipconfig`, then use that address instead of `localhost`:

```powershell
flutter run --dart-define=AI_RECIPE_ENDPOINT=http://192.168.1.10:8081/recipes
```

Allow the development port through Windows Firewall once if the phone cannot
connect:

```powershell
New-NetFirewallRule -DisplayName "Nexus Recipe API" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow
```

For Google Cloud Run, from the `server` folder:

```powershell
gcloud run deploy nexus-recipe-api --source . --region us-central1 --allow-unauthenticated --set-env-vars GEMINI_MODEL=gemini-2.5-flash --set-env-vars GEMINI_API_KEY=YOUR_NEW_KEY
```

Use the service URL printed by Cloud Run as `AI_RECIPE_ENDPOINT`. For
production, prefer a secret manager instead of passing the key directly in
the deploy command.

### Firebase accounts, recipe history, and live admin insights

Firebase Authentication and Firestore are the only account and history store.
Saved recipes live at `users/{uid}/recipes`; the admin dashboard listens to
Firestore snapshots, so its metrics update immediately as users and recipes
change. To grant dashboard access, set the Firebase custom claim `admin: true`
(or `role: admin`) on the administrator�s Auth user, then have them sign in
again. Deploy `firestore.rules` before using admin insights.

The Node service is only a Gemini proxy. It keeps `GEMINI_API_KEY` private and
returns the requested-language recipe plus an AI-generated tutorial search
query. The app opens that query as a YouTube search rather than trusting an
AI-invented third-party URL.
## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android debug build

## Firebase authentication and Firestore

The Android Firebase project for this app is `leftoverlab-76ed0`. The checked-in
Firestore rules let an authenticated user create and access only their own
`users/{uid}` profile and `users/{uid}/recipes` history. This covers both
email/password registration and Google sign-in because both flows create a
Firebase Auth user before writing to Firestore.

In the Firebase console for this project, enable these providers under
**Authentication > Sign-in method**:

- Email/Password
- Google

For Google sign-in on Android, add the SHA-1 (and preferably SHA-256) of every
debug/release signing certificate to the Android app with package name
`com.example.nexus`, then download the updated `google-services.json` into
`android/app/`.

Deploy the included rules after signing in to the Firebase CLI:

```powershell
npx firebase-tools@latest login
npx firebase-tools@latest deploy --only firestore:rules --project leftoverlab-76ed0
```

Do not use test-mode rules in production: they would let unrelated users read
or change other users' saved recipes.

For a physical device, replace the example IP with this PC's current Wi-Fi IPv4 address. Firebase Authentication and Firestore handle login and recipe history.

```powershell
flutter build apk --debug `
  --dart-define=AI_RECIPE_ENDPOINT=http://192.168.1.10:8081/recipes `
 
```
