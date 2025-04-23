import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock.dart';

// Service class to handle all MarketStack API calls
class MarketStackService {
  // Grab the API key from the .env file
  static final String _apiKey = dotenv.env['MARKETSTACK_API_KEY'] ?? '';
  static const String _baseUrl = 'api.marketstack.com';

  // Manually blocked symbols that cause problems or are not U.S. based
  static const List<String> _manualBlocklist = [
    'SGLRF', 'SPYR', 'OTCM', 'TD', 'RY', 'BNS', 'BMO', 'SHOP.TO',
    'CM.TO', 'ENB.TO', 'SU.TO', 'TRP.TO', 'CNQ.TO', 'T.TO',
    'BCE.TO', 'MFC.TO', 'BAM.TO', 'GWO.TO', 'SLF.TO',
    'FB', 'MTLFF', 'HEMED'
  ];

  // Helper function to filter out invalid or non-U.S. tickers
  bool _isValidUSSymbol(String symbol) {
    return !symbol.contains('.') &&
           !symbol.contains(':') &&
           !_manualBlocklist.contains(symbol.toUpperCase());
  }

  // Fetch top stocks from MarketStack and filter them for U.S. use
  Future<List<Stock>> getTopStocks() async {
    if (_apiKey.isEmpty) {
      throw Exception("MarketStack API Key is missing! Check .env file.");
    }

    try {
      final uri = Uri.https(_baseUrl, '/v1/tickers', {
        'access_key': _apiKey,
        'limit': '50',
      });

      final response = await http.get(uri);
      print('[DEBUG] Response Status: ${response.statusCode}');

      // If API call is successful
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stocksData = data['data'] as List;

        print('[DEBUG] Total stocks returned: ${stocksData.length}');

        // Filter out invalid names and symbols
        final filtered = stocksData.where((stock) {
          final name = stock['name'];
          final symbol = stock['symbol'];
          final valid = name != null && name.toString().isNotEmpty && _isValidUSSymbol(symbol);

          if (!valid) {
            if (_manualBlocklist.contains(symbol.toUpperCase())) {
              print('[BLOCKLISTED] $symbol (name=$name)');
            } else {
              print('[FILTERED OUT] $symbol (name=$name)');
            }
          }

          return valid;
        }).map((stock) => Stock.fromJson(stock)).toList();

        print('[DEBUG] Filtered valid U.S. stocks: ${filtered.length}');

        // Return only top 10
        return filtered.take(10).toList();
      } else {
        throw Exception('Failed to load stocks');
      }
    } catch (e) {
      throw Exception('Error fetching stocks: $e');
    }
  }

  // Search for stocks by keyword using MarketStack
  Future<List<Stock>> searchStocks(String query) async {
    if (query.isEmpty) return [];

    if (_apiKey.isEmpty) {
      throw Exception("MarketStack API Key is missing! Check .env file.");
    }

    try {
      final uri = Uri.https(_baseUrl, '/v1/tickers', {
        'access_key': _apiKey,
        'search': query,
        'limit': '20'
      });

      final response = await http.get(uri);
      print('[DEBUG - SEARCH] Status: ${response.statusCode}');

      // If API call is successful
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stocksData = data['data'] as List;

        // Filter out international or incomplete tickers
        final filtered = stocksData.where((stock) {
          final name = stock['name'];
          final symbol = stock['symbol'];
          final valid = name != null && name.toString().isNotEmpty && _isValidUSSymbol(symbol);

          if (!valid) {
            if (_manualBlocklist.contains(symbol.toUpperCase())) {
              print('[BLOCKLISTED - SEARCH] $symbol (name=$name)');
            } else {
              print('[FILTERED OUT - SEARCH] $symbol (name=$name)');
            }
          }

          return valid;
        }).map((stock) => Stock.fromJson(stock)).toList();

        print('[DEBUG - SEARCH] Filtered: ${filtered.length}');
        return filtered;
      } else {
        throw Exception('Failed to search stocks');
      }
    } catch (e) {
      throw Exception('Error searching stocks: $e');
    }
  }
}
