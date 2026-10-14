import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/attention.dart';
import '../../data/providers.dart';
import '../../data/revenue.dart';
import '../app_shell.dart';
import '../design/money_text.dart';
import '../design/status_badge.dart';
import '../design/stokas_tokens.dart';
import '../widgets/account_menu_button.dart';
import '../widgets/error_view.dart';
import 'product_detail_screen.dart';

/// Lebar maksimum isi layar owner di layar lebar (>= [railBreakpoint]).
const ownerMaxWidth = 640.0;

/// Jarak samping: isi dipusatkan selebar [ownerMaxWidth] bila layar >= [railBreakpoint].
double ownerSidePadding(BuildContext context, double available) {
  if (MediaQuery.sizeOf(context).width < railBreakpoint) return StokasSpace.s4;
  return math.max(StokasSpace.s4, (available - ownerMaxWidth) / 2);
}

/// Home owner (HP dulu): kartu "Omzet hari ini" dan daftar "Perlu diurus".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static Future<void> refresh(WidgetRef ref) async {
    ref.invalidate(homeRevenueProvider);
    ref.invalidate(homeAttentionProvider);
    try {
      await Future.wait([ref.read(homeRevenueProvider.future), ref.read(homeAttentionProvider.future)]);
    } catch (_) {
      // Galat ditampilkan oleh bagian masing-masing.
    }
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref, AttentionItem item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: item.product)),
    );
    if (changed == true) {
      ref.invalidate(homeAttentionProvider);
      ref.invalidate(stockListProvider);
      ref.invalidate(productListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.stokas;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Home'), actions: const [AccountMenuButton(), SizedBox(width: StokasSpace.s2)]),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = ownerSidePadding(context, constraints.maxWidth);
          return RefreshIndicator(
            onRefresh: () => refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(side, StokasSpace.s4, side, StokasSpace.s6),
              children: [
                _RevenueCard(
                  value: ref.watch(homeRevenueProvider),
                  onRetry: () => ref.invalidate(homeRevenueProvider),
                ),
                const SizedBox(height: StokasSpace.s5),
                Text('Perlu diurus', style: StokasType.titleLg.copyWith(color: c.ink)),
                const SizedBox(height: StokasSpace.s2),
                _AttentionList(
                  value: ref.watch(homeAttentionProvider),
                  onRetry: () => ref.invalidate(homeAttentionProvider),
                  onOpen: (item) => _openDetail(context, ref, item),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

BoxDecoration _cardDecoration(StokasColors c) => BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(StokasRadius.lg),
      border: Border.all(color: c.line),
    );

class _Skeleton extends StatelessWidget {
  final double height;
  final double? width;

  const _Skeleton({required this.height, this.width});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: context.stokas.surfaceSunken, borderRadius: BorderRadius.circular(StokasRadius.sm)),
      );
}

class _RevenueCard extends StatelessWidget {
  final AsyncValue<RevenueSummary> value;
  final VoidCallback onRetry;

  const _RevenueCard({required this.value, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final content = value.when(
      skipLoadingOnRefresh: false,
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
      data: (summary) => _RevenueContent(summary),
      loading: () => const Column(
          key: Key('home-revenue-skeleton'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Skeleton(height: StokasSpace.s4, width: StokasSpace.s8 * 2),
            SizedBox(height: StokasSpace.s3),
            _Skeleton(height: StokasSpace.s6 + StokasSpace.s2, width: StokasSpace.s8 * 4),
            SizedBox(height: StokasSpace.s3),
            _Skeleton(height: StokasSpace.s4, width: StokasSpace.s8 * 3),
          ],
        ),
    );
    return Container(
      key: const Key('home-revenue'),
      padding: const EdgeInsets.all(StokasSpace.s4),
      decoration: _cardDecoration(c),
      child: content,
    );
  }
}

class _RevenueContent extends StatelessWidget {
  final RevenueSummary summary;

  const _RevenueContent(this.summary);

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final change = summary.changePercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Omzet hari ini', style: StokasType.label.copyWith(color: c.inkMuted)),
        const SizedBox(height: StokasSpace.s1),
        MoneyText(summary.todayTotal, style: StokasType.displayL.copyWith(color: c.ink)),
        const SizedBox(height: StokasSpace.s1),
        Text('${summary.todayCount} transaksi', style: StokasType.body.copyWith(color: c.inkMuted)),
        if (change != null) ...[
          const SizedBox(height: StokasSpace.s2),
          _ChangeLine(change),
        ],
      ],
    );
  }
}

/// Perbandingan dengan kemarin: ikon panah + kata, bukan warna saja.
class _ChangeLine extends StatelessWidget {
  final int percent;

  const _ChangeLine(this.percent);

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final (icon, color, text) = switch (percent) {
      > 0 => (Icons.arrow_upward, c.positive, 'Naik $percent% dari kemarin'),
      < 0 => (Icons.arrow_downward, c.negative, 'Turun ${-percent}% dari kemarin'),
      _ => (Icons.arrow_forward, c.inkMuted, 'Sama dengan kemarin'),
    };
    return Row(
      key: const Key('home-revenue-change'),
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: StokasSpace.s1),
        Flexible(child: Text(text, style: StokasType.label.copyWith(color: color))),
      ],
    );
  }
}

class _AttentionList extends StatelessWidget {
  final AsyncValue<List<AttentionItem>> value;
  final VoidCallback onRetry;
  final ValueChanged<AttentionItem> onOpen;

  const _AttentionList({required this.value, required this.onRetry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return value.when(
      skipLoadingOnRefresh: false,
      error: (error, _) => Container(
        decoration: _cardDecoration(c),
        child: ErrorView(error: error, onRetry: onRetry),
      ),
      loading: () => Column(
        key: const Key('home-attention-skeleton'),
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: StokasSpace.s2),
              child: _Skeleton(height: StokasSpace.s8 + StokasSpace.s3),
            ),
        ],
      ),
      data: (items) => items.isEmpty
          ? Container(
              key: const Key('home-attention-empty'),
              padding: const EdgeInsets.all(StokasSpace.s4),
              decoration: _cardDecoration(c),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: c.positive),
                  const SizedBox(width: StokasSpace.s3),
                  Expanded(
                    child: Text('Semua beres. Tidak ada yang perlu diurus.', style: StokasType.body.copyWith(color: c.ink)),
                  ),
                ],
              ),
            )
          : Container(
              decoration: _cardDecoration(c),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: c.surface,
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.line),
                      _AttentionRow(key: Key('attention-$i'), item: items[i], onTap: () => onOpen(items[i])),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

StatusBadge attentionBadge(AttentionKind kind) => switch (kind) {
      AttentionKind.expired => const StatusBadge(StockStatus.bahaya),
      AttentionKind.nearExpiry => const StatusBadge(StockStatus.menipis, label: 'Hampir kedaluwarsa'),
      AttentionKind.belowMin => const StatusBadge(StockStatus.menipis),
      AttentionKind.noPrice => const StatusBadge(StockStatus.menipis, label: 'Harga belum diatur'),
    };

class _AttentionRow extends StatelessWidget {
  final AttentionItem item;
  final VoidCallback onTap;

  const _AttentionRow({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: StokasSpace.tapMin + StokasSpace.s4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: StokasType.title.copyWith(color: c.ink)),
                    Text(item.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: StokasType.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: StokasSpace.s3),
              attentionBadge(item.kind),
              Icon(Icons.chevron_right, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
