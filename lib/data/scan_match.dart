/// Hasil pencocokan ketikan/scan: [match] bila tepat satu barang, [candidates] = semua barang
/// yang namanya mengandung kata kunci (untuk "pilih dari daftar").
typedef ScanMatch<T> = ({T? match, List<T> candidates});

/// Cocokkan ketikan/scan: kode ([id]) persis dulu, lalu nama persis (abaikan huruf besar),
/// lalu nama yang mengandung kata kunci bila hanya satu.
ScanMatch<T> matchScan<T>(Iterable<T> items, String query, {required String Function(T) id, required String Function(T) name}) {
  final q = query.trim();
  if (q.isEmpty) return (match: null, candidates: <T>[]);
  for (final p in items) {
    if (id(p) == q) return (match: p, candidates: [p]);
  }
  final k = q.toLowerCase();
  final partial = items.where((p) => name(p).toLowerCase().contains(k)).toList();
  final exact = partial.where((p) => name(p).toLowerCase() == k).toList();
  if (exact.length == 1) return (match: exact.single, candidates: partial);
  return (match: partial.length == 1 ? partial.single : null, candidates: partial);
}
