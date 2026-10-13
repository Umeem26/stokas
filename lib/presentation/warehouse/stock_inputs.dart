import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/jakarta_time.dart';
import '../design/stokas_tokens.dart';

/// Baca isian jumlah ("12", "1,5", "1.5"); null bila bukan angka.
num? parseQty(String text) => num.tryParse(text.trim().replaceAll(',', '.'));

/// Stepper jumlah: tombol -/+ 48 px dan kolom angka yang bisa diketik (scanner/keyboard).
class QtyStepper extends StatefulWidget {
  final num value;
  final ValueChanged<num> onChanged;
  final Key? fieldKey;

  const QtyStepper({super.key, required this.value, required this.onChanged, this.fieldKey});

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  late final _controller = TextEditingController(text: formatQty(widget.value));

  @override
  void didUpdateWidget(QtyStepper old) {
    super.didUpdateWidget(old);
    // Nilai berubah dari luar (scan ulang, tombol -/+): samakan isian tanpa menimpa ketikan yang sama nilainya.
    if ((parseQty(_controller.text) ?? 0) != widget.value) _controller.text = formatQty(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(num delta) {
    final next = widget.value + delta;
    if (next < 1) return;
    _controller.text = formatQty(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size.square(StokasSpace.tapMin),
      side: BorderSide(color: c.lineStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.md)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: buttonStyle,
          icon: Icon(Icons.remove, color: c.ink),
          tooltip: 'Kurangi',
          onPressed: widget.value > 1 ? () => _step(-1) : null,
        ),
        const SizedBox(width: StokasSpace.s2),
        SizedBox(
          width: StokasSpace.s8 + StokasSpace.s5,
          child: TextField(
            key: widget.fieldKey,
            controller: _controller,
            textAlign: TextAlign.center,
            style: StokasType.title.copyWith(color: c.ink),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: StokasSpace.s3)),
            onChanged: (text) => widget.onChanged(parseQty(text) ?? 0),
          ),
        ),
        const SizedBox(width: StokasSpace.s2),
        IconButton(
          style: buttonStyle,
          icon: Icon(Icons.add, color: c.ink),
          tooltip: 'Tambah',
          onPressed: () => _step(1),
        ),
      ],
    );
  }
}

/// Pilihan lantai (Lantai 1 / Lantai 2), tinggi 48 px.
class FloorPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const FloorPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return SegmentedButton<String>(
      segments: [for (final f in storeFloors) ButtonSegment(value: f, label: Text(f))],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, StokasSpace.tapMin),
        textStyle: StokasType.label,
        foregroundColor: c.ink,
        selectedForegroundColor: c.onPrimary,
        selectedBackgroundColor: c.primary,
        side: BorderSide(color: c.lineStrong),
      ),
    );
  }
}

/// Tanggal kedaluwarsa opsional: tombol date picker + "Hapus tanggal"; galat ditulis di bawahnya.
class ExpiryField extends StatelessWidget {
  final DateTime? value;
  final DateTime today; // hari ini (WIB) untuk tanggal awal picker
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;
  final Key? buttonKey;

  const ExpiryField({super.key, required this.value, required this.today, required this.onChanged, this.errorText, this.buttonKey});

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 10),
      helpText: 'Tanggal kedaluwarsa',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: buttonKey,
                onPressed: () => _pick(context),
                icon: Icon(Icons.event_outlined, color: hasError ? c.negative : c.inkMuted),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value == null ? 'Kedaluwarsa (opsional)' : 'Kedaluwarsa ${formatDayId(value!)}',
                    style: StokasType.body.copyWith(color: value == null ? c.inkMuted : c.ink),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, StokasSpace.tapMin),
                  side: BorderSide(color: hasError ? c.negative : c.lineStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StokasRadius.md)),
                ),
              ),
            ),
            if (value != null)
              IconButton(
                icon: Icon(Icons.close, color: c.inkMuted),
                tooltip: 'Hapus tanggal',
                onPressed: () => onChanged(null),
              ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: StokasSpace.s1),
          FieldError(errorText!),
        ],
      ],
    );
  }
}

/// Pesan galat kecil: ikon + kata, warna negative.
class FieldError extends StatelessWidget {
  final String message;

  const FieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 16, color: c.negative),
        const SizedBox(width: StokasSpace.s1),
        Expanded(child: Text(message, style: StokasType.caption.copyWith(color: c.negative))),
      ],
    );
  }
}
