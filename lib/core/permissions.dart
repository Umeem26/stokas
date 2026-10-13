enum AppRole {
  owner('Owner'),
  cashier('Kasir'),
  warehouse('Gudang');

  final String label;
  const AppRole(this.label);

  /// Null jika nilai dari database tidak dikenal.
  static AppRole? tryParse(String? value) {
    for (final r in AppRole.values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

enum Permission {
  viewDashboard,
  useCashier,
  viewHistory,
  viewStock,
  addProduct,
  editProduct,
  deleteProduct,
  moveStock,
  restockStock, // Stok masuk (RPC restock)
  countStock, // Opname (RPC stock_count)
  editPrices,
  viewCapitalPrice,
  manageStaff,
}

const _cashierPermissions = {
  Permission.useCashier,
  Permission.viewHistory,
  Permission.viewStock,
};

const _warehousePermissions = {
  Permission.viewStock,
  Permission.addProduct,
  Permission.editProduct,
  Permission.moveStock,
  Permission.restockStock,
  Permission.countStock,
};

/// Satu-satunya sumber aturan hak akses di UI. Penjagaan sebenarnya ada di RLS.
bool can(AppRole? role, Permission permission) {
  switch (role) {
    case AppRole.owner:
      return true;
    case AppRole.cashier:
      return _cashierPermissions.contains(permission);
    case AppRole.warehouse:
      return _warehousePermissions.contains(permission);
    case null:
      return false;
  }
}
