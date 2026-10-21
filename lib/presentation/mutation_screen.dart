import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../data/providers.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';

class MutationScreen extends ConsumerStatefulWidget {
  // Data yang dikirim dari halaman depan
  final Map<String, dynamic> sourceStock;

  const MutationScreen({super.key, required this.sourceStock});

  @override
  ConsumerState<MutationScreen> createState() => _MutationScreenState();
}

class _MutationScreenState extends ConsumerState<MutationScreen> {
  final _qtyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String _currentFloor;
  late String _targetFloor;
  late num _maxQty;
  late String _productName;
  late String _unit;

  @override
  void initState() {
    super.initState();
    // Ambil data dari parameter yang dikirim
    final stock = widget.sourceStock;
    final product = stock['products'];

    _productName = product['brand_name'];
    _unit = product['unit_type'];
    _currentFloor = stock['floor_name'];
    _maxQty = stock['quantity'] as num;

    // Logika otomatis: Kalau asal Lt 1, tujuan pasti Lt 2 (dan sebaliknya)
    _targetFloor = storeFloors.firstWhere((f) => f != _currentFloor, orElse: () => storeFloors.first);
  }

  bool _saving = false;

  void _submitMutation() async {
    if (_saving) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _saving = true);
      try {
        final qty = num.parse(_qtyController.text);
        final expiry = widget.sourceStock['expiry_date'] as String?;

        // Atomik di server (RPC transfer_stock): batch asal & tujuan memakai kedaluwarsa yang sama.
        await ref.read(stockRepositoryProvider).transferStock(
          productId: widget.sourceStock['product_id'],
          from: _currentFloor,
          to: _targetFloor,
          expiry: expiry == null ? null : DateTime.parse(expiry.substring(0, 10)),
          qty: qty,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Stok dipindahkan")),
          );
          Navigator.pop(context, true); // Kembali & Refresh
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(Icons.error_outline, color: context.stokas.canvas),
              const SizedBox(width: StokasSpace.s2),
              Expanded(child: Text(e.toString().replaceAll("Exception:", ""))),
            ]),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Scaffold(
      appBar: AppBar(title: const Text("Pindah Lokasi Stok")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(StokasSpace.s4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s5),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Barang
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(StokasSpace.s3),
                        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.md)),
                        child: Icon(Icons.swap_horiz, color: c.stock, size: StokasSpace.s6),
                      ),
                      const SizedBox(width: StokasSpace.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: StokasType.titleLg.copyWith(color: c.ink),
                            ),
                            Text("Stok Tersedia: ${formatQty(_maxQty)} $_unit", style: StokasType.body.copyWith(color: c.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StokasSpace.s4),
                  const Divider(),
                  const SizedBox(height: StokasSpace.s4),

                  // Info Pindah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: _buildFloorBadge(c, _currentFloor, false)),
                      Icon(Icons.arrow_forward, color: c.inkMuted),
                      Flexible(child: _buildFloorBadge(c, _targetFloor, true)),
                    ],
                  ),
                  const SizedBox(height: StokasSpace.s5),

                  // Input Jumlah
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Jumlah yang dipindah",
                      suffixText: _unit,
                      helperText: "Maksimal ${formatQty(_maxQty)} $_unit",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Isi jumlah dulu";
                      final n = num.tryParse(value);
                      if (n == null) return "Harus angka";
                      if (n <= 0) return "Minimal 1";
                      if (n > _maxQty) return "Stok tidak cukup!";
                      return null;
                    },
                  ),

                  const SizedBox(height: StokasSpace.s5),
                  StokasButton(
                    label: "Pindahkan",
                    icon: Icons.check_circle_outline,
                    expand: true,
                    loading: _saving,
                    onPressed: _submitMutation,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Asal dan tujuan dibedakan dengan label + ikon, bukan warna.
  // Layar sempit / font besar: diperkecil agar nama lantai tetap utuh, tidak meluap.
  Widget _buildFloorBadge(StokasColors c, String text, bool isDest) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(isDest ? "Ke lokasi" : "Dari lokasi", style: StokasType.label.copyWith(color: c.inkMuted)),
          const SizedBox(height: StokasSpace.s1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
            decoration: BoxDecoration(
              color: isDest ? c.surfaceSunken : c.surface,
              borderRadius: BorderRadius.circular(StokasRadius.pill),
              border: Border.all(color: isDest ? c.stock : c.lineStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isDest ? Icons.login : Icons.logout, size: 16, color: c.ink),
                const SizedBox(width: StokasSpace.s1),
                Text(text, style: StokasType.title.copyWith(color: c.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
