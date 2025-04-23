import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/appbar.dart';
import 'AIDashboard.dart';
import 'services/stock_state.dart';

// Different ways users can organize their favorite stocks
enum SortType { alphabetical, recentlyAdded, byTimeframe }

// Data structure for saved stocks in user's favorites list
class FavoriteItem {
  final String symbol;
  final String timeframe;
  final String? added_time;
  final String? addedRawTime;

  FavoriteItem({
    required this.symbol,
    required this.timeframe,
    this.added_time,
    this.addedRawTime,

  });

  // Converts the JSON from our backend into a proper FavoriteItem object
  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    final raw = json["added_raw"];
    return FavoriteItem(
      symbol: json["symbol"],
      timeframe: json["timeframe"],
      added_time: json["added_time"],
      addedRawTime: raw == null || raw == "null" ? null : raw,

    );
  }
}

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<FavoriteItem> _favorites = [];
  bool _isLoading = true;
  final StockState stockState = StockState();
  SortType _currentSortType = SortType.recentlyAdded;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  // Pulls the current user's email from local device storage
  Future<String?> _getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("userEmail");
  }

  // Gets the complete list of user's favorite stocks from our server
  Future<void> _fetchFavorites() async {
    String? email = await _getUserEmail();
    if (email == null) {
      debugPrint("Error: No user email found.");
      setState(() => _isLoading = false);
      return;
    }

    final url = "http://10.0.2.2:5000/get_favorites?user_email=$email";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _favorites = data.map((item) => FavoriteItem.fromJson(item)).toList();
          _isLoading = false;
          _sortFavorites(); // Sort after fetching
        });
      } else {
        debugPrint("Failed to fetch favorites: ${response.body}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
      setState(() => _isLoading = false);
    }
  }

  // Arranges favorites in different orders based on what sorting option is active
  void _sortFavorites() {
    switch (_currentSortType) {
      case SortType.alphabetical:
        _favorites.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
      case SortType.recentlyAdded:
        if (_favorites.any((item) => item.addedRawTime != null)) {
          _favorites.sort((a, b) {
            if (a.addedRawTime == null && b.addedRawTime == null) return 0;
            if (a.addedRawTime == null) return 1;
            if (b.addedRawTime == null) return -1;
            return b.addedRawTime!.compareTo(a.addedRawTime!);
          });
        }
        break;

      case SortType.byTimeframe:
        // Sorts by timeframe duration (15min, 1week, 1month, 1year)
        _favorites.sort((a, b) => _compareTimeframes(a.timeframe, b.timeframe));
        break;
    }
  }

  // Helps sort stocks by their timeframe duration (15min, 1week, 1month, 1year)
  // Sorted by highest to lowest in UI
  // 30 mins, 1hr, 1day included to prevent sized inconsistencies
  int _compareTimeframes(String a, String b) {
    // Define timeframe weights (smaller number = shorter timeframe)
    final weights = {
      '15min': 1,
      '30min': 2,
      '1hr': 3,
      '1day': 4,
      '1week': 5,
      '1month': 6,
    };
    return (weights[a] ?? 0).compareTo(weights[b] ?? 0);
  }

  // Returns the right label text for whichever sort method is currently selected
  String _getSortTypeText() {
    switch (_currentSortType) {
      case SortType.alphabetical:
        return "A-Z";
      case SortType.recentlyAdded:
        return "Recent";

      case SortType.byTimeframe:
        return "Time";
    }
  }

  // Handles user changing sort preference
  void _changeSortType(SortType sortType) {
    setState(() {
      _currentSortType = sortType;
      _sortFavorites();
    });
  }

  // Removes a favorite from the backend and local list
  Future<void> _removeFavorite(FavoriteItem item) async {
    String? email = await _getUserEmail();
    if (email == null) {
      debugPrint("Error: No user email found.");
      return;
    }

    if (item.addedRawTime == null) {
      debugPrint("Skipping removal: missing addedRawTime for ${item.symbol}");
      return;
    }

    final url = "http://10.0.2.2:5000/remove_favorite";
    final body = jsonEncode({
      "user_email": email,
      "symbol": item.symbol,
      "timeframe": item.timeframe,
      "added_time": item.addedRawTime,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        setState(() {
          _favorites.removeWhere(
            (fav) =>
                fav.symbol == item.symbol &&
                fav.timeframe == item.timeframe &&
                fav.addedRawTime == item.addedRawTime,
          );
        });
      } else {
        debugPrint("Failed to remove favorite: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error removing favorite: $e");
    }
  }

  // UI for sort button using dynamic theme lookups
  Widget _buildSortButton(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
            ),
            child: PopupMenuButton<SortType>(
              color: theme.cardColor,
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, color: theme.dividerColor),
                  const SizedBox(width: 4),
                  Text(
                    _getSortTypeText(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              onSelected: _changeSortType,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortType.alphabetical,
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha,
                          color: _currentSortType == SortType.alphabetical
                              ? theme.colorScheme.secondary
                              : theme.dividerColor),
                      const SizedBox(width: 8),
                      Text(
                        "Alphabetical",
                        style: TextStyle(
                          color: _currentSortType == SortType.alphabetical
                              ? theme.colorScheme.secondary
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortType.recentlyAdded,
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          color: _currentSortType == SortType.recentlyAdded
                              ? theme.colorScheme.secondary
                              : theme.dividerColor),
                      const SizedBox(width: 8),
                      Text(
                        "Recently Added",
                        style: TextStyle(
                          color: _currentSortType == SortType.recentlyAdded
                              ? theme.colorScheme.secondary
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuItem(
                  value: SortType.byTimeframe,
                  child: Row(
                    children: [
                      Icon(Icons.timeline,
                          color: _currentSortType == SortType.byTimeframe
                              ? theme.colorScheme.secondary
                              : theme.dividerColor),
                      const SizedBox(width: 8),
                      Text(
                        "Timeframe",
                        style: TextStyle(
                          color: _currentSortType == SortType.byTimeframe
                              ? theme.colorScheme.secondary
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget for each favorite card using dynamic theme values.
  Widget _buildFavoriteCard(BuildContext context, FavoriteItem item) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final accentColor = theme.colorScheme.secondary;
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: secondaryTextColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      elevation: 4.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AiDashboard(
                symbol: item.symbol,
                timeframe: item.timeframe,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            leading: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(Icons.star, color: accentColor, size: 28),
            ),
            title: Text(
              item.symbol,
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.timeframe,
                  style: TextStyle(
                    color: secondaryTextColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                if (item.added_time != null)
                  Text(
                    'Added ${item.added_time}',
                    style: TextStyle(
                      color: secondaryTextColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.close, color: secondaryTextColor),
              onPressed: () => _removeFavorite(item),
            ),
          ),
        ),
      ),
    );
  }

  // Shows a friendly message when user hasn't saved any favorites yet
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No favorites yet!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save stocks from the Dashboard to track them here.',
            style: TextStyle(color: secondaryTextColor, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    // Uses dynamic values for colors
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Favorites',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary))
          : _favorites.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  children: [
                    _buildSortButton(context),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) => Dismissible(
                          key: Key("${_favorites[index].symbol}-${_favorites[index].timeframe}"),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) => _removeFavorite(_favorites[index]),
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child: Icon(Icons.delete, color: bgColor),
                          ),
                          child: _buildFavoriteCard(context, _favorites[index]),
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: Theme(
        data: theme.copyWith(canvasColor: bgColor),
        child: const AppBarWidget(selectedIndex: 2),
      ),
    );
  }
}
