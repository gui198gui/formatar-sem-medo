#Requires -Version 5.1
<#
  Formatar Sem Medo - RESTAURO
  Repoe o que o backup copiou: redes Wi-Fi, programas (winget), extensoes do VS Code,
  pastas pessoais, definicoes de programas, saves de jogos, registo e drivers.

  So copia ficheiros para o PC. Nao apaga nada. Podes correr varias vezes
  (por exemplo, outra vez depois de instalares os jogos).
#>

$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
. (Join-Path $Root 'comum.ps1')
$script:Warnings = New-Object System.Collections.ArrayList

function Ask([string]$question) {
  $a = Read-Host "$question (S/n)"
  return ($a -eq '' -or $a -match '^[sS]')
}

# --------------------------------------------------------------------------
# Encontrar a pasta de backup
# --------------------------------------------------------------------------
$backups = @(Get-ChildItem -LiteralPath $Root -Directory -Filter 'Backup_*' -ErrorAction SilentlyContinue |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') } |
  Sort-Object Name -Descending)

if ($backups.Count -eq 0) {
  Write-Host "Nao encontrei nenhuma pasta Backup_... com manifest.json ao lado deste script." -ForegroundColor Red
  exit 1
}

$Backup = $backups[0]
if ($backups.Count -gt 1) {
  Write-Host "Encontrei varios backups:"
  for ($i = 0; $i -lt $backups.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $backups[$i].Name) }
  $choice = Read-Host "Qual queres restaurar? (Enter = 1, o mais recente)"
  if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $backups.Count) { $Backup = $backups[[int]$choice - 1] }
}
$B = $Backup.FullName
$Manifest = Get-Content -LiteralPath (Join-Path $B 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$items = @($Manifest.items)

try { Start-Transcript -Path (Join-Path $B ("restauro-log_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm'))) -Force | Out-Null } catch {}

Write-Host ""
Write-Host "  FORMATAR SEM MEDO - Restauro" -ForegroundColor White
Write-Host "  Backup: $($Backup.Name)  (PC $($Manifest.computer), utilizador $($Manifest.user))"
Write-Host "  Este script so copia ficheiros para o PC. Ficheiros com o mesmo nome sao substituidos pelos do backup."
Write-Host ""

$isAdmin = $false
try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}

# --------------------------------------------------------------------------
# 1. Wi-Fi
# --------------------------------------------------------------------------
$wifiDir = Join-Path $B 'wifi'
$wifiFiles = @(Get-ChildItem -LiteralPath $wifiDir -Filter *.xml -ErrorAction SilentlyContinue)
if ($wifiFiles.Count -gt 0 -and (Test-Command 'netsh') -and (Ask "Restaurar $($wifiFiles.Count) rede(s) Wi-Fi?")) {
  Write-Step "Redes Wi-Fi"
  foreach ($f in $wifiFiles) {
    netsh wlan add profile filename="$($f.FullName)" user=current | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok $f.BaseName } else { Write-Warn2 "Falhou: $($f.BaseName)" }
  }
}

# --------------------------------------------------------------------------
# 2. Programas (winget)
# --------------------------------------------------------------------------
$wingetFile = Join-Path $B 'programas\winget.json'
if (Test-Path -LiteralPath $wingetFile) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    if (Ask "Reinstalar os programas com o winget? (pode demorar bastante)") {
      Write-Step "A instalar programas (winget import)"
      winget import -i "$wingetFile" --accept-package-agreements --accept-source-agreements --ignore-unavailable
      # Atualiza o PATH para encontrar programas acabados de instalar (ex: VS Code)
      $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }
  } else {
    Write-Warn2 "winget nao disponivel: instala a 'App Installer' da Microsoft Store e corre o restauro outra vez."
  }
}
$listFile = Join-Path $B 'programas\programas-instalados.txt'
if (Test-Path -LiteralPath $listFile) {
  Write-Host "    Lista completa dos programas que tinhas: $listFile" -ForegroundColor DarkGray
}

