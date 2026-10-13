/// Pecahan uang kertas untuk tombol uang cepat.
const cashDenominations = [2000, 5000, 10000, 20000, 50000, 100000];

/// Kelipatan pembulatan untuk total di atas pecahan terbesar.
const _largeStep = 50000;

/// Nominal tombol uang cepat untuk [total], di luar tombol "Uang pas" yang selalu ada.
///
/// Total <= 100.000: pecahan terkecil yang menutup total lalu dua pecahan di atasnya
/// (yang ada saja). Total > 100.000: dibulatkan ke atas ke kelipatan 50.000, lalu dua
/// kelipatan berikutnya. Nilai yang sama dengan total tidak diulang (sudah "Uang pas"),
/// sehingga deretnya bergeser ke nominal berikutnya. Maksimal 3 nominal.
List<int> quickCashAmounts(int total) {
  if (total <= 0) return const [];
  if (total > cashDenominations.last) {
    final first = (total ~/ _largeStep + 1) * _largeStep;
    return [first, first + _largeStep, first + 2 * _largeStep];
  }
  return cashDenominations.where((d) => d > total).take(3).toList();
}
