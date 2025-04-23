import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'widgets/appbar.dart';
import 'services/stock_state.dart';
import 'stock_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiDashboard extends StatefulWidget {
  final String? symbol;
  final String? timeframe;

  const AiDashboard({super.key, this.symbol, this.timeframe});

  @override
  State<AiDashboard> createState() => _AiDashboardState();
}

class _AiDashboardState extends State<AiDashboard> {
  // Stuff for stock price and market data display
  List<StockData> stockData = [];
  String analysisResult = "";
  bool hasError = false;
  bool isLoading = true;

  // Variables for our price predictions
  String forecastSymbol = "";
  String forecastDate = "";
  double forecastPrice = 0.0;
  bool isForecastLoading = true;
  bool hasForecastError = false;

  // Tracks if current stock is in user's favorites
  bool isFavorite = false;

  // Connects to our global stock info across screens
  final StockState stockState = StockState();

  // Keeps the logged-in user's email handy
  String? userEmail;

  @override
  void initState() {
    super.initState();

    // Load user email from local storage
    getUserEmail().then((email) {
      if (email != null) {
        setState(() {
          userEmail = email;
        });
        // If symbol and timeframe were provided, checks if it's already a favorite
        if (widget.symbol != null && widget.timeframe != null) {
          checkFavorite(widget.symbol!, widget.timeframe!);
        }
      }
    });

    // If constructor had symbol andtimeframe, stores it in StockState
    if (widget.symbol != null && widget.timeframe != null) {
      stockState.setStock(widget.symbol!, widget.timeframe!);
    }

    // If StockState has a valid symbol, fetchs data
    if (stockState.selectedSymbol != null) {
      fetchStockData();
      fetchAIAnalysis();
      fetchForecastData();
    }
  }

