import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextFormatter {
  static String _normalizeReferenceDisplay(String reference) {
    // Prefer "2:16,17" over "2:16, 17" for display.
    return reference.replaceAll(RegExp(r',\s+'), ',');
  }

  static String _ordinal(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  /// Converts a Bible reference like "2 Corinthians 7:6" into a screen-reader-friendly
  /// spoken form like "2nd Corinthians 7 verse 6".
  ///
  /// Keeps the on-screen text unchanged; this is intended for semantics only.
  static String? bibleReferenceSemanticsLabel(String reference) {
    var r = reference.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (r.isEmpty) return null;

    // Strip common trailing punctuation that sometimes leaks into references.
    r = r.replaceAll(RegExp(r'[\)\]\.,;]+$'), '');

    final parts = r.split(' ');
    if (parts.length < 2) return null;

    final last = parts.last;
    final rest = parts.sublist(0, parts.length - 1);

    final leadingNumber = int.tryParse(rest.isNotEmpty ? rest.first : '');
    String bookName;
    String bookSpoken;
    if (leadingNumber != null && leadingNumber >= 1 && leadingNumber <= 3) {
      bookName = rest.sublist(1).join(' ');
      bookSpoken = '${_ordinal(leadingNumber)} $bookName';
    } else {
      bookName = rest.join(' ');
      bookSpoken = bookName;
    }

    // Chapter:Verse form (allow hyphen/en-dash ranges, or comma-separated verses).
    final cvMatch =
        RegExp(r'^(\d+):(\d+(?:[,\u2013\u2014-]\d+)*)$').firstMatch(last);
    if (cvMatch != null) {
      final chapter = cvMatch.group(1)!;
      final versesRaw = cvMatch.group(2)!;

      // Range like 6-7 / 6–7.
      final rangeMatch =
          RegExp(r'^(\d+)[\u2013\u2014-](\d+)$').firstMatch(versesRaw);
      if (rangeMatch != null) {
        final start = rangeMatch.group(1)!;
        final end = rangeMatch.group(2)!;
        return '$bookSpoken $chapter verses $start through $end';
      }

      // Comma-separated verses like 6,7,8.
      if (versesRaw.contains(',')) {
        final verseNums = versesRaw
            .split(',')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
        if (verseNums.isNotEmpty) {
          return '$bookSpoken $chapter verses ${verseNums.join(', ')}';
        }
      }

      return '$bookSpoken $chapter verse $versesRaw';
    }

    // Chapter-only form like "Jude 1".
    final chapterOnly = RegExp(r'^\d+$').hasMatch(last) ? last : null;
    if (chapterOnly != null) {
      return '$bookSpoken chapter $chapterOnly';
    }

    return null;
  }

  static List<TextSpan> formatContent(String content,
      {Color textColor = Colors.black}) {
    // Keep formatting behavior deterministic and order-preserving.
    // We do not attempt poem extraction/reordering.
    var normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remove navigation artifacts from source text exports.
    normalized = normalized.replaceAll(
      RegExp(r'\[\d+\]Go To (Morning|Evening) Reading', caseSensitive: false),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'^\s*_{10,}\s*$', multiLine: true), '');
    normalized = normalized.replaceAll(RegExp(r'^\s*-{10,}\s*$', multiLine: true), '');

    final rawParagraphs = normalized
        .split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final spans = <TextSpan>[];
    var startIndex = 0;

    // Scripture pair: first paragraph is a quoted verse, second is a reference.
    final referencePattern = RegExp(
      r'^((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+))$',
    );
    final sameParagraphPattern = RegExp(
      r'''^(["'])([\s\S]+?)\1\.?\s*[-\s]\s*((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+))$''',
    );
    final quotedParagraphPattern =
        RegExp(r'''^(["']).*?\1\.?$''', dotAll: true);

    if (rawParagraphs.isNotEmpty) {
      final first = rawParagraphs[0];
      final sameParaMatch = sameParagraphPattern.firstMatch(first);
      if (sameParaMatch != null) {
        final quote = sameParaMatch.group(1)!;
        final verse = sameParaMatch.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
        final ref = sameParaMatch.group(3)!.trim();
        final displayRef = _normalizeReferenceDisplay(ref);
        spans.add(TextSpan(
          text: '$quote$verse$quote\n',
          style: GoogleFonts.inter(
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ));
        spans.add(TextSpan(
          text: '$displayRef\n\n',
          semanticsLabel: bibleReferenceSemanticsLabel(displayRef) ?? displayRef,
          style: GoogleFonts.inter(
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ));
        startIndex = 1;
      } else {
        // Handle the common source format where the opening verse is wrapped into
        // multiple paragraphs before the closing quote, followed by a standalone reference.
        final startsWithQuote = first.startsWith('"') || first.startsWith("'");
        if (startsWithQuote) {
          final quoteChar = first[0];
          final verseParts = <String>[];
          var closeIdx = -1;
          final scanLimit = rawParagraphs.length < 8 ? rawParagraphs.length : 8;

          for (var idx = 0; idx < scanLimit; idx++) {
            final p = rawParagraphs[idx].trim();
            if (p.isEmpty) continue;
            verseParts.add(p);
            final endsQuote = p.endsWith(quoteChar) || p.endsWith('$quoteChar.');
            if (idx > 0 && endsQuote) {
              closeIdx = idx;
              break;
            }
          }

          final refIdx = closeIdx + 1;
          final hasReference = closeIdx >= 0 &&
              refIdx < rawParagraphs.length &&
              referencePattern.hasMatch(rawParagraphs[refIdx]);

          if (hasReference) {
            final verseCombined =
                verseParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
            final ref = referencePattern.firstMatch(rawParagraphs[refIdx])!.group(1)!;
            final displayRef = _normalizeReferenceDisplay(ref);
            spans.add(TextSpan(
              text: '$verseCombined\n',
              style: GoogleFonts.inter(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ));
            spans.add(TextSpan(
              text: '$displayRef\n\n',
              semanticsLabel:
                  bibleReferenceSemanticsLabel(displayRef) ?? displayRef,
              style: GoogleFonts.inter(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ));
            startIndex = refIdx + 1;
          } else if (rawParagraphs.length >= 2 &&
              quotedParagraphPattern.hasMatch(first) &&
              referencePattern.hasMatch(rawParagraphs[1])) {
            // Keep single-paragraph verse + next-line reference support.
            final ref = referencePattern.firstMatch(rawParagraphs[1])!.group(1)!;
            final displayRef = _normalizeReferenceDisplay(ref);
            spans.add(TextSpan(
              text: '${first.replaceAll(RegExp(r'\s+'), ' ').trim()}\n',
              style: GoogleFonts.inter(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ));
            spans.add(TextSpan(
              text: '$displayRef\n\n',
              semanticsLabel:
                  bibleReferenceSemanticsLabel(displayRef) ?? displayRef,
              style: GoogleFonts.inter(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ));
            startIndex = 2;
          }
        }
      }
    }

    bool isPoemCandidate(String text) {
      final t = text.trim();
      if (t.isEmpty) return false;
      final startsQuoted = t.startsWith('"') || t.startsWith("'");
      if (!startsQuoted) return false;
      // Keep this strict so normal quoted prose isn't treated as poetry.
      return t.length <= 90;
    }

    void appendBody(String text) {
      spans.add(TextSpan(
        text: '$text\n\n',
        style: GoogleFonts.inter(
          fontSize: 18,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ));
    }

    final proseParts = <String>[];
    var i = startIndex;
    while (i < rawParagraphs.length) {
      final current = rawParagraphs[i].replaceAll(RegExp(r'\s+'), ' ').trim();
      if (current.isEmpty) {
        i++;
        continue;
      }

      // Treat as poem only when there are 2+ consecutive short quoted lines.
      if (isPoemCandidate(current)) {
        final poemLines = <String>[current];
        var j = i + 1;
        while (j < rawParagraphs.length) {
          final next = rawParagraphs[j].replaceAll(RegExp(r'\s+'), ' ').trim();
          if (!isPoemCandidate(next)) break;
          poemLines.add(next);
          j++;
        }

        if (poemLines.length >= 2) {
          if (proseParts.isNotEmpty) {
            appendBody(proseParts.join(' '));
            proseParts.clear();
          }
          appendBody(poemLines.join('\n'));
          i = j;
          continue;
        }
      }

      // Default: coalesce wrapped prose lines into continuous body text.
      proseParts.add(current);
      i++;
    }

    if (proseParts.isNotEmpty) {
      appendBody(proseParts.join(' '));
    }

    if (kDebugMode) {
      debugPrint(
          'TextFormatter: rendered paragraphs=${rawParagraphs.length - startIndex}, scriptureHandled=${startIndex > 0}');
    }
    return spans;
  }
}
