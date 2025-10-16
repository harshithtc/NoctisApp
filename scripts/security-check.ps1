Param(
  [string]$ApiBaseUrl = "https://api.example.com",
  [string]$WsBaseUrl  = "wss://api.example.com",
  [string]$AndroidDir = "android",
  [string]$IosDir     = "ios",
  [string]$WebDir     = ".",
  [switch]$SkipAndroid,
  [switch]$SkipIOS,
  [switch]$SkipWeb
)

$ErrorActionPreference = "Stop"
Write-Host "=== Security Checks (PowerShell) ==="
Write-Host "Android dir: $AndroidDir"
Write-Host "iOS dir:     $IosDir"
Write-Host "Web dir:     $WebDir"
Write-Host "API:         $ApiBaseUrl"
Write-Host "WS:          $WsBaseUrl"

function Resolve-ApkAnalyzer {
  $candidates = @(
    "$env:ANDROID_HOME\cmdline-tools\latest\bin\apkanalyzer.bat",
    "$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin\apkanalyzer.bat"
  ) | Where-Object { $_ -and (Test-Path $_) }
  if ($candidates.Count -eq 0) {
    if (Get-Command apkanalyzer -ErrorAction SilentlyContinue) { return "apkanalyzer" }
    throw "apkanalyzer not found. Set ANDROID_HOME/ANDROID_SDK_ROOT and install cmdline-tools."
  }
  return $candidates[0]
}
function Require-Match($File, $Pattern, $Message) {
  if (-not (Select-String -Path $File -Pattern $Pattern)) { throw $Message }
}

# ---------- Android ----------
if (-not $SkipAndroid) {
  Write-Host "`n[Android] Build release and validate manifest..."
  if (-not (Test-Path $AndroidDir)) { throw "Android dir '$AndroidDir' not found." }
  Push-Location $AndroidDir
  ./gradlew.bat clean :app:assembleRelease

  $apk = (Get-ChildItem .\app\build\outputs\apk\release\app-release*.apk -ErrorAction SilentlyContinue | Select-Object -First 1)
  if (-not $apk) { throw "Release APK not found. Check Gradle output." }

  $an = Resolve-ApkAnalyzer
  & $an manifest print $apk.FullName > manifest_release.xml

  Require-Match "manifest_release.xml" 'usesCleartextTraffic="false"' 'usesCleartextTraffic must be false'
  Require-Match "manifest_release.xml" 'allowBackup="false"'        'allowBackup must be false'
  Require-Match "manifest_release.xml" 'debuggable="false"'         'debuggable must be false'

  Write-Host "[Android] Lint gates..."
  ./gradlew.bat :app:lintRelease :app:lintVitalRelease

  if (-not (Test-Path .\app\build\outputs\mapping\release\mapping.txt)) {
    throw "R8 mapping.txt not found; ensure minifyEnabled/shrinkResources true"
  }
  Pop-Location
  Write-Host "[Android] OK."
} else { Write-Host "[Android] Skipped." }

# ---------- iOS ----------
if (-not $SkipIOS) {
  if ($IsWindows) {
    Write-Warning "[iOS] Skipped (requires macOS)."
  } else {
    Write-Host "`n[iOS] Archive and ATS check..."
    if (-not (Test-Path $IosDir)) { throw "iOS dir '$IosDir' not found." }
    Push-Location $IosDir
    pod install --repo-update
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -archivePath build/Runner.xcarchive clean archive

    $plist = "build/Runner.xcarchive/Products/Applications/Runner.app/Info.plist"
    if (Test-Path $plist) {
      & /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" $plist 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        $val = (& /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" $plist)
        if ($val -eq "true") { throw "ATS weak (NSAllowsArbitraryLoads=true)" }
      }
    } else {
      Write-Warning "Info.plist missing in archive; verify archive path."
    }
    Pop-Location
    Write-Host "[iOS] OK (or check warnings)."
  }
} else { Write-Host "[iOS] Skipped." }

# ---------- Web ----------
if (-not $SkipWeb) {
  Write-Host "`n[Web] Build release (no SW caching) and validate CSP..."
  if (-not (Test-Path $WebDir)) { throw "Web dir '$WebDir' not found." }
  Push-Location $WebDir

  flutter clean
  flutter build web --release --pwa-strategy=none `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    --dart-define=WS_BASE_URL=$WsBaseUrl

  $index = Join-Path (Get-Location) "build/web/index.html"
  if (-not (Test-Path $index)) { throw "index.html missing in build output" }

  # CSP present
  if (-not (Select-String -Path $index -Pattern '<meta[^>]+http-equiv="Content-Security-Policy"' -SimpleMatch:$false)) { throw "CSP meta tag missing" }
  # No wildcards
  if (Select-String $index -Pattern 'default-src[^;]*\*' -SimpleMatch:$false) { throw "CSP default-src contains *" }
  if (Select-String $index -Pattern 'connect-src[^;]*\*' -SimpleMatch:$false) { throw "CSP connect-src contains *" }
  # No unsafe-eval
  if (Select-String $index -Pattern 'unsafe-eval') { throw "CSP contains unsafe-eval" }
  # Block embedding
  if (-not (Select-String $index -Pattern "frame-ancestors 'none'")) { throw "CSP missing frame-ancestors 'none'" }
  # Force https/wss only
  if (Select-String $index -Pattern 'connect-src[^;]*http://' -SimpleMatch:$false) { throw "CSP allows http:// in connect-src" }
  if (Select-String $index -Pattern 'connect-src[^;]*ws://' -SimpleMatch:$false)   { throw "CSP allows ws:// in connect-src" }

  # Warn if SW is present
  $sw = Join-Path (Get-Location) "build/web/flutter_service_worker.js"
  if (Test-Path $sw) { Write-Warning "flutter_service_worker.js present; ensure it never caches API/auth responses." }

  # No .env artifacts
  $envLeaks = Get-ChildItem -Recurse -Path (Join-Path (Get-Location) "build/web") -Include ".env*"
  if ($envLeaks) { throw "Build contains .env-like files. Remove them." }

  Pop-Location
  Write-Host "[Web] OK."
} else { Write-Host "[Web] Skipped." }

Write-Host "`nAll selected checks passed."
