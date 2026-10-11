<#
.SYNOPSIS
  Crea las bases motorix y motorix_test y el usuario dedicado motorix_app.
.DESCRIPTION
  Usa una cuenta administradora de MySQL (por ejemplo root) SOLO para este paso inicial.
  La aplicación nunca usa root. Las contraseñas se piden por consola y no se guardan en archivos.
.EXAMPLE
  database/scripts/crear-entorno.ps1
#>
param(
  [string]$Servidor = 'localhost',
  [int]$Puerto = 3306,
  [string]$UsuarioAdmin = 'root',
  [string]$UsuarioApp = 'motorix_app'
)

$ErrorActionPreference = 'Stop'

$mysql = (Get-Command mysql -ErrorAction SilentlyContinue).Source
if (-not $mysql) {
  throw 'No se encontró el cliente mysql en el PATH. Instala MySQL Server 8.0 o agrega su carpeta bin al PATH.'
}

function ConvertTo-PlainText([System.Security.SecureString]$Secure) {
  $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
  try { [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$claveAdmin = ConvertTo-PlainText (Read-Host "Contraseña de MySQL para '$UsuarioAdmin'" -AsSecureString)
$claveApp = ConvertTo-PlainText (Read-Host "Contraseña NUEVA para el usuario '$UsuarioApp' (será tu DB_PASSWORD)" -AsSecureString)
if ($claveApp.Length -lt 8) { throw 'La contraseña de la aplicación debe tener al menos 8 caracteres.' }
if ($claveApp.Contains("'") -or $claveApp.Contains('\')) {
  throw "La contraseña no puede contener comillas simples ni barras invertidas."
}

$sql = @"
CREATE DATABASE IF NOT EXISTS motorix CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS motorix_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS '$UsuarioApp'@'localhost' IDENTIFIED BY '$claveApp';
ALTER USER '$UsuarioApp'@'localhost' IDENTIFIED BY '$claveApp';
GRANT ALL PRIVILEGES ON motorix.* TO '$UsuarioApp'@'localhost';
GRANT ALL PRIVILEGES ON motorix_test.* TO '$UsuarioApp'@'localhost';
FLUSH PRIVILEGES;
"@

# La contraseña del administrador se pasa por variable de entorno para no mostrarla en la línea de comandos.
$env:MYSQL_PWD = $claveAdmin
try {
  $sql | & $mysql --host=$Servidor --port=$Puerto --user=$UsuarioAdmin --default-character-set=utf8mb4
  if ($LASTEXITCODE -ne 0) { throw 'MySQL rechazó la creación del entorno.' }
}
finally {
  Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}

Write-Host "Entorno creado: bases 'motorix' y 'motorix_test', usuario '$UsuarioApp'."
Write-Host "Copia .env.example a .env y escribe esa contraseña en DB_PASSWORD."
