#!/usr/bin/env bash
set -euo pipefail

# Config (override with env vars when calling)
API_BASE_URL="${API_BASE_URL:-https://api.example.com}"
WS_BASE_URL="${WS_BASE_URL:-wss://api.example.com}"
ANDROID_DIR="${ANDROID_DIR:-android}"
IOS_DIR="${IOS_DIR:-ios}"
WEB_DIR="${WEB_DIR:-.}"

SKIP_ANDROID="${SKIP_ANDROID:-0}"   # set to 1 to skip
SKIP_IOS="${SKIP_IOS:-0}"           # set to 1 to skip
SKIP_WEB="${SKIP_WEB:-0}"           # set to 1 to skip

echo "=== Security Checks (shell) ==="
echo "Android dir: $ANDROID_DIR"
echo "iOS dir:     $IOS_DIR"
echo "Web dir:     $WEB_DIR"
echo "API:         $API_BASE_URL"
echo "WS:          $WS_BASE_URL"

# ---------- Android ----------
if [ "$SKIP_ANDROID" != "1" ]; then
  echo -e "\n[Android] Build release and validate manifest..."
  pushd "$ANDROID_DIR" >/dev/null

  ./gradlew clean :app:assembleRelease

  APK=$(ls app/build/outputs/apk/release/app-release*.apk | head -n1)
  if [ -z "${APK:-}" ]; then
    echo "Release APK not found. Check Gradle output." >&2
    exit 1
  fi

  # Resolve apkanalyzer
  if command -v apkanalyzer >/dev/null 2>&1; then
    APKA="apkanalyzer"
  else
    APKA="${ANDROID_SDK_ROOT:-$ANDROID_HOME}/cmdline-tools/latest/bin/apkanalyzer"
  fi
  if [ ! -x "$APKA" ] && ! command -v apkanalyzer >/dev/null 2>&1; then
    echo "apkanalyzer not found; ensure Android SDK cmdline-tools are installed and ANDROID_HOME/ANDROID_SDK_ROOT is set." >&2
    exit 1
  fi

  "$APKA" manifest print "$APK" > manifest_release.xml

  grep -E 'usesCleartextTraffic="false"' manifest_release.xml >/dev/null || { echo "usesCleartextTraffic must be false"; exit 1; }
  grep -E 'allowBackup="false"'          manifest_release.xml >/dev/null || { echo "allowBackup must be false"; exit 1; }
  grep -E 'debuggable="false"'           manifest_release.xml >/dev/null || { echo "debuggable must be false"; exit 1; }

  echo "[Android] Lint gates..."
  ./gradlew :app:lintRelease :app:lintVitalRelease

  test -f app/build/outputs/mapping/release/mapping.txt || { echo "R8 mapping.txt not found; ensure minifyEnabled/shrinkResources true"; exit 1; }

  popd >/dev/null
  echo "[Android] OK."
else
  echo "[Android] Skipped."
fi

# ---------- iOS ----------
if [ "$SKIP_IOS" != "1" ]; then
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "[iOS] Skipped (requires macOS)."
  else
    echo -e "\n[iOS] Archive and ATS check..."
    pushd "$IOS_DIR" >/dev/null

    pod install --repo-update
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -archivePath build/Runner.xcarchive clean archive

    PLIST="build/Runner.xcarchive/Products/Applications/Runner.app/Info.plist"
    if [ -f "$PLIST" ]; then
      if /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" "$PLIST" >/dev/null 2>&1; then
        VAL=$(/usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" "$PLIST")
        [ "$VAL" = "true" ] && { echo "ATS weak (NSAllowsArbitraryLoads=true)"; exit 1; }
      fi
    else
      echo "Warning: Info.plist not found in archive bundle; verify archive path."
    fi

    # Optional privacy strings presence (informational)
    BASE_PLIST="Runner/Info.plist"
    if [ -f "$BASE_PLIST" ]; then
      /usr/libexec/PlistBuddy -c "Print :NSCameraUsageDescription" "$BASE_PLIST" >/dev/null 2>&1 || echo "Info: NSCameraUsageDescription missing (add if camera used)."
      /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$BASE_PLIST" >/dev/null 2>&1 || echo "Info: NSMicrophoneUsageDescription missing (add if mic used)."
      /usr/libexec/PlistBuddy -c "Print :NSPhotoLibraryUsageDescription" "$BASE_PLIST" >/dev/null 2>&1 || echo "Info: NSPhotoLibraryUsageDescription missing (add if Photos used)."
    fi

    popd >/dev/null
    echo "[iOS] OK."
  fi
else
  echo "[iOS] Skipped."
fi

# ---------- Web ----------
if [ "$SKIP_WEB" != "1" ]; then
  echo -e "\n[Web] Build release (no SW caching) and validate CSP..."
  pushd "$WEB_DIR" >/dev/null

  flutter clean
  flutter build web --release --pwa-strategy=none \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=WS_BASE_URL="$WS_BASE_URL"

  INDEX="build/web/index.html"
  [ -f "$INDEX" ] || { echo "index.html missing in build output"; exit 1; }

  # CSP present
  grep -qiE '<meta[^>]+http-equiv="Content-Security-Policy"' "$INDEX" || { echo "CSP meta tag missing"; exit 1; }
  # No wildcards
  ! grep -qiE "default-src[^;]*\*" "$INDEX" || { echo "CSP default-src has *"; exit 1; }
  ! grep -qiE "connect-src[^;]*\*" "$INDEX" || { echo "CSP connect-src has *"; exit 1; }
  # No unsafe-eval
  ! grep -qi "unsafe-eval" "$INDEX" || { echo "CSP contains unsafe-eval"; exit 1; }
  # Block embedding
  grep -qiE "frame-ancestors 'none'" "$INDEX" || { echo "CSP missing frame-ancestors 'none'"; exit 1; }
  # Force https/wss
  ! grep -qiE "connect-src[^;]*http://" "$INDEX" || { echo "CSP allows http:// in connect-src"; exit 1; }
  ! grep -qiE "connect-src[^;]*ws://" "$INDEX"   || { echo "CSP allows ws:// in connect-src"; exit 1; }

  # Warn if SW file still exists (PWA disabled should remove it, but some hosts keep it around)
  if [ -f build/web/flutter_service_worker.js ]; then
    echo "Warning: flutter_service_worker.js present. Ensure it never caches API/auth responses."
  fi

  # No .env artifacts shipped
  if find build/web -type f -iname ".env*" | grep -q .; then
    echo "Build contains .env-like files; remove them." >&2
    exit 1
  fi

  popd >/dev/null
  echo "[Web] OK."
else
  echo "[Web] Skipped."
fi

echo -e "\nAll selected checks passed."
