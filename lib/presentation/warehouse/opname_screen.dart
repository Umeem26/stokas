import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/format.dart';
import '../../core/jakarta_time.dart';
import '../../data/providers.dart';
import '../../data/stock_availability.dart';
import '../../data/stock_ops.dart';
import '../design/status_badge.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import '../widgets/account_menu_button.dart';
import 'stock_inputs.dart';
import 'warehouse_widgets.dart';

const writeOffNote = 'Tulis rugi';

/// Batch stok (jumlah > 0) milik [productId], urut lantai lalu tanggal kedaluwarsa.
List<Map<String, dynamic>> batchesOf(List<Map<String, dynamic>> stocks, String productId) {
  final rows = stocks.where((r) => r['product_id'] == productId && ((r['quantity'] as num?) ?? 0) > 0).toList();
  rows.sort((a, b) {
    final byFloor = '${a['floor_name']}'.compareTo('${b['floor_name']}');
    return byFloor != 0 ? byFloor : '${a['expiry_date'] ?? '9999'}'.compareTo('${b['expiry_date'] ?? '9999'}');
  });
  return rows;
}

DateTime? batchExpiry(Map<String, dynamic> stock) {
  final e = stock['expiry_date'] as String?;
  return e == null || e.isEmpty ? null : DateTime.parse(e.substring(0, 10));
}

/// "Lantai 1 · Exp 12 Okt 2026" / "Lantai 1 · Tanpa tanggal kedaluwarsa".
String batchLabel(Map<String, dynamic> stock) {
  final expiry = batchExpiry(stock);
  return '${stock['floor_name']} · ${expiry == null ? 'Tanpa tanggal kedaluwarsa' : 'Exp ${formatDayId(expiry)}'}';
}

