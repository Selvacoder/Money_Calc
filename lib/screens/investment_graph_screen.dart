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
    final transactions = investmentProvider.transactions;
    final totalCurrent = investmentProvider.totalCurrentValue;

    // Highlights Calculations
    // 1. Top Performer
    final topPerformer = investments.isNotEmpty
        ? investments.reduce((a, b) {
            final profitA = a.currentAmount - a.investedAmount;
            final profitB = b.currentAmount - b.investedAmount;
            return profitA > profitB ? a : b;
          })
        : null;

    // 2. Monthly Invested
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final monthlyInvested = transactions
        .where(
          (t) =>
              t.type == 'buy' &&
              t.dateTime.isAfter(startOfMonth) &&
              t.dateTime.isBefore(now.add(const Duration(days: 1))),
        )
        .fold(0.0, (sum, t) => sum + t.amount);

    // 3. Largest Holding
    final largestHolding = investments.isNotEmpty
        ? investments.reduce(
            (a, b) => a.currentAmount > b.currentAmount ? a : b,
          )
        : null;

    // Group by Type for Chart
    final Map<String, double> typeTotals = {};
    for (var i in investments) {
      typeTotals[i.type] = (typeTotals[i.type] ?? 0) + i.currentAmount;
    }

    final sortedTypes = typeTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Summary',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Highlights Section
          if (investments.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. Top Performing Asset
                  if (topPerformer != null)
                    _buildHighlightCard(
                      context,
                      title: 'Top Performer',
                      value: topPerformer.name,
                      subtitle:
                          '${(topPerformer.currentAmount - topPerformer.investedAmount) >= 0 ? '+' : ''}$currencySymbol${(topPerformer.currentAmount - topPerformer.investedAmount).toStringAsFixed(0)}',
                      icon: Icons.emoji_events_outlined,
                      color: Colors.amber,
                    ),

                  // 2. Monthly Invested
                  _buildHighlightCard(
                    context,
                    title: 'Invested (Month)',
                    value:
                        '$currencySymbol${monthlyInvested.toStringAsFixed(0)}',
                    subtitle: 'Added this month',
                    icon: Icons.calendar_today_outlined,
                    color: Colors.blue,
                  ),

                  // 3. Largest Holding
                  if (largestHolding != null)
                    _buildHighlightCard(
                      context,
                      title: 'Largest Holding',
                      value: largestHolding.name,
                      subtitle:
                          '$currencySymbol${largestHolding.currentAmount.toStringAsFixed(0)}',
                      icon: Icons.pie_chart_outline,
                      color: Colors.purple,
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          Text(
            'Allocation',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          if (totalCurrent == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 48,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No assets to analyze',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Chart
                SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(200, 200),
                        painter: DonutChartPainter(
                          data: sortedTypes.map((e) => e.value).toList(),
                          colors: _getColors(sortedTypes.length, colorScheme),
                          total: totalCurrent,
                        ),
                      ),
                      Column(
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
                            '$currencySymbol${totalCurrent.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Legend
                ...sortedTypes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final percent = (data.value / totalCurrent) * 100;
                  final color = _getColors(
                    sortedTypes.length,
                    colorScheme,
                  )[index % 8];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currencySymbol${data.value.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${percent.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
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

  Widget _buildHighlightCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
