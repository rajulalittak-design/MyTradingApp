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

if (-not $env:GITHUB_REPO){ Abort "GITHUB_REPO env var is required (owner/repo)." }
if (-not $env:GITHUB_TOKEN){ Abort "GITHUB_TOKEN env var is required." }

Write-Host "Looking for recent workflow runs for build_apk.yml (via REST API)..." -ForegroundColor Cyan

$maxPollMinutes = 30
$pollIntervalSec = 15
$deadline = (Get-Date).AddMinutes($maxPollMinutes)

$parts = $env:GITHUB_REPO.Split('/')
$owner = $parts[0]
$repo = $parts[1]
$headers = @{ Authorization = "token $env:GITHUB_TOKEN"; "User-Agent" = "auto_fetch_script"; "Accept" = "application/vnd.github.v3+json" }

function Get-LatestRun(){
    $url = "https://api.github.com/repos/$owner/$repo/actions/runs?workflow_id=build_apk.yml&per_page=10"
    try{
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -Method GET -ErrorAction Stop
    } catch { return $null }
    if (-not $resp.workflow_runs){ return $null }
    $runs = $resp.workflow_runs
    # Prefer latest completed successful run
    $succ = $runs | Where-Object { $_.status -eq 'completed' -and $_.conclusion -eq 'success' } | Select-Object -First 1
    if ($succ) { return $succ }
    $comp = $runs | Where-Object { $_.status -eq 'completed' } | Select-Object -First 1
    if ($comp) { return $comp }
    return $runs | Select-Object -First 1
}

$run = Get-LatestRun
if (-not $run){ Abort "No workflow runs found for build_apk.yml. Ensure the workflow has been dispatched on branch main." }

Write-Host "Found run: id=$($run.id) status=$($run.status) conclusion=$($run.conclusion) url=$($run.html_url)" -ForegroundColor Green

while (($run.status -ne 'completed') -and ((Get-Date) -lt $deadline)){
    Write-Host "Run $($run.id) status=$($run.status). Waiting $pollIntervalSec seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $pollIntervalSec
    $run = Get-LatestRun
    if (-not $run){ Abort "No workflow run found during polling." }
}

if ($run.status -ne 'completed'){
    Abort "Run did not complete within $maxPollMinutes minutes. Check the Actions page: $($run.html_url)"
}

Write-Host "Run completed. Conclusion: $($run.conclusion). Downloading artifacts..." -ForegroundColor Green

$outdir = Join-Path -Path (Get-Location) -ChildPath ("artifacts/$($run.id)")
New-Item -ItemType Directory -Path $outdir -Force | Out-Null

# List artifacts
$artUrl = "https://api.github.com/repos/$owner/$repo/actions/runs/$($run.id)/artifacts"
try{
    $artResp = Invoke-RestMethod -Uri $artUrl -Headers $headers -Method GET -ErrorAction Stop
} catch { Abort "Failed to list artifacts: $_" }

if (-not $artResp.artifacts -or $artResp.total_count -eq 0){ Write-Host "No artifacts found for run $($run.id). Check logs: $($run.html_url)" -ForegroundColor Red; exit 1 }

foreach ($a in $artResp.artifacts){
    $zipPath = Join-Path $outdir ($a.name + ".zip")
    $downloadUrl = $a.archive_download_url
    Write-Host "Downloading artifact $($a.name) to $zipPath..." -ForegroundColor Cyan
    try{
        Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $zipPath -DestinationPath $outdir -Force
    } catch { Write-Host "Failed to download or extract artifact $($a.name): $_" -ForegroundColor Yellow }
}

Write-Host "Artifacts downloaded. Listing APK files:" -ForegroundColor Cyan
$apkFiles = Get-ChildItem -Path $outdir -Recurse -Filter *.apk -File | Select-Object -ExpandProperty FullName
if (-not $apkFiles){ Write-Host "No APK files found in artifacts; check the run logs: $($run.html_url)" -ForegroundColor Red; exit 1 }

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

Write-Host "Done. Open the run URL to view logs: $($run.html_url)" -ForegroundColor Green
