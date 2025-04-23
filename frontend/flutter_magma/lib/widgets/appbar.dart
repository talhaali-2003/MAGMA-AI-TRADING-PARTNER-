import 'package:flutter/material.dart';
import 'package:flutter_magma/AIDashboard.dart';
import '../favorites.dart';
import '../settings.dart'; // Updated import
import 'package:flutter_magma/stock_selection_page.dart';

class AppBarWidget extends StatefulWidget {
  final int selectedIndex;

  const AppBarWidget({super.key, required this.selectedIndex});

  @override
  _AppBarWidgetState createState() => _AppBarWidgetState();
}

class _AppBarWidgetState extends State<AppBarWidget> {
  int _currentIndex = 0;

  // Add the accent red color to match the theme
  static const accentRed = Color(0xFFFF3B30);
  static const textSecondary = Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return; // Avoid unnecessary reloads

    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => StockSelectionPage()));
        break;
      case 1:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const AiDashboard()));
        break;
      case 2:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const FavoritePage()));
        break;
      case 3:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const SettingsPage())); // Updated to SettingsPage
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onItemTapped,
      selectedItemColor: accentRed, 
      unselectedItemColor: textSecondary, 
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard), label: 'AI Interaction'),
        BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings'), // Changed from person to settings
      ],
    );
  }
}
