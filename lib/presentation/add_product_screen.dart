import 'dart:io'; // Untuk File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Plugin Foto
import '../data/product_model.dart';
import '../data/product_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();
  final _picker = ImagePicker(); // Inisialisasi Picker

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');
  final _priceController = TextEditingController();
  final _capitalPriceController = TextEditingController();
  
  String? _selectedCategory;
  String _selectedUnit = 'pcs';
  String _selectedFloor = 'Lantai 1';
  DateTime? _selectedExpiry;
  File? _imageFile; // Variabel penampung foto sementara

  List<Map<String, dynamic>> _categories = [];
  bool _isUploading = false; // Loading indicator saat upload

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    final data = await _service.getCategories();
    if (mounted) setState(() => _categories = data);
  }

  // --- FUNGSI PILIH FOTO ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 70); // Kompres dikit biar ringan
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      print("Error Foto: $e");
    }
  }

  // --- POPUP PILIH SUMBER ---
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto (Kamera)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      setState(() => _isUploading = true); // Mulai Loading

      try {
        String? imageUrl;
        
        // 1. Jika ada foto, upload dulu
        if (_imageFile != null) {
          imageUrl = await _service.uploadImage(_imageFile!);
        }

        final cleanPrice = _priceController.text.replaceAll('.', '');
        final cleanCapital = _capitalPriceController.text.replaceAll('.', '');

        final product = ProductModel(
          id: _idController.text,
          brandName: _nameController.text,
          categoryId: int.parse(_selectedCategory!),
          unitType: _selectedUnit,
          minStock: double.parse(_minStockController.text),
          price: double.parse(cleanPrice),
          capitalPrice: double.parse(cleanCapital),
        );

        // 2. Simpan Data Produk (termasuk URL foto)
        await _service.addProduct(
          product, 
          _selectedFloor, 
          double.parse(_qtyController.text), 
          _selectedExpiry,
          imageUrl // Kirim URL
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Barang & Foto Berhasil Disimpan!")),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false); // Stop Loading
      }
    } else if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Pilih Kategori dulu!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Input Barang Baru")),
      body: _isUploading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- AREA FOTO ---
                  Center(
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade400),
                          image: _imageFile != null 
                            ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                            : null
                        ),
                        child: _imageFile == null 
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                SizedBox(height: 5),
                                Text("Tambah Foto", style: TextStyle(color: Colors.grey, fontSize: 12))
                              ],
                            ) 
                          : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(_idController, "Barcode / Kode", Icons.qr_code),
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
                  const Divider(height: 40, thickness: 1),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_capitalPriceController, "Harga Modal", Icons.monetization_on_outlined, isCurrency: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_priceController, "Harga Jual", Icons.sell, isCurrency: true)),
                    ],
                  ),
                  const Divider(height: 40, thickness: 1),

                  Row(
                    children: [
                      Expanded(child: _buildTextField(_qtyController, "Jumlah", Icons.inventory, isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildFloorDropdown()),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(_minStockController, "Minimal Stok (Alert)", Icons.warning_amber, isNumber: true),
                  
                  const SizedBox(height: 15),
                  _buildDatePicker(),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                      onPressed: _saveProduct,
                      child: const Text("SIMPAN DATA", style: TextStyle(fontSize: 16, color: Colors.white)),
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

  // --- Widget Helper Tetap Sama ---
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, bool isCurrency = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isCurrency 
          ? TextInputType.number 
          : (isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      inputFormatters: isCurrency 
          ? [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()] 
          : (isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue[700]),
        suffixText: isCurrency ? "IDR" : null,
      ),
      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Kategori"),
      value: _selectedCategory,
      items: _categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v),
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Satuan"),
      value: _selectedUnit,
      items: ['pcs', 'gram', 'liter', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) => setState(() => _selectedUnit = v!),
    );
  }

  Widget _buildFloorDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Lokasi"),
      value: _selectedFloor,
      items: ['Lantai 1', 'Lantai 2'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
      onChanged: (v) => setState(() => _selectedFloor = v!),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _selectedExpiry = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Tanggal Kadaluarsa (Opsional)",
          prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          _selectedExpiry == null ? "-" : DateFormat('dd MMM yyyy').format(_selectedExpiry!),
          style: TextStyle(color: _selectedExpiry == null ? Colors.grey : Colors.black87),
        ),
      ),
    );
  }
}

// Formatter Rupiah
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int value = int.parse(newText);
    final formatter = NumberFormat('#,###', 'id_ID');
    newText = formatter.format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}