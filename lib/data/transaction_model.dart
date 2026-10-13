class TransactionModel {
  final int? id;
  final double totalAmount;
  final double paidAmount;
  final double changeAmount;
  final DateTime? createdAt;
  final List<CartItem> items; // Daftar belanjaan

  TransactionModel({
    this.id,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    this.createdAt,
    required this.items,
  });

  // Untuk mengubah data jadi format yang dimengerti Supabase
  Map<String, dynamic> toMap() {
    return {
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
    };
  }
}

// Class Kecil untuk Keranjang Belanja
class CartItem {
  final String productId;
  final String productName;
  final double price;
  int quantity; // Bisa diubah-ubah (tambah/kurang)

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
  });

  // Hitung subtotal per barang
  double get subtotal => price * quantity;
}