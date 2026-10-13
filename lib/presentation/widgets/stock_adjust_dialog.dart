import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../design/stokas_tokens.dart';

enum StockAdjustMode { restock, opname }

/// Dialog Stok masuk (RPC restock) / Opname (RPC stock_count) untuk satu batch stok.
/// Mengembalikan true jika tersimpan.
Future<bool?> showStockAdjustDialog(BuildContext context, {required StockAdjustMode mode, required Map<String, dynamic> stock}) {
  return showDialog<bool>(context: context, builder: (_) => StockAdjustDialog(mode: mode, stock: stock));
}

class StockAdjustDialog extends ConsumerStatefulWidget {
  final StockAdjustMode mode;
  final Map<String, dynamic> stock; // Baris stok beserta `products`

  const StockAdjustDialog({super.key, required this.mode, required this.stock});

  @override
  ConsumerState<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends ConsumerState<StockAdjustDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  late String _floor;
  DateTime? _expiry;
  bool _saving = false;

  bool get _isOpname => widget.mode == StockAdjustMode.opname;

  @override
  void initState() {
    super.initState();
    _floor = widget.stock['floor_name'] ?? storeFloors.first;
    final expiry = widget.stock['expiry_date'] as String?;
    _expiry = expiry == null ? null : DateTime.parse(expiry.substring(0, 10));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateQty(String? value) {
    final n = num.tryParse((value ?? '').trim());
    if (n == null) return "Isi jumlah (angka)";
    if (_isOpname ? n < 0 : n <= 0) return _isOpname ? "Tidak boleh minus" : "Harus lebih dari 0";
    return null;
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(stockRepositoryProvider);
    final productId = widget.stock['product_id'] as String;
    final qty = num.parse(_qtyController.text.trim());
    try {
      if (_isOpname) {
        await repo.stockCount(productId: productId, floor: _floor, expiry: _expiry, counted: qty, note: _noteController.text);
      } else {
        await repo.restock(productId: productId, floor: _floor, expiry: _expiry, qty: qty, note: _noteController.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isOpname ? "✅ Opname tersimpan" : "✅ Stok masuk tersimpan")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.stock['products'] as Map;
    final unit = product['unit_type'] ?? '';
    final floors = {...storeFloors, _floor}.toList();
    return AlertDialog(
      title: Text(_isOpname ? "Opname Stok" : "Stok Masuk"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product['brand_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Lokasi"),
                initialValue: _floor,
                items: floors.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: _saving ? null : (v) => setState(() => _floor = v!),
              ),
              const SizedBox(height: 15),
              InkWell(
                onTap: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expiry ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _expiry = picked);
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Tanggal Kadaluarsa (Opsional)",
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[700]),
                    suffixIcon: _expiry == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: "Tanpa tanggal",
                            onPressed: _saving ? null : () => setState(() => _expiry = null),
                          ),
                  ),
                  child: Text(
                    _expiry == null ? "-" : DateFormat('dd MMM yyyy').format(_expiry!),
                    style: TextStyle(color: _expiry == null ? context.stokas.inkMuted : context.stokas.ink),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                key: const Key('stockAdjustQty'),
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  labelText: _isOpname ? "Jumlah hasil hitung" : "Jumlah masuk",
                  suffixText: unit,
                  helperText: _isOpname ? "Stok tercatat: ${formatQty(widget.stock['quantity'] as num? ?? 0)} $unit" : null,
                ),
                validator: _validateQty,
              ),
              const SizedBox(height: 15),
              TextFormField(
                key: const Key('stockAdjustNote'),
                controller: _noteController,
                decoration: const InputDecoration(labelText: "Catatan (Opsional)"),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("SIMPAN"),
        ),
      ],
    );
  }
}