$extFile = Join-Path $B 'programas\vscode-extensoes.txt'
if ((Test-Path -LiteralPath $extFile) -and (Get-Command code -ErrorAction SilentlyContinue)) {
  if (Ask "Reinstalar as extensoes do VS Code?") {
    Write-Step "Extensoes do VS Code"
    Get-Content -LiteralPath $extFile | Where-Object { $_.Trim() } | ForEach-Object { code --install-extension $_ --force | Out-Null; Write-Ok $_ }
  }
}

# --------------------------------------------------------------------------
# 3. Ficheiros (pastas, definicoes, saves) e registo
# --------------------------------------------------------------------------
function Resolve-Target($item) {
  if ($item.root -eq 'abs') { return $item.rel }
  if ($item.root -like 'game:*') {
    $dir = Get-SteamGameDir ($item.root.Substring(5))
    if (-not $dir) { return $null }
    $base = $dir
  } else {
    $base = $Roots[$item.root]
    if (-not $base) { return $null }
  }
  if ($item.rel) { return (Join-Path $base $item.rel) }
  return $base
}

$groups = [ordered]@{
  'pastas'               = 'Pastas pessoais'
  'programas-definicoes' = 'Definicoes de programas'
  'jogos-definicoes'     = 'Definicoes de jogos'
  'jogos-saves'          = 'Saves de jogos'
}
$pending = New-Object System.Collections.ArrayList

foreach ($g in $groups.Keys) {
  $groupItems = @($items | Where-Object { $_.group -eq $g })
  if ($groupItems.Count -eq 0) { continue }
  if (-not (Ask "Restaurar $($groups[$g]) ($($groupItems.Count) itens)?")) { continue }
  Write-Step $groups[$g]
  foreach ($it in $groupItems) {
    $src = Join-Path $B $it.backup
    if ($it.type -eq 'reg') {
      if (-not (Test-Command 'reg')) { continue }
      reg import "$src" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { Write-Ok "$($it.label): registo" } else { Write-Warn2 "$($it.label): falhou o registo (tenta como administrador)" }
      continue
    }
    $target = Resolve-Target $it
    if (-not $target) {
      [void]$pending.Add($it.label)
      Write-Skip "$($it.label): ainda nao da para restaurar (instala primeiro o jogo/Steam e corre outra vez)"
      continue
    }
    if ($it.type -eq 'dir') { $ok = Copy-Folder $src $target }
    else { $ok = Copy-OneFile $src (Split-Path -Path $target -Parent) }
    if ($ok) { Write-Ok "$($it.label) -> $target" } else { Write-Warn2 "$($it.label): falhou a copia para $target" }
  }
}

# --------------------------------------------------------------------------
# 4. Drivers
# --------------------------------------------------------------------------
$drvDir = Join-Path $B 'drivers'
if ((Test-Path -LiteralPath $drvDir) -and (Ask "Instalar os drivers guardados?")) {
  if ($isAdmin -and (Test-Command 'pnputil')) {
    Write-Step "Drivers"
    pnputil /add-driver "$drvDir\*.inf" /subdirs /install | Out-Null
    Write-Ok "Drivers instalados (pode ser preciso reiniciar)"
  } else {
    Write-Warn2 "Para instalar drivers corre o RESTAURAR.bat como administrador."
  }
}

# --------------------------------------------------------------------------
# Resumo
# --------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Restauro concluido." -ForegroundColor Green
if ($pending.Count -gt 0) {
  $unique = $pending | Sort-Object -Unique
  Write-Host "  Por restaurar (instala estes jogos/programas e corre o RESTAURAR.bat outra vez):" -ForegroundColor Yellow
  $unique | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
}
if ($script:Warnings.Count -gt 0) {
  Write-Host "  Avisos:" -ForegroundColor Yellow
  $script:Warnings | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
}
Write-Host "==========================================================" -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch {}
