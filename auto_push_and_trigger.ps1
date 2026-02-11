<#
Non-interactive helper to push this repo to GitHub and trigger the Buildozer CI workflow.

Usage (PowerShell):

# Set required env vars (non-interactive):
$env:GITHUB_REPO = 'owner/repo'        # required
$env:GITHUB_TOKEN = 'ghp_xxx'          # required (personal access token with repo and workflow scope) 

# Optional: set keystore secrets to produce a signed release build:
$env:KEYSTORE_BASE64 = ''               # base64 contents of your .jks file
$env:KEY_ALIAS = ''
$env:KEYSTORE_PASSWORD = ''
$env:KEY_PASSWORD = ''

# Then run this script from the repo root:
.\auto_push_and_trigger.ps1

This script will:
- ensure git and gh are available (attempt to install gh via winget/choco if missing)
- initialize a git repo and commit if needed
- create the GitHub repo and push to `main`
- set the keystore-related secrets if provided
- trigger the `build_apk.yml` workflow on `main`
#>

function Abort($msg){ Write-Host $msg -ForegroundColor Red; exit 1 }

Push-Location $PSScriptRoot

if (-not $env:GITHUB_REPO){ Abort "GITHUB_REPO environment variable is required (owner/repo)." }
if (-not $env:GITHUB_TOKEN){ Abort "GITHUB_TOKEN environment variable is required (GitHub PAT with repo and workflow permissions)." }

if (-not (Get-Command git -ErrorAction SilentlyContinue)){
    Abort "Git is not installed. Install Git and re-run this script: https://git-scm.com/downloads"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)){
    Write-Host "GitHub CLI (gh) not found. Attempting to install via winget or choco..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue){
        winget install --id GitHub.cli -e --source winget
    } elseif (Get-Command choco -ErrorAction SilentlyContinue){
        choco install gh -y
    } else {
        Abort "Please install GitHub CLI (gh) and retry: https://cli.github.com/"
    }
}

# Authenticate gh using the provided token (non-interactive)
try{
    Write-Host "Authenticating gh..." -ForegroundColor Cyan
    $env:GITHUB_TOKEN | gh auth login --with-token 2>$null
} catch {
    Write-Host "gh auth login failed; ensure gh is authenticated or GITHUB_TOKEN is valid." -ForegroundColor Yellow
}

if (-not (Test-Path .git)){
    git init
    git config user.email "you@example.com"
    git config user.name "Your Name"
    git add -A
    git commit -m "Initial commit: mobile app and CI" 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "No changes to commit" -ForegroundColor Yellow }
    git branch -M main
}

