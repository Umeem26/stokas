import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_model.dart';
import 'stock_availability.dart';
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

class DashboardSummary {
  final int todayRevenue;
  final int lowStockCount;

  const DashboardSummary({required this.todayRevenue, required this.lowStockCount});
}

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final now = ref.watch(clockProvider)();

  // 1. Omzet hari ini (sejak tengah malam Asia/Jakarta)
  final transactions = await ref.watch(transactionRepositoryProvider).getTodayTransactions(now);
  final total = transactions.fold(0, (sum, t) => sum + t.totalAmount);

  // 2. Barang menipis: stok tersedia (tanpa batch kedaluwarsa) <= min_stock
  final stocks = await ref.watch(stockRepositoryProvider).getStockList();

  return DashboardSummary(todayRevenue: total, lowStockCount: lowStockCount(stocks, now));
});
