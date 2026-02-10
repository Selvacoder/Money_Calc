import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StarterGuide extends StatefulWidget {
  final List<GlobalKey> targetKeys;
  final Function(int)? onStepChanged;
  final VoidCallback onFinish;

  const StarterGuide({
    super.key,
    required this.targetKeys,
    this.onStepChanged,
    required this.onFinish,
  });

  @override
  State<StarterGuide> createState() => _StarterGuideState();
}

class _StarterGuideState extends State<StarterGuide> {
  int _currentStep = 0;

  final List<Map<String, String>> _guideData = [
    {
      'title': 'Personal Mode',
      'description':
          'Track your daily expenses, manage categories, and see your personal balance at a glance.',
    },
    {
      'title': 'Ledger Mode',
      'description':
          'Manage debts and credits with friends. Record transactions and set due date reminders.',
    },
    {
      'title': 'Investment Mode',
      'description':
          'Monitor your stocks and crypto portfolio. Get AI-powered insights for smarter growth.',
    },
    {
      'title': 'Go Dutch Mode',
      'description':
          'Perfect for split bills and group trips. Settle up shared expenses effortlessly.',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_guide', true);
    widget.onFinish();
  }

  void _nextStep() {
    if (_currentStep < _guideData.length - 1) {
      setState(() => _currentStep++);
      widget.onStepChanged?.call(_currentStep);
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.targetKeys.isEmpty || _currentStep >= widget.targetKeys.length) {
      return const SizedBox.shrink();
    }

    final targetKey = widget.targetKeys[_currentStep];
    final RenderBox? renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
      return const SizedBox.shrink();
    }

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark Cutout Background
          GestureDetector(
            onTap: _nextStep,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.85),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: position.dx - 6,
                    top: position.dy - 6,
                    child: Container(
                      width: size.width + 12,
                      height: size.height + 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          size.height / 2 + 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tooltip/Description Box (Positioned BELOW the highlight)
          Positioned(
            left: 20,
            right: 20,
            top: position.dy + size.height + 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Upward Arrow
                Padding(
                  padding: EdgeInsets.only(
                    left: (position.dx + size.width / 2) - 40,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CustomPaint(
                      painter: ArrowPainter(color: Colors.white, isUp: true),
                      size: const Size(20, 10),
                    ).animate().fadeIn(delay: 300.ms),
                  ),
                ),
                Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getIconForStep(_currentStep),
                                  color: Theme.of(context).primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _guideData[_currentStep]['title']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _guideData[_currentStep]['description']!,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_currentStep + 1} / ${_guideData.length}',
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _nextStep,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _currentStep == _guideData.length - 1
                                      ? 'Got it!'
                                      : 'Next',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fade(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),

          // Skip Button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Center(
              child: InkWell(
                onTap: _completeOnboarding,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Skip Onboarding',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForStep(int step) {
    switch (step) {
      case 0:
        return Icons.person_rounded;
      case 1:
        return Icons.menu_book_rounded;
      case 2:
        return Icons.trending_up_rounded;
      case 3:
        return Icons.groups_rounded;
      default:
        return Icons.help_outline;
    }
  }
}

class ArrowPainter extends CustomPainter {
  final Color color;
  final bool isUp;
  ArrowPainter({required this.color, this.isUp = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
