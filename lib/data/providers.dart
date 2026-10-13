import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_model.dart';
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

final stockListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(stockRepositoryProvider).getStockList(),
);

final transactionHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(transactionRepositoryProvider).getTransactionHistory(),
);

class DashboardSummary {
  final double todayRevenue;
  final int lowStockCount;

  const DashboardSummary({required this.todayRevenue, required this.lowStockCount});
}

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  // 1. Omzet hari ini
  final transactions = await ref.watch(transactionRepositoryProvider).getTodayTransactions();
  double total = 0;
  for (var t in transactions) {
    total += (t['total_amount'] as num).toDouble();
  }

  // 2. Stok menipis (qty <= min_stock)
  final stocks = await ref.watch(stockRepositoryProvider).getStockList();
  int lowCount = 0;
  for (var s in stocks) {
    final qty = (s['quantity'] as num).toDouble();
    final min = (s['products']['min_stock'] as num).toDouble();
    if (qty <= min) lowCount++;
  }

  return DashboardSummary(todayRevenue: total, lowStockCount: lowCount);
});
