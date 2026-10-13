# install.ps1 - One-line interactive installer for setup-opencode
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$OverwriteAll,
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$EnableMemorix,
    [switch]$DisableMemorix,
    [string]$OpenCodeDir = "$env:USERPROFILE\.config\opencode"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

function Safe-Trash {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (Get-Command "trash" -ErrorAction SilentlyContinue) {
        trash $Path
        return
    }
    try {
        if ([System.IO.Directory]::Exists($Path)) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } elseif ([System.IO.File]::Exists($Path)) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        }
    } catch {
        Write-Warning "Khong the di chuyen '$Path' vao Thung rac: $($_.Exception.Message)"
    }
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          SETUP-OPENCODE INSTALLER - INTERACTIVE SETUP          " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Kiem tra va ho tro cai dat OpenCode CLI trong PATH
Write-Host "==> Kiem tra OpenCode CLI trong he thong..." -ForegroundColor Cyan
$opencodeCmd = Get-Command "opencode" -ErrorAction SilentlyContinue
if (-not $opencodeCmd) {
    Write-Host "[!] OpenCode CLI chua duoc tim thay trong PATH." -ForegroundColor Yellow
    $installPrompt = Read-Host "OpenCode CLI chua duoc cai dat. Ban co muon cai dat OpenCode ngay qua npm (npm install -g opencode-ai) khong? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($installPrompt) -or $installPrompt.Trim().ToLower() -eq 'y') {
        Write-Host "==> Dang cai dat OpenCode CLI qua npm..." -ForegroundColor Cyan
        try {
            npm install -g opencode-ai
            Write-Host "==> Cai dat OpenCode CLI hoan tat. Dang cap nhat PATH trong session hien tai..." -ForegroundColor Green

            $npmPrefix = (npm prefix -g 2>$null)
            $candidatePaths = @(
                $npmPrefix,
                (Join-Path $env:APPDATA "npm"),
                (Join-Path $env:LOCALAPPDATA "Programs\opencode"),
                (Join-Path $env:USERPROFILE ".opencode\bin")
            )
            try {
                $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
                $machinePath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
                foreach ($p in ("$userPath;$machinePath" -split ';')) {
                    if (-not [string]::IsNullOrWhiteSpace($p)) { $candidatePaths += $p.Trim() }
                }
            } catch {}

            $pathItems = ($env:PATH -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
            foreach ($cand in ($candidatePaths | Select-Object -Unique)) {
                if ((Test-Path $cand) -and ($pathItems -notcontains $cand)) {
                    $env:PATH = "$cand;$env:PATH"
                    $pathItems += $cand
                }
            }

            $opencodeCmd = Get-Command "opencode" -ErrorAction SilentlyContinue
            if ($opencodeCmd) {
                Write-Host "==> Da tim thay OpenCode CLI tai: $($opencodeCmd.Source)" -ForegroundColor Green
            } else {
                Write-Host "[!] Da chay npm install nhung chua nhan dien duoc 'opencode' trong session hien tai. Ban co the can mo lai terminal sau khi cai dat." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[!] Loi khi cai dat OpenCode CLI: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[!] Bo qua cai dat OpenCode CLI. Tiep tuc cau hinh moi truong setup-opencode..." -ForegroundColor Yellow
    }
} else {
    Write-Host "==> Da phat hien OpenCode CLI tai: $($opencodeCmd.Source)" -ForegroundColor Green
}

# 2. Cau hinh ket noi AI Provider
Write-Host ""
Write-Host "==> Cau hinh ket noi AI Provider..." -ForegroundColor Cyan
$defaultAiUrl = "http://localhost:20128/v1"
if ($env:AI_BASE_URL) { $defaultAiUrl = $env:AI_BASE_URL }
$inputAiUrl = Read-Host "Nhap AI Base URL [Mac dinh: $defaultAiUrl]"
$aiBaseUrl = if ([string]::IsNullOrWhiteSpace($inputAiUrl)) { $defaultAiUrl } else { $inputAiUrl.Trim() }

$aiApiKey = ""
if ($env:AI_API_KEY) { $aiApiKey = $env:AI_API_KEY }
while ([string]::IsNullOrWhiteSpace($aiApiKey)) {
    if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) {
        if (-not [string]::IsNullOrWhiteSpace($env:AI_API_KEY)) {
            $aiApiKey = $env:AI_API_KEY.Trim()
            break
        }
        throw "Loi: Dang chay o che do non-interactive nhung AI API Key chua duoc cung cap qua bien moi truong `$env:AI_API_KEY`."
    }
    $inputKey = Read-Host "Nhap AI API Key (Bat buoc, khong co mac dinh)"
    if (-not [string]::IsNullOrWhiteSpace($inputKey)) {
        $aiApiKey = $inputKey.Trim()
        break
    }
    Write-Host "Loi: AI API Key la bat buoc, khong duoc de trong. Vui long nhap lai!" -ForegroundColor Red
}

# 3. Cau hinh tien ich bo sung (Memorix)
Write-Host ""
Write-Host "==> Cau hinh tien ich bo sung..." -ForegroundColor Cyan
$enableMemorix = $false

if ($PSBoundParameters.ContainsKey('EnableMemorix')) {
    $enableMemorix = $true
} elseif ($PSBoundParameters.ContainsKey('DisableMemorix')) {
    $enableMemorix = $false
} else {
    $existingMemorix = Get-Command "memorix" -ErrorAction SilentlyContinue
    if ($existingMemorix) {
        Write-Host "==> Phat hien he thong da co san Memorix tai: $($existingMemorix.Source)" -ForegroundColor Green
        Write-Host "==> Tu dong bat Memorix va cap nhat len phien ban moi nhat." -ForegroundColor Green
        $enableMemorix = $true
    } else {
        $memorixPrompt = Read-Host "Ban co muon cai dat them tien ich Memorix (quan ly memory, reasoning, project history) khong? [y/N]"
        if (-not [string]::IsNullOrWhiteSpace($memorixPrompt) -and $memorixPrompt.Trim().ToLower() -eq 'y') {
            $enableMemorix = $true
        } else {
            $enableMemorix = $false
        }
    }
}

# 4. Tai va kich hoat bootstrap.ps1
$tempBase = Join-Path $env:TEMP ("setup-opencode-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("setup-opencode-" + [System.Guid]::NewGuid().ToString("N") + ".zip")
$zipUrl = "https://github.com/thanhpk6120/setup-opencode/archive/refs/heads/main.zip"

try {
    $localBootstrap = Join-Path $PSScriptRoot "bootstrap.ps1"
    $bootstrapScript = ""

    if (Test-Path $localBootstrap) {
        Write-Host "==> Su dung ma nguon cuc bo tai: $PSScriptRoot" -ForegroundColor Green
        $bootstrapScript = $localBootstrap
    } else {
        Write-Host "`n==> Dang tai goi setup-opencode tu GitHub ($zipUrl)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

        Write-Host "==> Dang giai nen tap tin..." -ForegroundColor Cyan
        Expand-Archive -Path $zipFile -DestinationPath $tempBase -Force

        $extractedRoot = Join-Path $tempBase "setup-opencode-main"
        if (-not (Test-Path $extractedRoot)) {
            $subDirs = Get-ChildItem -Path $tempBase -Directory
            if ($subDirs.Count -gt 0) { $extractedRoot = $subDirs[0].FullName }
        }

        $bootstrapScript = Join-Path $extractedRoot "bootstrap.ps1"
    }

    if (-not (Test-Path $bootstrapScript)) {
        throw "Loi: Khong tim thay bootstrap.ps1 trong goi cai dat."
    }

    $env:AI_BASE_URL = $aiBaseUrl
    $env:AI_API_KEY = $aiApiKey

    Write-Host "==> Kich hoat bootstrap.ps1..." -ForegroundColor Cyan
    $bootstrapParams = @{}
    if ($PSBoundParameters.ContainsKey('Force')) { $bootstrapParams['Force'] = $Force }
    if ($PSBoundParameters.ContainsKey('OverwriteAll')) { $bootstrapParams['OverwriteAll'] = $OverwriteAll }
    if ($PSBoundParameters.ContainsKey('DryRun')) { $bootstrapParams['DryRun'] = $DryRun }
    if ($PSBoundParameters.ContainsKey('SkipInstall')) { $bootstrapParams['SkipInstall'] = $SkipInstall }
    if ($PSBoundParameters.ContainsKey('OpenCodeDir')) { $bootstrapParams['OpenCodeDir'] = $OpenCodeDir }
    if ($enableMemorix) {
        $bootstrapParams['EnableMemorix'] = $true
    } else {
        $bootstrapParams['DisableMemorix'] = $true
    }

    $paramList = @()
    foreach ($key in $bootstrapParams.Keys) {
        if ($bootstrapParams[$key] -eq $true) {
            $paramList += "-$key"
        } else {
            $paramList += "-$key", "$($bootstrapParams[$key])"
        }
    }

    $psExe = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path $psExe)) { $psExe = Join-Path $PSHOME "powershell.exe" }
    if (-not (Test-Path $psExe)) { $psExe = "powershell" }

    $argsArray = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $bootstrapScript) + $paramList
    & $psExe $argsArray
    if ($LASTEXITCODE -ne 0) { throw "bootstrap.ps1 that bai voi ma loi exit code $LASTEXITCODE." }
}
finally {
    if (Test-Path $zipFile) { Safe-Trash -Path $zipFile }
    if (Test-Path $tempBase) { Safe-Trash -Path $tempBase }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " CAI DAT THANH CONG CHO OPENCODE!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
