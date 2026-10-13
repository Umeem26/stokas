import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_exception.dart';
import '../product_model.dart';

abstract class ProductRepository {
  Future<List<Map<String, dynamic>>> getCategories();

  /// Simpan produk baru beserta stok awalnya.
  Future<void> addProduct(ProductModel product, String floor, double initialQty, DateTime? expiry, String? imageUrl);

  /// [includePrices] false: harga jual & modal tidak dikirim (peran non-owner).
  Future<void> updateProduct(ProductModel product, {bool includePrices = true});

  /// Soft delete: produk ditandai is_deleted agar riwayat transaksi tetap aman.
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
  Future<void> addProduct(ProductModel product, String floor, double initialQty, DateTime? expiry, String? imageUrl) {
    return guard('Gagal menyimpan barang', () async {
      await _client.from('products').insert({
        'id': product.id,
        'brand_name': product.brandName,
        'category_id': product.categoryId,
        'unit_type': product.unitType,
        'min_stock': product.minStock,
        'price': product.price,
        'capital_price': product.capitalPrice,
        'image_url': imageUrl,
      });

      // Simpan Stok Awal
      await _client.from('stocks').insert({
        'product_id': product.id,
        'floor_name': floor,
        'quantity': initialQty,
        'expiry_date': expiry?.toIso8601String(),
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
        if (includePrices) 'capital_price': product.capitalPrice,
      }).eq('id', product.id);
    });
  }

  @override
  Future<void> deleteProduct(String productId) {
    return guard('Gagal menghapus barang', () async {
      await _client.from('products').update({'is_deleted': true}).eq('id', productId);

      // Stok dihapus agar tidak muncul di daftar stok; data produk tetap ada demi riwayat.
      await _client.from('stocks').delete().eq('product_id', productId);
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
