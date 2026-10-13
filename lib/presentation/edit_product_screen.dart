import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/product_model.dart';
import '../core/permissions.dart';
import '../data/providers.dart';
import '../data/session.dart';
import 'add_product_screen.dart'; // Pinjam Formatter Rupiah

class EditProductScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> productData; // Data barang yang mau diedit

  const EditProductScreen({super.key, required this.productData});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _minStockController;
  late TextEditingController _priceController;
  late TextEditingController _capitalPriceController;
  
  String? _selectedCategory;
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    final p = widget.productData;
    
    // 1. Isi Formulir dengan Data Lama
    _idController = TextEditingController(text: p['id']);
    _nameController = TextEditingController(text: p['brand_name']);
    _minStockController = TextEditingController(text: p['min_stock'].toString());
    
    // Format Harga biar ga error (Hilangkan .0 jika ada)
    double price = (p['price'] as num).toDouble();
    double capital = (p['capital_price'] as num).toDouble();
    _priceController = TextEditingController(text: price.toInt().toString());
    _capitalPriceController = TextEditingController(text: capital.toInt().toString());

    _selectedCategory = p['category_id'].toString();
    _selectedUnit = p['unit_type'];
  }

  // Fungsi Update
  void _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Bersihkan titik rupiah
        final cleanPrice = _priceController.text.replaceAll('.', '');
        final cleanCapital = _capitalPriceController.text.replaceAll('.', '');

        final product = ProductModel(
          id: _idController.text, // ID Tetap
          brandName: _nameController.text,
          categoryId: int.parse(_selectedCategory!),
          unitType: _selectedUnit!,
          minStock: double.parse(_minStockController.text),
          price: double.parse(cleanPrice),
          capitalPrice: double.parse(cleanCapital),
        );

        // Non-owner tidak mengirim harga sama sekali (penjagaan DB: trigger + Fase 2).
        await ref.read(productRepositoryProvider).updateProduct(
              product,
              includePrices: can(ref.read(currentRoleProvider), Permission.editPrices),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Data Berhasil Diperbarui!")));
          Navigator.pop(context, true); // Kembali & Refresh
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Fungsi Hapus
  void _deleteProduct() async {
    // Tampilkan Dialog Konfirmasi Dulu
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: const Text("Barang ini akan hilang permanen dari database. Yakin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Tutup dialog
              try {
                await ref.read(productRepositoryProvider).deleteProduct(_idController.text);
                if (mounted) {
                  Navigator.pop(context, true); // Kembali ke Home & Refresh
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🗑️ Barang Dihapus")));
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal Hapus: $e")));
              }
            }, 
            child: const Text("HAPUS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Produk"),
        actions: [
          if (can(role, Permission.deleteProduct))
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            tooltip: "Hapus Barang",
            onPressed: _deleteProduct,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ID Read Only (TIdak boleh diedit)
                  TextFormField(
                    controller: _idController,
                    readOnly: true, 
                    decoration: const InputDecoration(
                      labelText: "Barcode / ID (Tidak bisa diubah)",
                      filled: true, fillColor: Colors.black12
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(_nameController, "Nama Produk", Icons.label),
                  const SizedBox(height: 15),
                   Row(
                    children: [
                      Expanded(flex: 2, child: _buildCategoryDropdown()),
                      const SizedBox(width: 10),
                      Expanded(flex: 1, child: _buildUnitDropdown()),
                    ],
                  ),
                  const Divider(height: 30),
                  if (can(role, Permission.editPrices))
                    Row(
                      children: [
                        if (can(role, Permission.viewCapitalPrice)) ...[
                          Expanded(child: _buildTextField(_capitalPriceController, "Modal", Icons.monetization_on, isCurrency: true)),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: _buildTextField(_priceController, "Jual", Icons.sell, isCurrency: true)),
                      ],
                    )
                  else
                    // Harga jual hanya bisa dilihat; harga modal disembunyikan.
                    _buildTextField(_priceController, "Jual (hanya owner yang bisa mengubah)", Icons.sell, isCurrency: true, readOnly: true),
                  const SizedBox(height: 15),
                  _buildTextField(_minStockController, "Min. Stok Alert", Icons.warning_amber, isNumber: true),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                      onPressed: _updateProduct,
                      child: const Text("UPDATE DATA", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget Helper (Sama seperti AddProduct) ---
  Widget _buildTextField(TextEditingController c, String l, IconData i, {bool isNumber = false, bool isCurrency = false, bool readOnly = false}) {
    return TextFormField(
      controller: c,
      readOnly: readOnly,
      keyboardType: isCurrency ? TextInputType.number : (isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      inputFormatters: isCurrency ? [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()] : null,
      decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: Colors.blue), suffixText: isCurrency ? "IDR" : null),
      validator: (v) => v!.isEmpty ? "Wajib" : null,
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = ref.watch(categoriesProvider);
    if (categories.hasError) {
      return InputDecorator(
        decoration: InputDecoration(labelText: "Kategori", errorText: categories.error.toString()),
        child: TextButton.icon(
          onPressed: () => ref.invalidate(categoriesProvider),
          icon: const Icon(Icons.refresh),
          label: const Text("Coba lagi"),
        ),
      );
    }
    final items = categories.value ?? const <Map<String, dynamic>>[];
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Kategori"),
      initialValue: _selectedCategory,
      items: items.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v),
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Satuan"),
      initialValue: _selectedUnit,
      items: ['pcs', 'gram', 'liter', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) => setState(() => _selectedUnit = v!),
    );
  }
}