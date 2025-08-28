Release & QA checklist

1) Prepare signing (local/CI)
- Copy `gradle.properties.example` to your `~/.gradle/gradle.properties` and fill values, or set CI secrets with the same property names.

2) Build signed AAB (recommended for Play Store)
- Debug build: `./gradlew :app:assembleDebug`
- Release (signed if properties present): `./gradlew :app:bundleRelease` or `./gradlew :app:assembleRelease`

3) Run basic static checks
- Lint: `./gradlew :app:lint` (produces HTML report under `app/build/reports/lint-results.html`)
- Compile: `./gradlew :app:compileDebugKotlin`
- Run asset QA: `python3 scripts/check_assets.py`

4) Install and smoke-test on device/emulator
- Install APK (debug): `adb install -r app/build/outputs/apk/debug/app-debug.apk`
- For AAB use bundletool or upload to internal testing
- Test flows: open Materi, load images, Save-to-Downloads, Share, change language, check Settings preview.

5) Accessibility & localization
- Check contentDescription on images/icons.
- Verify all strings appear in Bahasa Indonesia by default.

6) Finalize Play Store
- Create release in Google Play Console, upload signed AAB, fill store listing, privacy, screenshots, and reviews.

Notes
- Do not commit your real keystore passwords; use environment/CI secrets.
- If resource shrinking removes locale resources, ensure `resourceConfigurations` includes needed locales (we already added id/jv/en).
