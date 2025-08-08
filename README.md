# Songbook Flutter

Flutter app that loads songs from a GitHub Gist.

## How to use
1. Enter your **Gist ID** in the input field (from gist URL).
2. Press **Fetch** to load songs.
3. Songs are grouped by artist (part before ` - ` in filename).

## Build APK locally
```bash
flutter pub get
flutter build apk --release
```

## Build APK on GitHub
Push to main branch — GitHub Actions will build `app-release.apk` in workflow artifacts.
