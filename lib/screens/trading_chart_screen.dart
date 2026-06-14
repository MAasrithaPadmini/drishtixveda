import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/candle.dart';

class TradingChartScreen extends StatefulWidget {
  final int token;
  final String symbol;
  final String exchange;
  final String interval;

  const TradingChartScreen({
    super.key,
    required this.token,
    required this.symbol,
    required this.exchange,
    this.interval = "1D",
  });

  @override
  State<TradingChartScreen> createState() => _TradingChartScreenState();
}

class _TradingChartScreenState extends State<TradingChartScreen> {
  final String baseUrl = "https://api.drishtixveda.com";

  List<Candle> candles = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCandles();
  }

  @override
  void didUpdateWidget(covariant TradingChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      loadCandles();
    }
  }

  // ================= LOAD DATA =================
  Future<void> loadCandles() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await http.get(Uri.parse(
        "$baseUrl/candles?token=${widget.token}&exchange=${widget.exchange}&interval=${widget.interval}",
      ));

      if (res.statusCode != 200) {
        throw Exception("Server error");
      }

      final decoded = jsonDecode(res.body);

      if (decoded is! List) {
        throw Exception("Invalid candle data");
      }

      setState(() {
        candles = decoded.map<Candle>((e) => Candle.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      print("CANDLE ERROR: $e");

      setState(() {
        loading = false;
        error = "Failed to load chart";
      });
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.symbol),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
        child: Text(
          error!,
          style: const TextStyle(color: Colors.red),
        ),
      )
          : Column(
        children: [
          // 🔥 INTERVAL SELECTOR (PREMIUM)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ["1D", "5D", "1M", "3M"].map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(e),
                    selected: widget.interval == e,
                    onSelected: (_) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TradingChartScreen(
                            token: widget.token,
                            symbol: widget.symbol,
                            exchange: widget.exchange,
                            interval: e,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 🔥 CHART
          Expanded(
            child: SfCartesianChart(
              backgroundColor: const Color(0xFF0D1117),

              zoomPanBehavior: ZoomPanBehavior(
                enablePinching: true,
                enablePanning: true,
                enableDoubleTapZooming: true,
              ),

              trackballBehavior: TrackballBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                tooltipDisplayMode:
                TrackballDisplayMode.groupAllPoints,
              ),

              primaryXAxis: DateTimeAxis(
                majorGridLines:
                const MajorGridLines(width: 0.2),
                axisLine: const AxisLine(color: Colors.grey),
              ),

              primaryYAxis: NumericAxis(
                majorGridLines:
                const MajorGridLines(width: 0.2),
                axisLine: const AxisLine(color: Colors.grey),
              ),

              series: <CandleSeries<Candle, DateTime>>[
                CandleSeries<Candle, DateTime>(
                  dataSource: candles,

                  xValueMapper: (c, _) => c.time,
                  openValueMapper: (c, _) => c.open,
                  highValueMapper: (c, _) => c.high,
                  lowValueMapper: (c, _) => c.low,
                  closeValueMapper: (c, _) => c.close,

                  bullColor: Colors.green,
                  bearColor: Colors.red,

                  // 🔥 PREMIUM TOUCH
                  animationDuration: 800,
                  enableSolidCandles: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}