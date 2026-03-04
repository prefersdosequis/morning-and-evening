import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/devotion.dart';
import 'services/asset_delivery_service.dart';
import 'services/devotion_service.dart';
import 'utils/storage_service.dart';
import 'utils/text_formatter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorningEveningApp());
}

class MorningEveningApp extends StatelessWidget {
  const MorningEveningApp({super.key});

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
      themeMode: ThemeMode.system,
      home: const DevotionPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DevotionPage extends StatefulWidget {
  const DevotionPage({
    super.key,
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  /// Which devotion audio is loaded (e.g. "morning/001.mp3") so we can resume or reload.
  String? _loadedAudioKey;
  bool _didAudioPreflight = false;

  @override
  void initState() {
    super.initState();
    _configureAudio();
    _loadDevotions();
  }

  bool _isLeapYear(int year) {
    if (year % 400 == 0) return true;
    if (year % 100 == 0) return false;
    return year % 4 == 0;
  }

  int _normalizePageForYear(int page, {required int year}) {
    if (page < 1 || page > _devotions.length) return page;
    if (_isLeapYear(year)) return page;

    final devotion = _devotions[page - 1];
    // Dataset includes Feb 29 as day 60. In non-leap years, redirect away from it.
    if (devotion.day != 60) return page;

    // Map Feb 29 Morning/Evening -> Mar 1 Morning/Evening (day 61), if present.
    final replacement = _findDevotionIndex(_devotions, 61, devotion.type);
    return replacement ?? page;
  }

  Future<void> _configureAudio() async {
    // Make playback behave like normal media audio on Android/iOS.
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      _audioPlayer.onPlayerStateChanged.listen((state) {
        debugPrint('MEAudio: player state=$state');
      });
    } catch (e) {
      debugPrint('MEAudio: audio config failed: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _currentDevotionAudioKey() {
    if (_devotions.isEmpty) return '';
    final d = _devotions[_currentPage - 1];
    return '${d.type}/${d.day.toString().padLeft(3, '0')}.mp3';
  }

  /// Pause at current position; resume with play.
  void _pauseAudio() {
    _audioPlayer.pause();
  }

  Future<void> _stopAudioForDevotionChange() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('MEAudio: stop failed: $e');
    } finally {
      // Ensure next play loads the newly selected devotion's audio.
      _loadedAudioKey = null;
    }
  }

  /// Play audio for the current devotion (asset pack: morning/NNN.mp3 or evening/NNN.mp3).
  /// Resumes from current position if this devotion is already loaded and paused.
  Future<void> _playCurrentDevotionAudio() async {
    if (_devotions.isEmpty) return;
    final devotion = _devotions[_currentPage - 1];
    final key = _currentDevotionAudioKey();
    final relativePath = key;

    try {
      debugPrint('MEAudio: play requested: type=${devotion.type} day=${devotion.day} key=$key');
      // Resume if same devotion is loaded and currently paused.
      if (_loadedAudioKey == key && _audioPlayer.state == PlayerState.paused) {
        await _audioPlayer.resume();
        return;
      }

      final path = await AssetDeliveryService.getAudioFilePath(relativePath);
      debugPrint('MEAudio: AssetDeliveryService returned path=$path');
      if (path != null && path.isNotEmpty) {
        final exists = await File(path).exists();
        debugPrint('MEAudio: file exists=$exists');
        if (!exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Audio pack path found, but file missing: $relativePath')),
            );
          }
          return;
        }
        await _audioPlayer.play(DeviceFileSource(path));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Audio not available.\n'
                'For local testing you must install an App Bundle (AAB) with the Play Asset Delivery pack (e.g. via bundletool or Play Internal Testing). '
                '`flutter run` installs an APK and won’t include asset packs.',
              ),
            ),
          );
        }
        return;
      }
      _loadedAudioKey = key;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play audio: $e')),
        );
      }
    }
  }

  int _getDayOfYear(DateTime date) {
    // Calculate day of year (1-365, or 366 for leap years)
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  int _devotionDayForDate(DateTime date) {
    // The devotions dataset includes Feb 29 as day 60.
    // In non-leap years, skip Feb 29 by mapping:
    // - Mar 1 (dayOfYear 60) -> devotion day 61
    // - ...
    // - Dec 31 (dayOfYear 365) -> devotion day 366
    final dayOfYear = _getDayOfYear(date);
    if (_isLeapYear(date.year)) return dayOfYear;
    return dayOfYear >= 60 ? dayOfYear + 1 : dayOfYear;
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
    final devotionDay = _devotionDayForDate(now);
    final hour = now.hour;

    // Morning: 2:00 AM – 1:59 PM. Evening: 2:00 PM – 1:59 AM.
    final String type;
    if (hour >= 2 && hour < 14) {
      type = 'morning';
    } else {
      type = 'evening';
    }

    // Find the devotion for today
    final pageIndex = _findDevotionIndex(devotions, devotionDay, type);

    // If found, return it; otherwise return 1 as fallback
    return pageIndex ?? 1;
  }

  Future<void> _loadDevotions() async {
    try {
      final devotions = await DevotionService.loadDevotions();
      final todayPage = _getInitialPage(devotions);
      // Always open to today's devotion (current date + morning/evening time)
      final initialPage = todayPage;

      setState(() {
        _devotions = devotions;
        _currentPage = initialPage.clamp(1, devotions.length);
        _isLoading = false;
      });

      await StorageService.saveCurrentPage(_currentPage);

      // Debug preflight: verify the asset pack path + today's MP3 exists without needing a Play tap.
      if (!_didAudioPreflight) {
        _didAudioPreflight = true;
        Future<void>.delayed(const Duration(milliseconds: 300), _audioPreflightForCurrentDevotion);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _audioPreflightForCurrentDevotion() async {
    if (!mounted || _devotions.isEmpty) return;
    final key = _currentDevotionAudioKey();
    if (key.isEmpty) return;

    try {
      debugPrint('MEAudio: preflight key=$key');
      final path = await AssetDeliveryService.getAudioFilePath(key);
      debugPrint('MEAudio: preflight resolved path=$path');
      if (path != null && path.isNotEmpty) {
        final exists = await File(path).exists();
        debugPrint('MEAudio: preflight file exists=$exists');
      }
    } catch (e) {
      debugPrint('MEAudio: preflight error: $e');
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _devotions.length) return;
    final normalized = _normalizePageForYear(page, year: DateTime.now().year);
    if (normalized != page) {
      _goToPage(normalized);
      return;
    }
    if (page == _currentPage) return;
    // If the user navigates to a different devotion, stop whatever audio is currently playing.
    // The next tap of Play should play the newly selected devotion's audio.
    if (page != _currentPage && _audioPlayer.state != PlayerState.stopped) {
      unawaited(_stopAudioForDevotionChange());
    } else {
      // Even if already stopped, make sure we don't resume a previous devotion by accident.
      _loadedAudioKey = null;
    }

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
    if (_devotions.isEmpty) return;
    final current = _devotions[_currentPage - 1];
    final year = DateTime.now().year;
    final isLeap = _isLeapYear(year);

    final String nextType;
    final int nextDay;
    if (current.type == 'morning') {
      nextType = 'evening';
      nextDay = current.day;
    } else {
      nextType = 'morning';
      // Skip Feb 29 (day 60) in non-leap years.
      if (!isLeap && current.day == 59) {
        nextDay = 61;
      } else {
        nextDay = current.day + 1;
      }
    }

    final idx = _findDevotionIndex(_devotions, nextDay, nextType);
    if (idx != null) _goToPage(idx);
  }

  void _goToPreviousPage() {
    if (_devotions.isEmpty) return;
    final current = _devotions[_currentPage - 1];
    final year = DateTime.now().year;
    final isLeap = _isLeapYear(year);

    final String prevType;
    final int prevDay;
    if (current.type == 'evening') {
      prevType = 'morning';
      prevDay = current.day;
    } else {
      prevType = 'evening';
      // Skip Feb 29 (day 60) in non-leap years.
      if (!isLeap && current.day == 61) {
        prevDay = 59;
      } else {
        prevDay = current.day - 1;
      }
    }

    final idx = _findDevotionIndex(_devotions, prevDay, prevType);
    if (idx != null) _goToPage(idx);
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
    final isDarkMode = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    // Header and status bar match theme: white bg + black text in light mode, black bg + white text in dark mode
    final headerColor = isDarkMode ? Colors.black : Colors.white;
    final headerTextAndIconColor = isDarkMode ? Colors.white : Colors.black;
    final statusBarIconBrightness = isDarkMode ? Brightness.light : Brightness.dark;

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
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
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
              // Header: play/pause button top-left, title centered
              Container(
                width: double.infinity,
                color: headerColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    StreamBuilder<PlayerState>(
                      stream: _audioPlayer.onPlayerStateChanged,
                      builder: (context, snapshot) {
                        final playing = snapshot.data == PlayerState.playing;
                        return IconButton(
                          icon: Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: headerTextAndIconColor,
                            size: 28,
                          ),
                          onPressed: _isLoading || _devotions.isEmpty
                              ? null
                              : (playing ? _pauseAudio : _playCurrentDevotionAudio),
                          tooltip: playing ? 'Pause' : 'Play devotion audio',
                        );
                      },
                    ),
                    Expanded(
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
                    const SizedBox(width: 48), // balance the left play button for visual center
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
