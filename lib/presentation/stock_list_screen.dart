import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../data/providers.dart';
import '../data/session.dart';
import '../data/stock_availability.dart';
import 'add_product_screen.dart';
import 'mutation_screen.dart';
import 'cashier_screen.dart';
import 'edit_product_screen.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/error_view.dart';
import 'widgets/stock_adjust_dialog.dart';

class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  void _refresh() => ref.invalidate(stockListProvider);

  Future<void> _adjust(Map<String, dynamic> stock, StockAdjustMode mode) async {
    final saved = await showStockAdjustDialog(context, mode: mode, stock: stock);
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Stok Toko (Real-time)"),
        actions: [
          if (can(role, Permission.useCashier))
          IconButton(
            icon: const Icon(Icons.point_of_sale, size: 30),
            tooltip: "Menu Kasir",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CashierScreen()),
              ).then((value) {
                // INI KUNCINYA: Saat kembali, paksa refresh data
                _refresh();
              });
            },
          ),
          const AccountMenuButton(),
          const SizedBox(width: 10),
        ],
      ),
      body: ref.watch(stockListProvider).when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: _refresh),
        data: (stocks) {
          if (stocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Belum ada stok barang.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final now = ref.read(clockProvider)();
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: stocks.length,
            itemBuilder: (context, index) {
              final stock = stocks[index];
              final product = stock['products'];
              final price = (product['price'] as num?)?.round() ?? 0; // Ambil harga
              final expired = isBatchExpired(stock, now);
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // 1. FOTO PRODUK (Ganti Bagian Ikon Lama dengan ini)
                      Container(
                        width: 60, height: 60, // Ukuran Kotak Foto
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          image: (product['image_url'] != null && product['image_url'].toString().isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(product['image_url']), // Load dari Supabase
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (product['image_url'] == null || product['image_url'].toString().isEmpty)
                            ? Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor, size: 30) // Fallback Icon
                            : null, // Kalau ada foto, child-nya null
                      ),
                      const SizedBox(width: 15),
                      
                      // 2. Info Barang & Harga
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['brand_name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            
                            // TAMPILKAN HARGA DISINI
                            Text(
                              formatRupiah(price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: Colors.green, // Warna hijau uang
                                fontSize: 14
                              ),
                            ),
                            const SizedBox(height: 4),

                            Text("Lokasi: ${stock['floor_name']}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            if (stock['expiry_date'] != null)
                               Text("Exp: ${stock['expiry_date'].substring(0, 10)}", 
                                   style: const TextStyle(color: Colors.red, fontSize: 11)),
                            // Batch kedaluwarsa tidak dihitung sebagai stok tersedia di Kasir
                            if (expired)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                child: const Text("Kedaluwarsa", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      
                      // 3. Stok & Tombol Mutasi
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatQty(stock['quantity'] as num),
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold, 
                                  color: Theme.of(context).primaryColor
                                ),
                              ),
                              Text(product['unit_type'], style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(width: 5),
                          
                          // Tombol Mutasi
                          // --- TOMBOL MUTASI (PINDAH) ---
                          if (can(role, Permission.moveStock))
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, color: Color(0xFFEF6C00), size: 30),
                            tooltip: "Pindah Lantai",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => MutationScreen(sourceStock: stock)),
                              ).then((value) { if (value == true) _refresh(); });
                            },
                          ),
                          
                          // --- STOK MASUK & OPNAME ---
                          if (can(role, Permission.restockStock) || can(role, Permission.countStock))
                          PopupMenuButton<StockAdjustMode>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            tooltip: "Stok Masuk / Opname",
                            onSelected: (mode) => _adjust(stock, mode),
                            itemBuilder: (context) => [
                              if (can(role, Permission.restockStock))
                                const PopupMenuItem(
                                  value: StockAdjustMode.restock,
                                  child: ListTile(leading: Icon(Icons.add_box), title: Text("Stok Masuk")),
                                ),
                              if (can(role, Permission.countStock))
                                const PopupMenuItem(
                                  value: StockAdjustMode.opname,
                                  child: ListTile(leading: Icon(Icons.fact_check), title: Text("Opname")),
                                ),
                            ],
                          ),

                          // --- TOMBOL EDIT (BARU) ---
                          if (can(role, Permission.editProduct))
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            tooltip: "Edit Barang",
                            onPressed: () {
                              // Kirim Data PRODUK (bukan stok) ke halaman edit
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProductScreen(productData: product),
                                ),
                              ).then((value) {
                                // Refresh jika ada perubahan (Update/Hapus)
                                if (value == true) _refresh();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: !can(role, Permission.addProduct) ? null : FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tambah Barang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          ).then((value) => _refresh());
        },
      ),
    );
  }
}