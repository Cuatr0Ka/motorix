// Formatos de fecha, hora e importes para mostrar en pantalla (sin dependencias adicionales).

String _two(int value) => value.toString().padLeft(2, '0');

/// 12/10/2026
String formatDate(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

/// 15:30
String formatTime(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// 12/10/2026 15:30
String formatDateTime(DateTime value) => '${formatDate(value)} ${formatTime(value)}';

/// Importe decimal de la API ("1250.00") → "$1,250.00".
String formatMoney(String amount) {
  final parsed = double.tryParse(amount);
  if (parsed == null) return amount;
  final fixed = parsed.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '\$${buffer.toString()}.${parts[1]}';
}

/// Kilometraje con separador de miles: 84500 → "84,500 km".
String formatMileage(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer km';
}
