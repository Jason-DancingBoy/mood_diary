import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/mood_log.dart';
import '../enums/mood_quadrant.dart';
import '../widgets/mood_scatter_chart.dart';
import '../widgets/quadrant_distribution_chart.dart';

enum AnalysisRange { week, month, all }

class MoodStatisticsPage extends StatefulWidget {
  final List<MoodLog> logs;

  const MoodStatisticsPage({super.key, required this.logs});

  @override
  State<MoodStatisticsPage> createState() => _MoodStatisticsPageState();
}

class _MoodStatisticsPageState extends State<MoodStatisticsPage> {
  AnalysisRange _range = AnalysisRange.week;

  List<MoodLog> get _filteredLogs {
    final now = DateTime.now();
    switch (_range) {
      case AnalysisRange.week:
        final cutoff = now.subtract(const Duration(days: 7));
        return widget.logs.where((l) => l.createdAt.isAfter(cutoff)).toList();
      case AnalysisRange.month:
        final cutoff = now.subtract(const Duration(days: 30));
        return widget.logs.where((l) => l.createdAt.isAfter(cutoff)).toList();
      case AnalysisRange.all:
        return widget.logs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('心情分析'),
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('暂无心情记录', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('快去记录心情吧', style: theme.textTheme.bodyMedium),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time filter
                  Center(
                    child: SegmentedButton<AnalysisRange>(
                      segments: const [
                        ButtonSegment(value: AnalysisRange.week, label: Text('近7天')),
                        ButtonSegment(value: AnalysisRange.month, label: Text('近30天')),
                        ButtonSegment(value: AnalysisRange.all, label: Text('全部')),
                      ],
                      selected: {_range},
                      onSelectionChanged: (s) => setState(() => _range = s.first),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Summary stats
                  _buildSummaryCard(logs, theme),
                  const SizedBox(height: 16),

                  // Scatter plot
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('情绪分布图', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('每个点代表一条心情记录', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 12),
                          MoodScatterChart(logs: logs),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final quad in MoodQuadrant.values)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: quad.color.withValues(alpha: 0.7),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(quad.label, style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quadrant distribution
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('象限分布', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          QuadrantDistributionChart(logs: logs),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trend chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('情绪趋势', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _buildTrendChart(logs, theme),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legendDot(Colors.orange.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              const Text('能量', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 16),
                              _legendDot(Colors.teal.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              const Text('愉悦度', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 2,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  Widget _buildSummaryCard(List<MoodLog> logs, ThemeData theme) {
    final totalRecords = logs.length;
    final days = <String>{};
    final quadCounts = <String, int>{};
    for (final log in logs) {
      days.add('${log.createdAt.year}-${log.createdAt.month}-${log.createdAt.day}');
      final q = log.effectiveQuadrant;
      quadCounts[q] = (quadCounts[q] ?? 0) + 1;
    }
    String dominant = '-';
    int maxCount = 0;
    for (final entry in quadCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }
    final quadLabel = {
      'red': '红色区',
      'yellow': '黄色区',
      'blue': '蓝色区',
      'green': '绿色区',
    }[dominant] ?? '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('总记录', '$totalRecords 条', theme),
            _statItem('记录天数', '${days.length} 天', theme),
            _statItem('主导象限', quadLabel, theme),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTrendChart(List<MoodLog> logs, ThemeData theme) {
    if (logs.length < 2) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('需要至少两条记录来显示趋势', style: theme.textTheme.bodySmall),
        ),
      );
    }

    // Sort by date
    final sorted = List<MoodLog>.from(logs)..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Build spots
    final energySpots = <FlSpot>[];
    final pleasantnessSpots = <FlSpot>[];

    for (int i = 0; i < sorted.length; i++) {
      energySpots.add(FlSpot(i.toDouble(), sorted[i].effectiveEnergy));
      pleasantnessSpots.add(FlSpot(i.toDouble(), sorted[i].effectivePleasantness));
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: -1.0,
          maxY: 1.0,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 0.5,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              if (value == 0) return FlLine(color: Colors.grey.shade500, strokeWidth: 1.5);
              return FlLine(color: Colors.grey.shade300, strokeWidth: 0.5);
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 0.5,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 16,
                interval: (sorted.length / 5).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sorted.length) return const SizedBox.shrink();
                  final d = sorted[idx].createdAt;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${d.month}/${d.day}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: energySpots,
              isCurved: true,
              color: Colors.orange.withValues(alpha: 0.7),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              dashArray: [5, 3],
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              spots: pleasantnessSpots,
              isCurved: true,
              color: Colors.teal.withValues(alpha: 0.7),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => theme.colorScheme.surface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final dateStr = idx >= 0 && idx < sorted.length
                      ? '${sorted[idx].createdAt.month}/${sorted[idx].createdAt.day}'
                      : '';
                  final isEnergy = spot.barIndex == 0;
                  return LineTooltipItem(
                    '${isEnergy ? "能量" : "愉悦"}: ${spot.y.toStringAsFixed(1)}\n$dateStr',
                    TextStyle(
                      color: isEnergy ? Colors.orange : Colors.teal,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
