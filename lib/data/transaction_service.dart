import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaction_model.dart';

class TransactionService {
  final supabase = Supabase.instance.client;

  // Simpan Transaksi & Potong Stok
  // Ubah void menjadi Future<int>
  Future<int> saveTransaction(TransactionModel transaction) async {
    try {
      // 1. Simpan HEADER
      final response = await supabase.from('transactions').insert({
        'total_amount': transaction.totalAmount,
        'paid_amount': transaction.paidAmount,
        'change_amount': transaction.changeAmount,
      }).select().single();

      final newTransactionId = response['id']; // Kita butuh angka ini

      // 2. Simpan DETAIL (Kode tetap sama)
      final List<Map<String, dynamic>> itemsData = transaction.items.map((item) {
        return {
          'transaction_id': newTransactionId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'price_at_purchase': item.price,
          'subtotal': item.subtotal,
        };
      }).toList();

      await supabase.from('transaction_items').insert(itemsData);

      // 3. Potong Stok (Kode tetap sama)
      for (var item in transaction.items) {
        final stockResponse = await supabase
            .from('stocks').select().eq('product_id', item.productId)
            .order('quantity', ascending: false).limit(1).maybeSingle();

        if (stockResponse != null) {
          final stockId = stockResponse['id'];
          final currentQty = (stockResponse['quantity'] as num).toDouble();
          double newQty = currentQty - item.quantity;
          if (newQty < 0) newQty = 0;
          await supabase.from('stocks').update({'quantity': newQty}).eq('id', stockId);
        }
      }

      // KEMBALIKAN ID NOTA
      return newTransactionId; 

    } catch (e) {
      throw Exception("Gagal Transaksi: $e");
    }
  }

  // --- AMBIL TRANSAKSI HARI INI (Untuk Dashboard) ---
  Future<List<Map<String, dynamic>>> getTodayTransactions() async {
    try {
      final now = DateTime.now();
      // Format tanggal hari ini: "YYYY-MM-DD"
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // Ambil transaksi yang created_at-nya dimulai dengan tanggal hari ini
      // Menggunakan filter gte (Greater Than or Equal) jam 00:00 hari ini
      final startOfDay = "${todayStr}T00:00:00";
      final endOfDay = "${todayStr}T23:59:59";

      final response = await supabase
          .from('transactions')
          .select()
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error Transaksi Hari Ini: $e");
      return [];
    }
  }

  // --- AMBIL SEMUA RIWAYAT TRANSAKSI ---
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      final response = await supabase
          .from('transactions')
          .select()
          .order('created_at', ascending: false); // Yang baru di atas
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error Riwayat: $e");
      return [];
    }
  }

  // --- AMBIL DETAIL ITEM DARI SEBUAH TRANSAKSI ---
  Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId) async {
    try {
      // Kita join dengan tabel products untuk dapat nama barangnya
      final response = await supabase
          .from('transaction_items')
          .select('*, products(brand_name)') 
          .eq('transaction_id', transactionId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error Detail Item: $e");
      return [];
    }
  }
}