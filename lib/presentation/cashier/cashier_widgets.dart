import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/checkout_controller.dart';
import '../../data/stock_availability.dart';
import '../../data/transaction_model.dart';
import '../design/money_text.dart';
import '../design/status_badge.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';

/// Lebar panel keranjang di tata letak dua panel.
const double cartPanelWidth = 408;

/// Cocokkan ketikan/scan: `products.id` persis dulu, lalu nama persis (abaikan huruf besar),
/// lalu nama yang mengandung kata kunci bila hanya satu. Null bila tidak ada atau lebih dari satu.
SellableProduct? findScanMatch(List<SellableProduct> products, String query) {
  final q = query.trim();
  if (q.isEmpty) return null;
  for (final p in products) {
    if (p.id == q) return p;
  }
  final k = q.toLowerCase();
  final exact = products.where((p) => p.name.toLowerCase() == k).toList();
  if (exact.length == 1) return exact.single;
  final partial = products.where((p) => p.name.toLowerCase().contains(k)).toList();
  return partial.length == 1 ? partial.single : null;
}

/// Lencana stok kartu produk: Habis (0), Menipis (<= min_stock), Stok aman.
(StockStatus, String) productStockStatus(SellableProduct p) {
  if (p.available <= 0) return (StockStatus.bahaya, 'Habis');
  if (p.available <= ((p.product['min_stock'] as num?) ?? 0)) return (StockStatus.menipis, 'Menipis');
  return (StockStatus.aman, 'Stok aman');
}

/// Kartu produk di kisi Kasir. Stok 0 = nonaktif + label Habis.
class ProductCard extends StatelessWidget {
  final SellableProduct product;
  final VoidCallback onAdd;

  const ProductCard({super.key, required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final soldOut = product.available <= 0;
    final (status, label) = productStockStatus(product);
    final textColor = soldOut ? c.inkMuted : c.ink;

    return Material(
      color: soldOut ? c.surfaceSunken : c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StokasRadius.lg),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        key: ValueKey('product-${product.id}'),
        onTap: soldOut ? null : onAdd,
        child: Padding(
          padding: const EdgeInsets.all(StokasSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: StokasType.title.copyWith(color: textColor)),
              const Spacer(),
              MoneyText(product.price, style: StokasType.title.copyWith(color: textColor)),
              const SizedBox(height: StokasSpace.s2),
              Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(status, label: label),
                    ),
                  ),
                  if (!soldOut) ...[
                    const SizedBox(width: StokasSpace.s2),
                    Flexible(
                      child: Text(
                        'Stok ${formatQty(product.available)}',
                        overflow: TextOverflow.ellipsis,
                        style: StokasType.caption.copyWith(color: c.inkMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isi keranjang: baris barang, total besar, "Bayar Rp ...", "Kosongkan keranjang".
class CartPanel extends StatelessWidget {
  final CheckoutState checkout;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;
  final VoidCallback onPay;
  final VoidCallback onClear;

  const CartPanel({
    super.key,
    required this.checkout,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onPay,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final items = checkout.items;
    final busy = checkout.isPaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined, color: c.inkMuted),
                      const SizedBox(width: StokasSpace.s2),
                      Text('Keranjang kosong', style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
                  itemBuilder: (context, i) => _CartLine(
                    item: items[i],
                    enabled: !busy,
                    onIncrement: () => onIncrement(items[i].productId),
                    onDecrement: () => onDecrement(items[i].productId),
                    onRemove: () => onRemove(items[i].productId),
                  ),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Total', style: StokasType.titleLg.copyWith(color: c.inkMuted)),
                    const SizedBox(width: StokasSpace.s3),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: MoneyText(
                          checkout.total,
                          key: const Key('cart-total'),
                          textAlign: TextAlign.right,
                          style: StokasType.displayL.copyWith(color: c.ink),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StokasSpace.s3),
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
          ),
        ),
      ],
    );
  }
}

/// Baris keranjang: nama + subtotal; harga satuan + stepper -/+ (48 px) + hapus.
class _CartLine extends StatelessWidget {
  final CartItem item;
  final bool enabled;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartLine({
    required this.item,
    required this.enabled,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final id = item.productId;
    const square = Size.square(StokasSpace.tapMin);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StokasSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.productName, style: StokasType.title.copyWith(color: c.ink))),
              const SizedBox(width: StokasSpace.s2),
              MoneyText(item.subtotal, textAlign: TextAlign.right, style: StokasType.title.copyWith(color: c.ink)),
            ],
          ),
          Row(
            children: [
              Expanded(child: MoneyText(item.price, style: StokasType.body.copyWith(color: c.inkMuted))),
              Container(
                height: StokasSpace.tapMin,
                // Garis di depan agar tidak memakan ruang: tombol -/+ tetap 48 x 48.
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(StokasRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('dec-$id'),
                      tooltip: 'Kurangi',
                      style: IconButton.styleFrom(minimumSize: square),
                      icon: const Icon(Icons.remove),
                      onPressed: enabled ? onDecrement : null,
                    ),
                    SizedBox(
                      width: StokasSpace.tapMin,
                      child: Text(
                        formatQty(item.quantity),
                        key: ValueKey('qty-$id'),
                        textAlign: TextAlign.center,
                        style: StokasType.title.copyWith(color: c.ink),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('inc-$id'),
                      tooltip: 'Tambah',
                      style: IconButton.styleFrom(minimumSize: square),
                      icon: const Icon(Icons.add),
                      onPressed: enabled ? onIncrement : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StokasSpace.s1),
              IconButton(
                key: ValueKey('remove-$id'),
                tooltip: 'Hapus',
                style: IconButton.styleFrom(minimumSize: square),
                icon: Icon(Icons.delete_outline, color: c.negative),
                onPressed: enabled ? onRemove : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Konfirmasi sebelum keranjang dikosongkan; true bila disetujui.
Future<bool> confirmClearCart(BuildContext context, int lines) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kosongkan keranjang?'),
      content: Text('$lines barang akan dihapus dari keranjang.'),
      actions: [
        StokasButton.secondary(label: 'Batal', onPressed: () => Navigator.pop(context, false)),
        StokasButton.danger(key: const Key('confirm-clear'), label: 'Kosongkan', onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  return ok == true;
}
