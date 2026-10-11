<#
.SYNOPSIS
  Elimina todas las tablas de la base indicada y la recrea: migraciones y seeds desde cero.
.DESCRIPTION
  Es destructivo: pide confirmación escribiendo el nombre de la base (omítela con -Forzar).
.EXAMPLE
  database/scripts/reiniciar-local.ps1 -Base motorix
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('motorix', 'motorix_test')][string]$Base,
  [switch]$Forzar,
  [switch]$SinSeeds
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')

if (-not $Forzar) {
  $respuesta = Read-Host "Se borrarán TODOS los datos de '$Base'. Escribe el nombre de la base para confirmar"
  if ($respuesta -ne $Base) { Write-Host 'Cancelado.'; return }
}

$conexion = Get-ConexionMySql -Base $Base

# Se eliminan TODAS las tablas de la base (no una lista fija), de modo que las tablas que agregue cada
# sprint tampoco impidan recrear el esquema desde cero.
$tablas = @(Invoke-MySql -Conexion $conexion -Sql 'SHOW TABLES;' -Silencioso | Where-Object { $_ })
if ($tablas.Count -gt 0) {
  $comilla = [char]96
  $lista = ($tablas | ForEach-Object { "$comilla$($_.Trim())$comilla" }) -join ', '
  Invoke-MySql -Conexion $conexion -Sql "SET FOREIGN_KEY_CHECKS = 0; DROP TABLE IF EXISTS $lista; SET FOREIGN_KEY_CHECKS = 1;"
}

& (Join-Path $PSScriptRoot 'aplicar-migraciones.ps1') -Base $Base
if (-not $SinSeeds) { & (Join-Path $PSScriptRoot 'aplicar-seeds.ps1') -Base $Base }

Write-Host "Base '$Base' reiniciada."
