param(
    [string]$Repo = ''
)

function Abort($msg){ Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)){
    Abort "Git is not installed. Install Git and re-run this script: https://git-scm.com/downloads"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)){
    Write-Host "GitHub CLI (gh) not found. Attempting to install via winget..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue){
        winget install --id GitHub.cli -e --source winget
    } elseif (Get-Command choco -ErrorAction SilentlyContinue){
        choco install gh -y
    } else {
        Abort "Please install GitHub CLI (gh): https://cli.github.com/"
    }
}

if (-not $Repo){
    $Repo = Read-Host "Enter repository name (owner/repo or repo). If owner omitted, it will use your account"
}

Push-Location $PSScriptRoot

if (-not (Test-Path .git)){
    git init
    git config user.email "you@example.com"
    git config user.name "Your Name"
    git add .
    git commit -m "Initial commit: mobile app and CI"
    git branch -M main
}

Write-Host "Creating GitHub repo and pushing..." -ForegroundColor Cyan
try{
    if ($Repo -match '/'){
        gh repo create $Repo --public --source=. --remote=origin --push
    } else {
        gh repo create $Repo --public --source=. --remote=origin --push
    }
} catch {
    Write-Host "gh repo create failed: $_" -ForegroundColor Yellow
    Write-Host "If the repo already exists, add a remote and push manually:"
    Write-Host "git remote add origin https://github.com/<owner>/$Repo.git"
    Write-Host "git push -u origin main"
    Pop-Location
    exit 1
}

Write-Host "Triggering CI workflow (build_apk.yml)..." -ForegroundColor Cyan
try{
    gh workflow run build_apk.yml --ref main
    Write-Host "Workflow dispatched. Check Actions tab on GitHub to monitor progress." -ForegroundColor Green
} catch {
    Write-Host "Could not dispatch workflow via gh: $_" -ForegroundColor Yellow
    Write-Host "Open the Actions tab on GitHub to monitor the run or start it manually." -ForegroundColor Yellow
}

Pop-Location

Write-Host "Done. Open your repo on GitHub and go to Actions to view the build." -ForegroundColor Green