  /// Grabs the logged in user's email from local storage
  Future<String?> getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("userEmail");
  }

  /// Adds or removes a stock from user's favorites list like a toggle switch
  Future<void> toggleFavorite(String symbol, String timeframe) async {
    String? email = await getUserEmail();
    if (email == null) {
      debugPrint("Error: No user email found for toggling favorite.");
      return;
    }

    final url = "http://10.0.2.2:5000/toggle_favorite";
    final body = jsonEncode({
      "user_email": email,
      "symbol": symbol,
      "timeframe": timeframe,
    });

    debugPrint("Toggling favorite for $symbol ($timeframe) - Email: $email");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          isFavorite = !isFavorite;
        });
        debugPrint(isFavorite
            ? "$symbol added to favorites"
            : "$symbol removed from favorites");
      } else {
        debugPrint("Failed to toggle favorite: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
    }
  }

  /// Looks up if the stock we're viewing is saved in user's favorites already
  Future<void> checkFavorite(String symbol, String timeframe) async {
    String? email = await getUserEmail();
    if (email == null) {
      debugPrint("Error: No user email found.");
      return;
    }
    final url =
        "http://10.0.2.2:5000/check_favorite?email=$email&symbol=$symbol&timeframe=$timeframe";
    debugPrint("Checking favorite status: $url");

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isFavorite = data["is_favorite"] ?? false;
        });
      } else {
        debugPrint("Failed to fetch favorite status: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error checking favorite: $e");
    }
  }

  /// Pulls in stock price data from our server. Gets OHLC values for charts
  Future<void> fetchStockData() async {
    final symbol = widget.symbol ?? stockState.selectedSymbol;
    final timeframe = widget.timeframe ?? stockState.selectedTimeframe;
    if (symbol == null || timeframe == null) return;

    // If we have cached data, this uses it first
    if (stockState.cachedStockData != null) {
      if (!mounted) return;
      setState(() {
        stockData = stockState.cachedStockData!
            .map((item) => StockData.fromJson(item, timeframe))
            .toList();
        hasError = stockData.isEmpty;
        isLoading = false;
      });
      // fetches fresh data in the background
      _fetchFreshStockData(symbol, timeframe);
      return;
    }

    // fetches fresh data from the server otherwise
    await _fetchFreshStockData(symbol, timeframe);
  }

  /// Gets the latest stock data directly from our backend API
  Future<void> _fetchFreshStockData(String symbol, String timeframe) async {
    final url =
        "http://10.0.2.2:5000/visualization_intent?symbol=$symbol&timeframe=$timeframe";
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final jsonString = response.body.replaceAll(":NaN", ":null");
        final List<dynamic> data = json.decode(jsonString);
        // Caches this data in StockState
        stockState.setStockData(data);
        setState(() {
          stockData = data.map((item) => StockData.fromJson(item, timeframe)).toList();
          hasError = stockData.isEmpty;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load stock data");
      }
    } catch (e) {
      debugPrint("Error fetching stock data: $e");
      if (!mounted) return;
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  /// Grabs the AI powered technical analysis from our server
  Future<void> fetchAIAnalysis() async {
    final symbol = widget.symbol ?? stockState.selectedSymbol;
    final timeframe = widget.timeframe ?? stockState.selectedTimeframe;
    if (symbol == null || timeframe == null) return;

    // Uses cached analysis if it’s for the same stock/timeframe
    if (stockState.cachedAnalysis != null &&
        symbol == stockState.selectedSymbol &&
        timeframe == stockState.selectedTimeframe) {
      setState(() {
        analysisResult = stockState.cachedAnalysis!;
      });
    }

    await _fetchFreshAnalysis(symbol, timeframe);
  }

  /// Forces an update of the AI analysis instead of using cached data
  Future<void> _fetchFreshAnalysis(String symbol, String timeframe) async {
    final url =
        "http://10.0.2.2:5000/ai_analysis_intent?symbol=$symbol&timeframe=$timeframe";
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final analysis = json.decode(response.body)["analysis"];
        stockState.setAnalysis(analysis);
        setState(() {
          analysisResult = analysis;
        });
      }
    } catch (e) {
      debugPrint("Error fetching AI analysis: $e");
      if (!mounted) return;
      setState(() => analysisResult = "Error fetching AI analysis.");
    }
  }

  /// Loads our AI price prediction for the next trading day
  Future<void> fetchForecastData() async {
    final symbol = widget.symbol ?? stockState.selectedSymbol;
    final timeframe = widget.timeframe ?? stockState.selectedTimeframe;
    if (symbol == null || timeframe == null) {
      if (!mounted) return;
      setState(() {
        hasForecastError = true;
        isForecastLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      isForecastLoading = true;
      hasForecastError = false;
    });

    final url = "http://10.0.2.2:5000/forecast?symbol=$symbol&timeframe=$timeframe";
    debugPrint("Fetching forecast data from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint("Forecast response status: ${response.statusCode}");
      debugPrint("Forecast response body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey("error")) {
          throw Exception(data["error"]);
        }
        setState(() {
          forecastSymbol = data["symbol"] ?? "";
          forecastDate = data["date"] ?? "";
          forecastPrice = (data["predicted_price"] ?? 0.0).toDouble();
          isForecastLoading = false;
          hasForecastError = false;
        });
        debugPrint("Forecast data loaded: $forecastSymbol, $forecastDate, $forecastPrice");
      } else {
        throw Exception("Failed to load forecast data");
      }
    } catch (e) {
      debugPrint("Error fetching forecast data: $e");
      if (!mounted) return;
      setState(() {
        hasForecastError = true;
        isForecastLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching forecast data: $e')),
      );
    }
  }

  /// Cleans up duplicate candles that sometimes show up in 15min stock data
  List<StockData> _removeConsecutiveDuplicates(List<StockData> data) {
    if (data.isEmpty) return [];
    final cleaned = <StockData>[data.first];
    for (int i = 1; i < data.length; i++) {
      final prev = cleaned.last;
      final current = data[i];
      if (current.open != prev.open ||
          current.high != prev.high ||
          current.low != prev.low ||
          current.close != prev.close) {
        cleaned.add(current);
      }
    }
    return cleaned;
  }

  /// Creates the chart series for our candlestick display and trend lines
  List<CartesianSeries<dynamic, dynamic>> _getChartSeries() {
    final is15Min = widget.timeframe == "15min";
    var displayData = stockData;
    if (is15Min) {
      displayData = _removeConsecutiveDuplicates(displayData);
    }

    return [
      // Candlestick series
      CandleSeries<StockData, DateTime>(
        dataSource: displayData,
        xValueMapper: (StockData data, _) => data.date,
        lowValueMapper: (StockData data, _) => data.low,
        highValueMapper: (StockData data, _) => data.high,
        openValueMapper: (StockData data, _) => data.open,
        closeValueMapper: (StockData data, _) => data.close,
        bearColor: const Color(0xFFFF3B30),  // Keep red for downward
        bullColor: const Color(0xFF00C805),  // Keep green for upward
        enableSolidCandles: true,
      ),
      // Simple line on top of candlesticks
      LineSeries<StockData, DateTime>(
        dataSource: displayData,
        xValueMapper: (StockData data, _) => data.date,
        yValueMapper: (StockData data, _) => data.close,
        color: const Color(0xFF1E90FF).withOpacity(0.7),
      ),
    ];
  }

  /// Builds the main scaffold
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkBackground = theme.scaffoldBackgroundColor;
    final canvasColor = theme.canvasColor;
    final primaryText = theme.textTheme.bodyLarge?.color ?? Colors.white;

    final symbol = widget.symbol ?? stockState.selectedSymbol;
    final timeframe = widget.timeframe ?? stockState.selectedTimeframe;

    // If no symbol/timeframe selected, prompts the user to go to stock selection
    if (symbol == null || timeframe == null) {
      return Scaffold(
        backgroundColor: darkBackground,
        appBar: AppBar(
          backgroundColor: darkBackground,
          title: Text(
            'MAGMA',
            style: TextStyle(
              color: primaryText,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryText),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const StockSelectionPage()),
              );
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Please select a stock',
                style: TextStyle(color: primaryText, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const StockSelectionPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: primaryText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Go to Stock Selection'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: theme.copyWith(canvasColor: darkBackground),
          child: const AppBarWidget(selectedIndex: 1),
        ),
      );
    }

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        title: Text(
          'MAGMA',
          style: TextStyle(
            color: primaryText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkBackground, canvasColor],
          ),
        ),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.secondary,
                ),
              )
            : hasError
                ? Center(
                    child: Text(
                      "Error loading data",
                      style: TextStyle(
                        color: theme.colorScheme.secondary.withOpacity(0.8),
                        fontSize: 18,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStockCard(context),
                        const SizedBox(height: 24),
                        _buildForecastCard(context),
                        const SizedBox(height: 24),
                        _buildStockChartCard(context),
                        const SizedBox(height: 24),
                        _buildAIAnalysisCard(context),
                        const SizedBox(height: 24),
                        _buildStockDefinitions(context),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: Theme(
        data: theme.copyWith(canvasColor: darkBackground),
        child: const AppBarWidget(selectedIndex: 1),
      ),
    );
  }

  /// Makes the top info card with stock ticker, timeframe selector, and favorite button
  Widget _buildStockCard(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final accentRed = theme.colorScheme.secondary;
    final cardColor = theme.cardColor.withOpacity(0.5);

    final symbol = widget.symbol ?? stockState.selectedSymbol;
    final timeframe = widget.timeframe ?? stockState.selectedTimeframe;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textSecondary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    symbol ?? 'Select Stock',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => toggleFavorite(symbol!, timeframe!),
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? accentRed : textSecondary,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Timeframe: $timeframe',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Displays our AI powered price prediction for the next trading day
  Widget _buildForecastCard(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final accentRed = theme.colorScheme.secondary;
    final cardColor = theme.cardColor.withOpacity(0.5);
    final darkerColor = theme.cardColor;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isForecastLoading ? 0.0 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textSecondary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Next Day Opening Price",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isForecastLoading)
              Center(child: CircularProgressIndicator(color: accentRed))
            else if (hasForecastError)
              Center(
                child: Text(
                  "Error loading forecast data",
                  style: TextStyle(
                    color: accentRed.withOpacity(0.8),
                    fontSize: 18,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "\$${forecastPrice.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: accentRed,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$forecastSymbol - $forecastDate",
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: darkerColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: textSecondary.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF1E90FF), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Forecasts are based on End-of-Day (EOD) prices and 15-minute intraday data. "
                            "Predictions are generated using historical trends and may not always reflect real-time market movements. "
                            "Use this data as a reference point, not as a definitive trading signal.",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Creates the interactive stock chart with candlesticks and price data
  Widget _buildStockChartCard(BuildContext context) {
    final theme = Theme.of(context);
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final primaryText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final background = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textSecondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Price Chart",
            style: TextStyle(
              color: primaryText,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 400,
            child: SfCartesianChart(
              backgroundColor: Colors.transparent,
              plotAreaBorderWidth: 0,
              primaryXAxis: DateTimeAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: AxisLine(color: textSecondary),
                labelStyle: TextStyle(color: primaryText, fontSize: 14),
                edgeLabelPlacement: EdgeLabelPlacement.shift,
                intervalType: widget.timeframe == "15min"
                    ? DateTimeIntervalType.minutes
                    : DateTimeIntervalType.days,
                interval: widget.timeframe == "15min" ? 15 : null,
                dateFormat: widget.timeframe == "15min"
                    ? DateFormat.jm()
                    : DateFormat.MMMd(),
                maximumLabels: widget.timeframe == "15min" ? 6 : 10,
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                minorGridLines: const MinorGridLines(width: 0),
                axisLine: AxisLine(color: textSecondary),
                labelStyle: TextStyle(color: primaryText, fontSize: 14),
                numberFormat: NumberFormat.compact(),
              ),
              zoomPanBehavior: ZoomPanBehavior(
                enablePanning: true,
                enablePinching: true,
                enableSelectionZooming: true,
                zoomMode: ZoomMode.xy,
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: background,
                textStyle: TextStyle(color: primaryText),
                borderWidth: 0,
                elevation: 0,
              ),
              series: _getChartSeries(),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the AI's technical analysis of the current stock in a readable format
  Widget _buildAIAnalysisCard(BuildContext context) {
    final theme = Theme.of(context);
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final primaryText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final cardColor = theme.cardColor.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textSecondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: primaryText),
              const SizedBox(width: 8),
              Text(
                "AI Analysis",
                style: TextStyle(
                  color: primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAnalysisContent(context),
        ],
      ),
    );
  }

  /// Breaks down the AI analysis into readable chunks with proper formatting
  Widget _buildAnalysisContent(BuildContext context) {
    final theme = Theme.of(context);
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final accentRed = theme.colorScheme.secondary;

    if (analysisResult.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: accentRed),
      );
    }
    // For demonstration, we assume the AI analysis is split by \n\n sections
    final sections = analysisResult.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        final lines = section.split('\n');
        if (lines.isEmpty) return const SizedBox();
        final title = lines.first.replaceAll(':', '');
        final content = lines.skip(1).join('\n');
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.trim(),
                style: TextStyle(
                  color: accentRed,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content.trim(),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Shows explanations of technical terms used in the analysis for beginner investors
  Widget _buildStockDefinitions(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final textSecondary = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final cardColor = theme.cardColor.withOpacity(0.5);

    final Map<String, String> terms = {
      'SMA': 'Simple Moving Average — Stock\'s average price over a time to identify trends.',
      'EMA': 'Exponential Moving Average — Similar to SMA but reacts faster to recent changes.',
      'RSI': 'Relative Strength Index — Indicates if stock is overbought (above 70) or oversold (below 30).',
      'MACD': 'Measures trend strength and momentum shifts via moving averages.',
      'Fibonacci': 'Fibonacci Retracement — Identifies key price points where a stock may reverse.',
      'ATR': 'Average True Range — Measures volatility / daily price movement.',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textSecondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: textPrimary),
              const SizedBox(width: 8),
              Text(
                "Stock Market Terms",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: terms.entries.map((entry) {
              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: theme.cardColor,
                        title: Text(
                          entry.key,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          entry.value,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Close',
                              style: TextStyle(color: theme.colorScheme.secondary),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: textSecondary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.secondary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Our custom data model for holding stock candle data which is optimized for charts
class StockData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;
  final double? adjHigh;
  final double? adjLow;
  final double? adjClose;
  final double? adjOpen;
  final double? adjVolume;
  final double? splitFactor;
  final double? dividend;

  // EOD constructor
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

  // Intraday constructor
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

  factory StockData.fromJson(Map<String, dynamic> json, String timeframe) {
    DateTime parsedDate;
    try {
      if (timeframe == "15min") {
        parsedDate = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", "en_US")
            .parse(json['date']);
      } else {
        // EOD data is typically in ISO8601
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
