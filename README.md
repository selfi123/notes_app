# Voicecard — Flutter App

A premium mobile app to save audio and text notes under your contacts.

## Setup

1. Run `flutter pub get`
2. Run `dart run build_runner build` to generate Hive adapters
3. Run `flutter run` to start the app

## Architecture

- **State:** Flutter Riverpod
- **Local DB:** Hive (offline-first)
- **Audio:** `record` + `just_audio`
- **Cloud:** Cloudflare R2 (S3-compatible via `minio_new`)
- **Payments:** Razorpay Flutter SDK
- **Navigation:** Go Router

## Environment Variables

All credentials are stored in `.env` (gitignored). Never commit `.env` to a public repository.

## Free vs Premium

| Feature | Free | Premium |
|---|---|---|
| Notes per contact | Unlimited | Unlimited |
| Total notes | Up to 50 | Unlimited |
| Storage | Local only | Local + Cloud (R2) |
| Multi-device sync | No | Yes |
| Price | Free | ₹99/mo or ₹799/yr |
