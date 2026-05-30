import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/mood_log.dart';
import '../enums/mood_quadrant.dart';

class MoodScatterChart extends StatelessWidget {
  final List<MoodLog> logs;

  const MoodScatterChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final spotToLog = <ScatterSpot, MoodLog>{};
    final spots = _buildSpots(spotToLog);
    final theme = Theme.of(context);

    if (spots.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.scatter_plot, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text('暂无数据', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: spots,
          minX: -1.0,
          maxX: 1.0,
          minY: -1.0,
          maxY: 1.0,
          backgroundColor: Colors.transparent,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            horizontalInterval: 0.5,
            verticalInterval: 0.5,
            getDrawingHorizontalLine: (value) {
              if (value == 0) {
                return FlLine(color: Colors.grey.shade500, strokeWidth: 1.5);
              }
              return FlLine(color: Colors.grey.shade300, strokeWidth: 0.5);
            },
            getDrawingVerticalLine: (value) {
              if (value == 0) {
                return FlLine(color: Colors.grey.shade500, strokeWidth: 1.5);
              }
              return FlLine(color: Colors.grey.shade300, strokeWidth: 0.5);
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('能量', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 0.5,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('愉悦度', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 0.5,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          scatterTouchData: ScatterTouchData(
            enabled: true,
            touchTooltipData: ScatterTouchTooltipData(
              getTooltipColor: (spot) => theme.colorScheme.surface,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(10),
              getTooltipItems: (spot) {
                final log = spotToLog[spot];
                if (log == null) return null;
                final date =
                    '${log.createdAt.month}/${log.createdAt.day} ${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}';
                return ScatterTooltipItem(
                  '${log.effectiveEmotionWord}\n$date\n能量${log.effectiveEnergy.toStringAsFixed(1)} 愉悦${log.effectivePleasantness.toStringAsFixed(1)}',
                  textStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<ScatterSpot> _buildSpots(Map<ScatterSpot, MoodLog> spotToLog) {
    final spots = <ScatterSpot>[];
    for (final log in logs) {
      final e = log.effectiveEnergy;
      final p = log.effectivePleasantness;
      final quad = MoodQuadrant.fromEnergyPleasantness(e, p);
      final spot = ScatterSpot(
        p,
        e,
        dotPainter: FlDotCirclePainter(
          radius: 6,
          color: quad.color.withValues(alpha: 0.7),
        ),
      );
      spots.add(spot);
      spotToLog[spot] = log;
    }
    return spots;
  }
}
