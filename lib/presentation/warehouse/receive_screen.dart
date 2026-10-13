import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/config.dart';
import '../../core/jakarta_time.dart';
import '../../data/providers.dart';
import '../../data/receive_lines.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import '../widgets/account_menu_button.dart';
import 'new_product_screen.dart';
import 'stock_inputs.dart';
import 'warehouse_widgets.dart';

/// Terima barang (gudang). Scan/cari menambah kartu per baris; "Simpan N barang" memanggil
/// RPC restock satu per baris secara berurutan. Baris sukses hilang, baris gagal tetap dengan
/// pesan server. restock tidak punya kunci idempotensi, jadi saat jaringan putus tidak ada
/// pengulangan otomatis: baris ditandai [uncertainSaveMessage] dan sisa baris tidak dikirim.
class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  final _lines = <ReceiveLine>[];
  int _nextKey = 1;
  String _lastFloor = storeFloors.first; // baris baru ikut lantai terakhir
  bool _saving = false;
  SaveSummary? _summary;

  DateTime get _now => ref.read(clockProvider)();

  /// Scan ulang barang yang sudah ada di daftar menambah jumlah baris terakhirnya.
  void _addProduct(ProductRow p) {
    setState(() {
      _summary = null;
      final existing = _lines.lastWhere((l) => l.productId == p['id'], orElse: () => _newLine(p));
      if (_lines.contains(existing)) {
        existing.qty += 1;
        existing.error = null;
      } else {
        _lines.add(existing);
      }
    });
  }

  ReceiveLine _newLine(ProductRow p) =>
      ReceiveLine(key: _nextKey++, productId: p['id'] as String, name: p['brand_name'] as String, unit: (p['unit_type'] as String?) ?? '', floor: _lastFloor);

  void _edit(ReceiveLine line, void Function() change) => setState(() {
        change();
        line.error = null;
        _summary = null;
      });

  Future<void> _openNewProduct(String code, VoidCallback resetSearch) async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NewProductScreen(initialCode: code)));
    if (!mounted) return;
    if (created == true) {
      ref.invalidate(productListProvider);
      ref.invalidate(stockListProvider);
      resetSearch();
    }
  }

  Future<void> _pickFromList() async {
    final picked = await showModalBottomSheet<ProductRow>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProductPickerSheet(products: ref.read(productListProvider).value ?? const []),
    );
    if (picked != null && mounted) _addProduct(picked);
  }

  Future<void> _save() async {
    if (_saving || saveBlockReason(_lines, _now) != null) return;
    setState(() {
      _saving = true;
      _summary = null;
    });
    final repo = ref.read(stockRepositoryProvider);
    var saved = 0, failed = 0;
    var offline = false;
    for (final line in List.of(_lines)) {
      try {
        await repo.restock(productId: line.productId, floor: line.floor, expiry: line.expiry, qty: line.qty);
        saved++;
        if (mounted) setState(() => _lines.remove(line));
      } on NetworkException catch (e) {
        // Hasil tidak diketahui: berhenti, jangan ulang otomatis; sisa baris belum dikirim.
        line.error = e.message;
        offline = true;
        break;
      } on AppException catch (e) {
        line.error = e.message;
        failed++;
      }
    }
    if (saved > 0) {
      ref.invalidate(stockListProvider);
      ref.invalidate(productListProvider);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _summary = (saved: saved, failed: failed, offline: offline);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final now = ref.watch(clockProvider)();
    final productsLoaded = ref.watch(productListProvider).hasValue;
    final blockReason = saveBlockReason(_lines, now);

    return WarehouseScaffold(
      title: 'Terima barang',
      actions: const [AccountMenuButton()],
      header: [
        ProductSearch(
          keyPrefix: 'receive',
          onPick: _addProduct,
          unknownAction: (code, reset) => StokasButton.secondary(
            key: const Key('receive-create-product'),
            label: 'Buat produk baru dengan kode ini',
            icon: Icons.add,
            onPressed: () => _openNewProduct(code, reset),
          ),
        ),
        if (_summary != null) SaveSummaryBanner(key: const Key('receive-summary'), summary: _summary!),
      ],
      content: [
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: StokasSpace.s5),
            child: Text(
              'Belum ada barang. Scan kode atau cari nama barang.',
              textAlign: TextAlign.center,
              style: StokasType.body.copyWith(color: c.inkMuted),
            ),
          ),
        for (final line in _lines)
          Padding(
            key: ValueKey('receive-line-${line.key}'),
            padding: const EdgeInsets.only(bottom: StokasSpace.s3),
            child: _LineCard(
              line: line,
              today: jakartaTodayLocal(now),
              problem: lineProblem(line, now),
              enabled: !_saving,
              onQty: (q) => _edit(line, () => line.qty = q),
              onFloor: (f) => _edit(line, () => line.floor = _lastFloor = f),
              onExpiry: (d) => _edit(line, () => line.expiry = d),
              onRemove: () => setState(() => _lines.remove(line)),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: StokasButton.secondary(
            key: const Key('receive-add-line'),
            label: 'Tambah baris',
            icon: Icons.add,
            onPressed: _saving || !productsLoaded ? null : _pickFromList,
          ),
        ),
      ],
      bottom: ActionBar(
        reason: blockReason,
        reasonKey: const Key('receive-save-reason'),
        button: StokasButton(
          key: const Key('receive-save'),
          label: _saving ? 'Menyimpan...' : (_lines.isEmpty ? 'Simpan barang' : 'Simpan ${_lines.length} barang'),
          icon: Icons.save_outlined,
          expand: true,
          onPressed: _saving || blockReason != null ? null : _save,
        ),
      ),
    );
  }
}

