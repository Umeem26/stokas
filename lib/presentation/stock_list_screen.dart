import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../data/providers.dart';
import '../data/session.dart';
import '../data/stock_availability.dart';
import 'add_product_screen.dart';
import 'design/money_text.dart';
import 'design/status_badge.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'mutation_screen.dart';
import 'edit_product_screen.dart';
import 'warehouse/new_product_screen.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/error_view.dart';
import 'widgets/stock_adjust_dialog.dart';

/// Daftar batch stok. Harga jual hanya untuk peran [Permission.viewPrices] (gudang tidak).
/// [showAllProducts]: produk tanpa batch stok ikut tampil dengan lencana "Habis" (tab Produk).
/// "Produk baru": owner ke form lengkap (harga, modal, foto); gudang ke [NewProductScreen] tanpa harga.
class StockListScreen extends ConsumerStatefulWidget {
  final String title;
  final bool showAllProducts;

  const StockListScreen({super.key, this.title = 'Stok Toko (Real-time)', this.showAllProducts = false});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  void _refresh() => ref.invalidate(stockListProvider);

  Future<void> _adjust(Map<String, dynamic> stock, StockAdjustMode mode) async {
    final saved = await showStockAdjustDialog(context, mode: mode, stock: stock);
    if (saved == true) _refresh();
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (changed == true) {
      _refresh();
      ref.invalidate(productListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final role = ref.watch(currentRoleProvider);
    final allProducts = widget.showAllProducts ? ref.watch(productListProvider).value ?? const <Map<String, dynamic>>[] : const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: Text(widget.title), actions: const [AccountMenuButton(), SizedBox(width: StokasSpace.s2)]),
      body: ref.watch(stockListProvider).when(
            skipLoadingOnRefresh: false,
            loading: () => const _StockSkeleton(),
            error: (error, _) => ErrorView(error: error, onRetry: _refresh),
            data: (stocks) {
              final stocked = {for (final s in stocks) s['product_id']};
              final noStock = allProducts.where((p) => !stocked.contains(p['id'])).toList();
              if (stocks.isEmpty && noStock.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: StokasSpace.s8, color: c.inkMuted),
                      const SizedBox(height: StokasSpace.s3),
                      Text('Belum ada stok. Terima barang dulu.', style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
                    ],
                  ),
                );
              }
              final now = ref.read(clockProvider)();
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(StokasSpace.s3, StokasSpace.s3, StokasSpace.s3, StokasSpace.s8 + StokasSpace.s8),
                itemCount: stocks.length + noStock.length,
                separatorBuilder: (_, _) => const SizedBox(height: StokasSpace.s2),
                itemBuilder: (context, index) => index >= stocks.length
                    ? _NoStockTile(
                        product: noStock[index - stocks.length],
                        role: role,
                        onEdit: () => _open(EditProductScreen(productData: noStock[index - stocks.length])),
                      )
                    : _StockTile(
                  stock: stocks[index],
                  expired: isBatchExpired(stocks[index], now),
                  role: role,
                  onMove: () => _open(MutationScreen(sourceStock: stocks[index])),
                  onAdjust: (mode) => _adjust(stocks[index], mode),
                  onEdit: () => _open(EditProductScreen(productData: stocks[index]['products'])),
                ),
              );
            },
          ),
      floatingActionButton: !can(role, Permission.addProduct)
          ? null
          : StokasButton(
              key: const Key('stock-new-product'),
              label: 'Produk baru',
              icon: Icons.add,
              onPressed: () => _open(can(role, Permission.editPrices) ? const AddProductScreen() : const NewProductScreen()),
            ),
    );
  }
}

class _StockTile extends StatelessWidget {
  final Map<String, dynamic> stock;
  final bool expired;
  final AppRole? role;
  final VoidCallback onMove;
  final ValueChanged<StockAdjustMode> onAdjust;
  final VoidCallback onEdit;

