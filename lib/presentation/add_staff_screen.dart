import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import '../core/validators.dart';
import '../data/providers.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'staff_screen.dart';

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
      showStaffMessage(context, "Staf berhasil ditambahkan");
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Pesan dari server, mis. "Username sudah dipakai" (409).
      showStaffMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Staf")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(StokasSpace.s4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s5),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isSaving,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.newUsername],
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.badge_outlined),
                      helperText: "Dipakai untuk login, mis. budi.kasir",
                    ),
                    validator: validateStaffUsername,
                  ),
                  const SizedBox(height: StokasSpace.s4),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: "Nama Lengkap", prefixIcon: Icon(Icons.person_outline)),
                    validator: validateStaffFullName,
                  ),
                  const SizedBox(height: StokasSpace.s4),
                  DropdownButtonFormField<AppRole>(
                    decoration: const InputDecoration(labelText: "Peran"),
                    initialValue: _selectedRole,
                    items: AppRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                    onChanged: _isSaving ? null : (v) => setState(() => _selectedRole = v!),
                  ),
                  const SizedBox(height: StokasSpace.s4),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isSaving,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: "Password Awal",
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: "Minimal 8 karakter",
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        tooltip: _obscurePassword ? "Tampilkan password" : "Sembunyikan password",
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: validateStaffPassword,
                  ),
                  const SizedBox(height: StokasSpace.s5),
                  StokasButton(label: "Simpan staf", expand: true, loading: _isSaving, onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
