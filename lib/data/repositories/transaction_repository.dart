import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../revenue.dart';
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

  /// Total dan waktu transaksi pada [start, end) (instan UTC), untuk ringkasan omzet Home.
  Future<List<RevenueRow>> getRevenueRows(DateTime start, DateTime end);

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
  Future<List<RevenueRow>> getRevenueRows(DateTime start, DateTime end) {
    return guard('Gagal memuat omzet', () async {
      final response = await _client
          .from('transactions')
          .select('total_amount, created_at')
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String());
      return [
        for (final r in response)
          (amount: (r['total_amount'] as num).round(), createdAt: DateTime.parse(r['created_at'] as String).toUtc()),
      ];
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
