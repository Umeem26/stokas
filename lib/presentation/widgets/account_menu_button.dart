import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session.dart';
import '../design/stokas_tokens.dart';

/// Konfirmasi lalu keluar; dipakai menu akun dan rel samping.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Keluar?"),
      content: const Text("Anda harus login lagi untuk memakai aplikasi."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("KELUAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(sessionControllerProvider.notifier).signOut();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
  }
}

/// Tombol akun di AppBar: nama + peran, dan Keluar dengan konfirmasi.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle),
      tooltip: "Akun",
      onSelected: (value) {
        if (value == 'logout') confirmSignOut(context, ref);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person),
            title: Text(profile.fullName.isEmpty ? "-" : profile.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: context.stokas.ink)),
            subtitle: Text(profile.role?.label ?? "-"),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Keluar"),
          ),
        ),
      ],
    );
  }
}
