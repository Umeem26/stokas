import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../transaction_model.dart';

abstract class TransactionRepository {
  /// Simpan transaksi, potong stok, dan kembalikan nomor nota.
  Future<int> saveTransaction(TransactionModel transaction);

  Future<List<Map<String, dynamic>>> getTodayTransactions();

  Future<List<Map<String, dynamic>>> getTransactionHistory();

  Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId);
}

class SupabaseTransactionRepository implements TransactionRepository {
  final SupabaseClient _client;

  SupabaseTransactionRepository(this._client);

  @override
  Future<int> saveTransaction(TransactionModel transaction) {
    return guard('Gagal menyimpan transaksi', () async {
      // 1. Simpan header
      final response = await _client.from('transactions').insert(transaction.toMap()).select().single();
      final newTransactionId = response['id'];

      // 2. Simpan detail
      final itemsData = transaction.items.map((item) {
        return {
          'transaction_id': newTransactionId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'price_at_purchase': item.price,
          'subtotal': item.subtotal,
        };
      }).toList();
      await _client.from('transaction_items').insert(itemsData);

      // 3. Potong stok dari baris dengan stok terbanyak
      for (var item in transaction.items) {
        final stockResponse = await _client
            .from('stocks').select().eq('product_id', item.productId)
            .order('quantity', ascending: false).limit(1).maybeSingle();

        if (stockResponse != null) {
          final stockId = stockResponse['id'];
          final currentQty = (stockResponse['quantity'] as num).toDouble();
          double newQty = currentQty - item.quantity;
          if (newQty < 0) newQty = 0;
          await _client.from('stocks').update({'quantity': newQty}).eq('id', stockId);
        }
      }

      return newTransactionId;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getTodayTransactions() {
    return guard('Gagal memuat transaksi hari ini', () async {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final startOfDay = "${todayStr}T00:00:00";
      final endOfDay = "${todayStr}T23:59:59";

      final response = await _client
          .from('transactions')
          .select()
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);
      return List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionHistory() {
    return guard('Gagal memuat riwayat transaksi', () async {
      final response = await _client.from('transactions').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId) {
    return guard('Gagal memuat detail transaksi', () async {
      // Join ke products untuk nama barang
      final response = await _client
          .from('transaction_items')
          .select('*, products(brand_name)')
          .eq('transaction_id', transactionId);
      return List<Map<String, dynamic>>.from(response);
    });
  }
}
