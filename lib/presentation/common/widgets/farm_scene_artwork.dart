import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum FarmArtworkVariant { welcome, field, crops, dashboard }

class FarmSceneArtwork extends StatelessWidget {
  const FarmSceneArtwork({
    super.key,
    this.height = 260,
    this.variant = FarmArtworkVariant.welcome,
    this.showFarmer = false,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(32),
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(24),
    ),
  });

  final double height;
  final FarmArtworkVariant variant;
  final bool showFarmer;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FarmScenePainter(
            variant: variant,
            showFarmer: showFarmer,
          ),
        ),
      ),
    );
  }
}

class _FarmScenePainter extends CustomPainter {
  const _FarmScenePainter({
    required this.variant,
    required this.showFarmer,
  });

  final FarmArtworkVariant variant;
  final bool showFarmer;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF8DD2FF),
          Color(0xFFC6EBFF),
          Color(0xFFEFF9FF),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    _drawCloud(canvas, Offset(size.width * 0.18, size.height * 0.18), size.width * 0.18);
    _drawCloud(canvas, Offset(size.width * 0.72, size.height * 0.12), size.width * 0.12);

    if (variant == FarmArtworkVariant.dashboard) {
      final Paint sunPaint = Paint()..color = AppColors.sunGold;
      canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), size.width * 0.08, sunPaint);
    }

    _drawHills(canvas, size);
    _drawPath(canvas, size);
    _drawHouse(canvas, Offset(size.width * 0.72, size.height * 0.54), size.width * 0.12);
    _drawTree(canvas, Offset(size.width * 0.15, size.height * 0.54), size.width * 0.10);

    if (variant == FarmArtworkVariant.crops) {
      _drawBananaPlant(canvas, size);
    }

    if (showFarmer) {
      _drawFarmer(canvas, size);
    }

    _drawForegroundLeaves(canvas, size);
  }

  void _drawHills(Canvas canvas, Size size) {
    final Paint backHill = Paint()..color = const Color(0xFF95D58A);
    final Paint midHill = Paint()..color = const Color(0xFF5FAA58);
    final Paint frontHill = Paint()..color = const Color(0xFF2F7A41);

    final Path back = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.48, size.width * 0.34, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.58, size.height * 0.70, size.width, size.height * 0.50)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, backHill);

    final Path middle = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.60, size.width * 0.52, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.74, size.height * 0.82, size.width, size.height * 0.66)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(middle, midHill);

    final Path front = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.74, size.width * 0.38, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.94, size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, frontHill);
  }

  void _drawPath(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..quadraticBezierTo(size.width * 0.52, size.height * 0.82, size.width * 0.58, size.height * 0.74)
      ..quadraticBezierTo(size.width * 0.64, size.height * 0.66, size.width * 0.72, size.height * 0.58);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF6E8BF);
    canvas.drawPath(path, paint);
  }

  void _drawHouse(Canvas canvas, Offset origin, double width) {
    final Paint wall = Paint()..color = Colors.white;
    final Paint roof = Paint()..color = const Color(0xFFC85C4E);
    final Paint outline = Paint()
      ..color = AppColors.primary.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Rect body = Rect.fromLTWH(origin.dx, origin.dy, width, width * 0.72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      wall,
    );
    final Path roofPath = Path()
      ..moveTo(origin.dx - 2, origin.dy + 4)
      ..lineTo(origin.dx + width * 0.50, origin.dy - width * 0.28)
      ..lineTo(origin.dx + width + 2, origin.dy + 4)
      ..close();
    canvas.drawPath(roofPath, roof);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + width * 0.42, origin.dy + width * 0.34, width * 0.18, width * 0.38),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8B5E3C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      outline,
    );
  }

  void _drawTree(Canvas canvas, Offset origin, double width) {
    final Paint trunk = Paint()..color = const Color(0xFF8B5E3C);
    final Paint leaves = Paint()..color = AppColors.leafGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + width * 0.38, origin.dy + width * 0.28, width * 0.14, width * 0.62),
        const Radius.circular(3),
      ),
      trunk,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(origin.dx + width * 0.46, origin.dy + width * 0.22), width: width, height: width * 0.84),
      leaves,
    );
  }

  void _drawBananaPlant(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.56, size.height * 0.54);
    final Paint stalk = Paint()..color = const Color(0xFF72B56A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 6, center.dy, 12, size.height * 0.26),
        const Radius.circular(6),
      ),
      stalk,
    );

    final Paint leaf = Paint()..color = const Color(0xFF2D9149);
    for (final double angle in <double>[-0.9, -0.42, 0.35, 0.88]) {
      final Path path = Path()..moveTo(center.dx, center.dy + 14);
      final double dx = math.cos(angle) * size.width * 0.18;
      final double dy = math.sin(angle) * size.height * 0.10;
      path.quadraticBezierTo(center.dx + dx * 0.6, center.dy + dy * 0.1, center.dx + dx, center.dy + dy);
      path.quadraticBezierTo(center.dx + dx * 0.55, center.dy + dy * 0.35, center.dx, center.dy + 14);
      canvas.drawPath(path, leaf);
    }

    final Paint fruit = Paint()..color = const Color(0xFFF2B638);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 18, center.dy + 48), width: 26, height: 38),
      fruit,
    );
  }

  void _drawFarmer(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.50, size.height * 0.66);
    final Paint skin = Paint()..color = const Color(0xFFC96F50);
    final Paint hat = Paint()..color = const Color(0xFFC85C62);
    final Paint shirt = Paint()..color = Colors.white;
    final Paint overalls = Paint()..color = const Color(0xFFF2B638);

    canvas.drawCircle(Offset(center.dx, center.dy - 66), 18, skin);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, center.dy - 78), width: 54, height: 18), hat);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 76), width: 44, height: 22),
      math.pi,
      math.pi,
      true,
      hat,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 8), width: 48, height: 72),
        const Radius.circular(14),
      ),
      shirt,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 6), width: 42, height: 64),
        const Radius.circular(14),
      ),
      overalls,
    );
    canvas.drawRect(Rect.fromLTWH(center.dx - 4, center.dy - 36, 8, 28), overalls);

    final Paint arm = Paint()
      ..color = const Color(0xFFC96F50)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    canvas.drawLine(Offset(center.dx - 26, center.dy - 12), Offset(center.dx - 44, center.dy + 16), arm);
    canvas.drawLine(Offset(center.dx + 26, center.dy - 14), Offset(center.dx + 50, center.dy + 8), arm);
    final Paint leg = Paint()
      ..color = const Color(0xFF4B2F25)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    canvas.drawLine(Offset(center.dx - 10, center.dy + 38), Offset(center.dx - 12, center.dy + 74), leg);
    canvas.drawLine(Offset(center.dx + 10, center.dy + 38), Offset(center.dx + 12, center.dy + 74), leg);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx + 56, center.dy + 2), width: 18, height: 34),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF303A48),
    );
  }

  void _drawForegroundLeaves(Canvas canvas, Size size) {
    final Paint leafPaint = Paint()..color = AppColors.leafGreen;
    for (final Offset origin in <Offset>[
      Offset(size.width * 0.06, size.height * 0.88),
      Offset(size.width * 0.88, size.height * 0.82),
      Offset(size.width * 0.18, size.height * 0.94),
    ]) {
      for (int i = 0; i < 3; i++) {
        final double dx = i * 10.0;
        final Path leaf = Path()..moveTo(origin.dx + dx, origin.dy);
        leaf.quadraticBezierTo(origin.dx + dx - 8, origin.dy - 18, origin.dx + dx + 2, origin.dy - 30);
        leaf.quadraticBezierTo(origin.dx + dx + 12, origin.dy - 18, origin.dx + dx, origin.dy);
        canvas.drawPath(leaf, leafPaint);
      }
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double width) {
    final Paint paint = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(center.translate(-width * 0.22, 0), width * 0.22, paint);
    canvas.drawCircle(center, width * 0.28, paint);
    canvas.drawCircle(center.translate(width * 0.24, 0), width * 0.20, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, width * 0.13), width: width * 0.9, height: width * 0.22),
        Radius.circular(width * 0.11),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FarmScenePainter oldDelegate) {
    return oldDelegate.variant != variant || oldDelegate.showFarmer != showFarmer;
  }
}
