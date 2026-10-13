import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk format Rupiah
import '../data/product_service.dart';
import 'add_product_screen.dart';
import 'mutation_screen.dart';
import 'cashier_screen.dart';
import 'edit_product_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final _service = ProductService();
  
  // Formatter Rupiah
  final _currency = NumberFormat.currency(
    locale: 'id_ID', 
    symbol: 'Rp ', 
    decimalDigits: 0
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stok Toko (Real-time)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale, size: 30),
            tooltip: "Menu Kasir",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CashierScreen()),
              ).then((value) {
                // INI KUNCINYA: Saat kembali, paksa refresh UI
                setState(() {}); 
              });
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service.getStockList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final stock = snapshot.data![index];
              final product = stock['products'];
              final price = product['price'] ?? 0; // Ambil harga
              
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
                              _currency.format(price),
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
                                "${stock['quantity']}",
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
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, color: Color(0xFFEF6C00), size: 30),
                            tooltip: "Pindah Lantai",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => MutationScreen(sourceStock: stock)),
                              ).then((value) { if (value == true) setState(() {}); });
                            },
                          ),
                          
                          // --- TOMBOL EDIT (BARU) ---
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
                                if (value == true) setState(() {});
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tambah Barang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          ).then((value) => setState(() {}));
        },
      ),
    );
  }
}