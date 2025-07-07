# verificar-dni.ps1

# CONFIGURA ESTOS DATOS ABAJO
$token     = "ghp_tuTokenPrivadoAQUI"  # 👈 NO RECOMENDADO EN PÚBLICO
$repo      = "tuusuario/repositorio-privado"
$branch    = "main"
$csvPath   = "datos/lista_dnis.csv"

# Ruta GitHub API
$apiUrl = "https://api.github.com/repos/$repo/contents/$csvPath?ref=$branch"

# Cabeceras
$headers = @{
    Authorization = "Bearer $token"
    Accept        = "application/vnd.github.v3.raw"
    "User-Agent"  = "dni-validator"
}

# Archivo temporal
$tempFile = "$env:TEMP\lista_dnis.csv"

# Descargar CSV
try {
    Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $tempFile
} catch {
    Write-Error "❌ Error al descargar el archivo CSV: $_"
    exit 1
}

# Pedir DNI
$dni = Read-Host "Introduce tu DNI"

# Leer CSV
$dniList = Get-Content $tempFile | Select-Object -Skip 1 | ForEach-Object { $_.Trim() }

# Verificar
if ($dniList -contains $dni) {
    Write-Host "✅ DNI validado correctamente."
} else {
    Write-Host "❌ DNI no encontrado en la lista."
}

# Limpiar
Remove-Item $tempFile -Force
