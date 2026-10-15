import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/jakarta_time.dart';
import '../../data/quick_cash.dart';
import '../../data/transaction_model.dart';
import '../add_product_screen.dart' show CurrencyInputFormatter;
import '../design/money_text.dart';
import '../design/payment_method_label.dart';
import '../design/status_badge.dart';
import '../design/stokas_button.dart';
import '../design/stokas_tokens.dart';

/// Lebar panel bayar di tata letak dua panel (menggantikan keranjang 408 px).
const double payPanelWidth = 480;

/// Tinggi tombol uang cepat di tablet kasir (lebih dari tap-min).
const double _quickCashHeight = 56;

/// Baris keranjang yang ditolak server: hint `product_id`, atau nama/kode setelah ": "
/// pada pesan seperti "Stok tidak cukup: Marlong 250 ml (tersedia 3)". Null bila tidak ada yang cocok.
String? problemProductId(String message, List<CartItem> items, {String? hintProductId}) {
  if (hintProductId != null && items.any((i) => i.productId == hintProductId)) return hintProductId;
  final start = message.indexOf(': ');
  if (start < 0) return null;
  var subject = message.substring(start + 2);
  final paren = subject.lastIndexOf(' (');
  if (paren > 0) subject = subject.substring(0, paren);
  final k = subject.trim().toLowerCase();
  for (final i in items) {
    if (i.productId.toLowerCase() == k || i.productName.toLowerCase() == k) return i.productId;
  }
  return null;
}

/// Ringkasan pesanan baca-saja (panel kiri saat bayar). Baris bermasalah diberi lencana.
class OrderSummary extends StatelessWidget {
  final List<CartItem> items;
  final int total;
  final String? problemProductId;

