import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/scan_match.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';

typedef ProductRow = Map<String, dynamic>;

/// Hasil simpan berurutan per baris: jumlah sukses, gagal, dan apakah berhenti karena jaringan.
typedef SaveSummary = ({int saved, int failed, bool offline});

/// Kolom scan/cari barang gudang (semua produk aktif, termasuk yang belum punya stok).
/// Enter: kode persis dulu, lalu nama persis, lalu nama mengandung bila tunggal; banyak cocok
/// -> "pilih dari daftar". Kode tak dikenal memakai [unknownAction] bila ada.
class ProductSearch extends ConsumerStatefulWidget {
  final String keyPrefix;
  final ValueChanged<ProductRow> onPick;
  final Widget Function(String code, VoidCallback reset)? unknownAction;

  const ProductSearch({super.key, required this.keyPrefix, required this.onPick, this.unknownAction});

  @override
  ConsumerState<ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends ConsumerState<ProductSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  String? _message;
  String? _unknownCode;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  ScanMatch<ProductRow> _match(String text) => matchScan(
        ref.read(productListProvider).value ?? const <ProductRow>[],
        text,
        id: (p) => p['id'] as String,
        name: (p) => p['brand_name'] as String,
      );

  void _reset() {
    _controller.clear();
    setState(() {
      _query = '';
      _message = null;
      _unknownCode = null;
    });
    _focus.requestFocus();
  }

  void _pick(ProductRow p) {
    widget.onPick(p);
    _reset();
  }

