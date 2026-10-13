import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_exception.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../data/checkout_controller.dart';
import '../data/session.dart';
import '../data/stock_availability.dart';
import '../data/providers.dart';
import '../data/transaction_model.dart';
import 'add_product_screen.dart'; // Untuk pinjam formatter uang
import 'package:google_fonts/google_fonts.dart';
import 'history_screen.dart';
import 'stock_list_screen.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/error_view.dart';

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  final _searchController = TextEditingController();
  final _payController = TextEditingController();

  // Data
  List<SellableProduct> _allProducts = []; // Semua barang (stok tersedia = batch belum kedaluwarsa)
  List<SellableProduct> _filteredProducts = []; // Hasil pencarian
  Object? _loadError; // Terisi jika daftar barang gagal dimuat

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _payController.dispose();
    super.dispose();
  }

  // Ambil data stok lalu kelompokkan per barang untuk dipilih kasir
  Future<void> _loadProducts() async {
    final List<Map<String, dynamic>> data;
    try {
      data = await ref.read(stockRepositoryProvider).getStockList();
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _allProducts = sellableProducts(data, ref.read(clockProvider)());
    });
    _runFilter(_searchController.text);
  }

  // Cari Barang
  void _runFilter(String keyword) {
    final k = keyword.toLowerCase();
    setState(() {
      _filteredProducts = k.isEmpty
          ? _allProducts
          : _allProducts.where((p) => p.name.toLowerCase().contains(k) || p.id.toLowerCase().contains(k)).toList();
    });
  }

  void _showMessage(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // Tambah ke Keranjang (dibatasi stok tersedia; server tetap sumber kebenaran)
  void _addToCart(SellableProduct product) {
    final error = ref.read(checkoutControllerProvider.notifier).add(product);
    if (error != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showMessage(error, color: Colors.orange);
    }
  }

  // Proses Bayar
  void _processPayment() async {
    final checkout = ref.read(checkoutControllerProvider);
    if (checkout.isPaying || _payController.text.isEmpty) return;

    final paid = parseRupiah(_payController.text);
    if (paid < checkout.total) {
      _showMessage("⚠️ Uang Pembayaran Kurang!", color: Colors.red);
      return;
    }

    final TransactionModel? transaction;
    try {
      transaction = await ref.read(checkoutControllerProvider.notifier).pay(paid);
    } on InsufficientStockException catch (e) {
      // Stok berubah sejak dimuat: muat ulang agar angka stok di layar benar.
      await _loadProducts();
      if (mounted) _showMessage("${e.message}. Stok sudah dimuat ulang, sesuaikan keranjang.", color: Colors.red);
      return;
    } catch (e) {
      // Keranjang & kunci transaksi tetap: tekan Bayar lagi aman (tidak tercatat ganda).
      if (mounted) _showMessage("$e", color: Colors.red);
      return;
    }
    if (transaction == null || !mounted) return;

    _payController.clear();
    _loadProducts();
    _showReceipt(transaction);
  }

  void _showReceipt(TransactionModel transaction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 10),
              const Text("TRANSAKSI SUKSES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 5),

              Text("Minimarket POS", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(DateFormat('dd-MM-yyyy HH:mm').format(transaction.createdAt.toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text("NO. NOTA: #${transaction.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),

              const Divider(thickness: 2, height: 30, color: Colors.black),

              // Isi nota dari server (nama & harga snapshot transaksi)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: transaction.items.length,
                  itemBuilder: (context, index) {
                    final item = transaction.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              "${item.productName}\n${formatQty(item.quantity)} x ${formatRupiah(item.price)}",
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              formatRupiah(item.subtotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const Divider(thickness: 2, height: 30, color: Colors.black),

              _buildReceiptRow("TOTAL", transaction.totalAmount, isBold: true),
              _buildReceiptRow("BAYAR", transaction.paidAmount),
              const SizedBox(height: 5),
              _buildReceiptRow("KEMBALI", transaction.changeAmount, isBold: true, color: Colors.green),

              const SizedBox(height: 25),
              const Text("Terima Kasih!", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup & Transaksi Baru", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper kecil buat baris angka struk
  Widget _buildReceiptRow(String label, int value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          Text(formatRupiah(value), style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            fontSize: isBold ? 14 : 12,
            color: color ?? Colors.black
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final cart = checkout.items;
    // Saat Kasir menjadi beranda (peran kasir), sediakan jalan ke Stok & Riwayat.
    final isHome = !Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kasir"),
        actions: [
          if (isHome && can(role, Permission.viewStock))
            IconButton(
              icon: const Icon(Icons.inventory_2),
              tooltip: "Stok Barang",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockListScreen()))
                  .then((_) => _loadProducts()),
            ),
          if (isHome && can(role, Permission.viewHistory))
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: "Riwayat Transaksi",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
          const AccountMenuButton(),
        ],
      ),
      body: Column(
        children: [
          // 1. Area Pencarian Barang
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "Cari Nama Barang / Scan Barcode",
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.qr_code_scanner),
              ),
              onChanged: _runFilter,
            ),
          ),

          // 2. Daftar Barang (Hasil Pencarian)
          Expanded(
            flex: 2,
            child: _loadError != null
                ? ErrorView(error: _loadError!, onRetry: _loadProducts)
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filteredProducts.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _filteredProducts[index];
                final floors = item.floors.isEmpty ? "-" : item.floors.join(", ");

                return ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.local_offer, color: Colors.blue),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$floors - Stok: ${formatQty(item.available)}"),
                  trailing: Text(formatRupiah(item.price), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  onTap: () => _addToCart(item),
                );
              },
            ),
          ),

          const Divider(thickness: 5, color: Colors.grey),

          // 3. Keranjang Belanja (Cart)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.blue.shade50,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("KERANJANG BELANJA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                  Expanded(
                    child: cart.isEmpty 
                    ? const Center(child: Text("Keranjang Kosong", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final cartItem = cart[index];
                          return ListTile(
                            dense: true,
                            title: Text(cartItem.productName),
                            subtitle: Text("${formatQty(cartItem.quantity)} x ${formatRupiah(cartItem.price)}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formatRupiah(cartItem.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: checkout.isPaying
                                      ? null
                                      : () => ref.read(checkoutControllerProvider.notifier).decrement(cartItem.productId),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Panel Pembayaran
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(formatRupiah(checkout.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _payController,
                  keyboardType: TextInputType.number,
                  // Menggunakan Formatter yang sama dengan AddProductScreen agar ada titik otomatis
                  inputFormatters: [CurrencyInputFormatter()], 
                  decoration: const InputDecoration(
                    labelText: "Uang Diterima (Tunai)",
                    prefixIcon: Icon(Icons.money),
                    suffixText: "IDR",
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF6C00)),
                    // Terkunci selama proses agar tidak tap ganda
                    onPressed: cart.isEmpty || checkout.isPaying ? null : _processPayment,
                    child: checkout.isPaying
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : const Text("BAYAR SEKARANG", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}