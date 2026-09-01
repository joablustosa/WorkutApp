# Script: setup-android-env.ps1
# Propósito: configurar Flutter, ANDROID_SDK_ROOT/ANDROID_HOME e adicionar ferramentas ao PATH.
# Uso: execute no diretório do projeto (padrão) com PowerShell; pode requerer permissão de administrador para alterações em nível Machine.

function Write-Info($m){ Write-Host "[INFO] $m" }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERROR] $m" -ForegroundColor Red }

# Local do projeto (diretório atual)
$projectRoot = (Get-Location).Path
$localProps = Join-Path $projectRoot 'android\local.properties'

if (-not (Test-Path $localProps)) {
    Write-Warn "Arquivo local.properties não encontrado em: $localProps"
    Write-Warn "Por favor verifique manualmente e execute este script novamente ou defina o SDK path manualmente."
    exit 1
}

# Ler sdk.dir do local.properties
$content = Get-Content $localProps -Raw
$sdkMatch = [regex]::Match($content, 'sdk\.dir\s*=\s*(.+)')
if (-not $sdkMatch.Success) {
    Write-Warn "sdk.dir não encontrado no local.properties"
    exit 1
}

$sdkPathRaw = $sdkMatch.Groups[1].Value.Trim()
# local.properties pode usar \ como escape; limpar aspas se houver
$sdkPathRaw = $sdkPathRaw.Trim('"')
# Normalizar para caminho Windows
$sdkPath = $sdkPathRaw -replace '/', '\\'

Write-Info "SDK detectado em: $sdkPath"

$flutterSdkPath = $null
$flutterMatch = [regex]::Match($content, 'flutter\.sdk\s*=\s*(.+)')
if ($flutterMatch.Success) {
    $flutterSdkPath = ($flutterMatch.Groups[1].Value.Trim().Trim('"') -replace '/', '\\')
    Write-Info "Flutter detectado em: $flutterSdkPath"
} elseif (Test-Path 'C:\flutter\bin\flutter.bat') {
    $flutterSdkPath = 'C:\flutter'
    Write-Info "Flutter detectado em: $flutterSdkPath (fallback padrão)"
} else {
    Write-Warn "Flutter SDK não encontrado. Instale em C:\flutter ou defina flutter.sdk no local.properties."
}

# Função para adicionar path se estiver faltando (scope: Machine ou User)
function Add-PathIfMissing([string]$scope, [string]$pathToAdd) {
    try {
        $current = [Environment]::GetEnvironmentVariable('Path', $scope)
        if (-not $current) { $current = '' }
        $parts = $current -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        if ($parts -contains $pathToAdd) {
            Write-Info "$pathToAdd já presente no PATH ($scope)"
            return $true
        }
        $new = $current + ';' + $pathToAdd
        [Environment]::SetEnvironmentVariable('Path', $new, $scope)
        Write-Info "Adicionado $pathToAdd ao PATH ($scope)"
        return $true
    } catch {
        Write-Warn "Falha ao adicionar $pathToAdd ao PATH ($scope): $_"
        return $false
    }
}

# Tentar setar variáveis de ambiente no nível Machine, com fallback para User
$setMachineOk = $true
try {
    [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdkPath, 'Machine')
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkPath, 'Machine')
    Write-Info "Definido ANDROID_SDK_ROOT e ANDROID_HOME no nível Machine"
} catch {
    Write-Warn "Não foi possível definir variáveis no nível Machine (provavelmente falta permissão): $_"
    $setMachineOk = $false
}

if (-not $setMachineOk) {
    try {
        [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdkPath, 'User')
        [Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkPath, 'User')
        Write-Info "Definido ANDROID_SDK_ROOT e ANDROID_HOME no nível User"
    } catch {
        Write-Err "Falha ao definir variáveis de ambiente no nível User: $_"
        exit 1
    }
}

