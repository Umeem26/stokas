import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attention.dart';
import 'profile_model.dart';
import 'revenue.dart';
import 'transaction_model.dart';
import 'repositories/auth_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/staff_repository.dart';
import 'repositories/stock_repository.dart';
import 'repositories/transaction_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => SupabaseProductRepository(ref.watch(supabaseClientProvider)),
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => SupabaseStockRepository(ref.watch(supabaseClientProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => SupabaseTransactionRepository(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => SupabaseStaffRepository(ref.watch(supabaseClientProvider)),
);

final staffListProvider = FutureProvider.autoDispose<List<Profile>>(
  (ref) => ref.watch(profileRepositoryProvider).getAllProfiles(),
);

final categoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(productRepositoryProvider).getCategories(),
);

/// Produk aktif untuk scan/cari di layar Terima.
final productListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(productRepositoryProvider).getProducts(),
);

final stockListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(stockRepositoryProvider).getStockList(),
);

final transactionHistoryProvider = FutureProvider.autoDispose<List<TransactionModel>>(
  (ref) => ref.watch(transactionRepositoryProvider).getTransactionHistory(),
);

/// Jam sekarang; bisa di-override di tes.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Kartu "Omzet hari ini" di Home owner (hari kalender WIB, dihitung di klien).
final homeRevenueProvider = FutureProvider.autoDispose<RevenueSummary>((ref) async {
  final now = ref.watch(clockProvider)();
  final range = revenueRangeUtc(now);
  final rows = await ref.watch(transactionRepositoryProvider).getRevenueRows(range.start, range.end);
  return summarizeRevenue(rows, now);
});

/// Daftar "Perlu diurus" di Home owner.
final homeAttentionProvider = FutureProvider.autoDispose<List<AttentionItem>>((ref) async {
  final now = ref.watch(clockProvider)();
  // Future.wait meneruskan galat aslinya (AppException), bukan ParallelWaitError.
  final [products, stocks] = await Future.wait([
    ref.watch(productRepositoryProvider).getProducts(),
    ref.watch(stockRepositoryProvider).getStockList(),
  ]);
  return attentionItems(products: products, stockRows: stocks, now: now);
});
