import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Live input level as a row of rounded bars, newest on the right.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.levels, this.height = 56, this.bars = 48});

  final List<double> levels;
  final double height;
  final int bars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WaveformPainter(levels: levels, bars: bars)),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.levels, required this.bars});

  final List<double> levels;
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / bars;
    final barWidth = slot * 0.55;
    final paint = Paint()..strokeCap = StrokeCap.round;
    // Right-align the samples we have; pad the left with silence.
    final offset = bars - levels.length;

    for (var i = 0; i < bars; i++) {
      final level = i >= offset ? levels[i - offset].clamp(0.0, 1.0) : 0.0;
      final barHeight = (size.height * (0.08 + 0.92 * level)).clamp(barWidth, size.height);
      final x = slot * i + slot / 2;
      paint
        ..color = level > 0 ? AppColors.accent : AppColors.border
        ..strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2),
        Offset(x, (size.height + barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.levels != levels;
}