  void _submit(String text) {
    _focus.requestFocus();
    if (text.trim().isEmpty) return;
    if (!ref.read(productListProvider).hasValue) {
      setState(() => _message = 'Daftar barang belum dimuat. Tunggu sebentar lalu scan lagi.');
      return;
    }
    final result = _match(text);
    if (result.match != null) return _pick(result.match!);
    setState(() {
      final many = result.candidates.isNotEmpty;
      _message = many ? 'Ada beberapa barang yang cocok, pilih dari daftar' : null;
      _unknownCode = many ? null : text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final products = ref.watch(productListProvider);
    final candidates = _query.trim().isEmpty || _unknownCode != null ? const <ProductRow>[] : _match(_query).candidates;
    final p = widget.keyPrefix;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s4, StokasSpace.s4, StokasSpace.s2),
          child: TextField(
            key: Key('$p-search'),
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: StokasType.bodyLg.copyWith(color: c.ink),
            decoration: const InputDecoration(hintText: 'Scan kode atau cari nama barang', prefixIcon: Icon(Icons.qr_code_scanner)),
            onChanged: (v) => setState(() {
              _query = v;
              _message = null;
              _unknownCode = null;
            }),
            onSubmitted: _submit,
          ),
        ),
        if (products.hasError)
          Notice(
            icon: Icons.error_outline,
            color: c.negative,
            text: 'Daftar barang gagal dimuat. ${products.error}',
            action: StokasButton.secondary(label: 'Coba lagi', onPressed: () => ref.invalidate(productListProvider)),
          ),
        if (_message != null) Notice(icon: Icons.info_outline, color: c.inkMuted, text: _message!),
        if (_unknownCode != null)
          widget.unknownAction == null
              ? Notice(icon: Icons.help_outline, color: c.warning, text: 'Barang "$_unknownCode" tidak ditemukan.')
              : Notice(
                  icon: Icons.help_outline,
                  color: c.warning,
                  text: 'Kode "$_unknownCode" belum terdaftar.',
                  action: widget.unknownAction!(_unknownCode!, _reset),
                ),
        if (candidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(StokasSpace.s4, 0, StokasSpace.s4, StokasSpace.s2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Material(
                color: c.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.lg), side: BorderSide(color: c.line)),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in candidates.take(8))
                      ListTile(
                        key: ValueKey('$p-candidate-${item['id']}'),
                        minTileHeight: StokasSpace.tapMin,
                        title: Text(item['brand_name'] as String, style: StokasType.title.copyWith(color: c.ink)),
                        subtitle: Text('${item['id']} · ${item['unit_type'] ?? ''}', style: StokasType.caption.copyWith(color: c.inkMuted)),
                        trailing: Icon(Icons.add, color: c.primary),
                        onTap: () => _pick(item),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pemberitahuan: ikon + teks, aksi opsional.
class Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  const Notice({super.key, required this.icon, required this.color, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Padding(
      padding: const EdgeInsets.fromLTRB(StokasSpace.s4, 0, StokasSpace.s4, StokasSpace.s2),
      child: Wrap(
        spacing: StokasSpace.s3,
        runSpacing: StokasSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: StokasSpace.s2),
              Flexible(child: Text(text, style: StokasType.body.copyWith(color: c.ink))),
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Ringkasan setelah simpan: "N tersimpan", jumlah gagal, dan koneksi terputus.
class SaveSummaryBanner extends StatelessWidget {
  final SaveSummary summary;

  const SaveSummaryBanner({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final ok = summary.failed == 0 && !summary.offline;
    final parts = [
      '${summary.saved} tersimpan',
      if (summary.failed > 0) '${summary.failed} gagal, lihat pesan di kartunya',
      if (summary.offline) 'koneksi terputus, sisa baris belum dikirim',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(StokasSpace.s4, 0, StokasSpace.s4, StokasSpace.s2),
      padding: const EdgeInsets.all(StokasSpace.s3),
      decoration: BoxDecoration(color: ok ? c.positiveSoft : c.warningSoft, borderRadius: BorderRadius.circular(StokasRadius.md)),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 20, color: ok ? c.positive : c.warning),
          const SizedBox(width: StokasSpace.s2),
          Expanded(child: Text('${parts.join('. ')}.', style: StokasType.body.copyWith(color: c.ink))),
        ],
      ),
    );
  }
}

/// Bilah aksi bawah: tombol primer selebar layar + alasan bila nonaktif (selalu terlihat).
class ActionBar extends StatelessWidget {
  final StokasButton button;
  final String? reason;
  final Key? reasonKey;
  final Widget? top; // mis. pesan galat di atas tombol

  const ActionBar({super.key, required this.button, this.reason, this.reasonKey, this.top});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Container(
      padding: const EdgeInsets.all(StokasSpace.s4),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (top != null) ...[top!, const SizedBox(height: StokasSpace.s2)],
          button,
          if (reason != null) ...[
            const SizedBox(height: StokasSpace.s2),
            Text(reason!, key: reasonKey, textAlign: TextAlign.center, style: StokasType.caption.copyWith(color: c.inkMuted)),
          ],
        ],
      ),
    );
  }
}

/// Kerangka layar gudang: lebar maksimal, isi menggulir, bilah aksi di bawah.
class WarehouseScaffold extends StatelessWidget {
  final String title;
  final List<Widget> header; // di atas area gulir (kolom cari, pemberitahuan)
  final List<Widget> content; // area gulir
  final Widget bottom;
  final List<Widget> actions;

  const WarehouseScaffold({super.key, required this.title, required this.header, required this.content, required this.bottom, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...header,
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
                    children: content,
                  ),
                ),
                bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilih barang dari daftar lengkap, dengan kolom cari (tombol "Tambah baris").
class ProductPickerSheet extends StatefulWidget {
  final List<ProductRow> products;

  const ProductPickerSheet({super.key, required this.products});

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final q = _query.trim().toLowerCase();
    final shown = widget.products
        .where((p) => q.isEmpty || (p['brand_name'] as String).toLowerCase().contains(q) || (p['id'] as String).toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Cari nama atau kode barang', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text('Barang tidak ditemukan', style: StokasType.body.copyWith(color: c.inkMuted)))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) => ListTile(
                        key: ValueKey('picker-${shown[i]['id']}'),
                        minTileHeight: StokasSpace.tapMin,
                        title: Text(shown[i]['brand_name'] as String, style: StokasType.title.copyWith(color: c.ink)),
                        subtitle: Text('${shown[i]['id']}', style: StokasType.caption.copyWith(color: c.inkMuted)),
                        onTap: () => Navigator.pop(context, shown[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