/// Kartu satu baris: nama, kode, stepper jumlah, lantai, kedaluwarsa opsional, pesan galat.
class _LineCard extends StatelessWidget {
  final ReceiveLine line;
  final DateTime today;
  final String? problem;
  final bool enabled;
  final ValueChanged<num> onQty;
  final ValueChanged<String> onFloor;
  final ValueChanged<DateTime?> onExpiry;
  final VoidCallback onRemove;

  const _LineCard({
    required this.line,
    required this.today,
    required this.problem,
    required this.enabled,
    required this.onQty,
    required this.onFloor,
    required this.onExpiry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final k = line.key;
    final hasIssue = problem != null || line.error != null;
    return Container(
      padding: const EdgeInsets.all(StokasSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StokasRadius.lg),
        border: Border.all(color: hasIssue ? c.negative : c.line),
      ),
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: StokasType.title.copyWith(color: c.ink)),
                      Text('Kode ${line.productId}', style: StokasType.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('receive-remove-$k'),
                  icon: Icon(Icons.delete_outline, color: c.inkMuted),
                  tooltip: 'Hapus baris',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: StokasSpace.s3),
            Wrap(
              spacing: StokasSpace.s4,
              runSpacing: StokasSpace.s3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QtyStepper(value: line.qty, onChanged: onQty, fieldKey: Key('receive-qty-$k')),
                    const SizedBox(width: StokasSpace.s2),
                    Text(line.unit, style: StokasType.body.copyWith(color: c.inkMuted)),
                  ],
                ),
                FloorPicker(key: Key('receive-floor-$k'), value: line.floor, onChanged: onFloor),
              ],
            ),
            const SizedBox(height: StokasSpace.s3),
            ExpiryField(
              buttonKey: Key('receive-expiry-$k'),
              value: line.expiry,
              today: today,
              onChanged: onExpiry,
              errorText: problem == pastDateMessage ? problem : null,
            ),
            if (problem != null && problem != pastDateMessage) ...[const SizedBox(height: StokasSpace.s2), FieldError(problem!)],
            if (line.error != null) ...[const SizedBox(height: StokasSpace.s2), FieldError(line.error!, key: Key('receive-error-$k'))],
          ],
        ),
      ),
    );
  }
}
