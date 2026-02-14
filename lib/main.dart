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
    // Always use the phone's current light/dark setting when the app opens
    final systemDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    setState(() {
      _isDarkMode = systemDark;
    });
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
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF800000),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: Colors.black,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DevotionPage(
        isDarkMode: _isDarkMode,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DevotionPage extends StatefulWidget {
  final bool isDarkMode;

  const DevotionPage({
    super.key,
    required this.isDarkMode,
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

    // Morning: 2:00 AM – 1:59 PM. Evening: 2:00 PM – 1:59 AM.
    final String type;
    if (hour >= 2 && hour < 14) {
      type = 'morning';
    } else {
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
      final todayPage = _getInitialPage(devotions);
      final savedPage = await StorageService.getCurrentPage();
      // Use saved page if valid and same “day” as today, else open to today’s devotion
      final initialPage = (savedPage >= 1 && savedPage <= devotions.length)
          ? savedPage
          : todayPage;

      setState(() {
        _devotions = devotions;
        _currentPage = initialPage.clamp(1, devotions.length);
        _isLoading = false;
      });

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
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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
    // Header and status bar match theme: white bg + black text in light mode, black bg + white text in dark mode
    final headerColor = widget.isDarkMode ? Colors.black : Colors.white;
    final headerTextAndIconColor = widget.isDarkMode ? Colors.white : Colors.black;
    final statusBarIconBrightness = widget.isDarkMode ? Brightness.light : Brightness.dark;

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
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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
        statusBarBrightness: widget.isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: statusBarIconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
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
            // Header
            Container(
              width: double.infinity,
              color: headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Text(
                  'Morning and Evening',
                  style: GoogleFonts.inter(
                    color: headerTextAndIconColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
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

                        // Devotion content
                        SizedBox(
                          width: double.infinity,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                height: 1.6,
                                color: textColor,
                                fontWeight: FontWeight.w700,
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
