/// Domain email sintetis untuk akun staf yang login dengan username.
/// Harus sama dengan STAFF_EMAIL_DOMAIN di supabase/functions/staff-admin.
/// TLD .invalid dicadangkan standar internet, jadi tidak pernah mengirim email sungguhan.
const staffEmailDomain = 'staff.pos.invalid';

/// Ubah input "Username atau email" menjadi email untuk Supabase Auth.
/// Jika mengandung '@' dipakai apa adanya (hanya spasi di tepi yang dibuang).
String usernameToEmail(String input) {
  final value = input.trim();
  if (value.contains('@')) return value;
  return '${value.toLowerCase()}@$staffEmailDomain';
}