if ($flutterSdkPath) {
    try {
        [Environment]::SetEnvironmentVariable('FLUTTER_ROOT', $flutterSdkPath, 'Machine')
        Write-Info "Definido FLUTTER_ROOT no nível Machine"
    } catch {
        [Environment]::SetEnvironmentVariable('FLUTTER_ROOT', $flutterSdkPath, 'User')
        Write-Info "Definido FLUTTER_ROOT no nível User"
    }
}

# Paths a adicionar
$platformTools = Join-Path $sdkPath 'platform-tools'
$emulatorDir = Join-Path $sdkPath 'emulator'
$cmdlineTools = Join-Path $sdkPath 'cmdline-tools\latest\bin'
$flutterBin = if ($flutterSdkPath) { Join-Path $flutterSdkPath 'bin' } else { $null }
$gitCmd = 'C:\Program Files\Git\cmd'

# Tentar adicionar ao PATH do Machine, com fallback para User
$addedPlatformMachine = $false
try {
    $addedPlatformMachine = Add-PathIfMissing 'Machine' $platformTools
    $addedEmulatorMachine = Add-PathIfMissing 'Machine' $emulatorDir
} catch {
    $addedPlatformMachine = $false
}

if (-not $addedPlatformMachine) {
    Write-Warn "Tentando adicionar ao PATH do User em vez de Machine"
    Add-PathIfMissing 'User' $platformTools | Out-Null
    Add-PathIfMissing 'User' $emulatorDir | Out-Null
    if (Test-Path $cmdlineTools) { Add-PathIfMissing 'User' $cmdlineTools | Out-Null }
    if ($flutterBin -and (Test-Path $flutterBin)) { Add-PathIfMissing 'User' $flutterBin | Out-Null }
    if (Test-Path $gitCmd) { Add-PathIfMissing 'User' $gitCmd | Out-Null }
}

if ($flutterBin -and (Test-Path $flutterBin)) {
    try {
        Add-PathIfMissing 'Machine' $flutterBin | Out-Null
    } catch {
        Add-PathIfMissing 'User' $flutterBin | Out-Null
    }
}

# Atualizar sessão atual do PowerShell para refletir mudanças sem reiniciar
$Env:ANDROID_SDK_ROOT = $sdkPath
$Env:ANDROID_HOME = $sdkPath
if ($flutterSdkPath) { $Env:FLUTTER_ROOT = $flutterSdkPath }
# Atualizar Path de sessão
$sessionPath = $Env:Path
foreach ($pathToAdd in @($platformTools, $emulatorDir, $cmdlineTools, $flutterBin, $gitCmd)) {
    if (-not $pathToAdd -or -not (Test-Path $pathToAdd)) { continue }
    if (-not ($sessionPath -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $pathToAdd })) {
        $sessionPath = "$sessionPath;$pathToAdd"
    }
}
$Env:Path = $sessionPath

Write-Info "Sessão atual atualizada. As alterações persistentes podem requerer reinício do PowerShell ou logoff/login dependendo do scope usado."

# Verificações rápidas
Write-Host "`n--- Verificações rápidas ---`n"
Write-Host "ANDROID_SDK_ROOT=$Env:ANDROID_SDK_ROOT"
Write-Host "ANDROID_HOME=$Env:ANDROID_HOME"
Write-Host "Onde emulator: "
Get-Command emulator -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.Source }
Write-Host "Onde adb: "
Get-Command adb -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.Source }
Write-Host "Onde sdkmanager: "
Get-Command sdkmanager -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.Source }
Write-Host "Onde git: "
Get-Command git -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.Source }

if ($flutterBin -and (Test-Path (Join-Path $flutterBin 'flutter.bat'))) {
    & (Join-Path $flutterBin 'flutter.bat') config --android-studio-dir="C:\Program Files\Android\Android Studio" | Out-Null
    Write-Info "Flutter configurado para o Android Studio em C:\Program Files\Android\Android Studio"
}

Write-Info "Script finalizado. Reinicie o Android Studio e execute 'flutter doctor -v' em um terminal novo."
Write-Info "Se o emulador falhar com INSTALL_FAILED_INSUFFICIENT_STORAGE, reinicie-o com: emulator -avd Pixel_9 -wipe-data"

