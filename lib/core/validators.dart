// Validasi form sisi klien. Mengembalikan pesan error, atau null jika valid.

final _usernamePattern = RegExp(r'^[a-z0-9._@+-]{3,60}$');

String? validateLoginIdentifier(String? value) {
  if (value == null || value.trim().isEmpty) return 'Username atau email wajib diisi';
  return null;
}

String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) return 'Password wajib diisi';
  return null;
}

String? validateStaffUsername(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (v.isEmpty) return 'Username wajib diisi';
  if (!_usernamePattern.hasMatch(v)) {
    return 'Username 3-60 karakter: huruf, angka, titik, strip, garis bawah';
  }
  return null;
}

String? validateStaffFullName(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Nama wajib diisi';
  if (v.length > 80) return 'Nama maksimal 80 karakter';
  return null;
}

String? validateStaffPassword(String? value) {
  if (value == null || value.length < 8) return 'Password minimal 8 karakter';
  return null;
}

final _rupiahPattern = RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$');

/// Isian uang (harga/modal): bilangan bulat >= 0, boleh bertitik ribuan ("12.500").
String? validateRupiahInput(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Wajib diisi (boleh 0)';
  if (!_rupiahPattern.hasMatch(v)) return 'Isi bilangan bulat 0 atau lebih';
  return null;
}

/// Minimum stok: angka >= 0 (boleh pecahan untuk gram/liter).
String? validateMinStock(String? value) {
  final n = num.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (n == null || n < 0) return 'Isi angka 0 atau lebih';
  return null;
}
