import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import '../core/validators.dart';
import '../data/profile_model.dart';
import '../data/providers.dart';
import '../data/session.dart';
import 'add_staff_screen.dart';
import 'design/status_badge.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'widgets/error_view.dart';

/// Pesan singkat di bawah layar: ikon + kata (galat tidak dibedakan dengan warna saja).
void showStaffMessage(BuildContext context, String text, {bool isError = false}) {
  final c = context.stokas;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: c.canvas),
          const SizedBox(width: StokasSpace.s2),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

/// Kelola akun staf (owner saja). Semua aksi lewat Edge Function staff-admin.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  void _refresh(WidgetRef ref) => ref.invalidate(staffListProvider);

  Future<void> _openAddStaff(BuildContext context, WidgetRef ref) async {
    final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddStaffScreen()));
    if (added == true) _refresh(ref);
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
          title: Text("Reset password ${staff.fullName}"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              enabled: !busy,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: "Password baru",
                helperText: "Minimal 8 karakter",
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  tooltip: obscure ? "Tampilkan password" : "Sembunyikan password",
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
              validator: validateStaffPassword,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            StokasButton.secondary(label: "Batal", onPressed: busy ? null : () => Navigator.pop(ctx, false)),
            StokasButton(
              label: "Simpan",
              loading: busy,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => busy = true);
                try {
                  await ref.read(staffRepositoryProvider).setPassword(userId: staff.id, password: controller.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (context.mounted) showStaffMessage(context, "$e", isError: true);
                  if (ctx.mounted) setDialogState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (done == true && context.mounted) showStaffMessage(context, "Password ${staff.fullName} diganti");
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, Profile staff) async {
    final activate = !staff.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? "Aktifkan ${staff.fullName}?" : "Nonaktifkan ${staff.fullName}?"),
        content: Text(activate
            ? "${staff.fullName} bisa masuk kembali."
            : "${staff.fullName} tidak bisa masuk sampai diaktifkan lagi."),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          activate
              ? StokasButton(key: const Key('confirm-toggle-active'), label: "Aktifkan", onPressed: () => Navigator.pop(ctx, true))
              : StokasButton.danger(key: const Key('confirm-toggle-active'), label: "Nonaktifkan", onPressed: () => Navigator.pop(ctx, true)),
          StokasButton.secondary(label: "Batal", onPressed: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(staffRepositoryProvider).setActive(userId: staff.id, isActive: activate);
      if (context.mounted) showStaffMessage(context, activate ? "${staff.fullName} diaktifkan" : "${staff.fullName} dinonaktifkan");
      _refresh(ref);
    } catch (e) {
      if (context.mounted) showStaffMessage(context, "$e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.stokas;
    final myId = ref.watch(currentProfileProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Kelola Staf")),
      body: ref.watch(staffListProvider).when(
        skipLoadingOnRefresh: false,
        loading: () => const _StaffSkeleton(),
        error: (error, _) => ErrorView(error: error, onRetry: () => _refresh(ref)),
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              key: const Key('staff-empty'),
              child: Padding(
                padding: const EdgeInsets.all(StokasSpace.s5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: StokasSpace.s8, color: c.inkMuted),
                    const SizedBox(height: StokasSpace.s3),
                    Text("Belum ada staf. Tambah staf dulu.", textAlign: TextAlign.center, style: StokasType.title.copyWith(color: c.ink)),
                    const SizedBox(height: StokasSpace.s4),
                    StokasButton(label: "Tambah staf", icon: Icons.person_add_alt, onPressed: () => _openAddStaff(context, ref)),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s4, StokasSpace.s4, StokasSpace.s8 + StokasSpace.s6),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(StokasRadius.lg),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < staffList.length; i++) ...[
                      if (i > 0) const Divider(),
                      _StaffRow(
                        key: Key('staff-${staffList[i].id}'),
                        staff: staffList[i],
                        isMe: staffList[i].id == myId,
                        onResetPassword: () => _resetPassword(context, ref, staffList[i]),
                        onToggleActive: () => _toggleActive(context, ref, staffList[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt),
        label: Text("Tambah staf", style: StokasType.title.copyWith(color: c.onPrimary)),
        onPressed: () => _openAddStaff(context, ref),
      ),
    );
  }
}

/// Lencana peran: ikon + kata, netral (peran bukan status).
class RoleBadge extends StatelessWidget {
  final AppRole? role;

  const RoleBadge(this.role, {super.key});

  static IconData iconFor(AppRole? role) => switch (role) {
        AppRole.owner => Icons.storefront_outlined,
        AppRole.cashier => Icons.point_of_sale,
        AppRole.warehouse => Icons.inventory_2_outlined,
        null => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final text = role?.label ?? "Peran tidak dikenal";
    return Semantics(
      label: "Peran $text",
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s2, vertical: StokasSpace.s1),
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.sm)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(role), size: 16, color: c.ink),
            const SizedBox(width: StokasSpace.s1),
            Text(text, style: StokasType.label.copyWith(color: c.ink)),
          ],
        ),
      ),
    );
  }
}

/// Status akun: ikon + kata ("Aktif" centang, "Nonaktif" silang), bukan warna saja.
StatusBadge staffStatusBadge(bool isActive) =>
    isActive ? const StatusBadge(StockStatus.aman, label: "Aktif") : const StatusBadge(StockStatus.bahaya, label: "Nonaktif");

class _StaffRow extends StatelessWidget {
  final Profile staff;
  final bool isMe;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleActive;

  const _StaffRow({super.key, required this.staff, required this.isMe, required this.onResetPassword, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: StokasSpace.tapMin + StokasSpace.s4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s3, StokasSpace.s1, StokasSpace.s3),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: c.surfaceSunken,
              child: Icon(Icons.person_outline, color: staff.isActive ? c.ink : c.inkMuted),
            ),
            const SizedBox(width: StokasSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? "${staff.fullName} (Anda)" : staff.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StokasType.title.copyWith(color: staff.isActive ? c.ink : c.inkMuted),
                  ),
                  const SizedBox(height: StokasSpace.s1),
                  Wrap(
                    spacing: StokasSpace.s2,
                    runSpacing: StokasSpace.s1,
                    children: [RoleBadge(staff.role), staffStatusBadge(staff.isActive)],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: Key('staff-actions-${staff.id}'),
              tooltip: "Aksi untuk ${staff.fullName}",
              icon: Icon(Icons.more_vert, color: c.inkMuted),
              onSelected: (value) {
                if (value == 'password') onResetPassword();
                if (value == 'active') onToggleActive();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'password',
                  child: ListTile(leading: Icon(Icons.key_outlined), title: Text("Reset password"), contentPadding: EdgeInsets.zero),
                ),
                if (!isMe)
                  PopupMenuItem(
                    value: 'active',
                    child: ListTile(
                      leading: Icon(staff.isActive ? Icons.block : Icons.check_circle_outline),
                      title: Text(staff.isActive ? "Nonaktifkan" : "Aktifkan"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffSkeleton extends StatelessWidget {
  const _StaffSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.sm)),
        );
    return ListView(
      key: const Key('staff-skeleton'),
      padding: const EdgeInsets.all(StokasSpace.s4),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: StokasSpace.s2),
            child: Container(
              padding: const EdgeInsets.all(StokasSpace.s4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(StokasRadius.lg),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: c.surfaceSunken),
                  const SizedBox(width: StokasSpace.s3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(140, StokasSpace.s4), const SizedBox(height: StokasSpace.s2), bar(96, StokasSpace.s3)],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
