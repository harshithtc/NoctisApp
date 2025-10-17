param(
  [string]$version = '9.4.2'
)

# This script downloads the Gradle distribution and places it in the expected
# Gradle wrapper cache folder so the wrapper won't attempt to download it.
# Usage: .\place-gradle-distribution.ps1 -version 9.4.2

$distUrl = "https://services.gradle.org/distributions/gradle-$version-all.zip"
$targetBase = Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-$version-all"
if (!(Test-Path $targetBase)) { New-Item -ItemType Directory -Force -Path $targetBase | Out-Null }
$child = Join-Path $targetBase "manual"
if (!(Test-Path $child)) { New-Item -ItemType Directory -Force -Path $child | Out-Null }
$zipPath = Join-Path $child "gradle-$version-all.zip"

Write-Host "Downloading $distUrl to $zipPath"
try {
  Invoke-WebRequest -Uri $distUrl -OutFile $zipPath -ErrorAction Stop
  Write-Host "Downloaded Gradle $version successfully. You can now run ./gradlew --version"
} catch {
  Write-Error "Failed to download Gradle: $_"
  exit 1
}
*** End Patch