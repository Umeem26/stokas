import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../data/stock_availability.dart';
import '../../data/stock_ops.dart';
import '../design/status_badge.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import '../widgets/account_menu_button.dart';
import 'opname_screen.dart' show batchesOf, batchExpiry, batchLabel;
import 'stock_inputs.dart';
import 'warehouse_widgets.dart';

/// Pindah stok antar-lantai (gudang). RPC transfer_stock bekerja pada SATU batch
/// (produk, lantai asal, tanggal kedaluwarsa): jumlah dikurangi dari batch itu dan ditambahkan
/// ke batch bertanggal sama di lantai tujuan. Server tidak memeriksa kedaluwarsa, jadi stok
/// asal dipilih per batch di sini. Jumlah tidak boleh melebihi isi batch asal.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  ProductRow? _product;
  int? _batchId;
  String? _to; // null = lantai lain dari lantai asal
  num _qty = 1;
  bool _saving = false;
  String? _error;
  String? _done;

  String get _unit => (_product?['unit_type'] as String?) ?? '';

  void _select(ProductRow p) => setState(() {
        _product = p;
        _batchId = null;
        _to = null;
        _qty = 1;
        _error = null;
        _done = null;
      });

  void _change(void Function() update) => setState(() {
        update();
        _error = null;
        _done = null;
      });

  Future<void> _save(Map<String, dynamic> batch, String to) async {
    setState(() {
      _saving = true;
      _error = null;
      _done = null;
    });
    final qty = _qty;
    try {
      await ref.read(stockRepositoryProvider).transferStock(
            productId: batch['product_id'] as String,
            from: batch['floor_name'] as String,
            to: to,
            expiry: batchExpiry(batch),
            qty: qty,
          );
      ref.invalidate(stockListProvider);
      if (!mounted) return;
      setState(() {
        _done = '${'${formatQty(qty)} $_unit'.trim()} ${_product!['brand_name']} dipindah ke $to.';
        _qty = 1;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final now = ref.watch(clockProvider)();
    final stocks = ref.watch(stockListProvider);
    final product = _product;
    final batches = product == null || !stocks.hasValue ? const <Map<String, dynamic>>[] : batchesOf(stocks.value!, product['id'] as String);
    // Satu batch saja = langsung terpilih.
    final batch = batches.where((b) => b['id'] == _batchId).firstOrNull ?? (batches.length == 1 ? batches.single : null);
    final from = batch?['floor_name'] as String?;
    final to = _to ?? storeFloors.firstWhere((f) => f != from, orElse: () => storeFloors.first);
    final available = batch?['quantity'] as num?;
    final reason = transferBlockReason(hasProduct: product != null, available: available, from: from, to: to, qty: _qty, unit: _unit);
    final overStock = available != null && _qty > available;

    return WarehouseScaffold(
      title: 'Pindah stok',
      actions: const [AccountMenuButton()],
      header: [
        ProductSearch(keyPrefix: 'transfer', onPick: _select),
        if (_done != null)
          Notice(key: const Key('transfer-done'), icon: Icons.check_circle_outline, color: c.positive, text: _done!),
      ],
      content: [
        if (product == null)
          _hint(c, 'Scan atau cari barang yang mau dipindah.')
        else ...[
          Text('${product['brand_name']}', style: StokasType.titleLg.copyWith(color: c.ink)),
          Text('Kode ${product['id']}', style: StokasType.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: StokasSpace.s4),
          if (stocks.hasError)
            Notice(
              icon: Icons.error_outline,
              color: c.negative,
              text: 'Stok gagal dimuat. ${stocks.error}',
              action: StokasButton.secondary(label: 'Coba lagi', onPressed: () => ref.invalidate(stockListProvider)),
            )
          else if (!stocks.hasValue)
            _hint(c, 'Memuat stok...')
          else if (batches.isEmpty)
            _hint(c, 'Belum ada stok. Terima barang dulu.')
          else ...[
            Text('Dari', style: StokasType.title.copyWith(color: c.ink)),
            const SizedBox(height: StokasSpace.s2),
            for (final b in batches)
              Padding(
                padding: const EdgeInsets.only(bottom: StokasSpace.s2),
                child: _BatchOption(
                  stock: b,
                  unit: _unit,
                  selected: identical(b, batch),
                  expired: isBatchExpired(b, now),
                  onTap: _saving ? null : () => _change(() => _batchId = b['id'] as int),
                ),
              ),
            const SizedBox(height: StokasSpace.s3),
            Text('Ke', style: StokasType.title.copyWith(color: c.ink)),
            const SizedBox(height: StokasSpace.s2),
            Align(
              alignment: Alignment.centerLeft,
              child: FloorPicker(key: const Key('transfer-to'), value: to, onChanged: (f) => _change(() => _to = f)),
            ),
            const SizedBox(height: StokasSpace.s4),
            Text('Jumlah', style: StokasType.title.copyWith(color: c.ink)),
            const SizedBox(height: StokasSpace.s2),
            Row(
              children: [
                QtyStepper(value: _qty, fieldKey: const Key('transfer-qty'), onChanged: (q) => _change(() => _qty = q)),
                const SizedBox(width: StokasSpace.s2),
                Text(_unit, style: StokasType.body.copyWith(color: c.inkMuted)),
              ],
            ),
            if (overStock) ...[
              const SizedBox(height: StokasSpace.s2),
              FieldError('Melebihi stok asal (${'${formatQty(available)} $_unit'.trim()})', key: const Key('transfer-over')),
            ],
            const SizedBox(height: StokasSpace.s3),
            Text('Tanggal kedaluwarsa ikut pindah bersama barangnya.', style: StokasType.caption.copyWith(color: c.inkMuted)),
          ],
        ],
      ],
      bottom: ActionBar(
        reason: _saving ? null : reason,
        reasonKey: const Key('transfer-save-reason'),
        top: _error == null ? null : FieldError(_error!, key: const Key('transfer-error')),
        button: StokasButton(
          key: const Key('transfer-save'),
          label: _saving ? 'Memindahkan...' : 'Pindahkan ${'${formatQty(_qty)} $_unit'.trim()}',
          icon: Icons.swap_horiz,
          expand: true,
          onPressed: _saving || reason != null ? null : () => _save(batch!, to),
        ),
      ),
    );
  }

  Widget _hint(StokasColors c, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: StokasSpace.s5),
        child: Text(text, textAlign: TextAlign.center, style: StokasType.body.copyWith(color: c.inkMuted)),
      );
}

/// Pilihan batch asal: lantai, tanggal kedaluwarsa, jumlah; lencana bila kedaluwarsa.
class _BatchOption extends StatelessWidget {
  final Map<String, dynamic> stock;
  final String unit;
  final bool selected;
  final bool expired;
  final VoidCallback? onTap;

  const _BatchOption({required this.stock, required this.unit, required this.selected, required this.expired, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? c.surfaceSunken : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StokasRadius.lg),
          side: BorderSide(color: selected ? c.primary : c.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          key: Key('transfer-batch-${stock['id']}'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.lg)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: StokasSpace.tapMin),
            child: Padding(
              padding: const EdgeInsets.all(StokasSpace.s3),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? c.primary : c.inkMuted),
                  const SizedBox(width: StokasSpace.s3),
                  Expanded(child: Text(batchLabel(stock), style: StokasType.body.copyWith(color: c.ink))),
                  if (expired) ...[const StatusBadge(StockStatus.bahaya), const SizedBox(width: StokasSpace.s2)],
                  Text('${formatQty(stock['quantity'] as num)} $unit', style: StokasType.title.copyWith(color: c.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
