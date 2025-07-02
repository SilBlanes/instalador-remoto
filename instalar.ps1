Add-Type -AssemblyName System.Windows.Forms

# -----------------------
# CONFIGURACIÓN
# -----------------------

# Token de GitHub (debe pasarse desde el .bat por variable de entorno)
$token = $env:GITHUB_TOKEN

if (-not $token) {
    Write-Host "❌ Token de GitHub no disponible. Aborta." -ForegroundColor Red
    exit 1
}

# URL para obtener el contenido raw del CSV desde un repo privado
$dniCSVUrl = "https://api.github.com/repos/SilBlanes/instalador/contents/dnis.csv?ref=main"

# Cabeceras para autenticar y obtener contenido plano
$headers = @{
    Authorization = "token $token"
    Accept        = "application/vnd.github.v3.raw"
    User-Agent    = "PowerShell"
}

# URL y hash esperado del instalador Bitdefender
$bitdefenderUrl = "https://github.com/SilBlanes/instalador/releases/download/v1.0/setupdownloader_.aHR0cHM6Ly9jbG91ZGd6LWVjcy5ncmF2aXR5em9uZS5iaXRkZWZlbmRlci5jb20vUGFja2FnZXMvQlNUV0lOLzAvYndLV0tWL2luc3RhbGxlci54bWw-bGFuZz1lcy1FUw.exe"
$expectedSHA256 = "2fd33220770ebd40cb0c3ef7fa3a735c070fb6d6a45bf2a41427e2804bf90967"

# -----------------------
# 1. Solicitar DNI
# -----------------------

$dniInput = Read-Host "Introduce tu DNI para continuar"

try {
    $csvContent = Invoke-RestMethod -Uri $dniCSVUrl -Headers $headers
    if (-not $csvContent) {
        Write-Host "❌ El contenido CSV está vacío." -ForegroundColor Red
        exit 1
    }
    $dniList = $csvContent -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} catch {
    Write-Host "❌ Error al acceder al CSV desde GitHub privado: $_" -ForegroundColor Red
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
    Rename-Computer -NewName $serial -Force -ErrorAction Stop
    Write-Host "Reiniciando equipo..." -ForegroundColor Yellow
    Restart-Computer -Force
    exit
}

# -----------------------
# 3. Detectar antivirus instalado
# -----------------------

function Get-ThirdPartyAV {
    Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct |
    Where-Object { $_.displayName -and $_.displayName -ne "Microsoft Defender Antivirus" }
}

$av = Get-ThirdPartyAV
if ($av) {
    foreach ($avProduct in $av) {
        Write-Host "Desinstalando antivirus existente: $($avProduct.displayName)" -ForegroundColor Yellow
        $uninstaller = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq $avProduct.displayName }
        if ($uninstaller) {
            $uninstaller.Uninstall() | Out-Null
            Write-Host "Esperando 30 segundos para completar la desinstalación..."
            Start-Sleep -Seconds 30
        } else {
            Write-Host "No se encontró el instalador para $($avProduct.displayName). Debe desinstalarse manualmente." -ForegroundColor Red
        }
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

# Ejecutar el instalador y esperar a que termine
$process = Start-Process -FilePath $tempInstaller -PassThru
$process.WaitForExit()

# -----------------------
# 5. Mensaje final
# -----------------------

[System.Windows.Forms.MessageBox]::Show("✅ Todo correcto. Instalación finalizada.", "Finalizado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
