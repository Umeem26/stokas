import 'package:flutter/material.dart';

import '../../data/transaction_model.dart';
import 'stokas_tokens.dart';

/// Ikon tetap per cara bayar (selalu dipasangkan dengan kata).
IconData paymentMethodIcon(PaymentMethod method) => switch (method) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.qris => Icons.qr_code_2,
      PaymentMethod.transfer => Icons.account_balance_outlined,
    };

/// Cara bayar sebagai ikon + kata ("Tunai", "QRIS", "Transfer"), bukan warna saja.
class PaymentMethodLabel extends StatelessWidget {
  final PaymentMethod method;
  final TextStyle? style;

  const PaymentMethodLabel(this.method, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final s = style ?? StokasType.body.copyWith(color: context.stokas.ink);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(paymentMethodIcon(method), size: (s.fontSize ?? StokasType.body.fontSize!) + StokasSpace.s1, color: s.color),
        const SizedBox(width: StokasSpace.s1),
        Text(method.label, style: s),
      ],
    );
  }
}
