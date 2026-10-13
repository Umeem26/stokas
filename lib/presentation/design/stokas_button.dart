import 'package:flutter/material.dart';

import 'stokas_tokens.dart';

enum StokasButtonVariant {
  /// Aksi utama (Bayar, Simpan). Satu per layar.
  primary,

  /// Aksi pendukung (Batal).
  secondary,

  /// Aksi yang menghapus (Hapus barang); selalu diikuti konfirmasi.
  danger,
}

/// Tombol Stokas: tinggi minimal tap-min (48), label kata kerja, cincin fokus 2 px `focus`
/// berjarak 2 px yang tidak pernah dihilangkan (kasir PC memakai keyboard/scanner).
class StokasButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed; // null = nonaktif
  final StokasButtonVariant variant;
  final IconData? icon;
  final bool expand; // selebar wadah
  final FocusNode? focusNode;
  final bool autofocus;

  const StokasButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StokasButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  });

  const StokasButton.secondary({super.key, required this.label, required this.onPressed, this.icon, this.expand = false, this.focusNode, this.autofocus = false})
      : variant = StokasButtonVariant.secondary;

  const StokasButton.danger({super.key, required this.label, required this.onPressed, this.icon, this.expand = false, this.focusNode, this.autofocus = false})
      : variant = StokasButtonVariant.danger;

  @override
  State<StokasButton> createState() => _StokasButtonState();
}

class _StokasButtonState extends State<StokasButton> {
  bool _focused = false;

  ButtonStyle _style(StokasColors c) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.md));
    const minSize = WidgetStatePropertyAll(Size(StokasSpace.tapMin, StokasSpace.tapMin));
    const padding = WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: StokasSpace.s5));
    final text = WidgetStatePropertyAll(StokasType.title);

    WidgetStateProperty<Color> resolve(Color enabled, Color disabled) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? disabled : enabled);

    switch (widget.variant) {
      case StokasButtonVariant.primary:
        return ButtonStyle(
          minimumSize: minSize,
          padding: padding,
          textStyle: text,
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
          foregroundColor: resolve(c.onPrimary, c.inkMuted),
          iconColor: resolve(c.onPrimary, c.inkMuted),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return c.surfaceSunken;
            if (s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)) return c.primaryHover;
            return c.primary;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        );
      case StokasButtonVariant.secondary:
      case StokasButtonVariant.danger:
        final accent = widget.variant == StokasButtonVariant.danger ? c.negative : c.ink;
        final border = widget.variant == StokasButtonVariant.danger ? c.negative : c.lineStrong;
        return ButtonStyle(
          minimumSize: minSize,
          padding: padding,
          textStyle: text,
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
          foregroundColor: resolve(accent, c.inkMuted),
          iconColor: resolve(accent, c.inkMuted),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered) ? c.surfaceSunken : c.surface,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.disabled) ? c.line : border),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final child = widget.icon == null
        ? Text(widget.label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20),
              const SizedBox(width: StokasSpace.s2),
              Flexible(child: Text(widget.label)),
            ],
          );

    final style = _style(c);
    Widget button = widget.variant == StokasButtonVariant.primary
        ? FilledButton(
            onPressed: widget.onPressed,
            style: style,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            onFocusChange: (f) => setState(() => _focused = f),
            child: child,
          )
        : OutlinedButton(
            onPressed: widget.onPressed,
            style: style,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            onFocusChange: (f) => setState(() => _focused = f),
            child: child,
          );
    if (widget.expand) button = SizedBox(width: double.infinity, child: button);

    // Cincin fokus digambar di luar tombol (offset 2 px) tanpa mengubah tata letak.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (_focused)
          Positioned.fill(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('stokasFocusRing'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StokasRadius.md + 4),
                  border: Border.all(color: c.focus, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
