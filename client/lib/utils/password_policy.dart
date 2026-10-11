/// Política mínima de contraseñas (la misma que valida el servidor): al menos 8 caracteres con una
/// mayúscula, una minúscula y un número. Devuelve el mensaje del incumplimiento o null si es válida.
String? checkPasswordPolicy(String password) {
  if (password.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
  if (!RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(password)) return 'La contraseña debe incluir al menos una letra mayúscula.';
  if (!RegExp(r'[a-záéíóúñ]').hasMatch(password)) return 'La contraseña debe incluir al menos una letra minúscula.';
  if (!RegExp(r'[0-9]').hasMatch(password)) return 'La contraseña debe incluir al menos un número.';
  return null;
}

const String kPasswordPolicyHint = 'Mínimo 8 caracteres, con una mayúscula, una minúscula y un número.';
