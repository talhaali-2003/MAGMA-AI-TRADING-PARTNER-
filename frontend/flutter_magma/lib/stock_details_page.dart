import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Page to show stock details fetched from backend
class StockDetailsPage extends StatefulWidget {
  final String symbol;
  final String timeframe;

  const StockDetailsPage({
    super.key,
    required this.symbol,
    required this.timeframe,
  });

  @override
  State<StockDetailsPage> createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> {
  List<StockData> stockData = [];
  bool hasError = false;

  // Called when the page loads
  @override
  void initState() {
    super.initState();
    debugPrint("StockDetailsPage Loaded with: ${widget.symbol}, ${widget.timeframe}");
    fetchStockData();
  }

  // Fetches stock data from the backend using symbol and timeframe
  Future<void> fetchStockData() async {
    final url = "http://10.0.2.2:5000/visualization_intent?symbol=${widget.symbol}&timeframe=${widget.timeframe}";
    debugPrint("Fetching data from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String jsonString = response.body.replaceAll(":NaN", ":null");
        List<dynamic> data = json.decode(jsonString);

        setState(() {
          stockData = data.map((item) => StockData.fromJson(item, widget.timeframe)).toList();
          hasError = stockData.isEmpty;
        });

        if (stockData.isEmpty) {
          debugPrint("Error: No valid stock data available.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No valid stock data available')),
          );
        }
      } else {
        throw Exception('Failed to load stock data');
      }
    } catch (e) {
      debugPrint("Error fetching stock data: $e");
      setState(() => hasError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching stock data: $e')),
      );
    }
  }

  // Basic UI to show loading, error or success message
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} - ${widget.timeframe}'),
      ),
      body: Center(
        child: hasError
            ? const Text('Error loading stock data')
            : stockData.isEmpty
                ? const CircularProgressIndicator()
                : Text('Stock data loaded: ${stockData.length} points'),
      ),
    );
  }
}

// Class to store a single stock data point
class StockData {
  final DateTime date;
  final double open, high, low, close;
  final double? volume, adjHigh, adjLow, adjClose, adjOpen, adjVolume, splitFactor, dividend;

  // Constructor used for end-of-day data
  StockData.eod({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.adjHigh,
    this.adjLow,
    this.adjClose,
    this.adjOpen,
    this.adjVolume,
    this.splitFactor,
    this.dividend,
  });

  // Constructor used for intraday (15min) data
  StockData.intraday({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  })  : volume = null,
        adjHigh = null,
        adjLow = null,
        adjClose = null,
        adjOpen = null,
        adjVolume = null,
        splitFactor = null,
        dividend = null;

  // Factory method to parse stock data JSON based on timeframe
  factory StockData.fromJson(Map<String, dynamic> json, String timeframe) {
    DateTime parsedDate;
    try {
      if (timeframe == "15min") {
        parsedDate = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", "en_US").parse(json['date']);
      } else {
        parsedDate = DateTime.parse(json['date']);
      }
    } catch (e) {
      debugPrint("Error parsing date: ${json['date']} - $e");
      throw FormatException("Invalid date format: ${json['date']}");
    }

    if (timeframe == "15min") {
      return StockData.intraday(
        date: parsedDate,
        open: json['open'].toDouble(),
        high: json['high'].toDouble(),
        low: json['low'].toDouble(),
        close: json['close'].toDouble(),
      );
    } else {
      return StockData.eod(
        date: parsedDate,
        open: json['open'].toDouble(),
        high: json['high'].toDouble(),
        low: json['low'].toDouble(),
        close: json['close'].toDouble(),
        volume: json['volume']?.toDouble(),
        adjHigh: json['adj_high']?.toDouble(),
        adjLow: json['adj_low']?.toDouble(),
        adjClose: json['adj_close']?.toDouble(),
        adjOpen: json['adj_open']?.toDouble(),
        adjVolume: json['adj_volume']?.toDouble(),
        splitFactor: json['split_factor']?.toDouble(),
        dividend: json['dividend']?.toDouble(),
      );
    }
  }
}
