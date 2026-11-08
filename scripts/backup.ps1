#Requires -Version 5.1
<#
  Formatar Sem Medo - BACKUP
  Copia saves de jogos, definicoes de programas, pastas pessoais, perfis Wi-Fi,
  lista de programas e (opcional) drivers para uma pasta ao lado deste script.

  Este script SO COPIA ficheiros. Nunca apaga nem altera nada no teu PC.
  Gerado por https://gui198gui.github.io/formatar-sem-medo/
#>

$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
$ConfigPath = Join-Path $Root 'config.json'
. (Join-Path $Root 'comum.ps1')

$script:Warnings = New-Object System.Collections.ArrayList
$script:Manifest = New-Object System.Collections.ArrayList
$script:Counter = 0

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Host "Nao encontrei o config.json ao lado deste script." -ForegroundColor Red
  exit 1
}
$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

# --------------------------------------------------------------------------
# Destino
# --------------------------------------------------------------------------
$IsWindowsOS = ($env:OS -eq 'Windows_NT')
if ($IsWindowsOS) {
  $rootDrive = (Split-Path -Path $Root -Qualifier)
  if ($rootDrive -and $rootDrive -ieq $env:SystemDrive) {
    Write-Host ""
    Write-Host "ATENCAO: esta pasta esta no disco do Windows ($rootDrive)." -ForegroundColor Yellow
    Write-Host "Se formatares este disco, o backup PERDE-SE. Copia esta pasta para uma pen ou disco externo" -ForegroundColor Yellow
    Write-Host "e corre o backup a partir de la." -ForegroundColor Yellow
    $ans = Read-Host "Queres continuar mesmo assim? (s/N)"
    if ($ans -notmatch '^[sS]') { exit 0 }
  }
}

$Stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$Dest = Join-Path $Root ("Backup_{0}_{1}" -f $env:COMPUTERNAME, $Stamp)
New-Item -ItemType Directory -Path $Dest -Force | Out-Null
try { Start-Transcript -Path (Join-Path $Dest 'backup-log.txt') -Force | Out-Null } catch {}
$script:RoboLog = Join-Path $Dest 'robocopy-log.txt'

Write-Host ""
Write-Host "  FORMATAR SEM MEDO - Backup" -ForegroundColor White
Write-Host "  Destino: $Dest"
Write-Host "  (este script so copia ficheiros, nao apaga nada)"

