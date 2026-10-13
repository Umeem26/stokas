import '../core/format.dart';
import 'transaction_model.dart';

/// Total belanja = jumlah subtotal semua item di keranjang.
int calculateTotal(List<CartItem> items) => items.fold(0, (sum, item) => sum + item.subtotal);

/// Kembalian = uang diterima - total belanja.
int calculateChange({required int total, required int paid}) => paid - total;

/// Pesan bila menambah [step] lagi melebihi stok [available]; null jika masih boleh.
/// Hanya pencegahan di UI; server (RPC checkout) tetap sumber kebenaran.
String? cartAddError({required num inCart, required num available, num step = 1}) {
  if (inCart + step > available) return 'Stok tersisa ${formatQty(available < 0 ? 0 : available)}';
  return null;
}
