import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The graduation-cap mark from the app icon, drawn in code.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Education ERP',
      child: SizedBox.square(dimension: size, child: CustomPaint(painter: _CapPainter())),
    );
  }
}

class _CapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(7 * s)),
      Paint()..color = AppColors.brand,
    );
    final top = Path()
      ..moveTo(6 * s, 12.5 * s)
      ..lineTo(16 * s, 7 * s)
      ..lineTo(26 * s, 12.5 * s)
      ..lineTo(16 * s, 18 * s)
      ..close();
    canvas.drawPath(top, Paint()..color = Colors.white);
    final band = Path()
      ..moveTo(10 * s, 15.5 * s)
      ..lineTo(10 * s, 20.5 * s)
      ..cubicTo(10 * s, 22.2 * s, 12.7 * s, 24 * s, 16 * s, 24 * s)
      ..cubicTo(19.3 * s, 24 * s, 22 * s, 22.2 * s, 22 * s, 20.5 * s)
      ..lineTo(22 * s, 15.5 * s)
      ..lineTo(16 * s, 18.8 * s)
      ..close();
    canvas.drawPath(band, Paint()..color = AppColors.brandSoft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