# --------------------------------------------------------------------------
# Traduzir um padrao do config.json (<appdata>\Jogo\<uid>\) em caminhos reais
# --------------------------------------------------------------------------
function Expand-Pattern([string]$pattern, $appid) {
  $results = New-Object System.Collections.ArrayList
  $p = $pattern.Replace('<uid>', '*').Replace('<username>', "$env:USERNAME").Replace('<wow64>', 'WOW6432Node')

  # <steamlibrary> pode ter varios valores
  $candidates = @($p)
  if ($p -match '<steamlibrary>') {
    $candidates = @($script:SteamLibs | ForEach-Object { $p.Replace('<steamlibrary>', $_) })
    if (-not $candidates) { return @() }
  }

  foreach ($c in $candidates) {
    $ok = $true
    if ($c -match '<game>') {
      $gameDir = Get-SteamGameDir $appid
      if (-not $gameDir) { $ok = $false } else { $c = $c.Replace('<game>', $gameDir) }
    }
    foreach ($key in $Roots.Keys) {
      $tok = "<$key>"
      if ($c.Contains($tok)) {
        if (-not $Roots[$key]) { $ok = $false; break }
        $c = $c.Replace($tok, $Roots[$key])
      }
    }
    if ($ok -and $c -notmatch '<[a-z]+>') { [void]$results.Add($c.Replace('\', $Sep).Replace('/', $Sep)) }
  }
  return $results.ToArray()
}

# Converte um caminho real em "raiz + resto" para o restauro funcionar noutro PC/utilizador
function ConvertTo-Portable([string]$path, $appid) {
  $best = $null; $bestLen = -1
  $all = [ordered]@{}
  foreach ($k in $Roots.Keys) { if ($Roots[$k]) { $all[$k] = $Roots[$k] } }
  if ($appid) { $gd = Get-SteamGameDir $appid; if ($gd) { $all["game:$appid"] = $gd } }
  foreach ($k in $all.Keys) {
    $r = $all[$k].TrimEnd('\', '/')
    if ($path.Length -ge $r.Length -and $path.Substring(0, $r.Length) -ieq $r -and ($path.Length -eq $r.Length -or $path[$r.Length] -eq '\' -or $path[$r.Length] -eq '/')) {
      if ($r.Length -gt $bestLen) { $best = $k; $bestLen = $r.Length }
    }
  }
  if ($best) { return @{ root = $best; rel = $path.Substring($bestLen).TrimStart('\', '/') } }
  return @{ root = 'abs'; rel = $path }
}

# Copia tudo o que um padrao encontrar e regista no manifesto
function Backup-Pattern([string]$group, [string]$label, [string]$pattern, $appid) {
  # Registo do Windows
  if ($pattern -match '^<(hkcu|hklm)>') {
    $hive = if ($matches[1] -eq 'hkcu') { 'HKCU' } else { 'HKLM' }
    $key = ($pattern -replace '^<(hkcu|hklm)>', $hive) -replace '<wow64>', 'WOW6432Node'
    $key = $key.TrimEnd('\')
    $psKey = $key -replace '^HKCU', 'HKCU:' -replace '^HKLM', 'HKLM:'
    if (-not (Test-Command 'reg') -or -not (Test-Path -LiteralPath $psKey)) { Write-Skip "Registo nao encontrado: $key"; return 0 }
    $script:Counter++
    $rel = Join-Path $group (Join-Path (Get-SafeName $label) ("reg{0}.reg" -f $script:Counter))
    $file = Join-Path $Dest $rel
    New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
    reg export "$key" "$file" /y | Out-Null
    if ($LASTEXITCODE -eq 0) {
      [void]$script:Manifest.Add([pscustomobject]@{ group = $group; label = $label; type = 'reg'; root = 'reg'; rel = $key; backup = $rel; appid = $appid })
      Write-Ok "Registo: $key"
      return 1
    }
    Write-Warn2 "Nao consegui exportar o registo $key"
    return 0
  }

  $copied = 0
  foreach ($concrete in (Expand-Pattern $pattern $appid)) {
    $clean = $concrete.TrimEnd('\', '/')
    $hasWild = $clean -match '[\*\?]'
    $items = if ($hasWild) { @(Get-Item -Path $clean -Force -ErrorAction SilentlyContinue) } else { @(Get-Item -LiteralPath $clean -Force -ErrorAction SilentlyContinue) }
    # Um padrao que acaba em \ refere-se a pastas: ignora ficheiros soltos apanhados pelo *
    if ($pattern.EndsWith('\') -or $pattern.EndsWith('/')) { $items = @($items | Where-Object { $_ -and $_.PSIsContainer }) }

    # Padrao do tipo pasta\*.sav: copia os ficheiros que correspondem
    foreach ($it in $items) {
      if (-not $it) { continue }
      $script:Counter++
      $portable = ConvertTo-Portable (Normalize-Path $it.FullName) $appid
      $slot = Join-Path $group (Join-Path (Get-SafeName $label) ("{0:D3}" -f $script:Counter))
      if ($it.PSIsContainer) {
        if (Copy-Folder $it.FullName (Join-Path $Dest $slot)) {
          [void]$script:Manifest.Add([pscustomobject]@{ group = $group; label = $label; type = 'dir'; root = $portable.root; rel = $portable.rel; backup = $slot; appid = $appid })
          $copied++
        } else { Write-Warn2 "Falhou a copia de $($it.FullName) (OneDrive desligado? pen cheia? ficheiro > 4 GB numa pen FAT32? ver robocopy-log.txt)" }
      } else {
        if (Copy-OneFile $it.FullName (Join-Path $Dest $slot)) {
          [void]$script:Manifest.Add([pscustomobject]@{ group = $group; label = $label; type = 'file'; root = $portable.root; rel = $portable.rel; backup = (Join-Path $slot $it.Name); appid = $appid })
          $copied++
        } else { Write-Warn2 "Falhou a copia de $($it.FullName)" }
      }
    }
  }
  return $copied
}

# --------------------------------------------------------------------------
# 1. Saves e definicoes dos jogos
# --------------------------------------------------------------------------
if ($Config.games -and $Config.games.Count -gt 0) {
  Write-Step "Saves e definicoes de jogos ($($Config.games.Count))"
  foreach ($g in $Config.games) {
    $n = 0
    foreach ($item in $g.items) {
      $grp = if ($item.kind -eq 'config') { 'jogos-definicoes' } else { 'jogos-saves' }
      $n += Backup-Pattern $grp $g.name $item.pattern $g.appid
    }
    if ($n -gt 0) { Write-Ok "$($g.name): $n item(s) copiado(s)" }
    elseif ($g.cloud) { Write-Skip "$($g.name): nada encontrado neste PC (tem cloud, os saves devem estar na nuvem)" }
    else { Write-Warn2 "$($g.name): nao encontrei nada deste jogo neste PC (pode nao estar instalado ou guardar noutro sitio)" }
  }
}

# --------------------------------------------------------------------------
# 2. Definicoes de programas
# --------------------------------------------------------------------------
if ($Config.configs -and $Config.configs.Count -gt 0) {
  Write-Step "Definicoes de programas"
  foreach ($c in $Config.configs) {
    $n = 0
    foreach ($pat in $c.patterns) { $n += Backup-Pattern 'programas-definicoes' $c.name $pat $null }
    if ($n -gt 0) { Write-Ok "$($c.name)" } else { Write-Skip "$($c.name): nao encontrado" }
  }
}

# --------------------------------------------------------------------------
# 3. Pastas pessoais
# --------------------------------------------------------------------------
if ($Config.folders -and $Config.folders.Count -gt 0) {
  Write-Step "Pastas pessoais (pode demorar)"
  foreach ($f in $Config.folders) {
    $src = $Roots[$f]
    if (-not $src -or -not (Test-Path -LiteralPath $src)) { Write-Skip "$f nao encontrada"; continue }
    $slot = Join-Path 'pastas' $f
    if (Copy-Folder $src (Join-Path $Dest $slot)) {
      [void]$script:Manifest.Add([pscustomobject]@{ group = 'pastas'; label = $f; type = 'dir'; root = $f; rel = ''; backup = $slot; appid = $null })
      Write-Ok "$f ($src)"
    } else { Write-Warn2 "Falhou a copia da pasta $src" }
  }
}

# --------------------------------------------------------------------------
# 3b. Outras pastas escolhidas pelo utilizador
# --------------------------------------------------------------------------
if ($Config.customFolders -and $Config.customFolders.Count -gt 0) {
  Write-Step "Outras pastas (pode demorar)"
  foreach ($cf in $Config.customFolders) {
    $n = Backup-Pattern 'outras-pastas' $cf.name $cf.pattern $null
    if ($n -gt 0) { Write-Ok $cf.name }
    elseif (-not (Test-Path -LiteralPath ($cf.pattern.TrimEnd('\')))) { Write-Warn2 "Pasta nao encontrada: $($cf.pattern.TrimEnd('\'))" }
  }
}

# --------------------------------------------------------------------------
# 4. Programas instalados
# --------------------------------------------------------------------------
$progDir = Join-Path $Dest 'programas'
if ($Config.options.winget -or $Config.options.programList -or $Config.options.vscodeExt) {
  Write-Step "Lista de programas instalados"
  New-Item -ItemType Directory -Path $progDir -Force | Out-Null
}

if ($Config.options.winget) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget export -o (Join-Path $progDir 'winget.json') --accept-source-agreements | Out-Null
    if (Test-Path -LiteralPath (Join-Path $progDir 'winget.json')) { Write-Ok "winget.json (para reinstalar tudo de uma vez)" }
    else { Write-Warn2 "O winget export falhou" }
  } else { Write-Warn2 "winget nao esta disponivel neste PC (instala a 'App Installer' da Microsoft Store)" }
}

if ($Config.options.programList) {
  $keys = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  $apps = foreach ($k in $keys) {
    Get-ItemProperty -Path $k -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName } |
      Select-Object @{n='Nome';e={$_.DisplayName}}, @{n='Versao';e={$_.DisplayVersion}}, @{n='Editor';e={$_.Publisher}}
  }
  $apps = $apps | Sort-Object Nome -Unique
  $apps | Export-Csv -Path (Join-Path $progDir 'programas-instalados.csv') -NoTypeInformation -Encoding UTF8
  ($apps | ForEach-Object { "- $($_.Nome)" }) | Set-Content -Path (Join-Path $progDir 'programas-instalados.txt') -Encoding UTF8
  Write-Ok "programas-instalados.txt ($(@($apps).Count) programas)"
}

if ($Config.options.vscodeExt) {
  if (Get-Command code -ErrorAction SilentlyContinue) {
    code --list-extensions | Set-Content -Path (Join-Path $progDir 'vscode-extensoes.txt') -Encoding UTF8
    Write-Ok "Extensoes do VS Code"
  } else { Write-Skip "VS Code nao encontrado" }
}

# --------------------------------------------------------------------------
# 5. Wi-Fi
# --------------------------------------------------------------------------
if ($Config.options.wifi) {
  Write-Step "Redes Wi-Fi guardadas"
  $wifiDir = Join-Path $Dest 'wifi'
  New-Item -ItemType Directory -Path $wifiDir -Force | Out-Null
  if (Test-Command 'netsh') { netsh wlan export profile key=clear folder="$wifiDir" | Out-Null }
  $count = @(Get-ChildItem -LiteralPath $wifiDir -Filter *.xml -ErrorAction SilentlyContinue).Count
  if ($count -gt 0) { Write-Ok "$count rede(s). ATENCAO: as palavras-passe ficam em texto nesta pasta, guarda a pen em seguranca." }
  else { Write-Skip "Nenhuma rede Wi-Fi encontrada (PC so com cabo?)" }
}

# --------------------------------------------------------------------------
# 6. Drivers
# --------------------------------------------------------------------------
if ($Config.options.drivers) {
  Write-Step "Drivers"
  $isAdmin = $false
  try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}
  if ($isAdmin -and (Test-Command 'pnputil')) {
    $drvDir = Join-Path $Dest 'drivers'
    New-Item -ItemType Directory -Path $drvDir -Force | Out-Null
    pnputil /export-driver * "$drvDir" | Out-Null
    Write-Ok "Drivers exportados"
  } else {
    Write-Warn2 "Para copiar drivers corre o FAZER-BACKUP.bat como administrador (botao direito > Executar como administrador)"
  }
}

# --------------------------------------------------------------------------
# Manifesto (usado pelo restauro) e resumo
# --------------------------------------------------------------------------
$manifestObj = [pscustomobject]@{
  version  = 1
  created  = (Get-Date).ToString('s')
  computer = $env:COMPUTERNAME
  user     = $env:USERNAME
  items    = $script:Manifest
}
$manifestObj | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $Dest 'manifest.json') -Encoding UTF8
Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $Dest 'config.json') -Force

$size = (Get-ChildItem -LiteralPath $Dest -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
$sizeTxt = if ($size -gt 1GB) { '{0:N1} GB' -f ($size / 1GB) } else { '{0:N0} MB' -f ($size / 1MB) }

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Backup concluido: $($script:Manifest.Count) itens, $sizeTxt" -ForegroundColor Green
Write-Host "  Pasta: $Dest"
if ($script:Warnings.Count -gt 0) {
  Write-Host "  Avisos ($($script:Warnings.Count)):" -ForegroundColor Yellow
  $script:Warnings | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
}
Write-Host "  Confirma a CHECKLIST.txt antes de formatar!" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
try { Stop-Transcript | Out-Null } catch {}
