import 'transaction_model.dart';

/// Total belanja = jumlah subtotal semua item di keranjang.
double calculateTotal(List<CartItem> items) => items.fold(0, (sum, item) => sum + item.subtotal);

/// Kembalian = uang diterima - total belanja.
double calculateChange({required double total, required double paid}) => paid - total;
