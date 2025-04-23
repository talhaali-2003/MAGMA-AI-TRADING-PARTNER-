class StockState {
  static final StockState _instance = StockState._internal();
  factory StockState() => _instance;
  StockState._internal();

  String? selectedSymbol;
  String? selectedTimeframe;
  String? cachedAnalysis;
  List<dynamic>? cachedStockData;
  Map<String, dynamic>? cachedForecast;

  void setStock(String symbol, String timeframe) {
    selectedSymbol = symbol;
    selectedTimeframe = timeframe;
  }

  void setAnalysis(String analysis) {
    cachedAnalysis = analysis;
  }

  void setStockData(List<dynamic> data) {
    cachedStockData = data;
  }

  void setForecast(Map<String, dynamic> forecast) {
    cachedForecast = forecast;
  }

  void clearStock() {
    selectedSymbol = null;
    selectedTimeframe = null;
    cachedAnalysis = null;
    cachedStockData = null;
    cachedForecast = null;
  }
} 