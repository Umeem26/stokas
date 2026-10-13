import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/format.dart';
import '../product_model.dart';

/// Isi RPC create_product_with_stock: produk baru + stok awal opsional dalam satu langkah.
/// [price] > 0 hanya diterima server dari owner; gudang selalu mengirim 0.
class NewProduct {
  final String id;
  final String name;
  final String unit;
  final int? categoryId;
  final num minStock;
  final int price;
  final String? imageUrl;
  final String floor;
  final num? qty; // null/0 = tanpa stok awal
  final DateTime? expiry;
  final String? note;

  const NewProduct({
    required this.id,
    required this.name,
    required this.unit,
    this.categoryId,
    this.minStock = 5,
    this.price = 0,
    this.imageUrl,
    required this.floor,
    this.qty,
    this.expiry,
    this.note,
  });

  Map<String, dynamic> toRpcParams() => {
        'p_id': id.trim(),
        'p_name': name.trim(),
        'p_unit': unit.trim(),
        'p_category': categoryId,
        'p_min_stock': minStock,
        'p_price': price,
        'p_image_url': imageUrl,
        'p_floor': floor,
        'p_qty': (qty ?? 0) > 0 ? qty : null,
        'p_expiry': expiry == null ? null : formatDateParam(expiry!),
        'p_note': (note == null || note!.trim().isEmpty) ? null : note!.trim(),
      };
}

abstract class ProductRepository {
  Future<List<Map<String, dynamic>>> getCategories();

  /// Semua produk aktif (tanpa harga modal), urut nama; termasuk yang belum punya stok.
  Future<List<Map<String, dynamic>>> getProducts();

  /// Produk baru lewat RPC create_product_with_stock (tabel products tidak ditulis langsung).
  /// Jaringan putus = [NetworkException] (hasil belum pasti, jangan ulang otomatis).
  Future<void> createProductWithStock(NewProduct product);

  /// [includePrices] false: harga jual tidak dikirim (peran non-owner).
  Future<void> updateProduct(ProductModel product, {bool includePrices = true});

  /// Harga modal dari product_costs (khusus owner); null jika belum diisi.
  Future<int?> getCapitalPrice(String productId);

  /// Simpan harga modal ke product_costs (upsert, khusus owner).
  Future<void> saveCapitalPrice(String productId, int capitalPrice);

  /// Soft delete: produk ditandai is_deleted; stok & riwayat transaksi tidak disentuh.
  Future<void> deleteProduct(String productId);

  /// Upload foto produk; mengembalikan URL publik, atau null jika gagal.
  Future<String?> uploadImage(File imageFile);
}

class SupabaseProductRepository implements ProductRepository {
  final SupabaseClient _client;

  SupabaseProductRepository(this._client);

  @override
  Future<List<Map<String, dynamic>>> getCategories() {
    return guard('Gagal memuat kategori', () async {
      final response = await _client.from('categories').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() {
    return guard('Gagal memuat daftar barang', () async {
      final response = await _client.from('products').select('id, brand_name, unit_type, min_stock, category_id, price, image_url').eq('is_deleted', false).order('brand_name');
      return List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Future<void> createProductWithStock(NewProduct product) {
    const message = 'Gagal menyimpan barang';
    return guard(message, () async {
      await _client.rpc('create_product_with_stock', params: product.toRpcParams());
    }, map: (e) => mapUncertainWriteError(message, e));
  }

  @override
  Future<void> updateProduct(ProductModel product, {bool includePrices = true}) {
    return guard('Gagal memperbarui barang', () async {
      await _client.from('products').update({
        'brand_name': product.brandName,
        'category_id': product.categoryId,
        'unit_type': product.unitType,
        'min_stock': product.minStock,
        if (includePrices) 'price': product.price,
      }).eq('id', product.id);
    });
  }

  @override
  Future<int?> getCapitalPrice(String productId) {
    return guard('Gagal memuat harga modal', () async {
      final row = await _client.from('product_costs').select('capital_price').eq('product_id', productId).maybeSingle();
      return (row?['capital_price'] as num?)?.round();
    });
  }

  @override
  Future<void> saveCapitalPrice(String productId, int capitalPrice) {
    return guard('Gagal menyimpan harga modal', () async {
      await _client.from('product_costs').upsert({'product_id': productId, 'capital_price': capitalPrice});
    });
  }

  @override
  Future<void> deleteProduct(String productId) {
    return guard('Gagal menghapus barang', () async {
      await _client.from('products').update({'is_deleted': true}).eq('id', productId);
    });
  }

  @override
  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'uploads/$fileName';

      await _client.storage.from('product-images').upload(path, imageFile);
      return _client.storage.from('product-images').getPublicUrl(path);
    } catch (e) {
      // Perilaku lama dipertahankan: barang tetap disimpan tanpa foto.
      debugPrint('Gagal Upload: $e');
      return null;
    }
  }
}
