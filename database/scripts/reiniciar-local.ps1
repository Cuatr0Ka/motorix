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

Invoke-MySql -Conexion $conexion -Sql @"
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS vehicles, clients, users, schema_migrations;
SET FOREIGN_KEY_CHECKS = 1;
"@

& (Join-Path $PSScriptRoot 'aplicar-migraciones.ps1') -Base $Base
if (-not $SinSeeds) { & (Join-Path $PSScriptRoot 'aplicar-seeds.ps1') -Base $Base }

Write-Host "Base '$Base' reiniciada."
