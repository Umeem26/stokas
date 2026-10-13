import 'package:flutter/material.dart';
import '../data/product_service.dart';

class MutationScreen extends StatefulWidget {
  // Data yang dikirim dari halaman depan
  final Map<String, dynamic> sourceStock; 

  const MutationScreen({super.key, required this.sourceStock});

  @override
  State<MutationScreen> createState() => _MutationScreenState();
}

class _MutationScreenState extends State<MutationScreen> {
  final _service = ProductService();
  final _qtyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String _currentFloor;
  late String _targetFloor;
  late double _maxQty;
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
    _maxQty = (stock['quantity'] as num).toDouble();

    // Logika otomatis: Kalau asal Lt 1, tujuan pasti Lt 2 (dan sebaliknya)
    _targetFloor = _currentFloor == 'Lantai 1' ? 'Lantai 2' : 'Lantai 1';
  }

  void _submitMutation() async {
    if (_formKey.currentState!.validate()) {
      try {
        final qty = double.parse(_qtyController.text);
        
        await _service.moveStock(
          sourceStockId: widget.sourceStock['id'],
          productId: widget.sourceStock['product_id'],
          targetFloor: _targetFloor,
          qtyToMove: qty,
          currentSourceQty: _maxQty,
          expiryDate: widget.sourceStock['expiry_date'] != null 
              ? DateTime.parse(widget.sourceStock['expiry_date']) 
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Berhasil Pindah Stok!")),
          );
          Navigator.pop(context, true); // Kembali & Refresh
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception:", "")), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pindah Lokasi Stok")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12)
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Barang
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.swap_horiz, color: Colors.blue, size: 30),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Stok Tersedia: $_maxQty $_unit", style: const TextStyle(color: Colors.grey)),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 30),

                  // Info Pindah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFloorBadge(_currentFloor, false),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      _buildFloorBadge(_targetFloor, true),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Input Jumlah
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Jumlah yang dipindah",
                      suffixText: _unit,
                      helperText: "Maksimal $_maxQty $_unit",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Isi jumlah dulu";
                      final n = double.tryParse(value);
                      if (n == null) return "Harus angka";
                      if (n <= 0) return "Minimal 1";
                      if (n > _maxQty) return "Stok tidak cukup!";
                      return null;
                    },
                  ),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF6C00), // Oranye
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitMutation,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("PROSES PINDAH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloorBadge(String text, bool isDest) {
    return Column(
      children: [
        Text(isDest ? "KE LOKASI" : "DARI LOKASI", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: isDest ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDest ? Colors.green : Colors.red),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDest ? Colors.green.shade700 : Colors.red.shade700
            ),
          ),
        ),
      ],
    );
  }
}