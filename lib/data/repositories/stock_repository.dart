import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';

abstract class StockRepository {
  /// Daftar stok per lantai beserta produk dan kategorinya (produk terhapus tidak ikut).
  Future<List<Map<String, dynamic>>> getStockList();

  /// Pindahkan stok antar lantai.
  Future<void> moveStock({
    required int sourceStockId,
    required String productId,
    required String targetFloor,
    required double qtyToMove,
    required double currentSourceQty,
    DateTime? expiryDate,
  });
}

class SupabaseStockRepository implements StockRepository {
  final SupabaseClient _client;

  SupabaseStockRepository(this._client);

  @override
  Future<List<Map<String, dynamic>>> getStockList() {
    return guard('Gagal memuat data stok', () async {
      final response = await _client
          .from('stocks')
          .select('*, products!inner(*, categories(*))') // !inner agar bisa difilter
          .eq('products.is_deleted', false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Future<void> moveStock({
    required int sourceStockId,
    required String productId,
    required String targetFloor,
    required double qtyToMove,
    required double currentSourceQty,
    DateTime? expiryDate,
  }) {
    return guard('Gagal memindahkan stok', () async {
      if (qtyToMove > currentSourceQty) {
        throw AppException('Stok tidak cukup! Cuma ada $currentSourceQty');
      }

      // Kurangi stok di lantai asal; hapus barisnya jika habis
      final sisa = currentSourceQty - qtyToMove;
      if (sisa == 0) {
        await _client.from('stocks').delete().eq('id', sourceStockId);
      } else {
        await _client.from('stocks').update({'quantity': sisa}).eq('id', sourceStockId);
      }

      final checkDest = await _client
          .from('stocks')
          .select()
          .eq('product_id', productId)
          .eq('floor_name', targetFloor)
          .maybeSingle();

      if (checkDest != null) {
        final double oldQty = (checkDest['quantity'] as num).toDouble();
        await _client.from('stocks').update({'quantity': oldQty + qtyToMove}).eq('id', checkDest['id']);
      } else {
        await _client.from('stocks').insert({
          'product_id': productId,
          'floor_name': targetFloor,
          'quantity': qtyToMove,
          'expiry_date': expiryDate?.toIso8601String(),
        });
      }
    });
  }
}
