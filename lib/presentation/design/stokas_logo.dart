import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum StokasLogoVariant {
  /// Tanda S saja (koin + kotak).
  mark,

  /// Tanda + nama "Stokas".
  lockup,
}

/// Logo Stokas dari assets/brand apa adanya. Versi `-reverse` dipakai otomatis di tema gelap.
/// Ukuran terkecil yang sudah diuji: tanda 16 px, lockup tinggi 32 px.
class StokasLogo extends StatelessWidget {
  final StokasLogoVariant variant;
  final double height;

  const StokasLogo({super.key, this.variant = StokasLogoVariant.mark, this.height = 32});

  const StokasLogo.lockup({super.key, this.height = 32}) : variant = StokasLogoVariant.lockup;

  static String assetFor(StokasLogoVariant variant, Brightness brightness) {
    final name = variant == StokasLogoVariant.mark ? 'stokas-mark' : 'stokas-logo';
    return 'assets/brand/$name${brightness == Brightness.dark ? '-reverse' : ''}.svg';
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetFor(variant, Theme.of(context).brightness),
      height: height,
      semanticsLabel: 'Stokas',
    );
  }
}
