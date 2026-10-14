import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_exception.dart';
import '../core/format.dart';
import '../data/checkout_controller.dart';
import '../data/providers.dart';
import '../data/scan_match.dart';
import '../data/scanner_buffer.dart';
import '../data/session.dart';
import '../data/stock_availability.dart';
import '../data/transaction_model.dart';
import 'app_shell.dart' show railBreakpoint;
import 'cashier/cashier_widgets.dart';
import 'cashier/pay_panel.dart';
import 'cashier/pc_widgets.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'receipt_download.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/error_view.dart';

/// Layar Kasir. Lebar >= 1280 (mode PC): kolom cari + status scanner + tabel keranjang |
/// kolom bayar 400 px, bilah pintasan di bawah. Lebar >= 768: dua panel (produk | keranjang
/// 408 px). Saat bayar, panel kiri menjadi ringkasan pesanan dan panel bayar 480 px menggantikan
/// keranjang. Di bawah 768 satu kolom dengan bilah "Keranjang (n) · Rp ..." dan panel bayar layar penuh.
/// Keranjang ada di [checkoutControllerProvider], jadi tidak hilang saat muat ulang/bayar gagal.
/// Setelah sukses tampil layar selesai sampai "Transaksi baru".
///
/// Keyboard (semua juga punya tombol layar): "/" cari; Enter di cari kosong = bayar; + − jumlah,
/// panah pilih baris, Del/Backspace hapus baris (mode PC, cari kosong); Esc tutup hasil cari/panel;
/// Enter di layar selesai = transaksi baru. Ketikan cepat di luar kolom teks = scan ([ScannerBuffer]).
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'cashier-search');
  final _keysFocus = FocusNode(debugLabel: 'cashier-keys'); // penerima tombol saat tidak ada kolom fokus
  final _scanner = ScannerBuffer();

  List<SellableProduct> _allProducts = []; // stok tersedia = batch belum kedaluwarsa
  bool _loading = true;
  Object? _loadError; // terisi jika daftar barang gagal dimuat
  String _query = '';
  String? _category; // null = Semua

  bool _payOpen = false; // panel bayar menggantikan keranjang
  String? _payError; // pesan gagal bayar terakhir (apa adanya dari server)
  String? _problemProductId; // baris keranjang yang ditolak server
  PaymentMethod _lastMethod = PaymentMethod.cash; // cara bayar terakhir dipakai di sesi ini

  String? _selectedId; // baris keranjang terpilih (mode PC)
  int _resultIndex = 0; // hasil pencarian yang disorot
  bool _resultsNavigated = false; // panah sudah dipakai: Enter menambah hasil yang disorot
  bool _resultsHidden = false; // ditutup dengan Esc sampai ketikan berikutnya
  String? _scanStatus; // hasil scan/tambah terakhir (mode PC)
  bool _scanStatusError = false;

  ModalRoute<Object?>? _route;
  bool _tabVisible = true;

  bool get _wide => MediaQuery.sizeOf(context).width >= railBreakpoint;
  bool get _pc => MediaQuery.sizeOf(context).width >= pcBreakpoint;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    FocusManager.instance.addListener(_onPrimaryFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPrimaryFocusChange());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onPrimaryFocusChange);
    _searchController.dispose();
    _searchFocus.dispose();
    _keysFocus.dispose();
    super.dispose();
  }

  /// Bila fokus jatuh ke lingkup rute (mis. kolom cari dilepas dengan klik di luar), layar ini
  /// mengambil fokus agar pintasan dan scanner tetap terdengar. Tidak saat tab lain/rute lain tampil.
  void _onPrimaryFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tabVisible || !(_route?.isCurrent ?? true)) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || (primary is FocusScopeNode && _keysFocus.ancestors.contains(primary))) {
        _keysFocus.requestFocus();
      }
    });
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

  List<SellableProduct> get _results => searchResults(_allProducts, _query, id: (p) => p.id, name: (p) => p.name);

  bool get _resultsVisible => _pc && !_payOpen && !_resultsHidden && _query.trim().isNotEmpty;

  /// Baris terpilih; bila belum ada atau sudah dihapus, baris terakhir.
  String? _selected(List<CartItem> items) {
    if (items.any((i) => i.productId == _selectedId)) return _selectedId;
    return items.isEmpty ? null : items.last.productId;
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

  /// Mode PC: pesan tampil di status scan (role=status). Di bawahnya: snackbar untuk galat
  /// (dan pesan sukses bila [toastOnNarrow]).
  void _notify(String message, {bool error = false, bool toastOnNarrow = false}) {
    if (_pc) {
      setState(() {
        _scanStatus = message;
        _scanStatusError = error;
      });
    } else if (error || toastOnNarrow) {
      _showMessage(message, error: error);
    }
  }

  /// Di tablet/PC kolom cari selalu fokus (scanner USB = keyboard).
  void _refocusSearch() {
    if (mounted && _wide) _searchFocus.requestFocus();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _resultIndex = 0;
      _resultsNavigated = false;
      _resultsHidden = false;
    });
  }

  /// Tambah 1; ditolak bila habis atau melebihi stok tersedia (server tetap sumber kebenaran).
  bool _addToCart(SellableProduct product, {bool toastOnNarrow = false}) {
    if (product.available <= 0) {
      _notify('${product.name} habis', error: true);
      return false;
    }
    final error = ref.read(checkoutControllerProvider.notifier).add(product);
    if (error != null) {
      _notify('${product.name}: $error', error: true);
      return false;
    }
    setState(() => _selectedId = product.id);
    final qty = ref.read(checkoutControllerProvider).quantityOf(product.id);
    _notify('Ditambahkan: ${product.name}, jumlah sekarang ${formatQty(qty)}', toastOnNarrow: toastOnNarrow);
    return true;
  }

  void _increment(String productId) {
    final product = _allProducts.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      _notify('Barang tidak ditemukan di daftar stok', error: true);
      return;
    }
    _addToCart(product);
  }

  /// Baris yang dipilih setelah [productId] hilang dari keranjang: baris berikutnya, atau sebelumnya.
  void _selectNeighborOf(String productId) {
    final items = ref.read(checkoutControllerProvider).items;
    final i = items.indexWhere((x) => x.productId == productId);
    if (i < 0) return;
    final rest = [...items]..removeAt(i);
    _selectedId = rest.isEmpty ? null : rest[i.clamp(0, rest.length - 1)].productId;
  }

  void _decrement(String productId) {
    final notifier = ref.read(checkoutControllerProvider.notifier);
    if (ref.read(checkoutControllerProvider).quantityOf(productId) <= 1) _selectNeighborOf(productId);
    notifier.decrement(productId);
    setState(() {});
  }

  void _remove(String productId) {
    _selectNeighborOf(productId);
    ref.read(checkoutControllerProvider.notifier).remove(productId);
    setState(() {});
  }

  void _pickResult(SellableProduct product) {
    if (_addToCart(product)) _clearSearch();
    _searchFocus.requestFocus();
  }

  /// Enter di kolom cari (scan): `products.id` persis, nama persis, lalu nama mengandung bila
  /// tunggal. Di mode PC, setelah panah dipakai, Enter menambah hasil yang disorot.
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
    final results = _results;
    if (_resultsVisible && _resultsNavigated && results.isNotEmpty) {
      _pickResult(results[_resultIndex.clamp(0, results.length - 1)]);
      return;
    }
    final match = findScanMatch(_allProducts, text);
    if (match != null) {
      if (_addToCart(match)) _clearSearch();
    } else if (_pc ? results.isNotEmpty : _visible.isNotEmpty) {
      _notify('Ada beberapa barang yang cocok, pilih dari daftar', toastOnNarrow: true);
      setState(() => _resultsHidden = false);
    } else {
      _notify(_pc ? 'Barang tidak ditemukan: ${text.trim()}' : 'Barang tidak ditemukan', error: true);
    }
    _searchFocus.requestFocus();
  }

  /// Kode dari scanner yang mengetik di luar kolom teks: aturan pencocokan sama dengan kolom cari.
  void _onScan(String code) {
    final m = matchScan(_allProducts, code, id: (p) => p.id, name: (p) => p.name);
    if (m.match != null) {
      _addToCart(m.match!, toastOnNarrow: true);
    } else if (m.candidates.length > 1) {
      _searchController.text = code;
      setState(() {
        _query = code;
        _resultIndex = 0;
        _resultsNavigated = false;
        _resultsHidden = false;
      });
      _notify('Ada beberapa barang yang cocok, pilih dari daftar', toastOnNarrow: true);
    } else {
      _notify('Barang tidak ditemukan: $code', error: true);
    }
    _refocusSearch();
  }

  Future<void> _clearCart() async {
    final lines = ref.read(checkoutControllerProvider).items.length;
    if (await confirmClearCart(context, lines)) ref.read(checkoutControllerProvider.notifier).clear();
    _refocusSearch();
  }

  void _openPay() {
    final checkout = ref.read(checkoutControllerProvider);
    if (checkout.items.isEmpty || checkout.isLocked) return;
    _scanner.clear();
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
      setState(() {
        _payOpen = false;
        _lastMethod = method;
        _scanStatus = null;
      });
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
    setState(() => _selectedId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refocusSearch());
  }

  // ---------------------------------------------------------------------------------------------
  // Keyboard & scanner

  static bool _isEnter(LogicalKeyboardKey k) => k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter;

  static bool _inTextField(FocusNode? node) => node?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  static bool _isPlus(KeyEvent e) => e.character == '+' || e.logicalKey == LogicalKeyboardKey.numpadAdd || e.logicalKey == LogicalKeyboardKey.add;

  static bool _isMinus(KeyEvent e) =>
      e.character == '-' || e.logicalKey == LogicalKeyboardKey.numpadSubtract || e.logicalKey == LogicalKeyboardKey.minus;

  /// Karakter cetak tunggal (bukan kontrol) yang dikirim tombol ini, atau null.
  static String? _printable(KeyEvent e) {
    final ch = e.character;
    if (ch == null || ch.length != 1) return null;
    final code = ch.codeUnitAt(0);
    return code < 0x20 || code == 0x7f ? null : ch;
  }

  bool _onDownloadButton(FocusNode? node) =>
      node?.context?.findAncestorWidgetOfExactType<StokasButton>()?.key == const Key('download-receipt');

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent || !(_route?.isCurrent ?? true)) return KeyEventResult.ignored;
    final down = event is KeyDownEvent;
    final key = event.logicalKey;
    final checkout = ref.read(checkoutControllerProvider);
    final primary = FocusManager.instance.primaryFocus;
    final inSearch = primary == _searchFocus;

    // Layar selesai: Enter = Transaksi baru (kecuali fokus di tombol Unduh struk).
    if (checkout.completed != null) {
      if (down && _isEnter(key) && !_onDownloadButton(primary)) {
        _startNew();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // Panel bayar menangani 1/2/3/Enter/Esc sendiri; kolom teks lain menerima ketikan apa adanya.
    if (_payOpen || (!inSearch && _inTextField(primary))) return KeyEventResult.ignored;

    final now = ref.read(scannerClockProvider)();
    final char = _printable(event);

    // Scanner: hanya saat tidak ada kolom teks yang fokus.
    if (!inSearch && down) {
      if (_isEnter(key)) {
        final code = _scanner.submit(now);
        if (code != null) {
          _onScan(code);
          return KeyEventResult.handled;
        }
      } else if (char != null) {
        final shortcut = char == '/' || _isPlus(event) || _isMinus(event);
        // Di tengah ketikan cepat, "/" "+" "-" adalah bagian kode, bukan pintasan.
        if (!shortcut || _scanner.isActive(now)) {
          _scanner.add(char, now);
          return KeyEventResult.handled;
        }
      }
    }

    if (inSearch) {
      if (_resultsVisible) {
        final results = _results;
        if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
          if (results.isNotEmpty) {
            final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
            setState(() {
              _resultIndex = _resultsNavigated ? (_resultIndex + step).clamp(0, results.length - 1) : (step > 0 ? 0 : results.length - 1);
              _resultsNavigated = true;
            });
          }
          return KeyEventResult.handled;
        }
        if (down && key == LogicalKeyboardKey.escape) {
          setState(() => _resultsHidden = true);
          return KeyEventResult.handled;
        }
      }
      if (down && _isEnter(key)) {
        _submitSearch(_searchController.text);
        return KeyEventResult.handled;
      }
    } else if (down && char == '/') {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    } else if (down && _isEnter(key) && primary == _keysFocus) {
      _submitSearch('');
      return KeyEventResult.handled;
    }

    // Pintasan keranjang (mode PC): hanya bila kolom cari kosong; selain itu tombol diketik biasa.
    if (!_pc || _searchController.text.isNotEmpty || checkout.isLocked || checkout.items.isEmpty) {
      return KeyEventResult.ignored;
    }
    final items = checkout.items;
    final selected = _selected(items);
    if (_isPlus(event)) {
      if (selected != null) _increment(selected);
      return KeyEventResult.handled;
    }
    if (_isMinus(event)) {
      if (selected != null) _decrement(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final i = items.indexWhere((x) => x.productId == selected);
      final next = (i + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, items.length - 1);
      setState(() => _selectedId = items[next].productId);
      return KeyEventResult.handled;
    }
    if (down && (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace)) {
      if (selected != null) _remove(selected);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------------------------
  // Tampilan

  Widget _payPanel(CheckoutState checkout, {Widget? header}) => PayPanel(
        total: checkout.total,
        busy: checkout.isPaying,
        error: _payError,
        header: header,
        initialMethod: _lastMethod,
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

  Widget _searchField({required bool wide}) => TextField(
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
                    _clearSearch();
                    _searchFocus.requestFocus();
                  },
                ),
        ),
        onChanged: (v) => setState(() {
          _query = v;
          _resultIndex = 0;
          _resultsNavigated = false;
          _resultsHidden = false;
        }),
        onSubmitted: _submitSearch,
      );

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
          child: _searchField(wide: wide),
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

  /// Mode PC kiri-tengah: kolom cari (+ daftar hasil), status scanner, tabel keranjang.
  Widget _buildPcCart(CheckoutState checkout) {
    final items = checkout.items;
    final table = _loadError != null
        ? ErrorView(error: _loadError!, onRetry: _loadProducts)
        : CartTable(
            items: items,
            selectedId: _selected(items),
            enabled: !checkout.isPaying,
            onSelect: (id) => setState(() => _selectedId = id),
            onIncrement: _increment,
            onDecrement: _decrement,
            onRemove: _remove,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s4, StokasSpace.s4, 0),
          child: _searchField(wide: true),
        ),
        ScannerStatus(paused: false, result: _scanStatus, resultIsError: _scanStatusError),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: table),
              if (_resultsVisible)
                Positioned(
                  left: StokasSpace.s4,
                  right: StokasSpace.s4,
                  top: 0,
                  child: SearchResultsList(
                    results: _results,
                    highlighted: _resultsNavigated ? _resultIndex : -1,
                    onPick: _pickResult,
                  ),
                ),
            ],
          ),
        ),
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

    if (_pc) {
      return Column(
        key: const Key('cashier-pc'),
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _payOpen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ScannerStatus(paused: true),
                            Expanded(child: OrderSummary(items: checkout.items, total: checkout.total, problemProductId: _problemProductId)),
                          ],
                        )
                      : _buildPcCart(checkout),
                ),
                VerticalDivider(width: 1, color: c.line),
                SizedBox(
                  key: Key(_payOpen ? 'cashier-pay-panel' : 'cashier-pc-checkout'),
                  width: _payOpen ? payPanelWidth : pcCheckoutWidth,
                  child: Material(
                    color: c.surface,
                    child: _payOpen
                        ? _payPanel(checkout)
                        : PcCheckoutColumn(checkout: checkout, method: _lastMethod, onPay: _openPay, onClear: _clearCart),
                  ),
                ),
              ],
            ),
          ),
          const ShortcutBar(),
        ],
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
    _route = ModalRoute.of(context);
    _tabVisible = Visibility.of(context);
    final checkout = ref.watch(checkoutControllerProvider);
    // Tombol kembali sistem menutup panel bayar, bukan layar Kasir.
    return PopScope(
      canPop: !_payOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _payOpen) _closePay();
      },
      child: Focus(
        focusNode: _keysFocus,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(title: const Text('Kasir'), actions: const [AccountMenuButton()]),
          body: _body(checkout),
        ),
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
