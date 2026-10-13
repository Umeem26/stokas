import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/config.dart';
import '../../core/jakarta_time.dart';
import '../../data/providers.dart';
import '../../data/receive_lines.dart';
import '../../data/scan_match.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';
import '../widgets/account_menu_button.dart';
import 'new_product_screen.dart';
import 'stock_inputs.dart';

typedef _Product = Map<String, dynamic>;

/// Terima barang (gudang). Scan/cari menambah kartu per baris; "Simpan N barang" memanggil
/// RPC restock satu per baris secara berurutan. Baris sukses hilang, baris gagal tetap dengan
/// pesan server. restock tidak punya kunci idempotensi, jadi saat jaringan putus tidak ada
/// pengulangan otomatis: baris ditandai [uncertainSaveMessage] dan sisa baris tidak dikirim.
class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  final _lines = <ReceiveLine>[];
  int _nextKey = 1;
  String _lastFloor = storeFloors.first; // baris baru ikut lantai terakhir
  String _query = '';
  String? _searchMessage; // "pilih dari daftar" / daftar belum dimuat
  String? _unknownCode; // kode yang tidak ditemukan saat Enter
  bool _saving = false;
  ({int saved, int failed, bool offline})? _summary;

  DateTime get _now => ref.read(clockProvider)();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<_Product> get _products => ref.read(productListProvider).value ?? const [];

  ScanMatch<_Product> _match(String text) => matchScan(_products, text, id: (p) => p['id'] as String, name: (p) => p['brand_name'] as String);

  void _resetSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _searchMessage = null;
      _unknownCode = null;
    });
    _searchFocus.requestFocus();
  }

  /// Enter di kolom cari: kode persis dulu, lalu nama persis, lalu nama mengandung bila tunggal.
  void _submitSearch(String text) {
    if (text.trim().isEmpty) return _searchFocus.requestFocus();
    if (!ref.read(productListProvider).hasValue) {
      setState(() => _searchMessage = 'Daftar barang belum dimuat. Tunggu sebentar lalu scan lagi.');
      return _searchFocus.requestFocus();
    }
    final result = _match(text);
    if (result.match != null) {
      _addProduct(result.match!);
    } else if (result.candidates.isNotEmpty) {
      setState(() {
        _searchMessage = 'Ada beberapa barang yang cocok, pilih dari daftar';
        _unknownCode = null;
      });
      _searchFocus.requestFocus();
    } else {
      setState(() {
        _searchMessage = null;
        _unknownCode = text.trim();
      });
      _searchFocus.requestFocus();
    }
  }

  /// Scan ulang barang yang sudah ada di daftar menambah jumlah baris terakhirnya.
  void _addProduct(_Product p) {
    setState(() {
      _summary = null;
      final existing = _lines.lastWhere((l) => l.productId == p['id'], orElse: () => _newLine(p));
      if (_lines.contains(existing)) {
        existing.qty += 1;
        existing.error = null;
      } else {
        _lines.add(existing);
      }
    });
    _resetSearch();
  }

  ReceiveLine _newLine(_Product p) =>
      ReceiveLine(key: _nextKey++, productId: p['id'] as String, name: p['brand_name'] as String, unit: (p['unit_type'] as String?) ?? '', floor: _lastFloor);

  void _edit(ReceiveLine line, void Function() change) => setState(() {
    change();
    line.error = null;
    _summary = null;
  });

  Future<void> _openNewProduct(String code) async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NewProductScreen(initialCode: code)));
    if (!mounted) return;
    if (created == true) {
      ref.invalidate(productListProvider);
      ref.invalidate(stockListProvider);
      _resetSearch();
    }
  }

  Future<void> _pickFromList() async {
    final picked = await showModalBottomSheet<_Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductPickerSheet(products: _products),
    );
    if (picked != null && mounted) _addProduct(picked);
  }

  Future<void> _save() async {
    if (_saving || saveBlockReason(_lines, _now) != null) return;
    setState(() {
      _saving = true;
      _summary = null;
    });
    final repo = ref.read(stockRepositoryProvider);
    var saved = 0, failed = 0;
    var offline = false;
    for (final line in List.of(_lines)) {
      try {
        await repo.restock(productId: line.productId, floor: line.floor, expiry: line.expiry, qty: line.qty);
        saved++;
        if (mounted) setState(() => _lines.remove(line));
      } on NetworkException catch (e) {
        // Hasil tidak diketahui: berhenti, jangan ulang otomatis; sisa baris belum dikirim.
        line.error = e.message;
        offline = true;
        break;
      } on AppException catch (e) {
        line.error = e.message;
        failed++;
      }
    }
    if (saved > 0) {
      ref.invalidate(stockListProvider);
      ref.invalidate(productListProvider);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _summary = (saved: saved, failed: failed, offline: offline);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final now = ref.watch(clockProvider)();
    final productsAsync = ref.watch(productListProvider);
    final blockReason = saveBlockReason(_lines, now);
    final candidates = _query.trim().isEmpty ? const <_Product>[] : _match(_query).candidates;

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(title: const Text('Terima barang'), actions: const [AccountMenuButton()]),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s4, StokasSpace.s4, StokasSpace.s2),
                  child: TextField(
                    key: const Key('receive-search'),
                    controller: _searchController,
                    focusNode: _searchFocus,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: StokasType.bodyLg.copyWith(color: c.ink),
                    decoration: const InputDecoration(hintText: 'Scan kode atau cari nama barang', prefixIcon: Icon(Icons.qr_code_scanner)),
                    onChanged: (v) => setState(() {
                      _query = v;
                      _searchMessage = null;
                      _unknownCode = null;
                    }),
                    onSubmitted: _submitSearch,
                  ),
                ),
                if (productsAsync.hasError)
                  _Notice(
                    icon: Icons.error_outline,
                    color: c.negative,
                    text: 'Daftar barang gagal dimuat. ${productsAsync.error}',
                    action: StokasButton.secondary(label: 'Coba lagi', onPressed: () => ref.invalidate(productListProvider)),
                  ),
                if (_searchMessage != null) _Notice(icon: Icons.info_outline, color: c.inkMuted, text: _searchMessage!),
                if (_unknownCode != null)
                  _Notice(
                    icon: Icons.help_outline,
                    color: c.warning,
                    text: 'Kode "$_unknownCode" belum terdaftar.',
                    action: StokasButton.secondary(
                      key: const Key('receive-create-product'),
                      label: 'Buat produk baru dengan kode ini',
                      icon: Icons.add,
                      onPressed: () => _openNewProduct(_unknownCode!),
                    ),
                  ),
                if (_summary != null) _SummaryBanner(summary: _summary!),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4, vertical: StokasSpace.s2),
                    children: [
                      if (candidates.isNotEmpty && _unknownCode == null) _CandidateList(candidates: candidates, onPick: _addProduct),
                      if (_lines.isEmpty && candidates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: StokasSpace.s5),
                          child: Text(
                            'Belum ada barang. Scan kode atau cari nama barang.',
                            textAlign: TextAlign.center,
                            style: StokasType.body.copyWith(color: c.inkMuted),
                          ),
                        ),
                      for (final line in _lines)
                        Padding(
                          key: ValueKey('receive-line-${line.key}'),
                          padding: const EdgeInsets.only(bottom: StokasSpace.s3),
                          child: _LineCard(
                            line: line,
                            today: jakartaTodayLocal(now),
                            problem: lineProblem(line, now),
                            enabled: !_saving,
                            onQty: (q) => _edit(line, () => line.qty = q),
                            onFloor: (f) => _edit(line, () => line.floor = _lastFloor = f),
                            onExpiry: (d) => _edit(line, () => line.expiry = d),
                            onRemove: () => setState(() => _lines.remove(line)),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StokasButton.secondary(
                          key: const Key('receive-add-line'),
                          label: 'Tambah baris',
                          icon: Icons.add,
                          onPressed: _saving || !productsAsync.hasValue ? null : _pickFromList,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(StokasSpace.s4),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.line)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StokasButton(
                        key: const Key('receive-save'),
                        label: _saving
                            ? 'Menyimpan...'
                            : _lines.isEmpty
                            ? 'Simpan barang'
                            : 'Simpan ${_lines.length} barang',
                        icon: Icons.save_outlined,
                        expand: true,
                        onPressed: _saving || blockReason != null ? null : _save,
                      ),
                      if (blockReason != null) ...[
                        const SizedBox(height: StokasSpace.s2),
                        Text(
                          blockReason,
                          key: const Key('receive-save-reason'),
                          textAlign: TextAlign.center,
                          style: StokasType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemberitahuan di bawah kolom cari: ikon + teks, aksi opsional.
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  const _Notice({required this.icon, required this.color, required this.text, this.action});

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
              Flexible(
                child: Text(text, style: StokasType.body.copyWith(color: c.ink)),
              ),
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Ringkasan setelah simpan: "N tersimpan", jumlah gagal, dan koneksi terputus.
class _SummaryBanner extends StatelessWidget {
  final ({int saved, int failed, bool offline}) summary;

  const _SummaryBanner({required this.summary});

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
      key: const Key('receive-summary'),
      margin: const EdgeInsets.fromLTRB(StokasSpace.s4, 0, StokasSpace.s4, StokasSpace.s2),
      padding: const EdgeInsets.all(StokasSpace.s3),
      decoration: BoxDecoration(color: ok ? c.positiveSoft : c.warningSoft, borderRadius: BorderRadius.circular(StokasRadius.md)),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 20, color: ok ? c.positive : c.warning),
          const SizedBox(width: StokasSpace.s2),
          Expanded(
            child: Text('${parts.join('. ')}.', style: StokasType.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  final List<_Product> candidates;
  final ValueChanged<_Product> onPick;

  const _CandidateList({required this.candidates, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Padding(
      padding: const EdgeInsets.only(bottom: StokasSpace.s3),
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StokasRadius.lg),
          side: BorderSide(color: c.line),
        ),
        child: Column(
          children: [
            for (final p in candidates.take(8))
              ListTile(
                key: ValueKey('receive-candidate-${p['id']}'),
                minTileHeight: StokasSpace.tapMin,
                title: Text(p['brand_name'] as String, style: StokasType.title.copyWith(color: c.ink)),
                subtitle: Text('${p['id']} · ${p['unit_type'] ?? ''}', style: StokasType.caption.copyWith(color: c.inkMuted)),
                trailing: Icon(Icons.add, color: c.primary),
                onTap: () => onPick(p),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pilih barang dari daftar (tombol "Tambah baris"), dengan kolom cari.
class _ProductPickerSheet extends StatefulWidget {
  final List<_Product> products;

  const _ProductPickerSheet({required this.products});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
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
                  ? Center(
                      child: Text('Barang tidak ditemukan', style: StokasType.body.copyWith(color: c.inkMuted)),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) => ListTile(
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

/// Kartu satu baris: nama, kode, stepper jumlah, lantai, kedaluwarsa opsional, pesan galat.
class _LineCard extends StatelessWidget {
  final ReceiveLine line;
  final DateTime today;
  final String? problem;
  final bool enabled;
  final ValueChanged<num> onQty;
  final ValueChanged<String> onFloor;
  final ValueChanged<DateTime?> onExpiry;
  final VoidCallback onRemove;

  const _LineCard({
    required this.line,
    required this.today,
    required this.problem,
    required this.enabled,
    required this.onQty,
    required this.onFloor,
    required this.onExpiry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final k = line.key;
    final hasIssue = problem != null || line.error != null;
    return Container(
      padding: const EdgeInsets.all(StokasSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StokasRadius.lg),
        border: Border.all(color: hasIssue ? c.negative : c.line),
      ),
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: StokasType.title.copyWith(color: c.ink)),
                      Text('Kode ${line.productId}', style: StokasType.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('receive-remove-$k'),
                  icon: Icon(Icons.delete_outline, color: c.inkMuted),
                  tooltip: 'Hapus baris',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: StokasSpace.s3),
            Wrap(
              spacing: StokasSpace.s4,
              runSpacing: StokasSpace.s3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QtyStepper(value: line.qty, onChanged: onQty, fieldKey: Key('receive-qty-$k')),
                    const SizedBox(width: StokasSpace.s2),
                    Text(line.unit, style: StokasType.body.copyWith(color: c.inkMuted)),
                  ],
                ),
                FloorPicker(key: Key('receive-floor-$k'), value: line.floor, onChanged: onFloor),
              ],
            ),
            const SizedBox(height: StokasSpace.s3),
            ExpiryField(
              buttonKey: Key('receive-expiry-$k'),
              value: line.expiry,
              today: today,
              onChanged: onExpiry,
              errorText: problem == pastDateMessage ? problem : null,
            ),
            if (problem != null && problem != pastDateMessage) ...[const SizedBox(height: StokasSpace.s2), FieldError(problem!)],
            if (line.error != null) ...[const SizedBox(height: StokasSpace.s2), FieldError(line.error!, key: Key('receive-error-$k'))],
          ],
        ),
      ),
    );
  }
}
