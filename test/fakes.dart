import 'dart:async';
import 'dart:io';

import 'package:minimarket_pos/core/app_exception.dart';
import 'package:minimarket_pos/data/product_model.dart';
import 'package:minimarket_pos/data/profile_model.dart';
import 'package:minimarket_pos/data/repositories/auth_repository.dart';
import 'package:minimarket_pos/core/permissions.dart';
import 'package:minimarket_pos/data/repositories/product_repository.dart';
import 'package:minimarket_pos/data/repositories/profile_repository.dart';
import 'package:minimarket_pos/data/repositories/staff_repository.dart';
import 'package:minimarket_pos/data/repositories/stock_repository.dart';
import 'package:minimarket_pos/data/repositories/transaction_repository.dart';
import 'package:minimarket_pos/data/revenue.dart';
import 'package:minimarket_pos/data/transaction_model.dart';

/// Panggilan checkout yang tercatat oleh [FakeTransactionRepository].
class CheckoutCall {
  final String key;
  final List<CartItem> items;
  final int paid;
  final PaymentMethod method;
  CheckoutCall(this.key, this.items, this.paid, this.method);
}

/// Repository palsu: meniru RPC checkout (idempoten per kunci; uang kurang dan QRIS/transfer
/// yang tidak pas ditolak seperti server). [nextError] dilempar sekali;
/// [gate] menahan jawaban sampai di-complete (untuk uji tap ganda).
class FakeTransactionRepository implements TransactionRepository {
  final calls = <CheckoutCall>[];
  final _byKey = <String, TransactionModel>{};
  Object? nextError;
  Completer<void>? gate;
  int _nextId = 1;

  @override
  Future<TransactionModel> checkout({
    required String idempotencyKey,
    required List<CartItem> items,
    required int paid,
    required PaymentMethod method,
  }) async {
    calls.add(CheckoutCall(idempotencyKey, items, paid, method));
    if (gate != null) await gate!.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final existing = _byKey[idempotencyKey];
    if (existing != null) return existing;
    final total = items.fold(0, (s, i) => s + i.subtotal);
    if (paid < total) throw const AppException('Uang bayar kurang dari total');
    if (method != PaymentMethod.cash && paid != total) throw const AppException('QRIS dan transfer harus dibayar pas');
    return _byKey.putIfAbsent(idempotencyKey, () {
      return TransactionModel(
        id: _nextId++,
        totalAmount: total,
        paidAmount: paid,
        changeAmount: paid - total,
        createdAt: DateTime.now(),
        paymentMethod: method,
        items: [
          for (final i in items)
            TransactionItem(productId: i.productId, productName: i.productName, quantity: i.quantity, price: i.price, subtotal: i.subtotal),
        ],
      );
    });
  }

  int get transactionCount => _byKey.length;

  /// Baris omzet untuk [getRevenueRows]; [revenueError] dilempar sekali.
  final revenueRows = <RevenueRow>[];
  Object? revenueError;
  int revenueLoads = 0;

  @override
  Future<List<RevenueRow>> getRevenueRows(DateTime start, DateTime end) async {
    revenueLoads++;
    final error = revenueError;
    if (error != null) {
      revenueError = null;
      throw error;
    }
    return [
      for (final r in revenueRows)
        if (!r.createdAt.isBefore(start) && r.createdAt.isBefore(end)) r,
    ];
  }

  @override
  Future<List<TransactionModel>> getTransactionHistory() async => _byKey.values.toList();

  @override
  Future<List<TransactionItem>> getTransactionItems(int transactionId) async =>
      _byKey.values.firstWhere((t) => t.id == transactionId).items;
}

/// Repository palsu: stok dalam memori dengan semantik RPC restock / stock_count / transfer_stock.
class FakeStockRepository implements StockRepository {
  final List<Map<String, dynamic>> rows;
  final calls = <String>[];
  int loads = 0;

  /// Galat restock per product_id, dilempar sekali (setelah panggilan dicatat).
  final restockErrors = <String, Object>{};

  /// Galat untuk panggilan yang catatannya diawali kunci (mis. 'opname A Lantai 2'), dilempar sekali.
  final failures = <String, Object>{};

  void _maybeFail(String call) {
    for (final key in failures.keys.toList()) {
      if (call.startsWith(key)) throw failures.remove(key)!;
    }
  }

  FakeStockRepository(this.rows);

  static String _d(DateTime? d) => d == null ? '-' : '${d.year}-${d.month}-${d.day}';

  Map<String, dynamic>? _find(String productId, String floor, DateTime? expiry) {
    for (final r in rows) {
      final e = r['expiry_date'] as String?;
      if (r['product_id'] == productId && r['floor_name'] == floor && _d(e == null ? null : DateTime.parse(e)) == _d(expiry)) {
        return r;
      }
    }
    return null;
  }

