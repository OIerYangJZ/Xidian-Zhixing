param([ValidateSet('backend','knowledge','ollama')][string]$Service)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
if ($Service -eq 'ollama') {
    $env:OLLAMA_HOST = '127.0.0.1:11434'
    $env:OLLAMA_NUM_PARALLEL = '1'
    $env:OLLAMA_FLASH_ATTENTION = '1'
    $env:OLLAMA_KV_CACHE_TYPE = 'q8_0'
    & "$env:LOCALAPPDATA/Programs/Ollama/ollama.exe" serve
    exit $LASTEXITCODE
}
$configPath = Join-Path $workspacePath "artifacts/ai/local/$Service-env.json"
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
foreach ($entry in $config.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable($entry.Name, [string]$entry.Value, 'Process')
}
Set-Location -LiteralPath $workspacePath
$env:PYTHONUTF8 = '1'
if ($Service -eq 'knowledge') {
    & "$workspacePath/.venv/rag/Scripts/python.exe" -m knowledge_service.server
} else {
    & python "$workspacePath/backend/server.py"
}
exit $LASTEXITCODE
