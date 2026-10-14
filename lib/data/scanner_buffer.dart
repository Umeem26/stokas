import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jeda maksimum antar-karakter (ms) agar ketikan dianggap berasal dari scanner.
const scannerMaxGapMs = 80;

/// Panjang minimum kode scan (karakter sebelum Enter).
const scannerMinLength = 3;

/// Jam untuk mengukur jeda ketikan scanner; bisa di-override di tes.
final scannerClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Penampung ketikan scanner USB (scanner = keyboard yang mengetik sangat cepat lalu Enter).
/// Karakter beruntun dengan jeda <= [scannerMaxGapMs] dikumpulkan; jeda lebih lama memulai
/// tampungan baru (ketikan manusia tidak pernah jadi scan).
class ScannerBuffer {
  final _chars = StringBuffer();
  DateTime? _last;

  bool _fresh(DateTime now) => _last != null && now.difference(_last!).inMilliseconds <= scannerMaxGapMs;

  /// Sedang di tengah ketikan cepat (karakter berikutnya ikut ditampung).
  bool isActive(DateTime now) => _chars.isNotEmpty && _fresh(now);

  void add(String char, DateTime now) {
    if (!_fresh(now)) _chars.clear();
    _chars.write(char);
    _last = now;
  }

  /// Enter: kode scan bila tampungan cukup panjang dan masih segar, selain itu null.
  /// Tampungan selalu dikosongkan.
  String? submit(DateTime now) {
    final code = _fresh(now) && _chars.length >= scannerMinLength ? _chars.toString() : null;
    clear();
    return code;
  }

  void clear() {
    _chars.clear();
    _last = null;
  }
}

/// Maksimum baris hasil pencarian di mode PC.
const searchResultLimit = 8;

/// Hasil pencarian mode PC: kode persis, lalu nama berawalan kata kunci, lalu nama/kode
/// yang mengandung kata kunci; urut nama di dalam tiap kelompok; maks [limit].
List<T> searchResults<T>(Iterable<T> items, String query,
    {required String Function(T) id, required String Function(T) name, int limit = searchResultLimit}) {
  final k = query.trim().toLowerCase();
  if (k.isEmpty) return [];
  int rank(T p) {
    if (id(p).toLowerCase() == k) return 0;
    if (name(p).toLowerCase().startsWith(k)) return 1;
    return 2;
  }

  final hits = items.where((p) => name(p).toLowerCase().contains(k) || id(p).toLowerCase().contains(k)).toList()
    ..sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : name(a).toLowerCase().compareTo(name(b).toLowerCase());
    });
  return hits.take(limit).toList();
}
