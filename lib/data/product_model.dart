class ProductModel {
  final String id;
  final String brandName;
  final int categoryId;
  final String unitType;
  final double minStock;
  // Tambahan Baru:
  final double price;        // Harga Jual
  final double capitalPrice; // Harga Modal

  ProductModel({
    required this.id,
    required this.brandName,
    required this.categoryId,
    required this.unitType,
    required this.minStock,
    required this.price,
    required this.capitalPrice,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      brandName: map['brand_name'],
      categoryId: map['category_id'],
      unitType: map['unit_type'],
      minStock: (map['min_stock'] as num).toDouble(),
      // Ambil data harga (pakai 0 jika kosong)
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      capitalPrice: (map['capital_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}