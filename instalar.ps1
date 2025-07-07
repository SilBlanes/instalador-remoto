# instalar.ps1

# URL del CSV con DNIs válidos
$csvUrl = "https://raw.githubusercontent.com/SilBlanes/instalador-remoto/main/dnis.csv"
$tempCsv = "$env:TEMP\lista_dnis.csv"

Write-Host "🔄 Descargando lista de DNIs válidos..."

try {
    Invoke-WebRequest -Uri $csvUrl -OutFile $tempCsv -UseBasicParsing
} catch {
    Write-Host "❌ Error al descargar el archivo CSV: $_"
    exit 1
}

# Solicitar DNI al usuario
$dni = Read-Host "🔐 Introduce tu DNI"

# Leer lista desde CSV
$dniList = Import-Csv -Path $tempCsv | ForEach-Object { $_.dni.Trim() }

# Validar DNI
if ($dniList -contains $dni) {
    Write-Host "`n✅ DNI validado correctamente. Continuando con la instalación..."
    # Aquí puedes continuar con la lógica de instalación
} else {
    Write-Host "`n❌ DNI no válido. El instalador se cerrará."
    exit 1
}

# Limpieza
Remove-Item $tempCsv -Force
