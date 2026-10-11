<#
.SYNOPSIS
  Ejecuta los seeds de database/seeds/ sobre la base indicada.
.DESCRIPTION
  Los seeds son idempotentes (claves únicas): se pueden repetir sin duplicar registros.
.EXAMPLE
  database/scripts/aplicar-seeds.ps1 -Base motorix
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('motorix', 'motorix_test')][string]$Base
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')

$conexion = Get-ConexionMySql -Base $Base
$archivos = Get-ChildItem (Join-Path $conexion.Raiz 'database\seeds') -Filter '*.sql' | Sort-Object Name

foreach ($archivo in $archivos) {
  Write-Host "Ejecutando seed: $($archivo.Name)"
  Invoke-MySql -Conexion $conexion -Archivo $archivo.FullName
}

Write-Host "Seeds aplicados en '$Base'."
