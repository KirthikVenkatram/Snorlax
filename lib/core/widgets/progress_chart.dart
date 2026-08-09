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
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
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
