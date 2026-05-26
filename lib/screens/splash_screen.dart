import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseOne;
  late Animation<double> _pulseTwo;
  late Animation<double> _loaderAlign;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _pulseOne = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _pulseTwo = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOut),
      ),
    );

    _loaderAlign = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;

    return Scaffold(
      body: Stack(
        children: [
          // Elegant decorative network grids (recreating CSS phone background)
          Positioned.fill(
            child: CustomPaint(
              painter: _NetworkGridPainter(
                cyanColor: pn.cyan.withOpacity(0.12),
                accentColor: pn.accent.withOpacity(0.08),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Concentric Animated Splash Orbit
                    SizedBox(
                      height: 200,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulse Circle 2 (Outer Accent Orange pulse)
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final opacity = (1.0 - (_pulseTwo.value - 0.8) / 0.45).clamp(0.0, 1.0);
                              return Transform.scale(
                                scale: _pulseTwo.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: pn.accent.withOpacity(opacity * 0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Pulse Circle 1 (Inner Cyan pulse)
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final opacity = (1.0 - (_pulseOne.value - 0.8) / 0.4).clamp(0.0, 1.0);
                              return Transform.scale(
                                scale: _pulseOne.value,
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: pn.cyan.withOpacity(opacity * 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Signal diagonal lines
                          CustomPaint(
                            size: const Size(180, 180),
                            painter: _SignalLinesPainter(color: pn.cyan.withOpacity(0.25)),
                          ),
                          // Central Power Core (Soft Glass)
                          Container(
                            width: 106,
                            height: 106,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: pn.cyan.withOpacity(0.45),
                                width: 1.5,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  pn.surface,
                                  Color.lerp(pn.softCyan, pn.surface, 0.3)!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pn.cyan.withOpacity(0.2),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(42, 42),
                                painter: _PowerSymbolPainter(color: pn.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Logo text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'POWER',
                          style: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: pn.text,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Text(
                          'NET',
                          style: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: pn.accent,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Future of Connectivity & Beyond',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: pn.textSoft,
                      ),
                    ),
                    const SizedBox(height: 36),
                    
                    // Network Live status box
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Color.lerp(pn.surface, pn.softCyan, 0.4),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: pn.border),
                        boxShadow: [
                          BoxShadow(
                            color: pn.text.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Network Status',
                                style: TextStyle(
                                  color: pn.textSoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: pn.softGreen,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: pn.success.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: pn.cyan,
                                        boxShadow: [
                                          BoxShadow(
                                            color: pn.cyan,
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Live',
                                      style: TextStyle(
                                        color: pn.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: pn.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: pn.border.withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Signal',
                                        style: TextStyle(
                                          color: pn.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Stable',
                                        style: TextStyle(
                                          color: pn.text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: pn.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: pn.border.withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sync',
                                        style: TextStyle(
                                          color: pn.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ready',
                                        style: TextStyle(
                                          color: pn.text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Connecting services progress line
                    Text(
                      'Connecting services...',
                      style: TextStyle(
                        fontSize: 12,
                        color: pn.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Animated keyframe-like loader
                    Container(
                      width: 148,
                      height: 4,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: pn.cyan.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment(_loaderAlign.value, 0.0),
                            child: Container(
                              width: 60,
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: [pn.accent, pn.cyan],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkGridPainter extends CustomPainter {
  final Color cyanColor;
  final Color accentColor;

  _NetworkGridPainter({required this.cyanColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Glowing circle in upper top-left
    paint.color = cyanColor;
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.06), 180, paint);

    // Glowing circle in upper top-right
    paint.color = accentColor;
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), 240, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignalLinesPainter extends CustomPainter {
  final Color color;

  _SignalLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Diagonal signal lines running through the orbit
    canvas.drawLine(
      const Offset(15, 45),
      const Offset(165, 90),
      paint,
    );
    canvas.drawLine(
      const Offset(15, 135),
      const Offset(165, 90),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PowerSymbolPainter extends CustomPainter {
  final Color color;

  _PowerSymbolPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw broken circle arc (open at top)
    const startAngle = -math.pi / 2 + 0.5; // Starts slightly right of top
    const sweepAngle = 2 * math.pi - 1.0;  // Sweeps almost all way around
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Draw central vertical line protruding out
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Line with subtle outer glow
    canvas.drawLine(
      Offset(center.dx, center.dy - 18),
      Offset(center.dx, center.dy + 4),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

