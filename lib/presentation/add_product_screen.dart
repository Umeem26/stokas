import 'dart:io'; // Untuk File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Plugin Foto
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../data/repositories/product_repository.dart';
import '../core/permissions.dart';
import '../data/providers.dart';
import '../data/session.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker(); // Inisialisasi Picker

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');
  final _priceController = TextEditingController();
  final _capitalPriceController = TextEditingController();
  
  String? _selectedCategory;
  String _selectedUnit = 'pcs';
  String _selectedFloor = storeFloors.first;
  DateTime? _selectedExpiry;
  File? _imageFile; // Variabel penampung foto sementara

  bool _isUploading = false; // Loading indicator saat upload

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
      debugPrint("Error Foto: $e");
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

      final service = ref.read(productRepositoryProvider);
      final role = ref.read(currentRoleProvider);
      try {
        String? imageUrl;
        
        // 1. Jika ada foto, upload dulu
        if (_imageFile != null) {
          imageUrl = await service.uploadImage(_imageFile!);
        }

        // 2. Produk + stok awal dalam satu RPC (create_product_with_stock).
        //    Non-owner tidak mengisi harga; harga jual 0 sampai diisi owner.
        final id = _idController.text.trim();
        await service.createProductWithStock(NewProduct(
          id: id,
          name: _nameController.text,
          unit: _selectedUnit,
          categoryId: int.parse(_selectedCategory!),
          minStock: num.parse(_minStockController.text),
          price: can(role, Permission.editPrices) ? parseRupiah(_priceController.text) : 0,
          imageUrl: imageUrl,
          floor: _selectedFloor,
          qty: num.parse(_qtyController.text),
          expiry: _selectedExpiry,
        ));

        // 3. Harga modal ke product_costs (khusus owner)
        if (can(role, Permission.viewCapitalPrice)) {
          await service.saveCapitalPrice(id, parseRupiah(_capitalPriceController.text));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Barang tersimpan")),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: context.stokas.negative));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false); // Stop Loading
      }
    } else if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih kategori dulu.")));
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
                          color: context.stokas.surfaceSunken,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: context.stokas.lineStrong),
                          image: _imageFile != null 
                            ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                            : null
                        ),
                        child: _imageFile == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: context.stokas.inkMuted),
                                const SizedBox(height: 5),
                                Text("Tambah Foto", style: StokasType.caption.copyWith(color: context.stokas.inkMuted))
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
                  
                  if (can(ref.watch(currentRoleProvider), Permission.editPrices))
                    Row(
                      children: [
                        if (can(ref.watch(currentRoleProvider), Permission.viewCapitalPrice)) ...[
                          Expanded(child: _buildTextField(_capitalPriceController, "Harga Modal", Icons.monetization_on_outlined, isCurrency: true)),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: _buildTextField(_priceController, "Harga Jual", Icons.sell, isCurrency: true)),
                      ],
                    )
                  else
                    Text("Harga jual & harga modal diisi oleh owner.", style: StokasType.body.copyWith(color: context.stokas.inkMuted)),
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
                  StokasButton(label: "Simpan", icon: Icons.save_outlined, expand: true, onPressed: _saveProduct),
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
        prefixIcon: Icon(icon, color: context.stokas.primary),
        suffixText: isCurrency ? "IDR" : null,
      ),
      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
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
      items: productUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) => setState(() => _selectedUnit = v!),
    );
  }

  Widget _buildFloorDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Lokasi"),
      initialValue: _selectedFloor,
      items: storeFloors.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
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
          prefixIcon: Icon(Icons.calendar_today, color: context.stokas.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          _selectedExpiry == null ? "-" : DateFormat('dd MMM yyyy').format(_selectedExpiry!),
          style: TextStyle(color: _selectedExpiry == null ? context.stokas.inkMuted : context.stokas.ink),
        ),
      ),
    );
  }
}

// Formatter input uang: angka saja, dengan titik ribuan (1.250.000)
class CurrencyInputFormatter extends TextInputFormatter {
  static String format(int value) => formatThousands(value);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    final newText = format(parseRupiah(digits));
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}