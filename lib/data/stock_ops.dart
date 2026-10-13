import '../core/format.dart';

/// Selisih opname: hitung nyata dibanding jumlah tercatat.
enum CountDiff { lebih, kurang, sama }

/// Jenis selisih dan besarnya ([counted] - [recorded]).
({CountDiff kind, num delta}) countDiff(num recorded, num counted) {
  final delta = counted - recorded;
  return (kind: delta > 0 ? CountDiff.lebih : (delta < 0 ? CountDiff.kurang : CountDiff.sama), delta: delta);
}

/// Label selisih dengan tanda, mis. "Lebih +2 pcs", "Kurang −3 pcs", "Sama".
String countDiffLabel(num recorded, num counted, String unit) {
  final d = countDiff(recorded, counted);
  final amount = '${formatQty(d.delta.abs())} $unit'.trim();
  return switch (d.kind) {
    CountDiff.lebih => 'Lebih +$amount',
    CountDiff.kurang => 'Kurang −$amount',
    CountDiff.sama => 'Sama',
  };
}

/// Alasan tombol Pindahkan nonaktif; null bila boleh. [available] = jumlah batch asal.
String? transferBlockReason({
  required bool hasProduct,
  required num? available,
  required String? from,
  required String to,
  required num qty,
  String unit = '',
}) {
  if (!hasProduct) return 'Pilih barang dulu.';
  if (available == null || from == null) return 'Pilih stok asal.';
  if (from == to) return 'Lantai tujuan harus berbeda dari lantai asal.';
  if (qty <= 0) return 'Jumlah harus lebih dari 0.';
  if (qty > available) return 'Jumlah melebihi stok asal (${'${formatQty(available)} $unit'.trim()}).';
  return null;
}
