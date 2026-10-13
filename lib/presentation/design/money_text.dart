import 'package:flutter/material.dart';

import '../../core/format.dart';

/// Nominal Rupiah: "Rp 37.500", digit tabular, minus memakai tanda "−" (U+2212), bukan warna saja.
class MoneyText extends StatelessWidget {
  final int amount;
  final TextStyle? style; // bawaan: gaya teks sekitar
  final TextAlign? textAlign; // rata kanan di tabel dan struk

  const MoneyText(this.amount, {super.key, this.style, this.textAlign});

  static const minusSign = '−';

  /// Memakai [formatRupiah] untuk besaran, lalu tanda minus tipografis bila negatif.
  static String format(int amount) => amount < 0 ? '$minusSign${formatRupiah(-amount)}' : formatRupiah(amount);

  @override
  Widget build(BuildContext context) {
    return Text(
      format(amount),
      textAlign: textAlign,
      style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
