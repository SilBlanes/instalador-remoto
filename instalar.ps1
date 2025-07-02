Add-Type -AssemblyName System.Windows.Forms

# -----------------------
# CONFIGURACIÓN
# -----------------------

$dniCSVUrl = "https://raw.githubusercontent.com/SilBlanes/instalador/refs/tags/v1.0/dnis.csv?token=..."
$bitdefenderUrl = "https://github.com/SilBlanes/instalador/releases/download/v1.0/setupdownloader_.aHR0cHM6Ly9jbG91ZGd6LWVjcy5ncmF2aXR5em9uZS5iaXRkZWZlbmRlci5jb20vUGFja2FnZXMvQlNUV0lOLzAvYndLV0tWL2luc3RhbGxlci54bWw-bGFuZz1lcy1FUw.exe"
$expectedSHA256 = "2fd33220770ebd40cb0c3ef7fa3a735c070fb6d6a45bf2a41427e2804bf90967"

# -----------------------
# 1. Solicitar DNI
# -----------------------

$dniInput = Read-Host "Introduce tu DNI para continuar"

try {
    $csvContent = Invoke-WebRequest -Uri $dniCSVUrl -UseBasicParsing | Select-Object -ExpandProperty Content
    $dniList = $csvContent -split "`n" | ForEach-Object { $_.Trim() }
} catch {
    Write-Host "Error al obtener la lista de DNIs autorizados." -ForegroundColor Red
    exit 1
}

if (-not ($dniList -contains $dniInput)) {
    Write-Host "❌ DNI NO autorizado. Acceso denegado." -ForegroundColor Red
    exit 1
}

Write-Host "✅ DNI autorizado. Iniciando verificación..." -ForegroundColor Green

# -----------------------
# 2. Comprobar nombre del equipo
# -----------------------

$serial = (Get-WmiObject Win32_BIOS).SerialNumber.Trim()
$currentName = $env:COMPUTERNAME

if ($currentName -ne $serial) {
    Write-Host "Renombrando equipo de $currentName a $serial"
    Rename-Computer -NewName $serial -Force
    Write-Host "Reiniciando equipo..." -ForegroundColor Yellow
    Restart-Computer -Force
    exit
}

# -----------------------
# 3. Detectar antivirus instalado
# -----------------------

function Get-ThirdPartyAV {
    Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct |
    Where-Object { $_.displayName -ne "Microsoft Defender Antivirus" }
}

$av = Get-ThirdPartyAV
if ($av) {
    Write-Host "Desinstalando antivirus existente: $($av.displayName)" -ForegroundColor Yellow
    $uninstaller = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq $av.displayName }
    if ($uninstaller) {
        $uninstaller.Uninstall()
        Start-Sleep -Seconds 20
    }
}

# -----------------------
# 4. Descargar e instalar Bitdefender
# -----------------------

$tempInstaller = "$env:TEMP\bitdefender.exe"
Write-Host "Descargando instalador desde GitHub..."
Invoke-WebRequest -Uri $bitdefenderUrl -OutFile $tempInstaller -UseBasicParsing

# Validar hash
$computedHash = (Get-FileHash $tempInstaller -Algorithm SHA256).Hash
if ($computedHash -ne $expectedSHA256) {
    Write-Host "❌ ERROR: El archivo descargado no coincide con el hash esperado." -ForegroundColor Red
    Remove-Item $tempInstaller -Force
    exit 1
}

Write-Host "✅ Instalador verificado. Ejecutando..."
Start-Process -FilePath $tempInstaller

# Esperar a que se cierre (por si no es silencioso)
Start-Sleep -Seconds 15
Wait-Process -Name "setupdownloader_*" -ErrorAction SilentlyContinue

# -----------------------
# 5. Mensaje final
# -----------------------

[System.Windows.Forms.MessageBox]::Show("✅ Todo correcto. Instalación finalizada.", "Finalizado", "OK", "Information")