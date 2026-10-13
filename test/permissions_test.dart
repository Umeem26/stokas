import 'package:flutter_test/flutter_test.dart';
import 'package:minimarket_pos/core/permissions.dart';

void main() {
  // Matriks lengkap: setiap peran x setiap izin.
  const expected = {
    AppRole.cashier: {Permission.useCashier, Permission.viewHistory, Permission.viewStock},
    AppRole.warehouse: {
      Permission.viewStock,
      Permission.addProduct,
      Permission.editProduct,
      Permission.moveStock,
      Permission.restockStock,
      Permission.countStock,
    },
  };

  test('owner boleh semua, termasuk kelola staf dan harga', () {
    for (final p in Permission.values) {
      expect(can(AppRole.owner, p), isTrue, reason: p.name);
    }
  });

  for (final role in [AppRole.cashier, AppRole.warehouse]) {
    test('${role.name}: hanya izin di matriks', () {
      for (final p in Permission.values) {
        expect(can(role, p), expected[role]!.contains(p), reason: '${role.name}.${p.name}');
      }
    });
  }

  test('kasir hanya lihat stok: tanpa tambah/edit/hapus/mutasi/stok masuk/opname', () {
    for (final p in [Permission.addProduct, Permission.editProduct, Permission.deleteProduct, Permission.moveStock, Permission.restockStock, Permission.countStock]) {
      expect(can(AppRole.cashier, p), isFalse, reason: p.name);
    }
  });

  test('gudang tidak bisa ubah harga, tidak melihat harga modal, tanpa kasir/riwayat', () {
    for (final p in [Permission.editPrices, Permission.viewCapitalPrice, Permission.useCashier, Permission.viewHistory, Permission.manageStaff]) {
      expect(can(AppRole.warehouse, p), isFalse, reason: p.name);
    }
  });

  test('tanpa peran (belum login / peran tak dikenal) tidak boleh apa pun', () {
    for (final p in Permission.values) {
      expect(can(null, p), isFalse, reason: p.name);
    }
  });

  test('AppRole.tryParse mengenali nilai enum database', () {
    expect(AppRole.tryParse('owner'), AppRole.owner);
    expect(AppRole.tryParse('cashier'), AppRole.cashier);
    expect(AppRole.tryParse('warehouse'), AppRole.warehouse);
    expect(AppRole.tryParse('admin'), isNull);
    expect(AppRole.tryParse(null), isNull);
  });
}
