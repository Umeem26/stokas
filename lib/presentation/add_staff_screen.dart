import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import '../core/validators.dart';
import '../data/providers.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  AppRole _selectedRole = AppRole.cashier;
  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(staffRepositoryProvider).createStaff(
            username: _usernameController.text,
            fullName: _nameController.text,
            role: _selectedRole,
            password: _passwordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Staf berhasil ditambahkan")));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Pesan dari server, mis. "Username sudah dipakai" (409).
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Staf")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isSaving,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.badge, color: Colors.blue),
                      helperText: "Dipakai untuk login, mis. budi.kasir",
                    ),
                    validator: validateStaffUsername,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: "Nama Lengkap", prefixIcon: Icon(Icons.label, color: Colors.blue)),
                    validator: validateStaffFullName,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<AppRole>(
                    decoration: const InputDecoration(labelText: "Peran"),
                    initialValue: _selectedRole,
                    items: AppRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                    onChanged: _isSaving ? null : (v) => setState(() => _selectedRole = v!),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isSaving,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password Awal",
                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                      helperText: "Minimal 8 karakter",
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: validateStaffPassword,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text("SIMPAN STAF", style: TextStyle(fontSize: 16, color: Colors.white)),
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
}