  const OrderSummary({super.key, required this.items, required this.total, this.problemProductId});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Column(
      key: const Key('order-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(StokasSpace.s4, StokasSpace.s4, StokasSpace.s4, StokasSpace.s2),
          child: Text('Ringkasan pesanan · ${items.length} barang', style: StokasType.titleLg.copyWith(color: c.ink)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s4),
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
            itemBuilder: (context, i) => _SummaryLine(item: items[i], problem: items[i].productId == problemProductId),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Padding(
            padding: const EdgeInsets.all(StokasSpace.s4),
            child: Row(
              children: [
                Text('Total', style: StokasType.titleLg.copyWith(color: c.inkMuted)),
                const SizedBox(width: StokasSpace.s3),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: MoneyText(total, style: StokasType.headline.copyWith(color: c.ink)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ringkasan pesanan yang bisa dibuka di panel bayar layar sempit; terbuka sendiri bila ada baris bermasalah.
class OrderSummaryTile extends StatelessWidget {
  final List<CartItem> items;
  final String? problemProductId;

  const OrderSummaryTile({super.key, required this.items, this.problemProductId});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Padding(
      padding: const EdgeInsets.only(bottom: StokasSpace.s3),
      child: ExpansionTile(
        key: ValueKey('order-summary-tile-$problemProductId'),
        initiallyExpanded: problemProductId != null,
        tilePadding: EdgeInsets.zero,
        title: Text('Lihat pesanan (${items.length} barang)', style: StokasType.title.copyWith(color: c.ink)),
        children: [
          for (final item in items) _SummaryLine(item: item, problem: item.productId == problemProductId),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final CartItem item;
  final bool problem;

  const _SummaryLine({required this.item, required this.problem});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Container(
      key: ValueKey('summary-${item.productId}'),
      color: problem ? c.negativeSoft : null,
      padding: const EdgeInsets.symmetric(vertical: StokasSpace.s2, horizontal: StokasSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: StokasType.title.copyWith(color: c.ink)),
                Text('${formatQty(item.quantity)} × ${formatRupiah(item.price)}', style: StokasType.body.copyWith(color: c.inkMuted)),
                if (problem) ...[
                  const SizedBox(height: StokasSpace.s1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(StockStatus.bahaya, key: ValueKey('summary-problem-${item.productId}'), label: 'Stok kurang'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: StokasSpace.s2),
          MoneyText(item.subtotal, textAlign: TextAlign.right, style: StokasType.title.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}

/// Panel bayar: cara bayar (Tunai bawaan / QRIS / Transfer), uang diterima, uang cepat,
/// kembalian, dan tombol Bayar yang nonaktif dengan alasan tertulis bila uang kurang.
/// QRIS/Transfer selalu dibayar pas (server menolak lebih). Keyboard: 1/2/3 pilih cara bayar
/// (di luar kolom isian), Enter di kolom = Bayar, Esc = kembali. QRIS/Transfer: Enter pertama
/// memfokuskan "Sudah dibayar", Enter kedua (tombol terfokus) baru mencatat; klik tetap langsung.
class PayPanel extends StatefulWidget {
  final int total;
  final bool busy;
  final String? error; // pesan gagal bayar terakhir, ditampilkan apa adanya
  final void Function(int paid, PaymentMethod method) onPay;
  final VoidCallback onBack;
  final Widget? header; // mis. ringkasan pesanan yang bisa dibuka (layar sempit)
  final PaymentMethod initialMethod; // cara bayar terakhir dipakai di sesi ini

  const PayPanel({
    super.key,
    required this.total,
    required this.busy,
    required this.onPay,
    required this.onBack,
    this.error,
    this.header,
    this.initialMethod = PaymentMethod.cash,
  });

  @override
  State<PayPanel> createState() => _PayPanelState();
}

class _PayPanelState extends State<PayPanel> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  final _panelFocus = FocusNode(debugLabel: 'pay-panel');
  final _confirmFocus = FocusNode(debugLabel: 'pay-confirm');
  late PaymentMethod _method = widget.initialMethod;

  @override
  void initState() {
    super.initState();
    // Tanpa kolom uang (QRIS/Transfer) fokus ke panel agar 1/2/3, Enter, dan Esc langsung jalan.
    if (_method != PaymentMethod.cash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _panelFocus.requestFocus();
      });
    }
  }

  bool get _cash => _method == PaymentMethod.cash;
  int get _cashReceived => parseRupiah(_controller.text);
  int get _paid => _cash ? _cashReceived : widget.total;
  bool get _enough => _paid >= widget.total;

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    _panelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _select(PaymentMethod method) {
    if (widget.busy) return;
    setState(() => _method = method);
    if (method == PaymentMethod.cash) {
      _fieldFocus.requestFocus();
    } else {
      _panelFocus.requestFocus();
    }
  }

  void _setReceived(int amount) {
    final text = formatThousands(amount);
    _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    setState(() {});
    _fieldFocus.requestFocus();
  }

  void _submit() {
    if (_enough && !widget.busy) widget.onPay(_paid, _method);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (!widget.busy) widget.onBack();
      return KeyEventResult.handled;
    }
    // QRIS/Transfer: Enter pertama hanya memfokuskan "Sudah dibayar" (uang belum tentu masuk),
    // Enter kedua saat tombol terfokus baru mencatat. Di kolom uang ditangani onSubmitted.
    final enter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    final primary = FocusManager.instance.primaryFocus;
    if (enter && primary == _panelFocus) {
      _cash ? _submit() : _confirmFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (enter && primary == _confirmFocus) {
      _submit();
      return KeyEventResult.handled;
    }
    // Angka di kolom uang adalah isian, bukan pintasan.
    final inField = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (inField) return KeyEventResult.ignored;
    final method = switch (key) {
      LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => PaymentMethod.cash,
      LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => PaymentMethod.qris,
      LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => PaymentMethod.transfer,
      _ => null,
    };
    if (method == null) return KeyEventResult.ignored;
    _select(method);
    return KeyEventResult.handled;
  }

  String? get _reason {
    if (_enough || widget.busy) return null;
    return _cashReceived == 0 ? 'Isi uang diterima dulu' : 'Uang kurang ${formatRupiah(widget.total - _cashReceived)}';
  }

  Widget _methodOption(PaymentMethod method, int shortcut) {
    final c = context.stokas;
    final selected = _method == method;
    final fg = selected ? c.onPrimary : c.ink;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: method == PaymentMethod.transfer ? 0 : StokasSpace.s2),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? c.primary : c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StokasRadius.md),
              side: BorderSide(color: selected ? c.primary : c.lineStrong),
            ),
            child: InkWell(
              key: ValueKey('method-${method.code}'),
              borderRadius: BorderRadius.circular(StokasRadius.md),
              onTap: widget.busy ? null : () => _select(method),
              child: SizedBox(
                height: _quickCashHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected ? Icons.check_circle : paymentMethodIcon(method), size: 20, color: fg),
                    const SizedBox(width: StokasSpace.s1),
                    Flexible(
                      child: Text('${method.label} ($shortcut)', overflow: TextOverflow.ellipsis, style: StokasType.title.copyWith(color: fg)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickCash() {
    final options = [(const Key('quick-exact'), 'Uang pas', widget.total), for (final v in quickCashAmounts(widget.total)) (ValueKey('quick-$v'), formatRupiah(v), v)];
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: StokasSpace.s2),
        child: Row(
          children: [
            for (final (key, label, amount) in options.skip(i).take(2))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: StokasSpace.s2),
                  child: SizedBox(
                    height: _quickCashHeight,
                    child: StokasButton.secondary(key: key, label: label, expand: true, onPressed: widget.busy ? null : () => _setReceived(amount)),
                  ),
                ),
              ),
            if (options.length - i == 1) const Expanded(child: SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final reason = _reason;
    final change = _cash && _enough ? _paid - widget.total : 0;
    final label = widget.busy ? 'Memproses…' : (_cash ? 'Bayar ${formatRupiah(widget.total)}' : 'Sudah dibayar');

    return Focus(
      focusNode: _panelFocus,
      onKeyEvent: _onKey,
      child: Column(
        key: const Key('pay-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(StokasSpace.s2, StokasSpace.s2, StokasSpace.s4, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('pay-back'),
                  tooltip: 'Kembali ke keranjang (Esc)',
                  style: IconButton.styleFrom(minimumSize: const Size.square(StokasSpace.tapMin)),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.busy ? null : widget.onBack,
                ),
                const SizedBox(width: StokasSpace.s2),
                Expanded(child: Text('Pembayaran', style: StokasType.titleLg.copyWith(color: c.ink))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(StokasSpace.s4),
              children: [
                ?widget.header,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Total', style: StokasType.titleLg.copyWith(color: c.inkMuted)),
                    const SizedBox(width: StokasSpace.s3),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: MoneyText(widget.total, key: const Key('pay-total'), style: StokasType.displayL.copyWith(color: c.ink)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StokasSpace.s4),
                Text('Cara bayar', style: StokasType.label.copyWith(color: c.inkMuted)),
                const SizedBox(height: StokasSpace.s2),
                Row(children: [
                  _methodOption(PaymentMethod.cash, 1),
                  _methodOption(PaymentMethod.qris, 2),
                  _methodOption(PaymentMethod.transfer, 3),
                ]),
                const SizedBox(height: StokasSpace.s4),
                if (_cash) ...[
                  TextField(
                    key: const Key('paid-field'),
                    controller: _controller,
                    focusNode: _fieldFocus,
                    autofocus: true,
                    enabled: !widget.busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: StokasType.displayL.copyWith(color: c.ink),
                    decoration: const InputDecoration(labelText: 'Uang diterima', prefixText: 'Rp '),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: StokasSpace.s3),
                  _quickCash(),
                  const SizedBox(height: StokasSpace.s2),
                  Container(
                    padding: const EdgeInsets.all(StokasSpace.s4),
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      borderRadius: BorderRadius.circular(StokasRadius.lg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Kembalian', style: StokasType.titleLg.copyWith(color: c.inkMuted)),
                        const SizedBox(width: StokasSpace.s3),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: MoneyText(change, key: const Key('change-amount'), style: StokasType.displayL.copyWith(color: c.ink)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text('Uang diterima', style: StokasType.title.copyWith(color: c.inkMuted)),
                      const Spacer(),
                      MoneyText(widget.total, key: const Key('paid-exact'), style: StokasType.headline.copyWith(color: c.ink)),
                    ],
                  ),
                  const SizedBox(height: StokasSpace.s3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: c.inkMuted),
                      const SizedBox(width: StokasSpace.s2),
                      Expanded(
                        child: Text(
                          '${_method.label} dibayar pas sesuai total. Pastikan uang sudah masuk, lalu tekan "Sudah dibayar".',
                          style: StokasType.body.copyWith(color: c.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Padding(
              padding: const EdgeInsets.all(StokasSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.error != null) ...[
                    Container(
                      key: const Key('pay-error'),
                      padding: const EdgeInsets.all(StokasSpace.s3),
                      decoration: BoxDecoration(color: c.negativeSoft, borderRadius: BorderRadius.circular(StokasRadius.md)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: c.negative),
                          const SizedBox(width: StokasSpace.s2),
                          Expanded(child: Text(widget.error!, style: StokasType.title.copyWith(color: c.negative))),
                        ],
                      ),
                    ),
                    const SizedBox(height: StokasSpace.s3),
                  ],
                  StokasButton(
                    key: const Key('pay-confirm'),
                    focusNode: _confirmFocus,
                    label: label,
                    icon: _cash ? Icons.payments_outlined : Icons.check,
                    expand: true,
                    onPressed: _enough && !widget.busy ? _submit : null,
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: StokasSpace.s1),
                    Text(reason, key: const Key('pay-reason'), textAlign: TextAlign.center, style: StokasType.body.copyWith(color: c.inkMuted)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar selesai: kembalian sangat besar, ringkasan, "Unduh struk (PDF)", "Transaksi baru" (Enter).
class CheckoutDoneView extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onNewTransaction;
  final VoidCallback onDownload;

  const CheckoutDoneView({super.key, required this.transaction, required this.onNewTransaction, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final t = transaction;
    final label = StokasType.bodyLg.copyWith(color: c.inkMuted);
    final value = StokasType.title.copyWith(color: c.ink);

    Widget row(String name, Widget child) => Padding(
          padding: const EdgeInsets.symmetric(vertical: StokasSpace.s1),
          child: Row(children: [Expanded(child: Text(name, style: label)), child]),
        );

    return Center(
      key: const Key('checkout-done'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: payPanelWidth + StokasSpace.s8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(StokasSpace.s5),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: c.positive),
                const SizedBox(width: StokasSpace.s2),
                Flexible(child: Text('Transaksi berhasil', style: StokasType.titleLg.copyWith(color: c.ink))),
              ],
            ),
            const SizedBox(height: StokasSpace.s5),
            Text('Kembalian', textAlign: TextAlign.center, style: StokasType.titleLg.copyWith(color: c.inkMuted)),
            // Angka paling besar di layar: display-xl diperbesar mengikuti ruang, tetap muat di HP.
            SizedBox(
              height: StokasSpace.s8 * 2,
              child: FittedBox(
                child: MoneyText(t.changeAmount, key: const Key('done-change'), style: StokasType.displayXl.copyWith(color: c.ink)),
              ),
            ),
            const SizedBox(height: StokasSpace.s4),
            Divider(height: 1, color: c.line),
            const SizedBox(height: StokasSpace.s2),
            row('Total', MoneyText(t.totalAmount, style: value)),
            row('Diterima', MoneyText(t.paidAmount, style: value)),
            row('Cara bayar', PaymentMethodLabel(t.paymentMethod, style: value)),
            row('No. struk', Text(t.receiptNumber, key: const Key('done-receipt-no'), style: value)),
            row('Waktu', Text(formatWibDateTime(t.createdAt), style: value)),
            const SizedBox(height: StokasSpace.s5),
            StokasButton.secondary(
              key: const Key('download-receipt'),
              label: 'Unduh struk (PDF)',
              icon: Icons.download_outlined,
              expand: true,
              onPressed: onDownload,
            ),
            const SizedBox(height: StokasSpace.s3),
            StokasButton(
              key: const Key('new-transaction'),
              label: 'Transaksi baru',
              icon: Icons.add_shopping_cart,
              autofocus: true,
              expand: true,
              onPressed: onNewTransaction,
            ),
          ],
        ),
      ),
    );
  }
}
