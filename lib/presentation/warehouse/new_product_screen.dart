import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/config.dart';
import '../../core/jakarta_time.dart';
import '../../data/providers.dart';
import '../../data/receive_lines.dart' show isPastDate, pastDateMessage;
import '../../data/repositories/product_repository.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import 'stock_inputs.dart';

/// Produk baru untuk gudang lewat RPC create_product_with_stock. Tidak ada kolom harga:
/// selalu mengirim p_price 0 (harga diatur owner). Pesan server tampil apa adanya; yang
/// menyangkut kode (mis. "Kode barang sudah dipakai") di bawah kolom kode.
/// Pop dengan `true` setelah tersimpan.
class NewProductScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const NewProductScreen({super.key, this.initialCode});

  @override
  ConsumerState<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends ConsumerState<NewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  final _name = TextEditingController();
  final _minStock = TextEditingController(text: '5');
  final _qty = TextEditingController();
  final _note = TextEditingController();
  final _nameFocus = FocusNode();

  String _unit = productUnits.first;
  int? _categoryId;
  String _floor = storeFloors.first;
  DateTime? _expiry;
  bool _saving = false;
  String? _codeError; // pesan server tentang kode
  String? _error; // pesan server lainnya

  @override
  void dispose() {
    for (final c in [_code, _name, _minStock, _qty, _note]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null;

  String? _number(String? v, {required bool optional}) {
    if (v == null || v.trim().isEmpty) return optional ? null : 'Wajib diisi';
    final n = parseQty(v);
    if (n == null) return 'Isi dengan angka';
    if (n < 0) return 'Tidak boleh negatif';
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _codeError = null;
      _error = null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || isPastDate(_expiry, ref.read(clockProvider)())) return;

    setState(() => _saving = true);
    final name = _name.text.trim();
    try {
      await ref.read(productRepositoryProvider).createProductWithStock(NewProduct(
            id: _code.text.trim(),
            name: name,
            unit: _unit,
            categoryId: _categoryId,
            minStock: parseQty(_minStock.text) ?? 5,
            price: 0, // gudang tidak menetapkan harga
            floor: _floor,
            qty: parseQty(_qty.text),
            expiry: _expiry,
            note: _note.text,
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produk $name tersimpan')));
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is! NetworkException && e.message.startsWith('Kode barang')) {
          _codeError = e.message;
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final now = ref.watch(clockProvider)();
    final categories = ref.watch(categoriesProvider);
    final expiryError = isPastDate(_expiry, now) ? pastDateMessage : null;
    const gap = SizedBox(height: StokasSpace.s4);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: StokasSpace.s2, bottom: StokasSpace.s3),
          child: Text(title, style: StokasType.title.copyWith(color: c.ink)),
        );

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Produk baru')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(StokasSpace.s4),
                      children: [
                        TextFormField(
                          key: const Key('np-code'),
                          controller: _code,
                          autofocus: (widget.initialCode ?? '').isEmpty,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Kode barang',
                            hintText: 'Scan atau ketik kode',
                            prefixIcon: const Icon(Icons.qr_code_scanner),
                            errorText: _codeError,
                            errorMaxLines: 2,
                          ),
                          inputFormatters: [LengthLimitingTextInputFormatter(64)],
                          validator: (v) => _required(v, 'Kode barang'),
                          onChanged: (_) {
                            if (_codeError != null) setState(() => _codeError = null);
                          },
                          onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                        ),
                        gap,
                        TextFormField(
                          key: const Key('np-name'),
                          controller: _name,
                          focusNode: _nameFocus,
                          autofocus: (widget.initialCode ?? '').isNotEmpty,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Nama barang'),
                          validator: (v) => _required(v, 'Nama barang'),
                        ),
                        gap,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: const Key('np-unit'),
                                initialValue: _unit,
                                decoration: const InputDecoration(labelText: 'Satuan'),
                                items: [for (final u in productUnits) DropdownMenuItem(value: u, child: Text(u))],
                                validator: (v) => _required(v, 'Satuan'),
                                onChanged: (v) => setState(() => _unit = v ?? _unit),
                              ),
                            ),
                            const SizedBox(width: StokasSpace.s3),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int?>(
                                key: const Key('np-category'),
                                initialValue: _categoryId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  helperText: categories.hasError ? 'Kategori gagal dimuat' : null,
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(value: null, child: Text('Tanpa kategori')),
                                  for (final cat in categories.value ?? const <Map<String, dynamic>>[])
                                    DropdownMenuItem<int?>(value: (cat['id'] as num).toInt(), child: Text('${cat['name']}')),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              ),
                            ),
                          ],
                        ),
                        gap,
                        TextFormField(
                          key: const Key('np-min'),
                          controller: _minStock,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Minimum stok', helperText: 'Di bawah ini barang ditandai Menipis'),
                          validator: (v) => _number(v, optional: false),
                        ),
                        section('Stok awal'),
                        FloorPicker(value: _floor, onChanged: (f) => setState(() => _floor = f)),
                        gap,
                        TextFormField(
                          key: const Key('np-qty'),
                          controller: _qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Jumlah awal (opsional)'),
                          validator: (v) => _number(v, optional: true),
                        ),
                        gap,
                        ExpiryField(
                          buttonKey: const Key('np-expiry'),
                          value: _expiry,
                          today: jakartaTodayLocal(now),
                          errorText: expiryError,
                          onChanged: (d) => setState(() => _expiry = d),
                        ),
                        gap,
                        TextFormField(
                          key: const Key('np-note'),
                          controller: _note,
                          decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'Stok awal'),
                        ),
                        gap,
                        Text('Harga jual diatur oleh owner.', style: StokasType.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(StokasSpace.s4),
                  decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        FieldError(_error!, key: const Key('np-error')),
                        const SizedBox(height: StokasSpace.s2),
                      ],
                      StokasButton(
                        key: const Key('np-save'),
                        label: _saving ? 'Menyimpan...' : 'Simpan produk',
                        icon: Icons.save_outlined,
                        expand: true,
                        onPressed: _saving || expiryError != null ? null : _save,
                      ),
                      if (expiryError != null) ...[
                        const SizedBox(height: StokasSpace.s2),
                        Text(
                          'Belum bisa disimpan: tanggal kedaluwarsa sudah lewat.',
                          textAlign: TextAlign.center,
                          style: StokasType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
