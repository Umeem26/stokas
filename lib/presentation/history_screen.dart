import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers.dart';
import 'widgets/error_view.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Fungsi untuk Membuka Detail Nota
  void _showDetail(Map<String, dynamic> transaction) async {
    // 1. Ambil detail barang dari database
    final List<Map<String, dynamic>> items;
    try {
      items = await ref.read(transactionRepositoryProvider).getTransactionItems(transaction['id']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: Colors.red));
      return;
    }

    if (!mounted) return;

    // 2. Tampilkan di BottomSheet (Panel bawah)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Detail Transaksi #${transaction['id']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(transaction['created_at'])), style: TextStyle(color: Colors.grey[600])),
              const Divider(),
              
              // List Barang
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final productName = item['products'] != null ? item['products']['brand_name'] : 'Produk Terhapus';
                    final qty = (item['quantity'] as num).toDouble();
                    final subtotal = (item['subtotal'] as num).toDouble();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("$qty x ${_currency.format(item['price_at_purchase'])}"),
                      trailing: Text(_currency.format(subtotal)),
                    );
                  },
                ),
              ),
              
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Bayar", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_currency.format(transaction['total_amount']), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Transaksi")),
      body: ref.watch(transactionHistoryProvider).when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: () => ref.invalidate(transactionHistoryProvider)),
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada transaksi"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: data.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final trx = data[index];
              final date = DateTime.parse(trx['created_at']);
              final total = (trx['total_amount'] as num).toDouble();

              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.receipt_long, color: Colors.blue),
                ),
                title: Text("Nota #${trx['id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () => _showDetail(trx),
              );
            },
          );
        },
      ),
    );
  }
}