  Map<String, dynamic> _upsert(String productId, String floor, DateTime? expiry) {
    final existing = _find(productId, floor, expiry);
    if (existing != null) return existing;
    final template = rows.firstWhere((r) => r['product_id'] == productId, orElse: () => {'product_id': productId});
    final row = {
      ...template,
      'id': rows.length + 1,
      'floor_name': floor,
      'expiry_date': expiry == null ? null : '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}',
      'quantity': 0,
    };
    rows.add(row);
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> getStockList() async {
    loads++;
    return [for (final r in rows) {...r}];
  }

  @override
  Future<void> restock({required String productId, required String floor, DateTime? expiry, required num qty, String? note}) async {
    calls.add('restock $productId $floor ${_d(expiry)} $qty ${note ?? ''}'.trim());
    final error = restockErrors.remove(productId);
    if (error != null) throw error;
    final row = _upsert(productId, floor, expiry);
    row['quantity'] = (row['quantity'] as num) + qty;
  }

  @override
  Future<void> stockCount({required String productId, required String floor, DateTime? expiry, required num counted, String? note}) async {
    calls.add('opname $productId $floor ${_d(expiry)} $counted ${note ?? ''}'.trim());
    _maybeFail(calls.last);
    _upsert(productId, floor, expiry)['quantity'] = counted;
  }

  @override
  Future<void> transferStock({required String productId, required String from, required String to, DateTime? expiry, required num qty}) async {
    calls.add('transfer $productId $from->$to ${_d(expiry)} $qty');
    _maybeFail(calls.last);
    final src = _find(productId, from, expiry);
    if (src == null || (src['quantity'] as num) < qty) throw const AppException('Stok di lantai asal tidak cukup');
    src['quantity'] = (src['quantity'] as num) - qty;
    final dst = _upsert(productId, to, expiry);
    dst['quantity'] = (dst['quantity'] as num) + qty;
  }
}

/// Repository produk palsu: meniru RPC create_product_with_stock (kode ganda ditolak),
/// mencatat harga modal (product_costs) dan soft delete. [nextError] dilempar sekali.
class FakeProductRepository implements ProductRepository {
  final List<Map<String, dynamic>> products;
  final created = <NewProduct>[];
  Object? nextError;
  final capitalPrices = <String, int>{};
  final deleted = <String>[];
  final updates = <(ProductModel, bool)>[];
  final capitalSaves = <(String, int)>[];
  int capitalReads = 0;

  /// Galat untuk updateProduct / getProducts, dilempar sekali.
  Object? updateError;
  Object? loadError;

  FakeProductRepository([List<Map<String, dynamic>>? products]) : products = products ?? [];

  @override
  Future<List<Map<String, dynamic>>> getCategories() async => [
        {'id': 1, 'name': 'Makanan'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    final error = loadError;
    if (error != null) {
      loadError = null;
      throw error;
    }
    return [for (final p in products) {...p}];
  }

  @override
  Future<void> createProductWithStock(NewProduct product) async {
    created.add(product);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    if (products.any((p) => p['id'] == product.id.trim())) throw const AppException('Kode barang sudah dipakai');
    products.add({'id': product.id.trim(), 'brand_name': product.name.trim(), 'unit_type': product.unit});
  }

  @override
  Future<void> updateProduct(ProductModel product, {bool includePrices = true}) async {
    updates.add((product, includePrices));
    final error = updateError;
    if (error != null) {
      updateError = null;
      throw error;
    }
  }

  @override
  Future<int?> getCapitalPrice(String productId) async {
    capitalReads++;
    return capitalPrices[productId];
  }

  @override
  Future<void> saveCapitalPrice(String productId, int capitalPrice) async {
    capitalSaves.add((productId, capitalPrice));
    capitalPrices[productId] = capitalPrice;
  }

  @override
  Future<void> deleteProduct(String productId) async => deleted.add(productId);

  @override
  Future<String?> uploadImage(File imageFile) async => null;
}

/// Auth palsu: [signIn] memakai identifier sebagai id pengguna.
class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthChange>.broadcast();
  String? userId;
  int signOutCalls = 0;

  FakeAuthRepository([this.userId]);

  @override
  String? get currentUserId => userId;

  @override
  Stream<AuthChange> get changes => _controller.stream;

  @override
  Future<void> signIn(String identifier, String password) async {
    userId = identifier;
    _controller.add(AuthChange.signedIn);
  }

  /// Event dari luar (mis. siaran antar-tab Supabase di web) tanpa memanggil signIn/signOut.
  void emit(AuthChange change) => _controller.add(change);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    userId = null;
    _controller.add(AuthChange.signedOut);
  }
}

class FakeProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles;
  FakeProfileRepository(this.profiles);

  @override
  Future<Profile?> getProfile(String userId) async => profiles[userId];

  @override
  Future<List<Profile>> getAllProfiles() async => profiles.values.toList();
}

/// Staf palsu: mencatat setiap panggilan setActive / setPassword / createStaff.
class FakeStaffRepository implements StaffRepository {
  final setActiveCalls = <(String, bool)>[];
  final setPasswordCalls = <String>[];
  final created = <String>[];

  @override
  Future<void> createStaff({required String username, required String fullName, required AppRole role, required String password}) async =>
      created.add(username);

  @override
  Future<void> setPassword({required String userId, required String password}) async => setPasswordCalls.add(userId);

  @override
  Future<void> setActive({required String userId, required bool isActive}) async => setActiveCalls.add((userId, isActive));
}
