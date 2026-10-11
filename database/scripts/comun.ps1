# Funciones compartidas por los scripts de database/scripts. No se ejecuta directamente.

function Read-DotEnv {
  param([string]$Ruta)
  $valores = @{}
  if (Test-Path $Ruta) {
    foreach ($linea in Get-Content $Ruta -Encoding utf8) {
      if ($linea -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
        $valores[$Matches[1]] = $Matches[2].Trim()
      }
    }
  }
  return $valores
}

function Get-ConexionMySql {
  param([string]$Base)
  $raiz = Resolve-Path (Join-Path $PSScriptRoot '..\..')
  $env_ = Read-DotEnv (Join-Path $raiz '.env')

  $mysql = (Get-Command mysql -ErrorAction SilentlyContinue).Source
  if (-not $mysql) { throw 'No se encontró el cliente mysql en el PATH.' }
  foreach ($clave in 'DB_USER', 'DB_PASSWORD') {
    if (-not $env_[$clave]) { throw "Falta $clave en .env (copia .env.example a .env y complétalo)." }
  }
  if ($env_['DB_USER'] -eq 'root') { throw 'La aplicación NO debe usar el usuario root.' }

  [pscustomobject]@{
    Mysql    = $mysql
    Host     = $(if ($env_['DB_HOST']) { $env_['DB_HOST'] } else { 'localhost' })
    Port     = $(if ($env_['DB_PORT']) { $env_['DB_PORT'] } else { '3306' })
    User     = $env_['DB_USER']
    Password = $env_['DB_PASSWORD']
    Base     = $Base
    Raiz     = $raiz
  }
}

function Invoke-MySql {
  param($Conexion, [string]$Sql, [string]$Archivo, [switch]$SinBase, [switch]$Silencioso)
  $argumentos = @("--host=$($Conexion.Host)", "--port=$($Conexion.Port)", "--user=$($Conexion.User)",
    '--default-character-set=utf8mb4')
  if (-not $SinBase) { $argumentos += $Conexion.Base }
  if ($Silencioso) { $argumentos += @('--batch', '--skip-column-names') }

  $env:MYSQL_PWD = $Conexion.Password
  # Windows PowerShell 5.1 envía el texto a los programas externos en ASCII y corrompe las tildes y la eñe.
  # Se fuerza UTF-8 (sin BOM) al enviar el SQL y se restaura al terminar.
  $codificacionPrevia = $global:OutputEncoding
  $global:OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  try {
    if ($Archivo) {
      Get-Content $Archivo -Raw -Encoding utf8 | & $Conexion.Mysql @argumentos
    } else {
      $Sql | & $Conexion.Mysql @argumentos
    }
    if ($LASTEXITCODE -ne 0) { throw "MySQL devolvió un error (código $LASTEXITCODE)." }
  }
  finally {
    $global:OutputEncoding = $codificacionPrevia
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
  }
}
