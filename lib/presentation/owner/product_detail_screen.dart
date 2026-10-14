import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/jakarta_time.dart';
import '../../core/permissions.dart';
import '../../core/validators.dart';
import '../../data/product_model.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../data/stock_availability.dart';
import '../add_product_screen.dart' show CurrencyInputFormatter;
import '../design/status_badge.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import '../warehouse/stock_inputs.dart' show FieldError;
import 'home_screen.dart' show ownerSidePadding;

const _units = ['pcs', 'gram', 'liter', 'ml'];

/// Detail barang (khusus owner): ubah nama, satuan, kategori, minimum stok, harga jual, dan
/// modal (product_costs). Stok per lantai/batch hanya dibaca. [product] = baris tabel products.
/// Kembali dengan `true` bila barang disimpan atau dihapus.
class ProductDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.product['brand_name'] ?? ''}');
  late final _minStock = TextEditingController(text: formatQty((widget.product['min_stock'] as num?) ?? 0));
  late final _price = TextEditingController(text: CurrencyInputFormatter.format((widget.product['price'] as num?)?.round() ?? 0));
  final _capital = TextEditingController();
  late String _unit = '${widget.product['unit_type'] ?? 'pcs'}';
  late int? _categoryId = widget.product['category_id'] as int?;

  int? _loadedCapital;
  bool _capitalLoaded = false;
  Object? _capitalError;
  bool _busy = false;
  String? _serverError;

  String get _id => widget.product['id'] as String;
  String get _originalName => '${widget.product['brand_name']}';
  bool get _isOwner => can(ref.read(currentRoleProvider), Permission.viewCapitalPrice);

  @override
  void initState() {
    super.initState();
    // Modal ada di product_costs dan hanya terbaca oleh owner.
    if (_isOwner) _loadCapital();
  }

  @override
  void dispose() {
    _name.dispose();
    _minStock.dispose();
    _price.dispose();
    _capital.dispose();
    super.dispose();
  }

  Future<void> _loadCapital() async {
    setState(() => _capitalError = null);
    try {
      final capital = await ref.read(productRepositoryProvider).getCapitalPrice(_id);
      if (!mounted) return;
      setState(() {
        _loadedCapital = capital;
        _capital.text = CurrencyInputFormatter.format(capital ?? 0);
        _capitalLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _capitalError = e);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    final repo = ref.read(productRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.updateProduct(ProductModel(
        id: _id,
        brandName: _name.text.trim(),
        categoryId: _categoryId,
        unitType: _unit,
        minStock: double.parse(_minStock.text.trim().replaceAll(',', '.')),
        price: parseRupiah(_price.text),
      ));
      // Modal hanya ditulis bila sudah termuat dan berubah (tidak menimpa dengan 0).
      final capital = parseRupiah(_capital.text);
      if (_capitalLoaded && capital != (_loadedCapital ?? 0)) await repo.saveCapitalPrice(_id, capital);
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(const SnackBar(content: Text('Barang disimpan')));
    } catch (e) {
      if (mounted) setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $_originalName?'),
        content: Text('$_originalName disembunyikan dari daftar dan Kasir. Riwayat transaksi tetap aman.'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          StokasButton.danger(
            key: const Key('confirm-delete'),
            label: 'Hapus barang',
            onPressed: () => Navigator.pop(ctx, true),
          ),
          StokasButton.secondary(label: 'Batal', onPressed: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(productRepositoryProvider).deleteProduct(_id);
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(content: Text('$_originalName dihapus')));
    } catch (e) {
      if (mounted) setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    if (!can(ref.watch(currentRoleProvider), Permission.editPrices)) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(title: const Text('Detail barang')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: StokasSpace.s8, color: c.inkMuted),
              const SizedBox(height: StokasSpace.s3),
              Text('Halaman ini khusus owner.', style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
      );
    }

    final price = parseRupiah(_price.text);
    final capital = parseRupiah(_capital.text);
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Detail barang')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = ownerSidePadding(context, constraints.maxWidth);
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, StokasSpace.s4, side, StokasSpace.s6),
              children: [
                TextFormField(
                  key: const Key('detail-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama barang'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: StokasSpace.s3),
                TextFormField(
                  key: const Key('detail-code'),
                  initialValue: _id,
                  readOnly: true,
                  enableInteractiveSelection: true,
                  decoration: const InputDecoration(labelText: 'Kode', helperText: 'Kode tidak bisa diubah'),
                ),
                const SizedBox(height: StokasSpace.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        initialValue: _unit,
                        items: [
                          for (final u in {..._units, _unit}) DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? _unit),
                      ),
                    ),
                    const SizedBox(width: StokasSpace.s3),
                    Expanded(flex: 2, child: _categoryField(c)),
                  ],
                ),
                const SizedBox(height: StokasSpace.s3),
                TextFormField(
                  key: const Key('detail-min-stock'),
                  controller: _minStock,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Minimum stok'),
                  validator: validateMinStock,
                ),
                const SizedBox(height: StokasSpace.s5),
                Text('Harga', style: StokasType.titleLg.copyWith(color: c.ink)),
                const SizedBox(height: StokasSpace.s3),
                _moneyField(const Key('detail-price'), _price, 'Harga jual'),
                if (price == 0) ...[
                  const SizedBox(height: StokasSpace.s1),
                  const _Warning('Harga belum diatur'),
                ],
                const SizedBox(height: StokasSpace.s3),
                _moneyField(const Key('detail-capital'), _capital, 'Modal', enabled: _capitalLoaded),
                if (_capitalError != null) ...[
                  const SizedBox(height: StokasSpace.s1),
                  FieldError('$_capitalError'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(onPressed: _loadCapital, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
                  ),
                ] else if (_capitalLoaded && capital > price) ...[
                  const SizedBox(height: StokasSpace.s1),
                  const _Warning('Modal lebih besar dari harga jual'),
                ],
                const SizedBox(height: StokasSpace.s5),
                Text('Stok', style: StokasType.titleLg.copyWith(color: c.ink)),
                const SizedBox(height: StokasSpace.s2),
                _StockSummary(productId: _id, unit: '${widget.product['unit_type'] ?? ''}'),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = ownerSidePadding(context, constraints.maxWidth);
              return Padding(
                padding: EdgeInsets.fromLTRB(side, StokasSpace.s3, side, StokasSpace.s3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_serverError != null) ...[
                      FieldError(_serverError!, key: const Key('detail-error')),
                      const SizedBox(height: StokasSpace.s2),
                    ],
                    Row(
                      children: [
                        StokasButton.danger(
                          key: const Key('detail-delete'),
                          label: 'Hapus barang',
                          onPressed: _busy ? null : _delete,
                        ),
                        const SizedBox(width: StokasSpace.s3),
                        Expanded(
                          child: StokasButton(
                            key: const Key('detail-save'),
                            label: 'Simpan',
                            expand: true,
                            onPressed: _busy ? null : _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _moneyField(Key key, TextEditingController controller, String label, {bool enabled = true}) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
      decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
      validator: enabled ? validateRupiahInput : null,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _categoryField(StokasColors c) {
    final categories = ref.watch(categoriesProvider);
    if (categories.hasError) {
      return InputDecorator(
        decoration: InputDecoration(labelText: 'Kategori', errorText: '${categories.error}'),
        child: TextButton.icon(
          onPressed: () => ref.invalidate(categoriesProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      );
    }
    final items = categories.value ?? const <Map<String, dynamic>>[];
    final known = items.any((cat) => cat['id'] == _categoryId);
    return DropdownButtonFormField<int?>(
      key: ValueKey('detail-category-${items.length}'),
      decoration: const InputDecoration(labelText: 'Kategori'),
      initialValue: known ? _categoryId : null,
      isExpanded: true,
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Tanpa kategori')),
        for (final cat in items) DropdownMenuItem<int?>(value: cat['id'] as int, child: Text('${cat['name']}')),
      ],
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }
}

/// Peringatan (bukan blokir): ikon + kata, warna warning.
class _Warning extends StatelessWidget {
  final String text;

  const _Warning(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
        const SizedBox(width: StokasSpace.s1),
        Expanded(child: Text(text, style: StokasType.caption.copyWith(color: c.warning))),
      ],
    );
  }
}

/// Ringkasan stok per lantai/batch (baca saja); batch kedaluwarsa berlabel.
class _StockSummary extends ConsumerWidget {
  final String productId;
  final String unit;

  const _StockSummary({required this.productId, required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.stokas;
    final now = ref.watch(clockProvider)();
    return ref.watch(stockListProvider).when(
          skipLoadingOnRefresh: false,
          loading: () => Container(
            height: StokasSpace.s8 + StokasSpace.s3,
            decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.lg)),
          ),
          error: (error, _) => Row(
            children: [
              Expanded(child: FieldError('$error')),
              TextButton(onPressed: () => ref.invalidate(stockListProvider), child: const Text('Coba lagi')),
            ],
          ),
          data: (rows) {
            final batches = [
              for (final r in rows)
                if (r['product_id'] == productId && (r['quantity'] as num? ?? 0) != 0) r,
            ]..sort((a, b) => '${a['floor_name']}${a['expiry_date'] ?? ''}'.compareTo('${b['floor_name']}${b['expiry_date'] ?? ''}'));
            if (batches.isEmpty) {
              return Text('Belum ada stok. Terima barang dulu.', style: StokasType.body.copyWith(color: c.inkMuted));
            }
            return Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(StokasRadius.lg),
                border: Border.all(color: c.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < batches.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: c.line),
                    _BatchRow(batch: batches[i], unit: unit, expired: isBatchExpired(batches[i], now)),
                  ],
                ],
              ),
            );
          },
        );
  }
}

class _BatchRow extends StatelessWidget {
  final Map<String, dynamic> batch;
  final String unit;
  final bool expired;

  const _BatchRow({required this.batch, required this.unit, required this.expired});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final expiry = batch['expiry_date'] as String?;
    final label = [
      '${batch['floor_name']}',
      if (expiry != null && expiry.isNotEmpty) 'Exp ${formatDayId(DateTime.parse(expiry.substring(0, 10)))}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: StokasType.body.copyWith(color: c.ink)),
                if (expired)
                  const Padding(
                    padding: EdgeInsets.only(top: StokasSpace.s1),
                    child: StatusBadge(StockStatus.bahaya),
                  ),
              ],
            ),
          ),
          Text('${formatQty(batch['quantity'] as num)} $unit', style: StokasType.title.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