  const _StockTile({
    required this.stock,
    required this.expired,
    required this.role,
    required this.onMove,
    required this.onAdjust,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final product = stock['products'] as Map<String, dynamic>;
    final imageUrl = product['image_url']?.toString() ?? '';
    final expiry = stock['expiry_date'] as String?;

    return Container(
      padding: const EdgeInsets.all(StokasSpace.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StokasRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: StokasSpace.s8 + StokasSpace.s3,
            height: StokasSpace.s8 + StokasSpace.s3,
            decoration: BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: BorderRadius.circular(StokasRadius.md),
              image: imageUrl.isEmpty ? null : DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
            ),
            child: imageUrl.isEmpty ? Icon(Icons.inventory_2_outlined, color: c.stock) : null,
          ),
          const SizedBox(width: StokasSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['brand_name']}', style: StokasType.title.copyWith(color: c.ink)),
                if (can(role, Permission.viewPrices))
                  MoneyText((product['price'] as num?)?.round() ?? 0, style: StokasType.body.copyWith(color: c.ink)),
                Text(
                  [
                    '${stock['floor_name']}',
                    if (expiry != null) 'Exp ${expiry.substring(0, 10)}',
                  ].join(' · '),
                  style: StokasType.caption.copyWith(color: c.inkMuted),
                ),
                // Batch kedaluwarsa tidak dihitung sebagai stok tersedia di Kasir
                if (expired)
                  const Padding(
                    padding: EdgeInsets.only(top: StokasSpace.s1),
                    child: StatusBadge(StockStatus.bahaya),
                  )
                else if ((stock['quantity'] as num) <= 0)
                  const Padding(
                    padding: EdgeInsets.only(top: StokasSpace.s1),
                    child: StatusBadge(StockStatus.bahaya, label: 'Habis'),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatQty(stock['quantity'] as num), style: StokasType.titleLg.copyWith(color: c.ink)),
              Text('${product['unit_type']}', style: StokasType.caption.copyWith(color: c.inkMuted)),
            ],
          ),
          if (can(role, Permission.moveStock))
            IconButton(icon: Icon(Icons.swap_horiz, color: c.stock), tooltip: 'Pindah Lantai', onPressed: onMove),
          if (can(role, Permission.restockStock) || can(role, Permission.countStock))
            PopupMenuButton<StockAdjustMode>(
              icon: Icon(Icons.more_vert, color: c.inkMuted),
              tooltip: 'Stok Masuk / Opname',
              onSelected: onAdjust,
              itemBuilder: (context) => [
                if (can(role, Permission.restockStock))
                  const PopupMenuItem(
                    value: StockAdjustMode.restock,
                    child: ListTile(leading: Icon(Icons.add_box_outlined), title: Text('Stok Masuk')),
                  ),
                if (can(role, Permission.countStock))
                  const PopupMenuItem(
                    value: StockAdjustMode.opname,
                    child: ListTile(leading: Icon(Icons.fact_check_outlined), title: Text('Opname')),
                  ),
              ],
            ),
          if (can(role, Permission.editProduct))
            IconButton(icon: Icon(Icons.edit_outlined, color: c.inkMuted), tooltip: 'Edit Barang', onPressed: onEdit),
        ],
      ),
    );
  }
}

/// Produk tanpa batch stok sama sekali: nama, kode, lencana "Habis".
class _NoStockTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final AppRole? role;
  final VoidCallback onEdit;

  const _NoStockTile({required this.product, required this.role, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Container(
      key: ValueKey('no-stock-${product['id']}'),
      padding: const EdgeInsets.all(StokasSpace.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StokasRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: StokasSpace.s8 + StokasSpace.s3,
            height: StokasSpace.s8 + StokasSpace.s3,
            decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.md)),
            child: Icon(Icons.inventory_2_outlined, color: c.inkMuted),
          ),
          const SizedBox(width: StokasSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['brand_name']}', style: StokasType.title.copyWith(color: c.ink)),
                if (can(role, Permission.viewPrices))
                  MoneyText((product['price'] as num?)?.round() ?? 0, style: StokasType.body.copyWith(color: c.ink)),
                Text('Kode ${product['id']} · ${product['unit_type'] ?? ''}', style: StokasType.caption.copyWith(color: c.inkMuted)),
                const Padding(
                  padding: EdgeInsets.only(top: StokasSpace.s1),
                  child: StatusBadge(StockStatus.bahaya, label: 'Habis'),
                ),
              ],
            ),
          ),
          if (can(role, Permission.editProduct))
            IconButton(icon: Icon(Icons.edit_outlined, color: c.inkMuted), tooltip: 'Edit Barang', onPressed: onEdit),
        ],
      ),
    );
  }
}

/// Kerangka saat memuat (bukan spinner layar penuh).
class _StockSkeleton extends StatelessWidget {
  const _StockSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return ListView.separated(
      padding: const EdgeInsets.all(StokasSpace.s3),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: StokasSpace.s2),
      itemBuilder: (_, _) => Container(
        height: StokasSpace.s8 + StokasSpace.s6,
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.lg)),
      ),
    );
  }
}
