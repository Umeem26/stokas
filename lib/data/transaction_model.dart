/// Cara bayar; [code] = nilai kolom `transactions.payment_method` / parameter `p_method`.
enum PaymentMethod {
  cash('cash', 'Tunai'),
  qris('qris', 'QRIS'),
  transfer('transfer', 'Transfer');

  final String code;
  final String label;
  const PaymentMethod(this.code, this.label);

  /// Nilai tak dikenal/kosong dianggap tunai (bawaan kolom di server).
  static PaymentMethod fromCode(String? code) =>
      values.firstWhere((m) => m.code == code, orElse: () => PaymentMethod.cash);
}

/// Transaksi tersimpan (nota). Uang dalam Rupiah bulat.
class TransactionModel {
  final int id;
  final int totalAmount;
  final int paidAmount;
  final int changeAmount;
  final DateTime createdAt; // Waktu lokal perangkat
  final PaymentMethod paymentMethod;
  final String? cashierId; // null pada hasil RPC checkout (pasti pengguna yang login)
  final List<TransactionItem> items; // Kosong bila hanya header yang dimuat

  const TransactionModel({
    required this.id,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.createdAt,
    this.paymentMethod = PaymentMethod.cash,
    this.cashierId,
    this.items = const [],
  });

  /// Nomor struk dari `transactions.id` (serial, naik; bisa melompat bila checkout dibatalkan).
  String get receiptNumber => id.toString().padLeft(6, '0');

  TransactionModel withItems(List<TransactionItem> items) => TransactionModel(
        id: id,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        createdAt: createdAt,
        paymentMethod: paymentMethod,
        cashierId: cashierId,
        items: items,
      );

  /// Hasil RPC checkout: {id,total,paid,change,created_at,items:[...]}.
  factory TransactionModel.fromCheckoutJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      totalAmount: (json['total'] as num).round(),
      paidAmount: (json['paid'] as num).round(),
      changeAmount: (json['change'] as num).round(),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      paymentMethod: PaymentMethod.fromCode(json['payment_method'] as String?),
      items: [
        for (final i in (json['items'] as List? ?? const []))
          TransactionItem.fromCheckoutJson(Map<String, dynamic>.from(i as Map)),
      ],
    );
  }

  /// Baris tabel transactions (tanpa item).
  factory TransactionModel.fromRow(Map<String, dynamic> row) {
    return TransactionModel(
      id: row['id'] as int,
      totalAmount: (row['total_amount'] as num).round(),
      paidAmount: (row['paid_amount'] as num? ?? 0).round(),
      changeAmount: (row['change_amount'] as num? ?? 0).round(),
      createdAt: DateTime.parse(row['created_at']).toLocal(),
      paymentMethod: PaymentMethod.fromCode(row['payment_method'] as String?),
      cashierId: row['cashier_id'] as String?,
    );
  }
}

/// Baris nota: nama & harga adalah snapshot saat transaksi, bukan data produk terkini.
class TransactionItem {
  final String productId;
  final String productName;
  final num quantity;
  final int price;
  final int subtotal;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory TransactionItem.fromCheckoutJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['product_id'],
      productName: json['name'] ?? '',
      quantity: json['qty'] as num,
      price: (json['price'] as num).round(),
      subtotal: (json['subtotal'] as num).round(),
    );
  }

  /// Baris tabel transaction_items.
  factory TransactionItem.fromRow(Map<String, dynamic> row) {
    return TransactionItem(
      productId: row['product_id'],
      productName: row['product_name'] ?? '',
      quantity: row['quantity'] as num,
      price: (row['price_at_purchase'] as num).round(),
      subtotal: (row['subtotal'] as num).round(),
    );
  }
}

// Class Kecil untuk Keranjang Belanja (tidak diubah langsung; lihat CheckoutController)
class CartItem {
  final String productId;
  final String productName;
  final int price;
  final num quantity;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
  });

  CartItem copyWith({num? quantity}) =>
      CartItem(productId: productId, productName: productName, price: price, quantity: quantity ?? this.quantity);

  // Subtotal dibulatkan sama seperti server: round(price * qty)
  int get subtotal => (price * quantity).round();
}
