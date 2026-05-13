# Run the Hyperion Flutter Windows app with all required Google sign-in env vars.
#
# Usage:
#   .\scripts\run-windows.ps1                     # debug run (default)
#   .\scripts\run-windows.ps1 -Release            # release run
#
# Configuration — paste the values from Google Cloud Console here once and you're done.
# All four values come from APIs & Services -> Credentials in your Google Cloud project.

param(
    [switch]$Release,
    [string]$AuthBaseUrl     = 'https://hyperion.techteastudio.cc/auth',
    [string]$DevicesBaseUrl  = 'https://hyperion.techteastudio.cc/mobileapi',
    [string]$PluginBaseUrl   = 'https://hyperion.techteastudio.cc/plugins',
    # ── Google sign-in (Windows uses loopback OAuth — needs a Desktop client) ─────
    [string]$GoogleDesktopClientId     = $env:HYPERION_GOOGLE_DESKTOP_CLIENT_ID,
    [string]$GoogleDesktopClientSecret = $env:HYPERION_GOOGLE_DESKTOP_CLIENT_SECRET,
    # ── GitHub sign-in (Windows uses loopback OAuth — no client secret required) ──
    [string]$GitHubClientId            = $env:HYPERION_GITHUB_CLIENT_ID
)

# Resolve repo root so the script works no matter the cwd.
$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $RepoRoot

if ([string]::IsNullOrWhiteSpace($GoogleDesktopClientId)) {
    Write-Warning @"
GOOGLE_DESKTOP_CLIENT_ID not provided.

Set it inline:
    .\scripts\run-windows.ps1 -GoogleDesktopClientId 123-cccc.apps.googleusercontent.com `
                              -GoogleDesktopClientSecret GOCSPX-xxxx

Or set environment variables once per shell session:
    `$env:HYPERION_GOOGLE_DESKTOP_CLIENT_ID = '123-cccc.apps.googleusercontent.com'
    `$env:HYPERION_GOOGLE_DESKTOP_CLIENT_SECRET = 'GOCSPX-xxxx'
    .\scripts\run-windows.ps1

Or persist for your user (one-time):
    [System.Environment]::SetEnvironmentVariable('HYPERION_GOOGLE_DESKTOP_CLIENT_ID', '123-cccc.apps.googleusercontent.com', 'User')
    [System.Environment]::SetEnvironmentVariable('HYPERION_GOOGLE_DESKTOP_CLIENT_SECRET', 'GOCSPX-xxxx', 'User')

The Google sign-in button will be disabled until these are set.
"@
}

$FlutterBin = 'D:\UslessTrash\Flutter\flutter\bin\flutter.bat'
if (-not (Test-Path $FlutterBin)) {
    $FlutterBin = 'flutter'   # fall back to whatever is in PATH
}

$flags = @(
    '-d', 'windows',
    "--dart-define=AUTH_BASE_URL=$AuthBaseUrl",
    "--dart-define=DEVICES_BASE_URL=$DevicesBaseUrl",
    "--dart-define=PLUGIN_BASE_URL=$PluginBaseUrl"
)

if (-not [string]::IsNullOrWhiteSpace($GoogleDesktopClientId)) {
    $flags += "--dart-define=GOOGLE_DESKTOP_CLIENT_ID=$GoogleDesktopClientId"
}
if (-not [string]::IsNullOrWhiteSpace($GoogleDesktopClientSecret)) {
    $flags += "--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=$GoogleDesktopClientSecret"
}
if (-not [string]::IsNullOrWhiteSpace($GitHubClientId)) {
    $flags += "--dart-define=GITHUB_CLIENT_ID=$GitHubClientId"
}

if ($Release) {
    $flags += '--release'
}

Write-Host "[run-windows] flutter run $($flags -join ' ')" -ForegroundColor Cyan
& $FlutterBin run @flags
