import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/validators.dart';
import '../data/profile_model.dart';
import '../data/providers.dart';
import '../data/session.dart';
import 'add_staff_screen.dart';
import 'widgets/error_view.dart';

/// Kelola akun staf (owner saja). Semua aksi lewat Edge Function staff-admin.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  void _refresh(WidgetRef ref) => ref.invalidate(staffListProvider);

  void _showMessage(BuildContext context, String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? Colors.red : null),
    );
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, Profile staff) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    bool obscure = true;
    bool busy = false;

    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text("Reset Password ${staff.fullName}"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: "Password baru",
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
              validator: validateStaffPassword,
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text("Batal")),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        await ref.read(staffRepositoryProvider).setPassword(userId: staff.id, password: controller.text);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (context.mounted) _showMessage(context, "$e", isError: true);
                        if (ctx.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: const Text("SIMPAN"),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (done == true && context.mounted) _showMessage(context, "✅ Password ${staff.fullName} diganti");
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, Profile staff) async {
    final activate = !staff.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? "Aktifkan Staf?" : "Nonaktifkan Staf?"),
        content: Text(activate
            ? "${staff.fullName} bisa login kembali."
            : "${staff.fullName} tidak bisa login sampai diaktifkan lagi."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(activate ? "AKTIFKAN" : "NONAKTIFKAN",
                style: TextStyle(color: activate ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(staffRepositoryProvider).setActive(userId: staff.id, isActive: activate);
      if (context.mounted) _showMessage(context, activate ? "✅ Staf diaktifkan" : "✅ Staf dinonaktifkan");
      _refresh(ref);
    } catch (e) {
      if (context.mounted) _showMessage(context, "$e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentProfileProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Kelola Staf")),
      body: ref.watch(staffListProvider).when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: () => _refresh(ref)),
        data: (staffList) {
          if (staffList.isEmpty) {
            return const Center(child: Text("Belum ada staf"));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: staffList.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final staff = staffList[index];
              final isMe = staff.id == myId;
              return ListTile(
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: staff.isActive ? Colors.blue.shade50 : Colors.grey.shade200,
                  child: Icon(Icons.person, color: staff.isActive ? Colors.blue : Colors.grey),
                ),
                title: Text(
                  isMe ? "${staff.fullName} (Anda)" : staff.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(staff.role?.label ?? "-"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      staff.isActive ? "Aktif" : "Nonaktif",
                      style: TextStyle(color: staff.isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                    PopupMenuButton<String>(
                      tooltip: "Aksi",
                      onSelected: (value) {
                        if (value == 'password') _resetPassword(context, ref, staff);
                        if (value == 'active') _toggleActive(context, ref, staff);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'password', child: Text("Reset password")),
                        if (!isMe)
                          PopupMenuItem(value: 'active', child: Text(staff.isActive ? "Nonaktifkan" : "Aktifkan")),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Tambah Staf", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStaffScreen()))
              .then((value) { if (value == true) _refresh(ref); });
        },
      ),
    );
  }
}
