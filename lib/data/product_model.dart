class ProductModel {
  final String id;
  final String brandName;
  final int categoryId;
  final String unitType;
  final double minStock;
  final int price; // Harga jual (Rupiah). Harga modal ada di tabel product_costs (khusus owner).

  ProductModel({
    required this.id,
    required this.brandName,
    required this.categoryId,
    required this.unitType,
    required this.minStock,
    required this.price,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      brandName: map['brand_name'],
      categoryId: map['category_id'],
      unitType: map['unit_type'],
      minStock: (map['min_stock'] as num).toDouble(),
      // Pakai 0 jika kosong
      price: (map['price'] as num?)?.round() ?? 0,
    );
  }
}
