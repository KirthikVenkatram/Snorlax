import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

class DayValue {
  const DayValue({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// A bar chart of one value per day (e.g. calories) against a flat goal
/// line, for the last N days.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.days, this.goal});

  final List<DayValue> days;

  /// Optional reference line (e.g. the calorie goal) drawn across the chart.
  final double? goal;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final maxValue = [
      ...days.map((d) => d.value),
      ?goal,
    ].reduce((a, b) => a > b ? a : b);
    final chartMax = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return BarChart(
      BarChartData(
        maxY: chartMax,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= days.length) return const SizedBox.shrink();
                const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final date = days[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    weekdays[date.weekday - 1],
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].value,
                  color: AppColors.accentGreen,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        extraLinesData: goal == null
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goal!,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
              ),
      ),
    );
  }
}
