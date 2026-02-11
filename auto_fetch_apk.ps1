<#
auto_fetch_apk.ps1

Usage:
  Set the environment variables in the same PowerShell session where you run this script:
    $env:GITHUB_REPO = 'owner/repo'
    $env:GITHUB_TOKEN = 'ghp_xxx'

  Then run:
    .\auto_fetch_apk.ps1

What it does:
- Uses `gh` to find the latest `build_apk.yml` workflow run on `main`.
- Polls until the run completes (timeout ~15 minutes).
- Downloads artifacts into `./artifacts/<run-id>` and lists APK files.
- If `adb` is available and you consent (script prompts), it can install the first APK found.

Note: run this from the repository root (where .git is).
#>

function Abort($msg){ Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)){
    Abort "GitHub CLI (gh) not found. Install it and re-run this script: https://cli.github.com/"
}

if (-not $env:GITHUB_REPO){ Abort "GITHUB_REPO env var is required (owner/repo)." }
if (-not $env:GITHUB_TOKEN){ Abort "GITHUB_TOKEN env var is required." }

Write-Host "Looking for recent workflow runs for build_apk.yml..." -ForegroundColor Cyan

$maxPollMinutes = 15
$pollIntervalSec = 15
$deadline = (Get-Date).AddMinutes($maxPollMinutes)

function Get-LatestRun(){
    $json = gh run list --workflow=build_apk.yml --limit 10 --json id,status,conclusion,htmlUrl --repo $env:GITHUB_REPO 2>$null
    if (-not $json){ return $null }
    $runs = $json | ConvertFrom-Json
    if (-not $runs){ return $null }
    # Prefer latest completed successful run
    $succ = $runs | Where-Object { $_.status -eq 'completed' -and $_.conclusion -eq 'success' } | Select-Object -First 1
    if ($succ) { return $succ }
    # else latest completed
    $comp = $runs | Where-Object { $_.status -eq 'completed' } | Select-Object -First 1
    if ($comp) { return $comp }
    # else return the most recent queued/in_progress run
    return $runs | Select-Object -First 1
}

$run = Get-LatestRun
if (-not $run){ Abort "No workflow runs found for build_apk.yml. Ensure the workflow has been dispatched on branch main." }

Write-Host "Found run: id=$($run.id) status=$($run.status) conclusion=$($run.conclusion) url=$($run.htmlUrl)" -ForegroundColor Green

while (($run.status -ne 'completed') -and ((Get-Date) -lt $deadline)){
    Write-Host "Run $($run.id) status=$($run.status). Waiting $pollIntervalSec seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $pollIntervalSec
    $run = Get-LatestRun
    if (-not $run){ Abort "No workflow run found during polling." }
}

if ($run.status -ne 'completed'){
    Abort "Run did not complete within $maxPollMinutes minutes. Check the Actions page: $($run.htmlUrl)"
}

Write-Host "Run completed. Conclusion: $($run.conclusion). Downloading artifacts..." -ForegroundColor Green

$outdir = Join-Path -Path (Get-Location) -ChildPath ("artifacts/$($run.id)")
New-Item -ItemType Directory -Path $outdir -Force | Out-Null

Write-Host "Downloading artifacts to $outdir..." -ForegroundColor Cyan
gh run download $run.id --repo $env:GITHUB_REPO --dir $outdir 2>$null

Write-Host "Artifacts downloaded. Listing APK files:" -ForegroundColor Cyan
$apkFiles = Get-ChildItem -Path $outdir -Recurse -Filter *.apk -File | Select-Object -ExpandProperty FullName
if (-not $apkFiles){ Write-Host "No APK files found in artifacts; check the run logs: $($run.htmlUrl)" -ForegroundColor Red; exit 1 }

foreach ($f in $apkFiles){ Write-Host " - $f" }

if (Get-Command adb -ErrorAction SilentlyContinue){
    Write-Host "adb found. Install first APK now? (Y/N)" -ForegroundColor Cyan
    $ans = Read-Host
    if ($ans -match '^[Yy]'){ 
        Write-Host "Installing $($apkFiles[0]) via adb..." -ForegroundColor Cyan
        adb install -r $apkFiles[0]
        Write-Host "adb install exit code: $LASTEXITCODE" -ForegroundColor Green
    } else { Write-Host "Skipping adb install." }
} else {
    Write-Host "adb not found locally. To install, copy the APK to your device and run: adb install -r <apk>" -ForegroundColor Yellow
}

Write-Host "Done. Open the run URL to view logs: $($run.htmlUrl)" -ForegroundColor Green