Write-Host "Committing local changes (if any) and preparing to push..." -ForegroundColor Cyan
git add -A
git commit -m "CI: update workflow and add helpers" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No changes to commit" -ForegroundColor Yellow }
Write-Host "Creating GitHub repo and pushing..." -ForegroundColor Cyan
try{
    if (Get-Command gh -ErrorAction SilentlyContinue){
        gh repo create $env:GITHUB_REPO --public --source=. --remote=origin --push --confirm
    } else {
        throw "gh-not-found"
    }
} catch {
    Write-Host "gh repo create unavailable or failed; attempting HTTPS push using GITHUB_TOKEN..." -ForegroundColor Yellow
    try{
        $ownerRepo = $env:GITHUB_REPO
        if (-not $ownerRepo -or -not ($ownerRepo -match "/")){
            Abort "GITHUB_REPO must be in the form owner/repo."
        }
        $token = $env:GITHUB_TOKEN
        if (-not $token){ Abort "GITHUB_TOKEN is required for HTTPS push fallback." }

        $parts = $ownerRepo.Split('/')
        $owner = $parts[0]
        $repo = $parts[1]

        # Check if repo exists
        $headers = @{ Authorization = "token $token"; "User-Agent" = "auto_push_script" }
        $repoUrl = "https://api.github.com/repos/$owner/$repo"
        $exists = $false
        try{
            Invoke-RestMethod -Uri $repoUrl -Headers $headers -Method GET -ErrorAction Stop | Out-Null
            $exists = $true
        } catch {
            $exists = $false
        }

        if (-not $exists){
            Write-Host "Repository does not exist on GitHub; attempting to create it via API..." -ForegroundColor Cyan
            # Get authenticated username
            $user = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method GET
            if ($user -and $user.login -and $user.login -eq $owner){
                # create under user
                $body = @{ name = $repo; private = $false } | ConvertTo-Json
                Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method POST -Body $body -ErrorAction Stop | Out-Null
                Write-Host "Created repository $ownerRepo under user $($user.login)" -ForegroundColor Green
            } else {
                # attempt to create under org
                try{
                    $body = @{ name = $repo; private = $false } | ConvertTo-Json
                    Invoke-RestMethod -Uri "https://api.github.com/orgs/$owner/repos" -Headers $headers -Method POST -Body $body -ErrorAction Stop | Out-Null
                    Write-Host "Created repository $ownerRepo under organization $owner" -ForegroundColor Green
                } catch {
                    Abort "Could not create repository $ownerRepo via API. Ensure your token has necessary permissions or create the repo manually." 
                }
            }
        }

        $remoteUrl = "https://$($token)@github.com/$ownerRepo.git"

        # Ensure branch exists
        if (-not (git rev-parse --verify main 2>$null)){
            git branch -M main
        }

        if ((git remote) -notcontains 'origin'){
            git remote add origin $remoteUrl
        } else {
            git remote set-url origin $remoteUrl
        }

        git push -u origin main --force
    } catch {
        Abort "Failed to push repo via HTTPS fallback: $_"
    }
}

# If keystore is provided, set GitHub secrets
if ($env:KEYSTORE_BASE64){
    Write-Host "Setting keystore secrets..." -ForegroundColor Cyan
    try{
        gh secret set KEYSTORE_BASE64 --body "$env:KEYSTORE_BASE64"
        if ($env:KEY_ALIAS){ gh secret set KEY_ALIAS --body "$env:KEY_ALIAS" }
        if ($env:KEYSTORE_PASSWORD){ gh secret set KEYSTORE_PASSWORD --body "$env:KEYSTORE_PASSWORD" }
        if ($env:KEY_PASSWORD){ gh secret set KEY_PASSWORD --body "$env:KEY_PASSWORD" }
    } catch {
        Write-Host "Failed to set secrets via gh: $_" -ForegroundColor Yellow
    }
}

Write-Host "Dispatching workflow build_apk.yml on branch main..." -ForegroundColor Cyan
try{
    if (Get-Command gh -ErrorAction SilentlyContinue){
        gh workflow run build_apk.yml --ref main
        Write-Host "Workflow dispatched via gh. Open Actions tab on GitHub to monitor progress." -ForegroundColor Green
    } else {
        # Use REST API to dispatch workflow
        $token = $env:GITHUB_TOKEN
        $headers = @{ Authorization = "token $token"; "User-Agent" = "auto_push_script"; "Accept" = "application/vnd.github.v3+json" }
        $dispatchUrl = "https://api.github.com/repos/$ownerRepo/actions/workflows/build_apk.yml/dispatches"
        $body = @{ ref = 'main' } | ConvertTo-Json
        Invoke-RestMethod -Uri $dispatchUrl -Headers $headers -Method POST -Body $body -ErrorAction Stop
        Write-Host "Workflow dispatched via REST API. Open Actions tab on GitHub to monitor progress." -ForegroundColor Green
    }
} catch {
    Write-Host "Could not dispatch workflow: $_" -ForegroundColor Yellow
    Write-Host "Open the Actions tab on GitHub to monitor the run or start it manually." -ForegroundColor Yellow
}

Pop-Location

Write-Host "Done." -ForegroundColor Green
