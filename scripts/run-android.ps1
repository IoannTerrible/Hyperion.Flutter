# Run / build the Hyperion Flutter Android app with all required env vars.
#
# Usage:
#   .\scripts\run-android.ps1                          # flutter run on a connected Android device
#   .\scripts\run-android.ps1 -Release                 # release run
#   .\scripts\run-android.ps1 -Build appbundle         # flutter build appbundle (Play Store)
#   .\scripts\run-android.ps1 -Build apk               # flutter build apk --release
#
# Reads HYPERION_GOOGLE_SERVER_CLIENT_ID from env if not passed inline.

param(
    [switch]$Release,
    [string]$Build = '',
    [string]$AuthBaseUrl    = 'https://hyperion.techteastudio.cc/auth',
    [string]$DevicesBaseUrl = 'https://hyperion.techteastudio.cc/mobileapi',
    [string]$PluginBaseUrl  = 'https://hyperion.techteastudio.cc/plugins',
    # On Android the "server client id" is the **Web** Client ID — see google_sign_in docs.
    [string]$GoogleServerClientId = $env:HYPERION_GOOGLE_SERVER_CLIENT_ID,
    # GitHub OAuth App client id (no client secret on the device — backend exchanges code).
    # Default = the **mobile** GitHub OAuth App (callback hyperion://oauth/github).
    # The Flutter client tags the login request with platform: "mobile" so the
    # backend pairs this client_id with the matching mobile client_secret.
    [string]$GitHubClientId       = $(if ($env:HYPERION_GITHUB_CLIENT_ID) { $env:HYPERION_GITHUB_CLIENT_ID } else { 'Ov23liAmJQVPvrstcSg2' })
)

$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $RepoRoot

if ([string]::IsNullOrWhiteSpace($GoogleServerClientId)) {
    Write-Warning @"
GOOGLE_SERVER_CLIENT_ID not provided — Google sign-in will be inactive in this build.

Pass it via:
    .\scripts\run-android.ps1 -GoogleServerClientId 123-aaaa.apps.googleusercontent.com

Or persist for your user (one-time):
    [System.Environment]::SetEnvironmentVariable('HYPERION_GOOGLE_SERVER_CLIENT_ID', '123-aaaa.apps.googleusercontent.com', 'User')

Reminder: this is the **Web** OAuth client id from Google Cloud Console, not the Android one.
"@
}

$FlutterBin = 'D:\UslessTrash\Flutter\flutter\bin\flutter.bat'
if (-not (Test-Path $FlutterBin)) {
    $FlutterBin = 'flutter'
}

$defines = @(
    "--dart-define=AUTH_BASE_URL=$AuthBaseUrl",
    "--dart-define=DEVICES_BASE_URL=$DevicesBaseUrl",
    "--dart-define=PLUGIN_BASE_URL=$PluginBaseUrl"
)
if (-not [string]::IsNullOrWhiteSpace($GoogleServerClientId)) {
    $defines += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId"
}
if (-not [string]::IsNullOrWhiteSpace($GitHubClientId)) {
    $defines += "--dart-define=GITHUB_CLIENT_ID=$GitHubClientId"
}

if ($Build) {
    $args = @('build', $Build)
    if ($Release -or $Build -eq 'appbundle') { $args += '--release' }
    $args += $defines
    Write-Host "[run-android] flutter $($args -join ' ')" -ForegroundColor Cyan
    & $FlutterBin @args
} else {
    $args = @('run')
    if ($Release) { $args += '--release' }
    $args += $defines
    Write-Host "[run-android] flutter $($args -join ' ')" -ForegroundColor Cyan
    & $FlutterBin @args
}
