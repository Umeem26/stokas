import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/format.dart';
import '../stock_availability.dart';

/// Tabel stocks hanya dibaca; semua perubahan stok lewat RPC (restock, stock_count, transfer_stock).
abstract class StockRepository {
  /// Daftar batch stok beserta produk dan kategorinya (produk terhapus tidak ikut).
  Future<List<Map<String, dynamic>>> getStockList();

  /// Stok masuk: tambah [qty] ke batch (produk, lantai, kedaluwarsa).
  Future<void> restock({required String productId, required String floor, DateTime? expiry, required num qty, String? note});

  /// Opname: set batch menjadi hasil hitung fisik [counted].
  Future<void> stockCount({required String productId, required String floor, DateTime? expiry, required num counted, String? note});

  /// Pindahkan [qty] dari batch di lantai [from] ke lantai [to] (kedaluwarsa sama).
  Future<void> transferStock({required String productId, required String from, required String to, DateTime? expiry, required num qty});
}

String? _note(String? note) => (note == null || note.trim().isEmpty) ? null : note.trim();

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
      return withoutDeleted(List<Map<String, dynamic>>.from(response));
    });
  }

  @override
  Future<void> restock({required String productId, required String floor, DateTime? expiry, required num qty, String? note}) {
    return guard('Gagal menyimpan stok masuk', () async {
      await _client.rpc('restock', params: {
        'p_product': productId,
        'p_floor': floor,
        'p_expiry': expiry == null ? null : formatDateParam(expiry),
        'p_qty': qty,
        'p_note': _note(note),
      });
    });
  }

  @override
  Future<void> stockCount({required String productId, required String floor, DateTime? expiry, required num counted, String? note}) {
    return guard('Gagal menyimpan opname', () async {
      await _client.rpc('stock_count', params: {
        'p_product': productId,
        'p_floor': floor,
        'p_expiry': expiry == null ? null : formatDateParam(expiry),
        'p_counted': counted,
        'p_note': _note(note),
      });
    });
  }

  @override
  Future<void> transferStock({required String productId, required String from, required String to, DateTime? expiry, required num qty}) {
    return guard('Gagal memindahkan stok', () async {
      await _client.rpc('transfer_stock', params: {
        'p_product': productId,
        'p_from': from,
        'p_to': to,
        'p_expiry': expiry == null ? null : formatDateParam(expiry),
        'p_qty': qty,
      });
    });
  }
}
