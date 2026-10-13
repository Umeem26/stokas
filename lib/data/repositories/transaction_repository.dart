import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/jakarta_time.dart';
import '../transaction_model.dart';

/// Transaksi hanya dibaca; penulisan lewat RPC checkout (atomik & idempoten).
abstract class TransactionRepository {
  /// Bayar keranjang. [idempotencyKey] yang sama tidak akan membuat transaksi ganda.
  /// QRIS/transfer wajib [paid] = total (server menolak lebih). Stok kurang ->
  /// [InsufficientStockException]; jaringan putus -> [NetworkException]; lainnya -> [AppException] berpesan server.
  Future<TransactionModel> checkout({
    required String idempotencyKey,
    required List<CartItem> items,
    required int paid,
    required PaymentMethod method,
  });

  /// Transaksi sejak tengah malam Asia/Jakarta untuk instan [now].
  Future<List<TransactionModel>> getTodayTransactions(DateTime now);

  Future<List<TransactionModel>> getTransactionHistory();

  Future<List<TransactionItem>> getTransactionItems(int transactionId);
}

class SupabaseTransactionRepository implements TransactionRepository {
  final SupabaseClient _client;

  SupabaseTransactionRepository(this._client);

  @override
  Future<TransactionModel> checkout({
    required String idempotencyKey,
    required List<CartItem> items,
    required int paid,
    required PaymentMethod method,
  }) {
    return guard('Gagal memproses pembayaran', map: mapCheckoutError, () async {
      final result = await _client.rpc('checkout', params: {
        'p_key': idempotencyKey,
        'p_items': [for (final i in items) {'product_id': i.productId, 'qty': i.quantity}],
        'p_paid': paid,
        'p_method': method.code,
      });
      return TransactionModel.fromCheckoutJson(Map<String, dynamic>.from(result as Map));
    });
  }

  @override
  Future<List<TransactionModel>> getTodayTransactions(DateTime now) {
    return guard('Gagal memuat transaksi hari ini', () async {
      final range = jakartaTodayRangeIso(now);
      final response = await _client
          .from('transactions')
          .select()
          .gte('created_at', range.start)
          .lt('created_at', range.end);
      return response.map(TransactionModel.fromRow).toList();
    });
  }

  @override
  Future<List<TransactionModel>> getTransactionHistory() {
    return guard('Gagal memuat riwayat transaksi', () async {
      final response = await _client.from('transactions').select().order('created_at', ascending: false);
      return response.map(TransactionModel.fromRow).toList();
    });
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(int transactionId) {
    return guard('Gagal memuat detail transaksi', () async {
      // Nama & harga diambil dari snapshot item, bukan join ke products
      final response = await _client
          .from('transaction_items')
          .select('product_id, product_name, quantity, price_at_purchase, subtotal')
          .eq('transaction_id', transactionId)
          .order('id');
      return response.map(TransactionItem.fromRow).toList();
    });
  }
}
