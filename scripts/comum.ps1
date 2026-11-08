# Formatar Sem Medo - funcoes comuns ao backup e ao restauro
# (este ficheiro e carregado pelos outros scripts; nao precisas de o abrir)

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
function Test-Command($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    [OK] $text" -ForegroundColor Green }
function Write-Skip($text) { Write-Host "    [--] $text" -ForegroundColor DarkGray }
function Write-Warn2($text){ Write-Host "    [!!] $text" -ForegroundColor Yellow; $script:Warnings.Add($text) | Out-Null }


$Sep = [IO.Path]::DirectorySeparatorChar

# --------------------------------------------------------------------------
# Pastas do sistema (raizes usadas para traduzir caminhos entre PCs)
# --------------------------------------------------------------------------
function Get-KnownFolder($name) {
  try { return [Environment]::GetFolderPath($name) } catch { return $null }
}

function Get-DownloadsFolder {
  try {
    $p = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($p) { return $p }
  } catch {}
  if ($env:USERPROFILE) { return (Join-Path $env:USERPROFILE 'Downloads') }
  return $null
}

function Get-SteamPath {
  try {
    $p = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
    if ($p) { return ($p -replace '/', '\') }
  } catch {}
  foreach ($c in @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam")) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Get-SteamLibraries($steam) {
  $libs = New-Object System.Collections.ArrayList
  if (-not $steam) { return @() }
  [void]$libs.Add($steam)
  $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
  if (Test-Path -LiteralPath $vdf) {
    $text = Get-Content -LiteralPath $vdf -Raw
    foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
      $p = $m.Groups[1].Value -replace '\\\\', '\'
      if ($libs -notcontains $p) { [void]$libs.Add($p) }
    }
  }
  return $libs.ToArray()
}

function Get-SteamGameDir($appid) {
  if (-not $appid) { return $null }
  foreach ($lib in $script:SteamLibs) {
    $acf = Join-Path $lib "steamapps\appmanifest_$appid.acf"
    if (Test-Path -LiteralPath $acf) {
      $m = [regex]::Match((Get-Content -LiteralPath $acf -Raw), '"installdir"\s+"([^"]+)"')
      if ($m.Success) {
        $dir = Join-Path $lib ("steamapps\common\" + $m.Groups[1].Value)
        if (Test-Path -LiteralPath $dir) { return (Normalize-Path $dir) }
      }
    }
  }
  return $null
}

function Get-UbisoftPath {
  foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher', 'HKLM:\SOFTWARE\Ubisoft\Launcher')) {
    try { $p = (Get-ItemProperty -Path $k -ErrorAction Stop).InstallDir; if ($p) { return $p.TrimEnd('\','/') } } catch {}
  }
  return $null
}

$script:SteamPath = Get-SteamPath
$script:SteamLibs = Get-SteamLibraries $script:SteamPath

$userProfile = $env:USERPROFILE
$Roots = [ordered]@{
  'documents'       = Get-KnownFolder 'MyDocuments'
  'desktop'         = Get-KnownFolder 'Desktop'
  'pictures'        = Get-KnownFolder 'MyPictures'
  'videos'          = Get-KnownFolder 'MyVideos'
  'music'           = Get-KnownFolder 'MyMusic'
  'downloads'       = Get-DownloadsFolder
  'savedgames'      = if ($userProfile) { Join-Path $userProfile 'Saved Games' } else { $null }
  'locallow'        = if ($userProfile) { Join-Path $userProfile 'AppData\LocalLow' } else { $null }
  'localappdata'    = $env:LOCALAPPDATA
  'appdata'         = $env:APPDATA
  'temp'            = $env:TEMP
  'steam'           = $script:SteamPath
  'ubisoftconnect'  = Get-UbisoftPath
  'userprofile'     = $userProfile
  'programdata'     = $env:ProgramData
  'public'          = $env:PUBLIC
  'programfilesx86' = ${env:ProgramFiles(x86)}
  'programfiles'    = $env:ProgramFiles
  'windir'          = $env:windir
}

# Normaliza separadores para comparar caminhos de forma fiavel
function Normalize-Path([string]$p) { if (-not $p) { return $p }; return $p.Replace('\', $Sep).Replace('/', $Sep).TrimEnd($Sep) }
foreach ($k in @($Roots.Keys)) { $Roots[$k] = Normalize-Path $Roots[$k] }
$script:SteamLibs = @($script:SteamLibs | ForEach-Object { Normalize-Path $_ })

function Get-SafeName([string]$name) {
  $n = ($name -replace '[\\/:*?"<>|]', '_').Trim()
  if ($n.Length -gt 60) { $n = $n.Substring(0, 60) }
  if (-not $n) { $n = 'item' }
  return $n
}

$HasRobocopy = [bool](Get-Command robocopy -ErrorAction SilentlyContinue)

function Copy-Folder([string]$src, [string]$dst) {
  New-Item -ItemType Directory -Path $dst -Force | Out-Null
  if ($HasRobocopy) {
    $roboArgs = @("$src", "$dst", '/E', '/COPY:DAT', '/R:1', '/W:1', '/XJ', '/NP', '/NFL', '/NDL')
    if ($script:RoboLog) { $roboArgs += "/LOG+:$($script:RoboLog)" }
    robocopy @roboArgs | Out-Null
    $code = $LASTEXITCODE
    if ($code -ge 8 -and $script:RoboLog) { Write-Host "    Detalhes do erro em: $($script:RoboLog)" -ForegroundColor Yellow }
    return ($code -lt 8)
  }
  try { Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force -ErrorAction Stop; return $true } catch { return $false }
}

function Copy-OneFile([string]$src, [string]$dstDir) {
  New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
  try { Copy-Item -LiteralPath $src -Destination $dstDir -Force -ErrorAction Stop; return $true } catch { return $false }
}

