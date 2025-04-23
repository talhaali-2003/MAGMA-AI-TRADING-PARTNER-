import 'package:flutter/material.dart';
import 'package:flutter_magma/LoginPage.dart';

// OnboardingPage is the first screen users see when launching the app

//Ibrahim Adegunlola - Worked on OnboardingPage class which just creates a state to OnboardingPageState.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

//Ibrahim Adegunlola & Yousef - Worked on OnboardingPageState class which manages the controller for managing the page transitions,
//theme colors for styling, and content for each onboarding slide.
class _OnboardingPageState extends State<OnboardingPage> {
  // Yousef- Controller for managing page transitions
  final PageController _pageController = PageController();
  int _currentPage = 0;

  //Ibrahim Adegunlola- Theme colors for  styling
  static const darkGrey = Color(0xFF121212);
  static const textPrimary = Color(0xFFEAEAEA);
  static const textSecondary = Color(0xFFB0B0B0);
  static const accentRed = Color(0xFFFF3B30);

  // Yousef- Content for each onboarding slide
  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to MAGMA',
      'subtitle': 'Your intelligent stock analysis companion'
    },
    {
      'title': 'Smart Analysis',
      'subtitle': 'Get detailed insights and predictions for your investments'
    },
    {
      'title': 'Make Informed Decisions',
      'subtitle': 'Start your investment journey today'
    }
  ];

  // Ibrahim Adegunlola-Navigates to the login page and removes the onboarding page from the navigation stack.
  void _goToLoginPage() {
    _pageController.dispose();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  // Ibrahim Adegunlola- Worked on build and sturcutre which consists of how the page functions such as the three dots showing what page your on,
  //get started button, skip button, and applying the dynamic theme colors to the page.
  @override
  Widget build(BuildContext context) {
    // Prevents back button from returning to previous screen
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          // Ibrahim Adegunlola-Dark gradient background
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [darkGrey, Color(0xFF1A1A1A)],
            ),
          ),
          child: Stack(
            children: [
              // Ibrahim Adegunlola-Main content area with page view
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    // Ibrahim Adegunlola-Scale animation for page transitions
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = (_pageController.page! - index);
                        value = (1 - (value.abs() * 0.5)).clamp(0.0, 1.0);
                      }
                      return Transform.scale(
                        scale: Curves.easeOutBack.transform(value),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ibrahim Adegunlola-Animated MAGMA logo/title
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: const Text(
                              'MAGMA',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Ibrahim Adegunlola-Animated page title
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _pages[index]['title']!,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Ibrahim Adegunlola-Animated page subtitle
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _pages[index]['subtitle']!,
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              //Ibrahim Adegunlola- Bottom navigation area
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    //Ibrahim Adegunlola- "Get Started" button (only shown on last page)
                    if (_currentPage == _pages.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 30, left: 40, right: 40),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0, end: 1),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _goToLoginPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentRed,
                                foregroundColor: textPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Ibrahim Adegunlola-Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? textPrimary
                                : textSecondary.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Ibrahim Adegunlola-"Skip to Login" button (shown on all pages except last)
                    if (_currentPage != _pages.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TextButton(
                          onPressed: _goToLoginPage,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Skip to Login',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                color: textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
