param([string]$Server='(localdb)\MSSQLLocalDB')
$ErrorActionPreference='Stop'
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) { throw 'Install SQL Server command-line tools (sqlcmd).' }
$scripts=@('01_create_oltp.sql','02_programmability.sql','03_seed_data.sql','04_create_dw.sql','05_etl_load_dw.sql','06_verify.sql')
foreach($script in $scripts) {
 Write-Host "Running $script" -ForegroundColor Cyan
 & sqlcmd -S $Server -E -b -f 65001 -i (Join-Path $PSScriptRoot $script)
 if($LASTEXITCODE -ne 0) {throw "Failed: $script"}
}
Write-Host 'Tinder OLTP + warehouse installed and verified.' -ForegroundColor Green
