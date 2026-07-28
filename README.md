# ParkPal

ParkPal is a standalone Circum company product for parking, loading, and roadside restriction intelligence.

Positioning: **Know before you park.**

This repository currently contains the Firebase database foundation and the first minimal MVP app shell. It does not include payments, subscriptions, AI interpretation, or Circum integration.

## What is included

- A basic ParkPal Flutter app shell.
- A manual "Can I park here?" location/road-name search flow.
- A parking result card with risk, confidence, time window, payment status, and evidence source.
- Firestore read/query logging service code with safe Unknown fallback.
- Firebase config pattern for Firestore, Storage, and local emulators.
- Strict draft Firestore security rules.
- Strict draft Firebase Storage rules.
- Firestore composite indexes for likely early queries.
- Dart model definitions for the planned Flutter app.
- Storage path constants for sign and report images.
- Environment config pattern using Dart compile-time values.
- Transparent London starter records for:
  - Kensington Road
  - Westminster loading bay
  - Camden permit zone
  - Red route example
  - School street example

## Firestore collections

| Collection | Purpose |
| --- | --- |
| `parkpal_signs` | Individual sign captures and interpreted restrictions. |
| `parkpal_roads` | Road/street-level parking and loading intelligence. |
| `parkpal_zones` | CPZs, permit zones, red routes, school streets, loading zones, bus lanes, and borough-wide rules. |
| `parkpal_reports` | User reports when rules or signs change. |
| `parkpal_contributors` | Pioneers, riders, admins, and public contributors. |
| `parkpal_queries` | User lookups for future product learning and analytics. |
| `parkpal_councils` | Council metadata and data-source tracking. |

## Storage paths

```text
parkpal/signs/{signId}/original.jpg
parkpal/signs/{signId}/thumb.jpg
parkpal/reports/{reportId}/photo.jpg
```

## Firebase setup

Install the Firebase CLI, then authenticate:

```sh
npm install -g firebase-tools
firebase login
```

Create a new Firebase project in the Firebase console, then connect this repo locally:

```sh
cp .firebaserc.example .firebaserc
firebase use --add
```

Replace the example project id in `.firebaserc` with the real ParkPal Firebase project id.

Enable these Firebase products:

- Authentication
- Firestore
- Storage
- Hosting later
- Functions later

Run local emulators after Firebase is connected:

```sh
firebase emulators:start
```

Deploy only after reviewing rules against the real Firebase project:

```sh
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Dart / Flutter setup

The model and MVP app shell are written for Flutter so they can be reused by the planned iOS, Android, and future web/admin surfaces.

When Flutter is installed, run:

```sh
flutter pub get
flutter analyze
flutter run
```

Try the starter-data flow with a road such as `Kensington Road` after the London starter records have been imported into the connected Firebase project.

Future app startup can pass environment values with:

```sh
flutter run \
  --dart-define=PARKPAL_ENV=dev \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com \
  --dart-define=FIREBASE_REGION=europe-west2
```

## Seed data

Seed records live in:

```text
firebase/seeds/london_seed.json
```

They are intentionally transparent ParkPal starter intelligence, not live council authority. They exist so the customer search/GPS flows can demonstrate confident answers for a small set of London examples while official D-TRO/council imports continue to expand Atlas.

To merge the starter records into the connected ParkPal project:

```sh
node tools/import_london_seed.js --project parkpal-prod
```

The importer is merge-only and does not delete existing records.

## Security model draft

- Public map intelligence can be read.
- Signed-in users can create pending sign captures and reports.
- Public users cannot verify signs.
- Public users cannot edit verified road intelligence.
- Contributors can update only their own pending submissions.
- Admins, via custom claims, can verify, reject, update, and delete.
- All unmatched paths deny reads and writes.

Expected admin claim:

```json
{
  "admin": true,
  "role": "admin"
}
```

Expected contributor role claims:

```json
{
  "role": "pioneer"
}
```

## Next setup steps

1. Create the GitHub repository and push this local foundation.
2. Create the ParkPal Firebase project.
3. Copy `.firebaserc.example` to `.firebaserc` and select the Firebase project.
4. Enable Auth, Firestore, and Storage.
5. Review security rules with real auth/custom-claim flows.
6. Add Firebase rules unit tests once the Firebase CLI and emulator tooling are installed.
7. Generate real FlutterFire options once the Flutter app shell exists.
8. Import starter data only when you need controlled ParkPal demo/test intelligence; authoritative records should come from D-TRO, council data, or verified field evidence.

## Not included yet

- Full mobile UI.
- Subscriptions or payments.
- AI / IRIS sign interpretation calls.
- Circum account or platform integration.
- Production deployment.
