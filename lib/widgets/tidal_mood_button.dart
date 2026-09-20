import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Map pleasantness (-1..1) to background gradient colors.
/// High pleasantness → warm pink/peach tones
/// Low pleasantness → cool blue/indigo tones
({Color c1, Color c2}) _pleasantnessColors(double? pleasantness) {
  final p = (pleasantness ?? 0).clamp(-1.0, 1.0);
  if (p >= 0) {
    final t = p;
    return (
      c1: Color.lerp(const Color(0xFFC8B8E8), const Color(0xFFFFD0D8), t)!,
      c2: Color.lerp(const Color(0xFFC0C8F0), const Color(0xFFC0D8FF), t)!,
    );
  } else {
    final t = -p;
    return (
      c1: Color.lerp(const Color(0xFFC8B8E8), const Color(0xFFA8C0D8), t)!,
      c2: Color.lerp(const Color(0xFFC0C8F0), const Color(0xFFB8A8D8), t)!,
    );
  }
}

/// Map pleasantness to wave gradient colors.
({Color c1, Color c2}) _waterColors(double? pleasantness) {
  final p = (pleasantness ?? 0).clamp(-1.0, 1.0);
  if (p >= 0) {
    final t = p;
    return (
      c1: Color.lerp(const Color(0xFF7C4DFF), const Color(0xFFFF8FB0), t)!,
      c2: Color.lerp(const Color(0xFF448AFF), const Color(0xFF7C4DFF), t)!,
    );
  } else {
    final t = -p;
    return (
      c1: Color.lerp(const Color(0xFF7C4DFF), const Color(0xFF1A237E), t)!,
      c2: Color.lerp(const Color(0xFF448AFF), const Color(0xFF4527A0), t)!,
    );
  }
}

/// CustomPainter that renders the tidal mood button interior:
/// rounded rect background → heart clip → dual wave layers.
class TidalMoodPainter extends CustomPainter {
  final double waterLevel;    // 0.0–1.0, driven by energy
  final double wavePhase1;    // first wave layer horizontal offset (0–2π)
  final double wavePhase2;    // second wave layer horizontal offset
  final double amplitudeMultiplier; // press feedback: 1.0 normal, 1.5 pressed
  final Color bgColor1;       // background gradient start
  final Color bgColor2;       // background gradient end
  final Color waterColor1;    // wave layer 1 color
  final Color waterColor2;    // wave layer 2 color

  TidalMoodPainter({
    required this.waterLevel,
    required this.wavePhase1,
    required this.wavePhase2,
    this.amplitudeMultiplier = 1.0,
    required this.bgColor1,
    required this.bgColor2,
    required this.waterColor1,
    required this.waterColor2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.233), // 28/120
    );

    // 1. Draw background rounded rect with gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgColor1, bgColor2],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, bgPaint);

    // 2. Draw pen icon between background and heart
    final iconText = String.fromCharCode(Icons.edit.codePoint);
    final textPainter = TextPainter(
      text: TextSpan(
        text: iconText,
        style: TextStyle(
          fontSize: size.width * 0.78,
          fontFamily: Icons.edit.fontFamily,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    // 3. Build heart path centered in the rect
    final heartPath = _buildHeartPath(size);

    // 4. Draw the full heart filled with red (above-water portion)
    final heartPaint = Paint()
      ..color = const Color(0xFFFF80AB)
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, heartPaint);

    // 5. Clip to heart path, then draw wave layers on top (below-water portion)
    canvas.save();
    canvas.clipPath(heartPath);
    _drawWave(canvas, size, wavePhase1, waterColor1, 0.0);
    _drawWave(canvas, size, wavePhase2, waterColor2, 12.0);
    canvas.restore();
  }

  Path _buildHeartPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 3; // slight downward adjust for visual balance
    final s = size.width / 130 * 0.92;
    final path = Path();
    path.moveTo(cx, cy + (-10) * s);
    path.cubicTo(cx + (-34) * s, cy + (-40) * s, cx + (-56) * s, cy + (-4) * s, cx + (-28) * s, cy + 18 * s);
    path.cubicTo(cx + (-10) * s, cy + 34 * s, cx, cy + 46 * s, cx, cy + 46 * s);
    path.cubicTo(cx, cy + 46 * s, cx + 10 * s, cy + 34 * s, cx + 28 * s, cy + 18 * s);
    path.cubicTo(cx + 56 * s, cy + (-4) * s, cx + 34 * s, cy + (-40) * s, cx, cy + (-10) * s);
    path.close();
    return path;
  }