/// Konfirmasi tulis rugi: menyebut nama, jumlah, tanggal kedaluwarsa. Bahaya di kiri, Batal di kanan.
Future<bool> confirmWriteOff(BuildContext context, {required String name, required String amount, required String expiry, required String floor}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final c = context.stokas;
      return AlertDialog(
        title: const Text('Tulis rugi?'),
        content: Text(
          '$name, $amount, kedaluwarsa $expiry di $floor akan dijadikan 0 dengan catatan "$writeOffNote".',
          style: StokasType.bodyLg.copyWith(color: c.ink),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          StokasButton.danger(
            key: const Key('writeoff-confirm'),
            label: 'Tulis rugi',
            onPressed: () => Navigator.pop(context, true),
          ),
          StokasButton.secondary(
            key: const Key('writeoff-cancel'),
            label: 'Batal',
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Opname (gudang): pilih/scan barang, isi jumlah hitung nyata per batch; selisih tampil sebagai
/// ikon + kata. Simpan memanggil RPC stock_count satu per batch yang berubah (berurutan); batch
/// sukses hilang dari daftar, gagal tetap dengan pesan server. stock_count tanpa kunci
/// idempotensi: jaringan putus tidak diulang otomatis. Batch kedaluwarsa bisa ditulis rugi.
class OpnameScreen extends ConsumerStatefulWidget {
  const OpnameScreen({super.key});

  @override
  ConsumerState<OpnameScreen> createState() => _OpnameScreenState();
}

class _OpnameScreenState extends ConsumerState<OpnameScreen> {
  ProductRow? _product;
  final _counts = <int, TextEditingController>{};
  final _errors = <int, String>{};
  final _done = <int>{}; // batch yang sudah tersimpan pada sesi ini
  final _note = TextEditingController();
  bool _saving = false;
  SaveSummary? _summary;

  @override
  void dispose() {
    _clearCounts();
    _note.dispose();
    super.dispose();
  }

  void _clearCounts() {
    for (final c in _counts.values) {
      c.dispose();
    }
    _counts.clear();
  }

  void _select(ProductRow p) => setState(() {
        _product = p;
        _clearCounts();
        _errors.clear();
        _done.clear();
        _summary = null;
      });

  TextEditingController _countFor(int id) => _counts.putIfAbsent(id, TextEditingController.new);

  String get _unit => (_product?['unit_type'] as String?) ?? '';

  List<Map<String, dynamic>> _visibleBatches() {
    final p = _product;
    final stocks = ref.watch(stockListProvider).value;
    if (p == null || stocks == null) return const [];
    return batchesOf(stocks, p['id'] as String).where((s) => !_done.contains(s['id'])).toList();
  }

  /// Hitung nyata yang diisi; null = kosong (tidak berubah); negatif/bukan angka = invalid.
  ({num? value, bool invalid}) _counted(int id) {
    final text = _counts[id]?.text.trim() ?? '';
    if (text.isEmpty) return (value: null, invalid: false);
    final v = parseQty(text);
    return (value: v, invalid: v == null || v < 0);
  }

  bool _isChanged(Map<String, dynamic> s) {
    final c = _counted(s['id'] as int);
    return !c.invalid && c.value != null && c.value != s['quantity'] as num;
  }

  String? _blockReason(List<Map<String, dynamic>> batches) {
    if (_product == null) return 'Pilih barang dulu.';
    final invalid = batches.where((s) => _counted(s['id'] as int).invalid).length;
    if (invalid > 0) return 'Belum bisa disimpan: $invalid baris jumlah hitungnya tidak valid.';
    if (!batches.any(_isChanged)) return 'Belum ada jumlah yang berubah.';
    return null;
  }

  Future<void> _save() async {
    final batches = _visibleBatches();
    if (_saving || _blockReason(batches) != null) return;
    setState(() {
      _saving = true;
      _summary = null;
      _errors.clear();
    });
    final repo = ref.read(stockRepositoryProvider);
    var saved = 0, failed = 0;
    var offline = false;
    for (final s in batches.where(_isChanged).toList()) {
      final id = s['id'] as int;
      try {
        await repo.stockCount(
          productId: s['product_id'] as String,
          floor: s['floor_name'] as String,
          expiry: batchExpiry(s),
          counted: _counted(id).value!,
          note: _note.text,
        );
        saved++;
        if (mounted) setState(() => _done.add(id));
      } on NetworkException catch (e) {
        // Hasil tidak diketahui: berhenti, jangan ulang otomatis.
        _errors[id] = e.message;
        offline = true;
        break;
      } on AppException catch (e) {
        _errors[id] = e.message;
        failed++;
      }
    }
    if (saved > 0) ref.invalidate(stockListProvider);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _summary = (saved: saved, failed: failed, offline: offline);
    });
  }

  Future<void> _writeOff(Map<String, dynamic> s) async {
    final id = s['id'] as int;
    final amount = '${formatQty(s['quantity'] as num)} $_unit'.trim();
    final ok = await confirmWriteOff(
      context,
      name: '${_product!['brand_name']}',
      amount: amount,
      expiry: formatDayId(batchExpiry(s)!),
      floor: '${s['floor_name']}',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _errors.remove(id);
    });
    try {
      await ref.read(stockRepositoryProvider).stockCount(
            productId: s['product_id'] as String,
            floor: s['floor_name'] as String,
            expiry: batchExpiry(s),
            counted: 0,
            note: writeOffNote,
          );
      if (!mounted) return;
      _done.add(id);
      ref.invalidate(stockListProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tulis rugi tersimpan: ${_product!['brand_name']} $amount')));
    } on AppException catch (e) {
      _errors[id] = e.message;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final now = ref.watch(clockProvider)();
    final stocks = ref.watch(stockListProvider);
    final batches = _visibleBatches();
    final reason = _blockReason(batches);
    final changed = batches.where(_isChanged).length;
    final product = _product;

    return WarehouseScaffold(
      title: 'Opname',
      actions: const [AccountMenuButton()],
      header: [
        ProductSearch(keyPrefix: 'opname', onPick: _select),
        if (_summary != null) SaveSummaryBanner(key: const Key('opname-summary'), summary: _summary!),
      ],
      content: [
        if (product == null)
          const _Hint('Scan atau cari barang yang mau dihitung.')
        else ...[
          Text('${product['brand_name']}', style: StokasType.titleLg.copyWith(color: c.ink)),
          Text('Kode ${product['id']}', style: StokasType.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: StokasSpace.s3),
          if (stocks.isLoading && !stocks.hasValue)
            const _Hint('Memuat stok...')
          else if (stocks.hasError)
            Notice(
              icon: Icons.error_outline,
              color: c.negative,
              text: 'Stok gagal dimuat. ${stocks.error}',
              action: StokasButton.secondary(label: 'Coba lagi', onPressed: () => ref.invalidate(stockListProvider)),
            )
          else if (batches.isEmpty)
            const _Hint('Belum ada stok. Terima barang dulu.')
          else ...[
            for (final s in batches)
              Padding(
                key: ValueKey('opname-row-${s['id']}'),
                padding: const EdgeInsets.only(bottom: StokasSpace.s3),
                child: _OpnameRow(
                  stock: s,
                  unit: _unit,
                  controller: _countFor(s['id'] as int),
                  expired: isBatchExpired(s, now),
                  invalid: _counted(s['id'] as int).invalid,
                  error: _errors[s['id']],
                  enabled: !_saving,
                  onChanged: () => setState(() {
                    _errors.remove(s['id']);
                    _summary = null;
                  }),
                  onWriteOff: () => _writeOff(s),
                ),
              ),
            TextField(
              key: const Key('opname-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ],
        ],
      ],
      bottom: ActionBar(
        reason: reason,
        reasonKey: const Key('opname-save-reason'),
        button: StokasButton(
          key: const Key('opname-save'),
          label: _saving ? 'Menyimpan...' : (changed == 0 ? 'Simpan opname' : 'Simpan $changed perubahan'),
          icon: Icons.save_outlined,
          expand: true,
          onPressed: _saving || reason != null ? null : _save,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: StokasSpace.s5),
        child: Text(text, textAlign: TextAlign.center, style: StokasType.body.copyWith(color: context.stokas.inkMuted)),
      );
}

/// Selisih opname: ikon + kata ("Lebih +2 pcs", "Kurang −3 pcs", "Sama"), bukan warna saja.
class CountDiffBadge extends StatelessWidget {
  final num recorded;
  final num counted;
  final String unit;

  const CountDiffBadge({super.key, required this.recorded, required this.counted, required this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final (icon, fg, bg) = switch (countDiff(recorded, counted).kind) {
      CountDiff.lebih => (Icons.add_circle_outline, c.positive, c.positiveSoft),
      CountDiff.kurang => (Icons.remove_circle_outline, c.negative, c.negativeSoft),
      CountDiff.sama => (Icons.check_circle_outline, c.inkMuted, c.surfaceSunken),
    };
    final text = countDiffLabel(recorded, counted, unit);
    return Semantics(
      label: 'Selisih $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s2, vertical: StokasSpace.s1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(StokasRadius.sm)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: StokasSpace.s1),
            Text(text, style: StokasType.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

class _OpnameRow extends StatelessWidget {
  final Map<String, dynamic> stock;
  final String unit;
  final TextEditingController controller;
  final bool expired;
  final bool invalid;
  final String? error;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onWriteOff;

  const _OpnameRow({
    required this.stock,
    required this.unit,
    required this.controller,
    required this.expired,
    required this.invalid,
    required this.error,
    required this.enabled,
    required this.onChanged,
    required this.onWriteOff,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final id = stock['id'];
    final recorded = stock['quantity'] as num;
    final counted = parseQty(controller.text);
    return Container(
      padding: const EdgeInsets.all(StokasSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StokasRadius.lg),
        border: Border.all(color: error != null || invalid ? c.negative : c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(batchLabel(stock), style: StokasType.title.copyWith(color: c.ink))),
              if (expired) const StatusBadge(StockStatus.bahaya),
            ],
          ),
          Text('Tercatat ${formatQty(recorded)} $unit', style: StokasType.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: StokasSpace.s3),
          Wrap(
            spacing: StokasSpace.s3,
            runSpacing: StokasSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: StokasSpace.s8 * 3,
                child: TextField(
                  key: Key('opname-count-$id'),
                  controller: controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: 'Jumlah hitung nyata', suffixText: unit),
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (counted != null && !invalid) CountDiffBadge(key: Key('opname-diff-$id'), recorded: recorded, counted: counted, unit: unit),
              if (expired)
                StokasButton.danger(
                  key: Key('opname-writeoff-$id'),
                  label: 'Tulis rugi',
                  icon: Icons.delete_sweep_outlined,
                  onPressed: enabled ? onWriteOff : null,
                ),
            ],
          ),
          if (invalid) ...[
            const SizedBox(height: StokasSpace.s2),
            const FieldError('Jumlah hitung tidak valid'),
          ],
          if (error != null) ...[
            const SizedBox(height: StokasSpace.s2),
            FieldError(error!, key: Key('opname-error-$id')),
          ],
        ],
      ),
    );
  }
}
