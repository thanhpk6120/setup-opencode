# test-bootstrap.ps1 - Assert-based test for setup-opencode bootstrap script
$ErrorActionPreference = "Stop"

$tempDir = Join-Path $env:TEMP ("opencode-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempDir2 = Join-Path $env:TEMP ("opencode-test2-" + [System.Guid]::NewGuid().ToString("N"))

try {
    $env:AI_BASE_URL = "https://test.local"
    $env:AI_API_KEY = "test-key-abc"
    $env:JIRA_URL = "https://test.jira"
    $env:JIRA_PERSONAL_TOKEN = "test-jira-token"
    $env:CONFLUENCE_URL = "https://test.conf"
    $env:CONFLUENCE_PERSONAL_TOKEN = "test-conf-token"
    $env:CONTEXT7_API_KEY = "test-ctx-token"

    # Setup mock environment for gitnexus and context7
    $mockBinDir = Join-Path $env:TEMP ("opencode-mock-bin-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $mockBinDir | Out-Null
    Set-Content -Path (Join-Path $mockBinDir "gitnexus.cmd") -Value "@echo off`necho gitnexus"
    Set-Content -Path (Join-Path $mockBinDir "npm.cmd") -Value "@echo off`nif `"%1`"==`"root`" if `"%2`"==`"-g`" (echo $mockNpmDir& exit /b 0)`nexit /b 0"
    $oldPath = $env:Path
    $env:Path = "$mockBinDir;$env:Path"

    $mockNpmDir = Join-Path $env:TEMP ("opencode-mock-npm-" + [System.Guid]::NewGuid().ToString("N"))
    $mockContext7Path = Join-Path $mockNpmDir "@upstash\context7-mcp\dist"
    New-Item -ItemType Directory -Force -Path $mockContext7Path | Out-Null
    Set-Content -Path (Join-Path $mockContext7Path "index.js") -Value "// mock"

    # =========================================================================
    # Test 1: Chay bootstrap voi -SkipInstall (non-interactive, all MCPs skipped)
    # =========================================================================
    Write-Host "Running OpenCode bootstrap (Test 1: SkipInstall non-interactive) into: $tempDir"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -OpenCodeDir $tempDir

    $configFile = Join-Path $tempDir "opencode.json"
    if (-not (Test-Path $configFile)) {
        throw "ASSERTION FAILED: Missing generated file: $configFile"
    }

    $configObj = Get-Content $configFile -Raw | ConvertFrom-Json
    if ($configObj.provider.custom.apiKey -ne "test-key-abc") {
        throw "ASSERTION FAILED: apiKey mismatch in opencode.json"
    }
    if ($configObj.provider.custom.baseURL -ne "https://test.local") {
        throw "ASSERTION FAILED: baseURL mismatch in opencode.json"
    }

    foreach ($f in @("AGENTS.md", "RULES.md", "SYSTEM.md")) {
        $p = Join-Path $tempDir $f
        if (-not (Test-Path $p)) {
            throw "ASSERTION FAILED: Missing copied static file: $p"
        }
    }

    $skillsDir = Join-Path $tempDir "skills"
    if (-not (Test-Path $skillsDir)) {
        throw "ASSERTION FAILED: Missing copied skills/ directory: $skillsDir"
    }

    # =========================================================================
    # Test 2: Chay bootstrap voi -Force (Tu dong cai dat tat ca MCP servers)
    # =========================================================================
    Write-Host "`nRunning OpenCode bootstrap (Test 2: -Force accept all MCPs) into: $tempDir2"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -Force -OpenCodeDir $tempDir2

    $configFile2 = Join-Path $tempDir2 "opencode.json"
    if (-not (Test-Path $configFile2)) {
        throw "ASSERTION FAILED: Missing generated file: $configFile2"
    }

    $configObj2 = Get-Content $configFile2 -Raw | ConvertFrom-Json
    if (-not $configObj2.mcp.gitnexus) {
        throw "ASSERTION FAILED: gitnexus missing in mcp block when -Force"
    }
    if ($configObj2.mcp.gitnexus.command[0] -ne "cmd") {
        throw "ASSERTION FAILED: gitnexus command should start with 'cmd'"
    }
    if (-not $configObj2.mcp.'company-atlassian') {
        throw "ASSERTION FAILED: company-atlassian missing in mcp block when -Force"
    }
    if ($configObj2.mcp.'company-atlassian'.command[0] -ne "mcp-atlassian") {
        throw "ASSERTION FAILED: company-atlassian command should be 'mcp-atlassian'"
    }
    if (-not $configObj2.mcp.context7) {
        throw "ASSERTION FAILED: context7 missing in mcp block when -Force"
    }
    if (-not $configObj2.mcp.cloakbrowser) {
        throw "ASSERTION FAILED: cloakbrowser missing in mcp block when -Force"
    }
    if (-not $configObj2.mcp.glab) {
        throw "ASSERTION FAILED: glab missing in mcp block when -Force"
    }

    Write-Host "`nAll isolated tests passed successfully for setup-opencode!" -ForegroundColor Green
}
finally {
    $env:Path = $oldPath
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    if (Test-Path $tempDir2) { Remove-Item -Recurse -Force $tempDir2 -ErrorAction SilentlyContinue }
    if ($mockBinDir -and (Test-Path $mockBinDir)) { Remove-Item -Recurse -Force $mockBinDir -ErrorAction SilentlyContinue }
    if ($mockNpmDir -and (Test-Path $mockNpmDir)) { Remove-Item -Recurse -Force $mockNpmDir -ErrorAction SilentlyContinue }
}
