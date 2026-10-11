<#
.SYNOPSIS
  Aplica en orden las migraciones de database/migrations/ que aún no estén registradas.
.DESCRIPTION
  Es idempotente: registra cada versión en schema_migrations y omite las ya aplicadas.
.EXAMPLE
  database/scripts/aplicar-migraciones.ps1 -Base motorix
  database/scripts/aplicar-migraciones.ps1 -Base motorix_test
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('motorix', 'motorix_test')][string]$Base
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')

$conexion = Get-ConexionMySql -Base $Base

Invoke-MySql -Conexion $conexion -Sql @'
CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(100) NOT NULL,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
'@

$aplicadas = @(Invoke-MySql -Conexion $conexion -Sql 'SELECT version FROM schema_migrations;' -Silencioso)
$carpeta = Join-Path $conexion.Raiz 'database\migrations'
$archivos = Get-ChildItem $carpeta -Filter '*.sql' | Sort-Object Name

$nuevas = 0
foreach ($archivo in $archivos) {
  $version = [System.IO.Path]::GetFileNameWithoutExtension($archivo.Name)
  if ($aplicadas -contains $version) {
    Write-Host "Omitida (ya aplicada): $version"
    continue
  }
  Write-Host "Aplicando: $version"
  Invoke-MySql -Conexion $conexion -Archivo $archivo.FullName
  Invoke-MySql -Conexion $conexion -Sql "INSERT INTO schema_migrations (version) VALUES ('$version');"
  $nuevas++
}

Write-Host "Migraciones nuevas aplicadas en '$Base': $nuevas"
