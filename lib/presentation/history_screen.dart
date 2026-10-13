import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/jakarta_time.dart';
import '../data/providers.dart';
import '../data/session.dart';
import '../data/transaction_model.dart';
import 'design/money_text.dart';
import 'design/payment_method_label.dart';
import 'design/stokas_button.dart';
import 'design/stokas_tokens.dart';
import 'receipt_download.dart';
import 'widgets/error_view.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  void _showError(Object error) {
    final c = context.stokas;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [Icon(Icons.error_outline, color: c.canvas), const SizedBox(width: StokasSpace.s2), Expanded(child: Text('$error'))]),
      ));
  }

  /// Nama kasir untuk struk: pengguna sendiri, atau (owner) dari daftar profil staf.
  Future<String> _cashierName(TransactionModel t) async {
    final me = ref.read(currentProfileProvider);
    if (t.cashierId == null || t.cashierId == me?.id) return me?.fullName ?? '';
    try {
      final profiles = await ref.read(profileRepositoryProvider).getAllProfiles();
      return profiles.where((p) => p.id == t.cashierId).firstOrNull?.fullName ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Struk dari data tersimpan (item snapshot server), bukan dari keranjang.
  Future<void> _download(TransactionModel t) async {
    final TransactionModel full;
    try {
      full = t.items.isNotEmpty ? t : t.withItems(await ref.read(transactionRepositoryProvider).getTransactionItems(t.id));
    } catch (e) {
      if (mounted) _showError(e);
      return;
    }
    final name = await _cashierName(full);
    if (!mounted) return;
    await downloadReceipt(context, ref, full, cashierName: name);
  }

  Future<void> _showDetail(TransactionModel transaction) async {
    final List<TransactionItem> items;
    try {
      items = await ref.read(transactionRepositoryProvider).getTransactionItems(transaction.id);
    } catch (e) {
      if (mounted) _showError(e);
      return;
    }
    if (!mounted) return;
    final t = transaction.withItems(items);
    final c = context.stokas;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StokasRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Struk ${t.receiptNumber}', style: StokasType.titleLg.copyWith(color: c.ink)),
                const SizedBox(height: StokasSpace.s1),
                Text(formatWibDateTime(t.createdAt), style: StokasType.body.copyWith(color: c.inkMuted)),
                Divider(height: StokasSpace.s5, color: c.line),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Nama & harga snapshot saat transaksi (tetap benar walau produk diubah/dihapus)
                      for (final item in t.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: StokasSpace.s1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName, style: StokasType.title.copyWith(color: c.ink)),
                                    Text('${formatQty(item.quantity)} × ${formatRupiah(item.price)}', style: StokasType.body.copyWith(color: c.inkMuted)),
                                  ],
                                ),
                              ),
                              MoneyText(item.subtotal, textAlign: TextAlign.right, style: StokasType.title.copyWith(color: c.ink)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: StokasSpace.s5, color: c.line),
                Row(
                  children: [
                    Expanded(child: Text('Total', style: StokasType.title.copyWith(color: c.ink))),
                    MoneyText(t.totalAmount, style: StokasType.headline.copyWith(color: c.ink)),
                  ],
                ),
                const SizedBox(height: StokasSpace.s1),
                Row(
                  children: [
                    Expanded(child: Text('Cara bayar', style: StokasType.body.copyWith(color: c.inkMuted))),
                    PaymentMethodLabel(t.paymentMethod),
                  ],
                ),
                const SizedBox(height: StokasSpace.s4),
                StokasButton.secondary(
                  label: 'Unduh struk (PDF)',
                  icon: Icons.download_outlined,
                  expand: true,
                  onPressed: () => _download(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: ref.watch(transactionHistoryProvider).when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(error: error, onRetry: () => ref.invalidate(transactionHistoryProvider)),
            data: (data) {
              if (data.isEmpty) {
                return Center(
                  child: Text('Belum ada transaksi. Transaksi dari Kasir muncul di sini.',
                      textAlign: TextAlign.center, style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(StokasSpace.s3),
                itemCount: data.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
                itemBuilder: (context, index) {
                  final trx = data[index];
                  return Material(
                    color: c.surface,
                    child: InkWell(
                      key: ValueKey('history-${trx.id}'),
                      onTap: () => _showDetail(trx),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s3, StokasSpace.s1, StokasSpace.s3),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, color: c.inkMuted),
                            const SizedBox(width: StokasSpace.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Struk ${trx.receiptNumber}', style: StokasType.title.copyWith(color: c.ink)),
                                  Text(formatWibDateTime(trx.createdAt), style: StokasType.body.copyWith(color: c.inkMuted)),
                                  const SizedBox(height: StokasSpace.s1),
                                  PaymentMethodLabel(trx.paymentMethod, style: StokasType.body.copyWith(color: c.inkMuted)),
                                ],
                              ),
                            ),
                            MoneyText(trx.totalAmount, textAlign: TextAlign.right, style: StokasType.title.copyWith(color: c.ink)),
                            IconButton(
                              key: ValueKey('download-${trx.id}'),
                              tooltip: 'Unduh struk',
                              style: IconButton.styleFrom(minimumSize: const Size.square(StokasSpace.tapMin)),
                              icon: const Icon(Icons.download_outlined),
                              onPressed: () => _download(trx),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
