import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/mood_log.dart';
import '../enums/mood_quadrant.dart';

class QuadrantDistributionChart extends StatelessWidget {
  final List<MoodLog> logs;

  const QuadrantDistributionChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _countByQuadrant();

    if (counts.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text('暂无数据', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sections: _buildSections(counts, total),
                centerSpaceRadius: 36,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final quad in MoodQuadrant.values)
                  _buildLegendItem(quad, counts[quad.name] ?? 0, total, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _countByQuadrant() {
    final map = <String, int>{};
    for (final log in logs) {
      final q = log.effectiveQuadrant;
      map[q] = (map[q] ?? 0) + 1;
    }
    return map;
  }

  List<PieChartSectionData> _buildSections(Map<String, int> counts, int total) {
    final sections = <PieChartSectionData>[];
    for (final quad in MoodQuadrant.values) {
      final count = counts[quad.name] ?? 0;
      if (count == 0) continue;
      final pct = (count / total * 100).toStringAsFixed(0);
      sections.add(PieChartSectionData(
        color: quad.color,
        value: count.toDouble(),
        title: '$pct%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        radius: 50,
      ));
    }
    return sections;
  }

  Widget _buildLegendItem(MoodQuadrant quad, int count, int total, ThemeData theme) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: quad.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${quad.label} $pct%',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
