import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/checkout_controller.dart';
import '../../data/stock_availability.dart';
import '../../data/transaction_model.dart';
import '../design/money_text.dart';
import '../design/payment_method_label.dart';
import '../design/status_badge.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import 'cashier_widgets.dart' show productStockStatus;

/// Lebar minimum mode PC Kasir (tabel keranjang + bilah pintasan).
const double pcBreakpoint = 1280;

/// Lebar kolom kanan (total + bayar) di mode PC.
const double pcCheckoutWidth = 400;

const double _codeWidth = 112;
const double _priceWidth = 120;
const double _qtyWidth = StokasSpace.tapMin * 3;
const double _subtotalWidth = 136;

BoxDecoration _focusRing(StokasColors c) => BoxDecoration(
      borderRadius: BorderRadius.circular(StokasRadius.md),
      border: Border.all(color: c.focus, width: 2),
    );

/// Tabel keranjang mode PC: Kode, Nama, Harga, Jumlah, Subtotal (angka rata kanan, tabular).
/// Baris terpilih ([selectedId]) diberi cincin fokus 2 px; ketuk baris untuk memilih.
class CartTable extends StatelessWidget {
  final List<CartItem> items;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;

  const CartTable({
    super.key,
    required this.items,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final head = StokasType.label.copyWith(color: c.inkMuted);
    Widget cell(double width, Widget child, {Alignment align = Alignment.centerLeft}) =>
        SizedBox(width: width, child: Align(alignment: align, child: child));

    return Column(
      key: const Key('cart-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4 + StokasSpace.s2, vertical: StokasSpace.s2),
          child: Row(
            children: [
              cell(_codeWidth, Text('Kode', style: head)),
              Expanded(child: Text('Nama', style: head)),
              cell(_priceWidth, Text('Harga', style: head), align: Alignment.centerRight),
              cell(_qtyWidth, Text('Jumlah', style: head), align: Alignment.center),
              cell(_subtotalWidth, Text('Subtotal', style: head), align: Alignment.centerRight),
              const SizedBox(width: StokasSpace.tapMin),
            ],
          ),
        ),
        Divider(height: 1, color: c.line),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined, color: c.inkMuted),
                      const SizedBox(width: StokasSpace.s2),
                      Text('Keranjang kosong. Scan barang atau ketik nama.', style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final id = item.productId;
                    final selected = id == selectedId;
                    const square = Size.square(StokasSpace.tapMin);
                    final body = StokasType.bodyLg.copyWith(color: c.ink);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: StokasSpace.s1),
                      child: Material(
                        color: selected ? c.surfaceSunken : c.surface,
                        borderRadius: BorderRadius.circular(StokasRadius.md),
                        child: InkWell(
                          key: ValueKey('cart-row-$id'),
                          borderRadius: BorderRadius.circular(StokasRadius.md),
                          canRequestFocus: false,
                          onTap: () => onSelect(id),
                          child: Container(
                            foregroundDecoration: selected ? _focusRing(c) : null,
                            padding: const EdgeInsets.only(left: StokasSpace.s2),
                            child: Semantics(
                              selected: selected,
                              child: Row(
                                children: [
                                  cell(_codeWidth, Text(id, overflow: TextOverflow.ellipsis, style: StokasType.body.copyWith(color: c.inkMuted))),
                                  Expanded(child: Text(item.productName, overflow: TextOverflow.ellipsis, style: StokasType.title.copyWith(color: c.ink))),
                                  cell(_priceWidth, MoneyText(item.price, textAlign: TextAlign.right, style: body), align: Alignment.centerRight),
                                  cell(
                                    _qtyWidth,
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          key: ValueKey('dec-$id'),
                                          tooltip: 'Kurangi (−)',
                                          style: IconButton.styleFrom(minimumSize: square),
                                          icon: const Icon(Icons.remove),
                                          onPressed: enabled ? () => onDecrement(id) : null,
                                        ),
                                        SizedBox(
                                          width: StokasSpace.tapMin,
                                          child: Text(formatQty(item.quantity),
                                              key: ValueKey('qty-$id'), textAlign: TextAlign.center, style: StokasType.title.copyWith(color: c.ink)),
                                        ),
                                        IconButton(
                                          key: ValueKey('inc-$id'),
                                          tooltip: 'Tambah (+)',
                                          style: IconButton.styleFrom(minimumSize: square),
                                          icon: const Icon(Icons.add),
                                          onPressed: enabled ? () => onIncrement(id) : null,
                                        ),
                                      ],
                                    ),
                                    align: Alignment.center,
                                  ),
                                  cell(_subtotalWidth, MoneyText(item.subtotal, textAlign: TextAlign.right, style: StokasType.title.copyWith(color: c.ink)),
                                      align: Alignment.centerRight),
                                  IconButton(
                                    key: ValueKey('remove-$id'),
                                    tooltip: 'Hapus baris (Del)',
                                    style: IconButton.styleFrom(minimumSize: square),
                                    icon: Icon(Icons.delete_outline, color: c.negative),
                                    onPressed: enabled ? () => onRemove(id) : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Daftar hasil pencarian di bawah kolom cari (mode PC). Baris [highlighted] bercincin fokus.
class SearchResultsList extends StatelessWidget {
  final List<SellableProduct> results;
  final int highlighted;
  final ValueChanged<SellableProduct> onPick;

  const SearchResultsList({super.key, required this.results, required this.highlighted, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Container(
      key: const Key('search-results'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StokasRadius.md),
        border: Border.all(color: c.line),
        boxShadow: StokasShadow.float(Theme.of(context).brightness),
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(StokasSpace.s4),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: c.inkMuted),
                  const SizedBox(width: StokasSpace.s2),
                  Text('Tidak ada barang yang cocok', style: StokasType.body.copyWith(color: c.inkMuted)),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < results.length; i++) _resultRow(context, results[i], i == highlighted),
              ],
            ),
    );
  }

  Widget _resultRow(BuildContext context, SellableProduct p, bool active) {
    final c = context.stokas;
    final soldOut = p.available <= 0;
    final (status, label) = productStockStatus(p);
    final text = soldOut ? c.inkMuted : c.ink;
    return Material(
      color: active ? c.surfaceSunken : c.surface,
      child: InkWell(
        key: ValueKey('result-${p.id}'),
        canRequestFocus: false,
        onTap: soldOut ? null : () => onPick(p),
        child: Container(
          constraints: const BoxConstraints(minHeight: StokasSpace.tapMin),
          foregroundDecoration: active ? _focusRing(c) : null,
          padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s3, vertical: StokasSpace.s1),
          child: Row(
            children: [
              Semantics(selected: active, child: SizedBox(width: _codeWidth, child: Text(p.id, style: StokasType.body.copyWith(color: c.inkMuted)))),
              Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis, style: StokasType.title.copyWith(color: text))),
              FittedBox(child: StatusBadge(status, label: label)),
              const SizedBox(width: StokasSpace.s3),
              SizedBox(width: _priceWidth, child: MoneyText(p.price, textAlign: TextAlign.right, style: StokasType.title.copyWith(color: text))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status scanner (ikon + kata) dan hasil scan terakhir sebagai role=status (live region).
/// Aplikasi tidak bisa mendeteksi perangkat, jadi tidak pernah menulis "terhubung".
class ScannerStatus extends StatelessWidget {
  final bool paused;
  final String? result;
  final bool resultIsError;

  const ScannerStatus({super.key, required this.paused, this.result, this.resultIsError = false});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
      child: Row(
        children: [
          Icon(paused ? Icons.pause_circle_outline : Icons.qr_code_scanner, size: 20, color: c.inkMuted),
          const SizedBox(width: StokasSpace.s2),
          Text(paused ? 'Scanner dijeda' : 'Siap scan', key: const Key('scanner-state'), style: StokasType.title.copyWith(color: c.ink)),
          if (!paused) ...[
            const SizedBox(width: StokasSpace.s2),
            Text('Menunggu ketikan scanner', style: StokasType.caption.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(width: StokasSpace.s4),
          Expanded(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: result == null
                  ? const SizedBox.shrink()
                  : Row(
                      key: const Key('scan-status'),
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(resultIsError ? Icons.error_outline : Icons.check_circle_outline,
                            size: 20, color: resultIsError ? c.negative : c.positive),
                        const SizedBox(width: StokasSpace.s1),
                        Flexible(child: Text(result!, overflow: TextOverflow.ellipsis, style: StokasType.body.copyWith(color: c.ink))),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom kanan mode PC: total besar, cara bayar terakhir dipakai, "Bayar Rp ...", "Kosongkan keranjang".
class PcCheckoutColumn extends StatelessWidget {
  final CheckoutState checkout;
  final PaymentMethod method;
  final VoidCallback onPay;
  final VoidCallback onClear;

  const PcCheckoutColumn({super.key, required this.checkout, required this.method, required this.onPay, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final items = checkout.items;
    final busy = checkout.isPaying;
    return Padding(
      padding: const EdgeInsets.all(StokasSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total', style: StokasType.titleLg.copyWith(color: c.inkMuted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: MoneyText(checkout.total, key: const Key('cart-total'), textAlign: TextAlign.right, style: StokasType.displayXl.copyWith(color: c.ink)),
          ),
          Text('${items.length} barang', textAlign: TextAlign.right, style: StokasType.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: StokasSpace.s5),
          Divider(height: 1, color: c.line),
          const SizedBox(height: StokasSpace.s4),
          Row(
            children: [
              Expanded(child: Text('Cara bayar', style: StokasType.title.copyWith(color: c.inkMuted))),
              PaymentMethodLabel(method, key: const Key('pc-method'), style: StokasType.title.copyWith(color: c.ink)),
            ],
          ),
          Text('Terakhir dipakai di sesi ini', style: StokasType.caption.copyWith(color: c.inkMuted)),
          const Spacer(),
          StokasButton(
            key: const Key('pay-button'),
            label: busy ? 'Memproses…' : 'Bayar ${formatRupiah(checkout.total)}',
            icon: Icons.payments_outlined,
            expand: true,
            onPressed: items.isEmpty || busy ? null : onPay,
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: StokasSpace.s1),
            Text('Tambah barang dulu untuk membayar', textAlign: TextAlign.center, style: StokasType.caption.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(height: StokasSpace.s2),
          StokasButton.danger(
            key: const Key('clear-cart'),
            label: 'Kosongkan keranjang',
            icon: Icons.delete_sweep_outlined,
            expand: true,
            onPressed: items.isEmpty || busy ? null : onClear,
          ),
        ],
      ),
    );
  }
}

/// Bilah pintasan keyboard di bawah layar (hanya mode PC).
class ShortcutBar extends StatelessWidget {
  const ShortcutBar({super.key});

  static const shortcuts = [('/', 'Cari'), ('Enter', 'Tambah/Bayar'), ('+ −', 'Jumlah'), ('Del', 'Hapus baris'), ('Esc', 'Tutup')];

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Container(
      key: const Key('shortcut-bar'),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
      child: Wrap(
        spacing: StokasSpace.s5,
        runSpacing: StokasSpace.s1,
        children: [
          for (final (key, label) in shortcuts)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s2, vertical: StokasSpace.s1 / 2),
                  decoration: BoxDecoration(
                    color: c.surfaceSunken,
                    borderRadius: BorderRadius.circular(StokasRadius.sm),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Text(key, style: StokasType.label.copyWith(color: c.ink)),
                ),
                const SizedBox(width: StokasSpace.s1),
                Text(label, style: StokasType.body.copyWith(color: c.inkMuted)),
              ],
            ),
        ],
      ),
    );
  }
}
