import 'package:flutter/material.dart';
import 'package:flutter_magma/AIDashboard.dart';
import 'widgets/appbar.dart';
import 'package:flutter_magma/services/market_stack_service.dart';
import 'package:flutter_magma/models/stock.dart';
import 'package:flutter_magma/services/stock_state.dart';

/// Displays a browsable list of available stocks with search capability.

/// Serves as the main entry point after login where users select
/// which stock they want to analyze before seeing the detailed dashboard.
class StockSelectionPage extends StatefulWidget {
  const StockSelectionPage({super.key});

  @override
  State<StockSelectionPage> createState() => _StockSelectionPageState();
}

class _StockSelectionPageState extends State<StockSelectionPage> {
  // Service to fetch stock data from MarketStack API
  final MarketStackService _marketStackService = MarketStackService();
  final TextEditingController _searchController = TextEditingController();
  // Available timeframes for stock data analysis
  final List<String> timeframes = ["15min", "1W", "1M", "YTD"];

  // Stock data management
  List<Stock> _stocks = [];
  List<Stock> _filteredStocks = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTopStocks();
  }

  /// Fetches popular stocks to populate the initial view
  /// Shows loading indicator during fetch and handles any errors
  Future<void> _loadTopStocks() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      final stocks = await _marketStackService.getTopStocks();
      setState(() {
        _stocks = stocks;
        _filteredStocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stocks: $e';
        _isLoading = false;
      });
    }
  }

  /// Filters stock list as user types in the search box
  /// Makes API call to find matching stocks when query isn't empty
  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredStocks = _stocks;
      });
      return;
    }
    try {
      final searchResults = await _marketStackService.searchStocks(query);
      setState(() {
        _filteredStocks = searchResults;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
      });
    }
  }

  /// Pops up options for different data timeframes (15min, 1W, 1M, YTD)
  void _showTimeframeSelection(BuildContext context, String symbol) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "⚠️ Today's data may not be available until after market close.",
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Wrap(
                children: timeframes.map((timeframe) {
                  return ListTile(
                    title: Text(
                      timeframe,
                      style: theme.textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      StockState().clearStock();
                      StockState().setStock(symbol, timeframe);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AiDashboard(
                            symbol: symbol,
                            timeframe: timeframe,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final canvasColor = theme.canvasColor;
    final dividerColor = theme.dividerColor;
    final accentColor = theme.colorScheme.secondary;
    final primaryTextColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          "MAGMA",
          style: theme.textTheme.titleLarge?.copyWith(
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
            colors: [bgColor, canvasColor],
          ),
        ),
        child: Column(
          children: [
            // Search bar container
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor.withOpacity(0.3)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    border: InputBorder.none,
                    hintText: 'Search stocks...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor.withOpacity(0.7),
                    ),
                    prefixIcon: Icon(Icons.search, color: dividerColor),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            // Error message display
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: accentColor),
                ),
              ),
            // Main content area
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: accentColor),
                    )
                  : _filteredStocks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, color: dividerColor, size: 60),
                              const SizedBox(height: 16),
                              Text(
                                "No stocks found",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Try a different search term",
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _filteredStocks.length,
                          itemBuilder: (context, index) {
                            final stock = _filteredStocks[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 6.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bgColor.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: dividerColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () =>
                                        _showTimeframeSelection(context, stock.symbol),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  stock.symbol,
                                                  style: TextStyle(
                                                    color: primaryTextColor,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  stock.name,
                                                  style: TextStyle(
                                                    color: secondaryTextColor,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            stock.exchange,
                                            style: TextStyle(
                                              color: accentColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: theme.copyWith(canvasColor: bgColor),
        child: const AppBarWidget(selectedIndex: 0),
      ),
    );
  }

  @override
  void dispose() {
    // Cleans up search field controller when screen closes
    _searchController.dispose();
    super.dispose();
  }
}
