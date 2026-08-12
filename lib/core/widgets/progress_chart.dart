import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

class ProgressPoint {
  const ProgressPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// A line chart of a single metric (e.g. top-set weight) over time.
class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
    ];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          // Left axis carries the metric (e.g. kg); the bottom axis labels the
          // first, middle, and last session dates. Top/right stay off.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final isEdgeOrMiddle = index == 0 ||
                    index == points.length - 1 ||
                    index == points.length ~/ 2;
                if (!isEdgeOrMiddle) return const SizedBox.shrink();
                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accentGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentGreen.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
