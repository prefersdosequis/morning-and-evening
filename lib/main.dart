import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/devotion.dart';
import 'services/devotion_service.dart';
import 'utils/storage_service.dart';
import 'utils/text_formatter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorningEveningApp());
}

class MorningEveningApp extends StatefulWidget {
  const MorningEveningApp({super.key});

  @override
  State<MorningEveningApp> createState() => _MorningEveningAppState();
}

class _MorningEveningAppState extends State<MorningEveningApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await StorageService.getIsDarkMode();
    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    StorageService.saveIsDarkMode(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morning and Evening',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF800000),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.crimsonTextTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF800000),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.crimsonTextTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: Colors.black,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DevotionPage(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DevotionPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const DevotionPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<DevotionPage> createState() => _DevotionPageState();
}

class _DevotionPageState extends State<DevotionPage> {
  List<Devotion> _devotions = [];
  int _currentPage = 1;
  bool _isLoading = true;
  bool _hasError = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDevotions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getDayOfYear(DateTime date) {
    // Calculate day of year (1-365, or 366 for leap years)
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  int? _findDevotionIndex(List<Devotion> devotions, int day, String type) {
    // Find the index of the devotion matching the day and type
    for (int i = 0; i < devotions.length; i++) {
      if (devotions[i].day == day && devotions[i].type == type) {
        return i + 1; // Return 1-based page number
      }
    }
    return null;
  }

  int _getInitialPage(List<Devotion> devotions) {
    final now = DateTime.now();
    final dayOfYear = _getDayOfYear(now);
    final hour = now.hour;
    final minute = now.minute;
    
    // Determine if it's morning (12:00 AM - 3:00 PM) or evening (3:01 PM - 11:59 PM)
    final String type;
    if (hour < 15 || (hour == 15 && minute == 0)) {
      // 12:00 AM (0:00) to 3:00 PM (15:00) inclusive
      type = 'morning';
    } else {
      // 3:01 PM (15:01) to 11:59 PM (23:59)
      type = 'evening';
    }
    
    // Find the devotion for today
    final pageIndex = _findDevotionIndex(devotions, dayOfYear, type);
    
    // If found, return it; otherwise return 1 as fallback
    return pageIndex ?? 1;
  }

  Future<void> _loadDevotions() async {
    try {
      final devotions = await DevotionService.loadDevotions();
      
      // Get the page for today's devotion based on time
      final todayPage = _getInitialPage(devotions);
      
      // Use today's page, but also check if there's a saved page preference
      // For now, we'll prioritize today's devotion
      final initialPage = todayPage;
      
      setState(() {
        _devotions = devotions;
        _currentPage = initialPage.clamp(1, devotions.length);
        _isLoading = false;
      });
      
      // Save the current page
      StorageService.saveCurrentPage(_currentPage);
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _devotions.length) return;
    
    setState(() {
      _currentPage = page;
    });
    
    // Scroll to top when page changes
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    
    StorageService.saveCurrentPage(page);
    HapticFeedback.lightImpact();
  }

  void _goToNextPage() {
    _goToPage(_currentPage + 1);
  }

  void _goToPreviousPage() {
    _goToPage(_currentPage - 1);
  }

  Widget _buildDateBadge(Devotion devotion) {
    // Extract just the date part (e.g., "January 1" from "January 1 - Morning")
    String dateText = devotion.title.split(' - ')[0];
    
    // Choose icon and colors based on type
    IconData icon;
    Color backgroundColor;
    
    if (devotion.type == 'morning') {
      icon = Icons.wb_sunny;
      backgroundColor = const Color(0xFFF39C12); // Orange/sun color
    } else {
      icon = Icons.nightlight_round;
      backgroundColor = const Color(0xFF5D4E75); // Purple/moon color
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30), // Oval/soft rectangle
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            dateText,
            style: GoogleFonts.crimsonText(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final headerColor = Colors.black; // Header stays black in both themes
    final statusBarIconBrightness = widget.isDarkMode ? Brightness.light : Brightness.light;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF800000)),
          ),
        ),
      );
    }

    if (_hasError || _devotions.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Error loading devotions',
            style: GoogleFonts.crimsonText(
              color: textColor,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    final devotion = _devotions[_currentPage - 1];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: headerColor,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: widget.isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          bottom: false,
          top: true, // Reserve space for Android status bar
          left: false,
          right: false,
          child: Column(
          children: [
            // Header with settings button
            Container(
              width: double.infinity,
              color: headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered title
                  Text(
                    'Morning and Evening',
                    style: GoogleFonts.crimsonText(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Theme button aligned to the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: Colors.white,
                      ),
                      onPressed: widget.onThemeToggle,
                      tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    ),
                  ),
                ],
              ),
            ),

            // Content - Full width white block with 3cm side borders
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  // Swipe left (negative velocity) = next page
                  // Swipe right (positive velocity) = previous page
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -500) {
                      // Swipe left - go to next
                      if (_currentPage < _devotions.length) {
                        _goToNextPage();
                      }
                    } else if (details.primaryVelocity! > 500) {
                      // Swipe right - go to previous
                      if (_currentPage > 1) {
                        _goToPreviousPage();
                      }
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  color: backgroundColor,
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: 16,
                    left: MediaQuery.of(context).size.width * 0.08, // ~3cm on most devices
                    right: MediaQuery.of(context).size.width * 0.08, // ~3cm on most devices
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title with icon
                        _buildDateBadge(devotion),
                        const SizedBox(height: 12),

                        // Content with King James style font
                        SizedBox(
                          width: double.infinity,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.crimsonText(
                                fontSize: 18, // Increased from 13 to 16
                                height: 1.6, // Increased from 1.2 to 1.6 for more spacing
                                color: textColor,
                                fontWeight: FontWeight.w700, // Bold for better readability
                              ),
                              children: TextFormatter.formatContent(devotion.content, textColor: textColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