  void _drawWave(Canvas canvas, Size size, double phase, Color color, double yOffset) {
    final baseY = size.height * (1.0 - waterLevel) + yOffset;
    final amplitude = size.height * 0.08 * amplitudeMultiplier;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      final y = baseY + amplitude * math.sin(normalizedX * 2 * math.pi * 1.3 + phase);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TidalMoodPainter oldDelegate) {
    return oldDelegate.waterLevel != waterLevel ||
        oldDelegate.wavePhase1 != wavePhase1 ||
        oldDelegate.wavePhase2 != wavePhase2 ||
        oldDelegate.amplitudeMultiplier != amplitudeMultiplier ||
        oldDelegate.bgColor1 != bgColor1 ||
        oldDelegate.bgColor2 != bgColor2 ||
        oldDelegate.waterColor1 != waterColor1 ||
        oldDelegate.waterColor2 != waterColor2;
  }
}

class TidalMoodButton extends StatefulWidget {
  final double? energy;
  final double? pleasantness;
  final bool compact;
  final VoidCallback onPressed;

  const TidalMoodButton({
    super.key,
    this.energy,
    this.pleasantness,
    this.compact = false,
    required this.onPressed,
  });

  @override
  State<TidalMoodButton> createState() => _TidalMoodButtonState();
}

class _TidalMoodButtonState extends State<TidalMoodButton>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _waveController;
  late AnimationController _ebbController;
  late Animation<double> _breatheAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _ebbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onPressed();
      }
    });

    _breatheAnim = CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _waveController.dispose();
    _ebbController.dispose();
    super.dispose();
  }

  double get _waterLevel {
    final e = widget.energy;
    if (e == null) return 0.5;
    return ((e.clamp(-1.0, 1.0) + 1.0) / 2.0 * 0.8 + 0.1).clamp(0.1, 0.9);
  }

  /// 退潮过程中水位下沉到 0.1，动画结束后再触发 onPressed。
  double get _effectiveWaterLevel {
    final base = _waterLevel;
    if (_ebbController.isAnimating) {
      return base * (1 - _ebbController.value) + 0.1 * _ebbController.value;
    }
    return base;
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
      _ebbController.reset();
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _ebbController.forward(from: 0);
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 100.0 : 120.0;
    final borderRadius = widget.compact ? 24.0 : 28.0;
    final bgColors = _pleasantnessColors(widget.pleasantness);
    final wColors = _waterColors(widget.pleasantness);

    // 按压反馈：波速翻倍、振幅放大
    final speedMultiplier = _isPressed ? 2.0 : 1.0;
    final amplitudeMultiplier = _isPressed ? 1.5 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breatheAnim, _waveController, _ebbController]),
        builder: (context, _) {
          final scale = 1.0 + _breatheAnim.value * 0.08;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: bgColors.c1.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: 0,
                  ),
                  // 两层随呼吸脉动的扩散环，形成光晕
                  BoxShadow(
                    color: bgColors.c1.withValues(alpha: 0.05),
                    blurRadius: 0,
                    spreadRadius: 8 * (1 + _breatheAnim.value * 0.5),
                  ),
                  BoxShadow(
                    color: bgColors.c1.withValues(alpha: 0.03),
                    blurRadius: 0,
                    spreadRadius: 18 * (1 + _breatheAnim.value * 0.33),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CustomPaint(
                  painter: TidalMoodPainter(
                    waterLevel: _effectiveWaterLevel,
                    wavePhase1: _waveController.value * 2 * math.pi * 1.2 * speedMultiplier,
                    wavePhase2: _waveController.value * 2 * math.pi * 0.857 * speedMultiplier + math.pi / 3,
                    amplitudeMultiplier: amplitudeMultiplier,
                    bgColor1: bgColors.c1,
                    bgColor2: bgColors.c2,
                    waterColor1: wColors.c1,
                    waterColor2: wColors.c2,
                  ),
                  size: Size(size, size),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
