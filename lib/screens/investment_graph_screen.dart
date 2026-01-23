import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../providers/investment_provider.dart';
import '../providers/currency_provider.dart';

class InvestmentGraphScreen extends StatelessWidget {
  const InvestmentGraphScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final investmentProvider = context.watch<InvestmentProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final colorScheme = Theme.of(context).colorScheme;

    final investments = investmentProvider.investments;

    // Group by Type
    final Map<String, double> typeTotals = {};
    double totalValue = 0;

    for (var i in investments) {
      typeTotals[i.type] = (typeTotals[i.type] ?? 0) + i.currentAmount;
      totalValue += i.currentAmount;
    }

    final sortedTypes = typeTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asset Allocation',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          if (totalValue == 0)
            Center(
              child: Text(
                'No assets to analyze',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          else
            Column(
              children: [
                // Chart
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    size: const Size(200, 200),
                    painter: DonutChartPainter(
                      data: sortedTypes.map((e) => e.value).toList(),
                      colors: _getColors(sortedTypes.length, colorScheme),
                      total: totalValue,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$currencySymbol${totalValue.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Legend
                ...sortedTypes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final percent = (data.value / totalValue) * 100;
                  final color = _getColors(
                    sortedTypes.length,
                    colorScheme,
                  )[index % 6]; // 6 colors defined below

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          data.key, // Type
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$currencySymbol${data.value.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  List<Color> _getColors(int count, ColorScheme scheme) {
    return [
      scheme.primary,
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.teal,
      Colors.red,
      Colors.brown,
      Colors.indigo,
    ];
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  final double total;

  DonutChartPainter({
    required this.data,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = 20.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    double startAngle = -pi / 2;

    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = colors[i % colors.length];

      // Draw Arc
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
