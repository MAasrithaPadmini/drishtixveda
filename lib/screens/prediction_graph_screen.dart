import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PredictionGraphScreen extends StatelessWidget {
  final List<FlSpot> historySpots;
  final List<FlSpot> futureSpots;

  const PredictionGraphScreen({
    super.key,
    required this.historySpots,
    required this.futureSpots,
  });

  LineChartData buildChart() {
    // ✅ SAFE CHECK
    if (historySpots.isEmpty && futureSpots.isEmpty) {
      return LineChartData();
    }

    final allSpots = [...historySpots, ...futureSpots];

    double minY = allSpots
        .map((e) => e.y)
        .reduce((a, b) => a < b ? a : b);

    double maxY = allSpots
        .map((e) => e.y)
        .reduce((a, b) => a > b ? a : b);

    // ✅ SAFE DIVIDER
    double dividerX =
    historySpots.isNotEmpty ? historySpots.last.x : 0;

    // ✅ SAFE RANGE
    double range = (maxY - minY);
    double padding =
    range == 0 ? maxY * 0.02 : range * 0.2;

    return LineChartData(
      minY: minY - padding,
      maxY: maxY + padding,

      // 🔥 GRID
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          );
        },
      ),

      borderData: FlBorderData(show: true),

      // ================= TOOLTIP =================
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.black,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              return LineTooltipItem(
                "₹${spot.y.toStringAsFixed(2)}",
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),

      // ================= TITLES =================
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: historySpots.length / 4,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              if (value < dividerX) {
                return const Text("Past",
                    style: TextStyle(
                        color: Colors.grey, fontSize: 10));
              } else {
                return const Text("Future",
                    style: TextStyle(
                        color: Colors.green, fontSize: 10));
              }
            },
          ),
        ),

        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: (range == 0) ? 1 : (range / 4),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),

        rightTitles:
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),

      // ================= DIVIDER =================
      extraLinesData: ExtraLinesData(
        verticalLines: [
          VerticalLine(
            x: dividerX,
            color: Colors.white38,
            strokeWidth: 2,
            dashArray: [5, 5],
            label: VerticalLineLabel(
              show: true,
              labelResolver: (line) => "Prediction Start",
              style: const TextStyle(
                  color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),

      // ================= LINES =================
      lineBarsData: [
        // 🔵 HISTORY
        LineChartBarData(
          spots: historySpots,
          isCurved: true,
          curveSmoothness: 0.15,
          color: Colors.blue,
          barWidth: 3,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),

        // 🟢 PREDICTION
        LineChartBarData(
          spots: futureSpots,
          isCurved: true,
          curveSmoothness: 0.15,
          color: Colors.green,
          barWidth: 3,
          dashArray: [6, 4],
          dotData: FlDotData(show: false),
        ),

        // 🔼 UPPER BAND
        LineChartBarData(
          spots: futureSpots
              .map((e) => FlSpot(e.x, e.y * 1.02))
              .toList(),
          isCurved: true,
          color: Colors.green.withOpacity(0.3),
          barWidth: 1,
          dotData: FlDotData(show: false),
        ),

        // 🔽 LOWER BAND
        LineChartBarData(
          spots: futureSpots
              .map((e) => FlSpot(e.x, e.y * 0.98))
              .toList(),
          isCurved: true,
          color: Colors.red.withOpacity(0.3),
          barWidth: 1,
          dotData: FlDotData(show: false),
        ),
      ],
    );
  }

  // ================= LEGEND =================
  Widget _legend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Prediction Graph"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: LineChart(buildChart())),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend("History", Colors.blue),
                const SizedBox(width: 12),
                _legend("Prediction", Colors.green),
                const SizedBox(width: 12),
                _legend("Confidence",
                    Colors.green.withOpacity(0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}