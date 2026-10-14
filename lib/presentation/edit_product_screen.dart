import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/validators.dart';
import '../data/product_model.dart';
import '../data/providers.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'warehouse/stock_inputs.dart' show FieldError;

const _units = ['pcs', 'gram', 'liter', 'ml'];

/// Edit barang untuk gudang: nama, kategori, satuan, minimum stok. Tanpa harga jual dan modal
/// (harga tidak dikirim sama sekali; owner memakai Detail barang).
class EditProductScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> productData;

  const EditProductScreen({super.key, required this.productData});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.productData['brand_name'] ?? ''}');
  late final _minStock = TextEditingController(text: formatQty((widget.productData['min_stock'] as num?) ?? 0));
  late int? _categoryId = widget.productData['category_id'] as int?;
  late String _unit = '${widget.productData['unit_type'] ?? 'pcs'}';
  bool _busy = false;
  String? _error;

  String get _id => widget.productData['id'] as String;

  @override
  void dispose() {
    _name.dispose();
    _minStock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(productRepositoryProvider).updateProduct(
            ProductModel(
              id: _id,
              brandName: _name.text.trim(),
              categoryId: _categoryId,
              unitType: _unit,
              minStock: double.parse(_minStock.text.trim().replaceAll(',', '.')),
              price: 0, // tidak dikirim (includePrices: false)
            ),
            includePrices: false,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(const SnackBar(content: Text('Barang disimpan')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final categories = ref.watch(categoriesProvider).value ?? const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Edit barang')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(StokasSpace.s4),
          children: [
            TextFormField(
              initialValue: _id,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Kode', helperText: 'Kode tidak bisa diubah'),
            ),
            const SizedBox(height: StokasSpace.s3),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama barang'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: StokasSpace.s3),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Satuan'),
                    initialValue: _unit,
                    items: [for (final u in {..._units, _unit}) DropdownMenuItem(value: u, child: Text(u))],
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
                const SizedBox(width: StokasSpace.s3),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('edit-category-${categories.length}'),
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    initialValue: categories.any((cat) => cat['id'] == _categoryId) ? _categoryId : null,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Tanpa kategori')),
                      for (final cat in categories) DropdownMenuItem<int?>(value: cat['id'] as int, child: Text('${cat['name']}')),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: StokasSpace.s3),
            TextFormField(
              controller: _minStock,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Minimum stok'),
              validator: validateMinStock,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
        padding: const EdgeInsets.all(StokasSpace.s4),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[FieldError(_error!), const SizedBox(height: StokasSpace.s2)],
              StokasButton(label: 'Simpan', expand: true, onPressed: _busy ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}
