import 'package:flutter/material.dart';

import '../design/stokas_tokens.dart';
import 'account_menu_button.dart';

/// Pengganti sementara untuk layar yang belum dibangun.
class SegeraHadirView extends StatelessWidget {
  final String title;

  const SegeraHadirView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [AccountMenuButton()]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(StokasSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: StokasSpace.s8, color: c.inkMuted),
              const SizedBox(height: StokasSpace.s3),
              Text("Segera hadir", style: StokasType.titleLg.copyWith(color: c.ink)),
              const SizedBox(height: StokasSpace.s1),
              Text("Layar $title sedang disiapkan.", textAlign: TextAlign.center, style: StokasType.body.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
