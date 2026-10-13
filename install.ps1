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

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          SETUP-OPENCODE INSTALLER - INTERACTIVE SETUP          " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Kiem tra opencode trong PATH
Write-Host "==> Kiem tra OpenCode CLI trong he thong..." -ForegroundColor Cyan
$opencodeCmd = Get-Command "opencode" -ErrorAction SilentlyContinue
if (-not $opencodeCmd) {
    Write-Host "[!] OpenCode CLI chua duoc tim thay trong PATH." -ForegroundColor Yellow
    Write-Host "  -> Luu y: Ban co the cai dat OpenCode qua npm: npm install -g opencode" -ForegroundColor DarkGray
} else {
    Write-Host "  -> Tim thay OpenCode: $($opencodeCmd.Source)" -ForegroundColor Green
}

# 2. Thu thap AI URL va API Key
Write-Host "`n==> Thiet lap AI Model Gateway (OpenAI-compatible / Custom Gateway):" -ForegroundColor Cyan
$aiBaseUrl = "http://localhost:20128/v1"
Write-Host "  -> AI Base URL co dinh mac dinh: $aiBaseUrl" -ForegroundColor Green

$envAiKey = [Environment]::GetEnvironmentVariable("AI_API_KEY", "Process")
if (-not $envAiKey) { $envAiKey = [Environment]::GetEnvironmentVariable("AI_API_KEY", "User") }
if (-not $envAiKey) { $envAiKey = [Environment]::GetEnvironmentVariable("AI_API_KEY", "Machine") }

$aiKey = $envAiKey
while ([string]::IsNullOrWhiteSpace($aiKey)) {
    $aiKeyInput = Read-Host "[?] Vui long nhap AI API Key (BAT BUOC, khong co mac dinh)"
    if (-not [string]::IsNullOrWhiteSpace($aiKeyInput)) {
        $aiKey = $aiKeyInput.Trim()
    } else {
        Write-Host "  [!] AI API Key khong duoc de trong. Vui long nhap key hop le." -ForegroundColor Red
    }
}

# 3. Tai va giai nen setup-opencode tu GitHub
$tempDir = Join-Path $env:TEMP ("setup-opencode-" + [System.Guid]::NewGuid().ToString("N"))
$zipFile = Join-Path $env:TEMP ("setup-opencode-" + [System.Guid]::NewGuid().ToString("N") + ".zip")
$zipUrl = "https://github.com/thanhpk6120/setup-opencode/archive/refs/heads/main.zip"

try {
    Write-Host "`n==> Downloading setup package from GitHub..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "==> Extracting setup package..." -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

    $extractedRoot = Join-Path $tempDir "setup-opencode-main"
    if (-not (Test-Path $extractedRoot)) {
        $subDirs = Get-ChildItem -Path $tempDir -Directory
        if ($subDirs.Count -gt 0) { $extractedRoot = $subDirs[0].FullName }
    }

    $bootstrapScript = Join-Path $extractedRoot "bootstrap.ps1"
    if (-not (Test-Path $bootstrapScript)) {
        throw "Loi: Khong tim thay bootstrap.ps1 trong goi cai dat."
    }

    $envFilePath = Join-Path $extractedRoot ".env"
    $envContent = @"
AI_BASE_URL=$aiBaseUrl
AI_API_KEY=$aiKey
"@
    Set-Content -Path $envFilePath -Value $envContent -Encoding utf8

    Write-Host "==> Launching bootstrap..." -ForegroundColor Cyan
    $bootstrapParams = @{}
    if ($PSBoundParameters.ContainsKey('Force')) { $bootstrapParams['Force'] = $Force }
    if ($PSBoundParameters.ContainsKey('OverwriteAll')) { $bootstrapParams['OverwriteAll'] = $OverwriteAll }
    if ($PSBoundParameters.ContainsKey('DryRun')) { $bootstrapParams['DryRun'] = $DryRun }
    if ($PSBoundParameters.ContainsKey('SkipInstall')) { $bootstrapParams['SkipInstall'] = $SkipInstall }
    if ($PSBoundParameters.ContainsKey('OpenCodeDir')) { $bootstrapParams['OpenCodeDir'] = $OpenCodeDir }
    if ($enableMemorix) {
        $bootstrapParams['EnableMemorix'] = $true
    } elseif ($disableMemorix) {
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
    if ($LASTEXITCODE -ne 0) { throw "bootstrap.ps1 failed with exit code $LASTEXITCODE." }
}
finally {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    if ($zipFile -and (Test-Path $zipFile)) {
        Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
    }
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "    SETUP-OPENCODE INSTALLATION COMPLETED SUCCESSFULLY!         " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
