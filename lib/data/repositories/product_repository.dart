import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../product_model.dart';

abstract class ProductRepository {
  Future<List<Map<String, dynamic>>> getCategories();

  /// Simpan produk baru (tanpa stok; stok awal lewat StockRepository.restock).
  Future<void> addProduct(ProductModel product, {String? imageUrl});

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
  Future<void> addProduct(ProductModel product, {String? imageUrl}) {
    return guard('Gagal menyimpan barang', () async {
      await _client.from('products').insert({
        'id': product.id,
        'brand_name': product.brandName,
        'category_id': product.categoryId,
        'unit_type': product.unitType,
        'min_stock': product.minStock,
        'price': product.price,
        'image_url': imageUrl,
      });
    });
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
