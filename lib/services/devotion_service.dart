import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/devotion.dart';

class DevotionService {
  static List<Devotion>? _devotions;
  static const String _assetPath = 'assets/devotions.json';

  static Future<List<Devotion>> loadDevotions() async {
    if (_devotions != null) {
      return _devotions!;
    }

    try {
      final String jsonString = await rootBundle.loadString(_assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _devotions = jsonList.map((json) => Devotion.fromJson(json)).toList();
      return _devotions!;
    } catch (e) {
      throw Exception('Failed to load devotions: $e');
    }
  }

  static List<Devotion> get devotions => _devotions ?? [];
  static int get totalPages => _devotions?.length ?? 0;
}
