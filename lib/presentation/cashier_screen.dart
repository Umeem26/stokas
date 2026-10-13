import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_exception.dart';
import '../core/format.dart';
import '../data/checkout_controller.dart';
import '../data/providers.dart';
import '../data/session.dart';
import '../data/stock_availability.dart';
import '../data/transaction_model.dart';
import 'app_shell.dart' show railBreakpoint;
import 'cashier/cashier_widgets.dart';
import 'cashier/pay_panel.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'receipt_download.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/error_view.dart';

/// Layar Kasir. Lebar >= 768: dua panel (produk | keranjang 408 px); saat bayar menjadi
/// (ringkasan pesanan | panel bayar 480 px). Di bawahnya satu kolom dengan bilah
/// "Keranjang (n) · Rp ..." yang membuka keranjang layar penuh; panel bayar layar penuh.
/// Keranjang ada di [checkoutControllerProvider], jadi tidak hilang saat muat ulang/bayar gagal.
/// Setelah sukses tampil layar selesai sampai "Transaksi baru".
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<SellableProduct> _allProducts = []; // stok tersedia = batch belum kedaluwarsa
  bool _loading = true;
  Object? _loadError; // terisi jika daftar barang gagal dimuat
  String _query = '';
  String? _category; // null = Semua

  bool _payOpen = false; // panel bayar menggantikan keranjang
  String? _payError; // pesan gagal bayar terakhir (apa adanya dari server)
  String? _problemProductId; // baris keranjang yang ditolak server

  bool get _wide => MediaQuery.sizeOf(context).width >= railBreakpoint;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (_loadError != null) setState(() => _loading = true);
    final List<Map<String, dynamic>> data;
    try {
      data = await ref.read(stockRepositoryProvider).getStockList();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _loading = false;
      _allProducts = sellableProducts(data, ref.read(clockProvider)());
    });
  }

  static String? _categoryOf(SellableProduct p) => (p.product['categories'] as Map?)?['name'] as String?;

  List<String> get _categories => {for (final p in _allProducts) ?_categoryOf(p)}.toList()..sort();

  List<SellableProduct> get _visible {
    final k = _query.trim().toLowerCase();
    return _allProducts
        .where((p) => _category == null || _categoryOf(p) == _category)
        .where((p) => k.isEmpty || p.name.toLowerCase().contains(k) || p.id.toLowerCase().contains(k))
        .toList();
  }

  void _showMessage(String message, {bool error = false}) {
    final c = context.stokas;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.info_outline, color: c.canvas),
            const SizedBox(width: StokasSpace.s2),
            Expanded(child: Text(message)),
          ],
        ),
      ));
  }

  /// Di tablet/PC kolom cari selalu fokus (scanner USB = keyboard).
  void _refocusSearch() {
    if (mounted && _wide) _searchFocus.requestFocus();
  }

  /// Tambah 1; ditolak bila habis atau melebihi stok tersedia (server tetap sumber kebenaran).
  void _addToCart(SellableProduct product) {
    if (product.available <= 0) {
      _showMessage('${product.name} habis', error: true);
      return;
    }
    final error = ref.read(checkoutControllerProvider.notifier).add(product);
    if (error != null) _showMessage('${product.name}: $error', error: true);
  }

  void _increment(String productId) {
    final product = _allProducts.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      _showMessage('Barang tidak ditemukan di daftar stok', error: true);
      return;
    }
    _addToCart(product);
  }

  /// Enter di kolom cari (scan): `products.id` persis dulu, baru nama.
  /// Enter di kolom kosong dengan keranjang terisi = buka panel bayar.
  void _submitSearch(String text) {
    if (text.trim().isEmpty) {
      if (ref.read(checkoutControllerProvider).items.isNotEmpty) {
        _openPay();
      } else {
        _refocusSearch();
      }
      return;
    }
    final match = findScanMatch(_allProducts, text);
    if (match != null) {
      _addToCart(match);
      _searchController.clear();
      setState(() => _query = '');
    } else if (_visible.isNotEmpty) {
      _showMessage('Ada beberapa barang yang cocok, pilih dari daftar');
    } else {
      _showMessage('Barang tidak ditemukan', error: true);
    }
    _searchFocus.requestFocus();
  }

  Future<void> _clearCart() async {
    final lines = ref.read(checkoutControllerProvider).items.length;
    if (await confirmClearCart(context, lines)) ref.read(checkoutControllerProvider.notifier).clear();
    _refocusSearch();
  }

  void _openPay() {
    final checkout = ref.read(checkoutControllerProvider);
    if (checkout.items.isEmpty || checkout.isLocked) return;
    setState(() {
      _payOpen = true;
      _payError = null;
      _problemProductId = null;
    });
  }

  void _closePay() {
    if (ref.read(checkoutControllerProvider).isPaying) return;
    setState(() {
      _payOpen = false;
      _payError = null;
      _problemProductId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refocusSearch());
  }

  /// Gagal: panel, keranjang, dan kunci transaksi tetap (bayar ulang aman); pesan server
  /// ditampilkan apa adanya dan baris yang ditolak ditandai bila bisa dikenali.
  Future<void> _submitPay(int paid, PaymentMethod method) async {
    setState(() {
      _payError = null;
      _problemProductId = null;
    });
    final items = ref.read(checkoutControllerProvider).items;
    try {
      final tx = await ref.read(checkoutControllerProvider.notifier).pay(paid, method: method);
      if (tx == null || !mounted) return;
      setState(() => _payOpen = false);
      ref.invalidate(transactionHistoryProvider);
      _loadProducts();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _payError = e.message;
        _problemProductId = problemProductId(e.message, items, hintProductId: e is InsufficientStockException ? e.productId : null);
      });
      // Stok berubah sejak dimuat: perbarui angka stok di kisi.
      if (e is InsufficientStockException) _loadProducts();
    } catch (e) {
      if (mounted) setState(() => _payError = '$e');
    }
  }

  void _startNew() {
    ref.read(checkoutControllerProvider.notifier).startNew();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refocusSearch());
  }

  Widget _payPanel(CheckoutState checkout, {Widget? header}) => PayPanel(
        total: checkout.total,
        busy: checkout.isPaying,
        error: _payError,
        header: header,
        onPay: _submitPay,
        onBack: _closePay,
      );

  Widget _cartPanel(CheckoutState checkout, {VoidCallback? onPay}) {
    final notifier = ref.read(checkoutControllerProvider.notifier);
    return CartPanel(
      checkout: checkout,
      onIncrement: _increment,
      onDecrement: notifier.decrement,
      onRemove: notifier.remove,
      onPay: onPay ?? _openPay,
      onClear: _clearCart,
    );
  }

  void _openCart() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _CartPage(screen: this)));
  }

  Widget _buildProducts({required bool wide}) {
    final c = context.stokas;
    final categories = _categories;
    final visible = _visible;

    Widget grid;
    if (_loadError != null) {
      grid = ErrorView(error: _loadError!, onRetry: _loadProducts);
    } else if (_loading) {
      grid = const Center(child: CircularProgressIndicator());
    } else if (visible.isEmpty) {
      grid = Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: c.inkMuted),
            const SizedBox(width: StokasSpace.s2),
            Text(_allProducts.isEmpty ? 'Belum ada barang' : 'Tidak ada barang yang cocok',
                style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
          ],
        ),
      );
    } else {
      grid = LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          padding: const EdgeInsets.all(StokasSpace.s4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            // 3 kolom di dua panel; panel yang sempit (dan HP) 2 kolom agar kartu tetap terbaca.
            crossAxisCount: wide && constraints.maxWidth >= 480 ? 3 : 2,
            mainAxisExtent: 148,
            crossAxisSpacing: StokasSpace.s3,
            mainAxisSpacing: StokasSpace.s3,
          ),
          itemCount: visible.length,
          itemBuilder: (context, i) => ProductCard(
            product: visible[i],
            onAdd: () {
              _addToCart(visible[i]);
              _refocusSearch();
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s4, StokasSpace.s4, StokasSpace.s2),
          child: TextField(
            key: const Key('cashier-search'),
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: wide,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Cari nama atau scan kode',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                        _searchFocus.requestFocus();
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: _submitSearch,
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: StokasSpace.tapMin + StokasSpace.s2,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4),
              children: [
                for (final (label, value) in [('Semua', null), for (final k in categories) (k, k)])
                  Padding(
                    padding: const EdgeInsets.only(right: StokasSpace.s2),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _category == value,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(() => _category = value),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: grid),
      ],
    );
  }

  Widget _body(CheckoutState checkout) {
    final c = context.stokas;
    final done = checkout.completed;
    if (done != null) {
      return CheckoutDoneView(
        transaction: done,
        onNewTransaction: _startNew,
        onDownload: () => downloadReceipt(context, ref, done, cashierName: ref.read(currentProfileProvider)?.fullName ?? ''),
      );
    }

    if (_wide) {
      return Row(
        key: const Key('cashier-two-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _payOpen
                ? OrderSummary(items: checkout.items, total: checkout.total, problemProductId: _problemProductId)
                : _buildProducts(wide: true),
          ),
          VerticalDivider(width: 1, color: c.line),
          SizedBox(
            key: Key(_payOpen ? 'cashier-pay-panel' : 'cashier-cart-panel'),
            width: _payOpen ? payPanelWidth : cartPanelWidth,
            child: Material(color: c.surface, child: _payOpen ? _payPanel(checkout) : _cartPanel(checkout)),
          ),
        ],
      );
    }

    if (_payOpen) {
      return Material(
        key: const Key('cashier-pay-panel'),
        color: c.surface,
        child: _payPanel(checkout, header: OrderSummaryTile(items: checkout.items, problemProductId: _problemProductId)),
      );
    }
    return Column(
      key: const Key('cashier-one-column'),
      children: [
        Expanded(child: _buildProducts(wide: false)),
        DecoratedBox(
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s3),
            child: StokasButton(
              key: const Key('cart-bar'),
              label: 'Keranjang (${checkout.items.length}) · ${formatRupiah(checkout.total)}',
              icon: Icons.shopping_cart_outlined,
              expand: true,
              onPressed: _openCart,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(checkoutControllerProvider);
    // Tombol kembali sistem menutup panel bayar, bukan layar Kasir.
    return PopScope(
      canPop: !_payOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _payOpen) _closePay();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Kasir'), actions: const [AccountMenuButton()]),
        body: _body(checkout),
      ),
    );
  }
}

/// Keranjang layar penuh (HP). Memakai state & aksi layar Kasir; "Bayar" menutupnya dan membuka panel bayar.
class _CartPage extends ConsumerWidget {
  final _CashierScreenState screen;

  const _CartPage({required this.screen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutControllerProvider);
    return Scaffold(
      key: const Key('cart-page'),
      appBar: AppBar(title: const Text('Keranjang')),
      body: SafeArea(
        child: screen._cartPanel(
          checkout,
          onPay: () {
            Navigator.pop(context);
            screen._openPay();
          },
        ),
      ),
    );
  }
}
