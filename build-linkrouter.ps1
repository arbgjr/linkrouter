

param(
  # SourceFolder: diretório onde está o código-fonte e scripts de build
  [string]$SourceFolder = "C:\Users\arman\source\repos\arbgjr\linkrouter",
  [string]$Ahk2Exe = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",

  # InstallPath: diretório de destino para o deploy (onde ficará o EXE/config em produção, ex: C:\tools\LinkRouter)
  [string]$InstallPath = "C:\\tools\\LinkRouter",

  # Comportamento padrão: registra no final
  [switch]$NoRegister,

  # Modo: só registra, não recompila nem troca EXE
  [switch]$RegisterOnly,

  # Teste opcional
  [switch]$Test
)

$ErrorActionPreference = "Stop"



$Ahk = Join-Path $SourceFolder "LinkRouter.ahk"
$NewExe = Join-Path $SourceFolder "LinkRouter_new.exe"
$ConfigPath = Join-Path $SourceFolder "linkrouter.config.json"
$installDir = $InstallPath
# Caminhos na pasta de instalação
$Exe = Join-Path $installDir "LinkRouter.exe"
$OldExe = Join-Path $installDir ("LinkRouter_old_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".exe")
$targetConfig = Join-Path $installDir "linkrouter.config.json"

function Restart-Explorer {
  Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 700
  Start-Process explorer
  Start-Sleep -Milliseconds 700
}

function Register-LinkRouter([string]$ExePath) {
  if (!(Test-Path $ExePath)) { throw "EXE não encontrado para registrar: $ExePath" }

  # Importante: registro idempotente, não desregistra nada previamente
  $exeCmd = '"' + $ExePath + '" "%1"'

  reg add "HKCU\Software\Classes\LinkRouterURL" /ve /d "LinkRouter URL" /f | Out-Null
  reg add "HKCU\Software\Classes\LinkRouterURL" /v "URL Protocol" /d "" /f | Out-Null
  reg add "HKCU\Software\Classes\LinkRouterURL\shell\open\command" /ve /d $exeCmd /f | Out-Null

  reg add "HKCU\Software\LinkRouter\Capabilities" /v "ApplicationName" /d "LinkRouter" /f | Out-Null
  reg add "HKCU\Software\LinkRouter\Capabilities" /v "ApplicationDescription" /d "Roteador de links" /f | Out-Null
  reg add "HKCU\Software\LinkRouter\Capabilities\URLAssociations" /v "http" /d "LinkRouterURL" /f | Out-Null
  reg add "HKCU\Software\LinkRouter\Capabilities\URLAssociations" /v "https" /d "LinkRouterURL" /f | Out-Null
  reg add "HKCU\Software\RegisteredApplications" /v "LinkRouter" /d "Software\LinkRouter\Capabilities" /f | Out-Null
}

Write-Host "SourceFolder: $SourceFolder"
Write-Host "RegisterOnly: $RegisterOnly"
Write-Host "NoRegister: $NoRegister"

# Caso 1: só registrar (não recompila, não troca EXE)
if ($RegisterOnly) {
  Write-Host "Modo RegisterOnly: registrando sem rebuild."
  if (!(Test-Path $Exe)) { throw "EXE não encontrado para registrar: $Exe" }
  Register-LinkRouter -ExePath $Exe
  Write-Host "Reiniciando Explorer para atualizar associações..."
  Restart-Explorer
  if ($Test) {
    Write-Host "Testando Start-Process https://example.com"
    Start-Process "https://example.com"
  }
  Write-Host "OK. Registro aplicado."
  exit 0
}

# Caso 2: pipeline normal: build + swap na InstallPath
if (!(Test-Path $Ahk)) { throw "Arquivo não encontrado: $Ahk" }
if (!(Test-Path $Ahk2Exe)) { throw "Ahk2Exe não encontrado: $Ahk2Exe" }

# Build para temporário no source
if (Test-Path $NewExe) { Remove-Item $NewExe -Force }
Write-Host "Compilando para: $NewExe"
& $Ahk2Exe /in $Ahk /out $NewExe | Out-Null
if (!(Test-Path $NewExe)) { throw "Falha ao gerar: $NewExe" }

# Criar diretório de instalação se não existir
if (!(Test-Path $installDir)) {
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Soltar locks e fazer swap na InstallPath
Write-Host "Reiniciando Explorer para soltar locks..."
Restart-Explorer

if (Test-Path $Exe) {
  Write-Host "Backup do exe atual: $OldExe"
  Move-Item $Exe $OldExe -Force
}

Write-Host "Ativando novo exe em $Exe..."
Move-Item $NewExe $Exe -Force

# Copiar config para InstallPath se não existir
if (Test-Path $ConfigPath) {
  if (!(Test-Path $targetConfig)) {
    Write-Host "Copiando config para: $targetConfig"
    Copy-Item $ConfigPath $targetConfig -Force
  }
  else {
    Write-Host "Config já existe em $targetConfig, não será sobrescrito."
  }
}

# Registro padrão (a menos que você desligue com -NoRegister)
if (-not $NoRegister) {
  Write-Host "Registrando LinkRouter (na InstallPath)..."
  Register-LinkRouter -ExePath $Exe
  Write-Host "Reiniciando Explorer para atualizar associações..."
  Restart-Explorer
}
else {
  Write-Host "NoRegister selecionado: pulando registro."
}

# Teste opcional
if ($Test) {
  Write-Host "Testando Start-Process https://example.com"
  Start-Process "https://example.com"
}

Write-Host "OK. LinkRouter atualizado em: $Exe"
if (Test-Path $OldExe) {
  Write-Host "Backup salvo em: $OldExe"
}
