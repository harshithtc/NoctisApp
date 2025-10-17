# Release & Security Checklist for NoctisApp (Android)

This file documents steps to prepare and produce a Play Store-ready Android APK/AAB.

## 1) Signing

- Preferred: provide `android/key.properties` (not committed) with keys:

  - storeFile=/path/to/keystore.jks
  - storePassword=...
  - keyAlias=...
  - keyPassword=...

- CI alternative: set these environment variables in your CI:

  - KEYSTORE_PATH (path to .jks on the runner)
  - KEYSTORE_PASSWORD
  - KEY_ALIAS
  - KEY_PASSWORD

- The Gradle script will fall back to `debug` signing if no release signing is found. Do NOT use debug-signed artifacts for Play Store uploads.

## 2) ProGuard / R8

- Release builds enable minification and resource shrinking.
- `app/proguard-rules.pro` contains rules to keep Flutter/Kotlin runtime and common plugin reflection usages.
- Verify third-party libraries that rely on reflection and add keep rules as needed.

## 3) Network & Security

- `AndroidManifest.xml` references `network_security_config.xml` to disallow cleartext traffic.
- Ensure your backend endpoints use TLS with strong ciphers and valid certificates.
- Remove any debug trust anchors or `debug-overrides` before publishing.

## 4) Privacy & Permissions

- Include only required permissions in the manifest and explain them in privacy policy.
- Provide `NSCameraUsageDescription` etc. for iOS (already present in `ios/Runner/Info.plist`).

## 5) Lint & ABI

- Lint is configured to `abortOnError` for release; fix all lint issues before release.
- Confirm `minSdk` is set correctly in `app/build.gradle.kts` (uses Flutter's minSdk) and `targetSdk` is at least 34.

## 6) Vulnerability checks

- Run dependency audits for native and Dart packages:
  - For Dart: `dart pub outdated --mode=null-safety` and `dart pub audit` (3rd-party tools)
  - For Android: run `./gradlew dependencies` and check for known CVEs in critical libs (OkHttp, Gson, etc.)

## 7) Final build commands (local)

```powershell
cd frontend
# regenerate wrapper if needed (this will download Gradle 9.x)
.\gradlew wrapper --gradle-version 9.5
.\gradlew assembleRelease --no-daemon
```

## 8) CI recommendations

- Use reproducible build runners with JDK 17+ (or Java 21 if you have validated it) matching AGP requirements.
- Store keystore as a secure secret or in artifact storage; inject at build time.
- Run `./gradlew lint` and `./gradlew test` in CI before publishing.

## 9) Post-release

- Monitor Play Console for security warnings and address them promptly.
- Keep dependencies up to date; apply security patches and re-run the build pipeline.

\*\*\* End of checklist

## CI secrets & GitHub Actions signing (how to set up)

This project includes a GitHub Actions workflow at `.github/workflows/android-ci.yml` that will build, lint and produce a release APK. To enable signing in CI you should set the following secrets in your repository settings (Settings → Secrets → Actions):

- `KEYSTORE_BASE64` — the base64-encoded contents of your release keystore (`.jks`).
- `KEYSTORE_PASSWORD` — the keystore password.
- `KEY_ALIAS` — the alias of the key inside the keystore.
- `KEY_PASSWORD` — the key password.

How to produce `KEYSTORE_BASE64` locally (PowerShell):

```powershell
# From the folder containing your release.jks
$path = 'C:\path\to\release.jks'
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
$b64 | Out-File -Encoding ascii keystore.base64.txt
# Copy the contents of keystore.base64.txt and paste into the GitHub secret field for KEYSTORE_BASE64
```

Or using a POSIX shell (macOS / Linux):

```bash
# base64 encode the keystore and copy it to the clipboard
base64 -w0 release.jks | pbcopy   # macOS (pbcopy)
# or on Linux
base64 -w0 release.jks > keystore.base64.txt
# then paste the file contents into the KEYSTORE_BASE64 secret
```

What the workflow does with these secrets

- The workflow will decode `KEYSTORE_BASE64` and write `frontend/android/keystore/release.jks`.
- It will create `frontend/android/key.properties` from the other secrets and Gradle will pick it up during signing.

Security notes

- Keep the keystore secret; do not commit key files or passwords to the repository.
- Use GitHub repository or organization secrets with least privilege.
- Rotate the key store passwords if a secret is ever exposed; follow Play Console guidance for key rotation if you need to update the signing key.

Troubleshooting

- If CI fails to find the keystore, check that `KEYSTORE_BASE64` is set and not truncated. The workflow expects the full base64 string.
- The workflow runs `./gradlew wrapper --gradle-version 9.4.2` in CI so the runner will download the Gradle distribution; if your org blocks external downloads, provide the distribution via a mirror configured in Gradle settings.

\*\*\* End of CI signing instructions
