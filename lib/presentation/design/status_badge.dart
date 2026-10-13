import 'package:flutter/material.dart';

import 'stokas_tokens.dart';

enum StockStatus {
  aman('Stok aman', Icons.check_circle_outline),
  menipis('Menipis', Icons.warning_amber_rounded),
  bahaya('Kedaluwarsa', Icons.cancel_outlined);

  final String defaultLabel;
  final IconData icon;
  const StockStatus(this.defaultLabel, this.icon);
}

/// Lencana status stok: selalu ikon + kata, bukan warna saja (hijau dan merah hanya beda rona).
/// Satu lencana per baris; bila ada beberapa kondisi tampilkan yang paling parah.
class StatusBadge extends StatelessWidget {
  final StockStatus status;
  final String? label; // mis. "Habis" untuk status bahaya; bawaan dari [StockStatus]

  const StatusBadge(this.status, {super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final (fg, bg) = switch (status) {
      StockStatus.aman => (c.positive, c.positiveSoft),
      StockStatus.menipis => (c.warning, c.warningSoft),
      StockStatus.bahaya => (c.negative, c.negativeSoft),
    };
    final text = label ?? status.defaultLabel;

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s2, vertical: StokasSpace.s1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(StokasRadius.sm)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: fg),
            const SizedBox(width: StokasSpace.s1),
            Text(text, style: StokasType.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
