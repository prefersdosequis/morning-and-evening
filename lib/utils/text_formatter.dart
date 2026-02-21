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
    final hasLeadingOrdinalBookNumber = leadingNumber != null && leadingNumber >= 1 && leadingNumber <= 3;

    final bookName = hasLeadingOrdinalBookNumber ? rest.sublist(1).join(' ') : rest.join(' ');
    final bookSpoken = hasLeadingOrdinalBookNumber ? '${_ordinal(leadingNumber!)} $bookName' : bookName;

    // Chapter:Verse form (allow hyphen/en-dash ranges, or comma-separated verses).
    final cvMatch = RegExp(r'^(\d+):(\d+(?:[,\u2013\u2014-]\d+)*)$').firstMatch(last);
    if (cvMatch != null) {
      final chapter = cvMatch.group(1)!;
      final versesRaw = cvMatch.group(2)!;

      // Range like 6-7 / 6–7.
      final rangeMatch = RegExp(r'^(\d+)[\u2013\u2014-](\d+)$').firstMatch(versesRaw);
      if (rangeMatch != null) {
        final start = rangeMatch.group(1)!;
        final end = rangeMatch.group(2)!;
        return '$bookSpoken $chapter verses $start through $end';
      }

      // Comma-separated verses like 6,7,8.
      if (versesRaw.contains(',')) {
        final verseNums = versesRaw.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
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

  static List<TextSpan> formatContent(String content, {Color textColor = Colors.black}) {
    // DEBUG: Show first 200 chars of raw content (no-op in release)
    if (kDebugMode) print('DEBUG: Raw content (first 200 chars): ${content.substring(0, content.length > 200 ? 200 : content.length)}');
    
    // Remove reference numbers like [33], [34] before "Go to..." links
    content = content.replaceAll(
        RegExp(r'\[\d+\]Go To (Morning|Evening) Reading', caseSensitive: false), '');
    
    // Remove separator lines (lines with only underscores or dashes)
    content = content.replaceAll(RegExp(r'^_{10,}$', multiLine: true), '');
    
    // Format Bible verses: Remove dash and move reference to next line
    // Pattern: "text"-Book Chapter:Verse or "text."-Book Chapter:Verse
    // Also handle: "text" Book Chapter:Verse (with space instead of dash)
    // Replace with: "text"\nReference\n\n (single newline between verse and reference, double after reference)
    // Handle both double and single quotes separately
    // Pattern for verse reference: can start with number (1 Chronicles) or word (John), may have "of" (Song of Solomon)
    // Full pattern: (optional number + space) + book name (may include "of Book") + space + chapter:verse
    // Allow comma-separated verses and ranges:
    // - 1:12,13 or 1:12, 13
    // - 1:12-13 / 1:12–13 (with optional spaces around separators)
    final verseRefPattern =
        r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+))';
    
    // Pattern 1: With dash - "text."-Reference or "text"-Reference
    final doubleQuotePatternDash = RegExp(r'"([^"]+?)"(\.?)-(' + verseRefPattern + r')(\s|\n\n|\n|$)');
    final singleQuotePatternDash = RegExp(r"'([^']+?)'(\.?)-(" + verseRefPattern + r')(\s|\n\n|\n|$)');
    
    // Pattern 2: With space (no dash) - "text." Reference or "text" Reference (at start of line/paragraph)
    // This handles cases where verse and reference are on same line with just a space
    final doubleQuotePatternSpace = RegExp(r'^"([^"]+?)"(\.?)\s+(' + verseRefPattern + r')(\s|\n\n|\n|$)', multiLine: true);
    final singleQuotePatternSpace = RegExp(r"^'([^']+?)'(\.?)\s+(" + verseRefPattern + r')(\s|\n\n|\n|$)', multiLine: true);
    
    int replacementCount = 0;
    
    // Replace patterns with dash first
    content = content.replaceAllMapped(
      doubleQuotePatternDash,
      (match) {
        replacementCount++;
        final verseText = match.group(1) ?? '';
        final period = match.group(2) ?? '';
        final reference = match.group(3) ?? '';
        final afterRef = match.group(4) ?? '';
        if (verseText.isEmpty || reference.isEmpty) return match.group(0) ?? '';
        if (kDebugMode) print('DEBUG: Replacing double quote with dash #$replacementCount: "$verseText"$period-$reference');
        // Always put double newline after reference to separate it from body text
        // If afterRef is just whitespace or single newline, replace with double newline
        final cleanAfterRef = afterRef.trim();
        final replacement = '"$verseText$period"\n$reference\n\n';
        return replacement;
      },
    );
    
    content = content.replaceAllMapped(
      singleQuotePatternDash,
      (match) {
        replacementCount++;
        final verseText = match.group(1) ?? '';
        final period = match.group(2) ?? '';
        final reference = match.group(3) ?? '';
        final afterRef = match.group(4) ?? '';
        if (verseText.isEmpty || reference.isEmpty) return match.group(0) ?? '';
        if (kDebugMode) print('DEBUG: Replacing single quote with dash #$replacementCount: \'$verseText\'$period-$reference');
        // Always put double newline after reference to separate it from body text
        final replacement = "'$verseText$period'\n$reference\n\n";
        return replacement;
      },
    );
    
    // Replace patterns with space (no dash) - typically at beginning of devotions
    content = content.replaceAllMapped(
      doubleQuotePatternSpace,
      (match) {
        replacementCount++;
        final verseText = match.group(1) ?? '';
        final period = match.group(2) ?? '';
        final reference = match.group(3) ?? '';
        final afterRef = match.group(4) ?? '';
        if (verseText.isEmpty || reference.isEmpty) return match.group(0) ?? '';
        if (kDebugMode) print('DEBUG: Replacing double quote with space #$replacementCount: "$verseText"$period $reference');
        // Always put double newline after reference to separate it from body text
        final replacement = '"$verseText$period"\n$reference\n\n';
        return replacement;
      },
    );
    
    content = content.replaceAllMapped(
      singleQuotePatternSpace,
      (match) {
        replacementCount++;
        final verseText = match.group(1) ?? '';
        final period = match.group(2) ?? '';
        final reference = match.group(3) ?? '';
        final afterRef = match.group(4) ?? '';
        if (verseText.isEmpty || reference.isEmpty) return match.group(0) ?? '';
        if (kDebugMode) print('DEBUG: Replacing single quote with space #$replacementCount: \'$verseText\'$period $reference');
        // Always put double newline after reference to separate it from body text
        final replacement = "'$verseText$period'\n$reference\n\n";
        return replacement;
      },
    );
    
    if (kDebugMode) print('DEBUG: Total replacements made: $replacementCount');
    final previewLength = content.length > 200 ? 200 : content.length;
    if (kDebugMode) print('DEBUG: Content after replacement (first $previewLength chars): ${content.substring(0, previewLength)}');
    
    // IMMEDIATELY identify and extract verse-reference pairs before splitting
    // This ensures they're never mixed with body text
    final verseRefPatternForExtract =
        r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+))';
    // Don't use ^ and $ - match anywhere in content, but ensure it's at start of a line
    // NOTE:
    // - scripture quotes can span multiple lines; use [\s\S] so matches cross newlines
    // - some inputs have a blank line between the quote and the reference, so allow \n+
    final verseRefPairPattern = RegExp(
      '(["\'])([\\s\\S]+?)(["\']\\.?)\\n+' + verseRefPatternForExtract + r'(?=\n\n|\n|$)',
      multiLine: true,
    );
    final verseRefPairPatternNoPeriod = RegExp(
      '(["\'])([\\s\\S]+?)(["\'])\\n+' + verseRefPatternForExtract + r'(?=\n\n|\n|$)',
      multiLine: true,
    );
    
    // Find the first verse-reference pair in the content
    Match? firstVerseRefMatch;
    String? extractedVerse;
    String? extractedReference;
    
    // Try pattern without period first (most common after our replacement)
    firstVerseRefMatch = verseRefPairPatternNoPeriod.firstMatch(content);
    if (firstVerseRefMatch != null) {
      final quoteOpen = firstVerseRefMatch.group(1) ?? '"';
      final verseBodyRaw = firstVerseRefMatch.group(2) ?? '';
      final quoteClose = firstVerseRefMatch.group(3) ?? '"';
      // Normalize whitespace inside the verse so we don't show random hard-wrapped/blank lines.
      final verseBody = verseBodyRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
      extractedVerse = '$quoteOpen$verseBody$quoteClose';
      extractedReference = firstVerseRefMatch.group(4);
      if (kDebugMode) print('DEBUG: [EXTRACT] Found verse-reference pair (no period): verse="$extractedVerse", ref="$extractedReference"');
    } else {
      // Try pattern with optional period
      firstVerseRefMatch = verseRefPairPattern.firstMatch(content);
      if (firstVerseRefMatch != null) {
        final quoteOpen = firstVerseRefMatch.group(1) ?? '"';
        final verseBodyRaw = firstVerseRefMatch.group(2) ?? '';
        final quoteClose = firstVerseRefMatch.group(3) ?? '"';
        final verseBody = verseBodyRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
        extractedVerse = '$quoteOpen$verseBody$quoteClose';
        extractedReference = firstVerseRefMatch.group(4);
        if (kDebugMode) print('DEBUG: [EXTRACT] Found verse-reference pair (with period): verse="$extractedVerse", ref="$extractedReference"');
      }
    }
    
    // If we found a verse-reference pair, remove it from content and we'll add it back later
    String contentWithoutVerseRef = content;
    if (firstVerseRefMatch != null && extractedVerse != null && extractedReference != null) {
      // Remove the verse-reference pair from content (including the double newline after it)
      final verseRefText = firstVerseRefMatch.group(0) ?? '';
      // Try removing with double newline first
      if (content.contains(verseRefText + '\n\n')) {
        contentWithoutVerseRef = content.replaceFirst(verseRefText + '\n\n', '');
      } else if (content.contains(verseRefText + '\n')) {
        contentWithoutVerseRef = content.replaceFirst(verseRefText + '\n', '');
      } else {
        contentWithoutVerseRef = content.replaceFirst(verseRefText, '');
      }
      if (kDebugMode) print('DEBUG: [EXTRACT] Removed verse-reference pair from content, remaining length: ${contentWithoutVerseRef.length}');
    }
    
    // Split by double newlines for paragraphs
    var paragraphs = contentWithoutVerseRef.split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && !RegExp(r'^[_\-\s]+$').hasMatch(p))
        .toList();
    
    // PRE-FILTER: Identify the initial scripture reference before processing
    String? initialRefForFiltering;
    final verseRefPatternForFilter =
        r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+))';
    bool foundInitialRef = false;
    
    for (final para in paragraphs) {
      // Check for verse-reference pair pattern (verse\nreference)
      final verseRefPairPattern = RegExp('^(["\'])([\\s\\S]+?)(["\'])\\n+' + verseRefPatternForFilter + r'\$');
      final pairMatch = verseRefPairPattern.firstMatch(para);
      if (pairMatch != null) {
        final refMatch = RegExp(verseRefPatternForFilter).firstMatch(para);
        if (refMatch != null) {
          initialRefForFiltering = refMatch.group(1);
          foundInitialRef = true;
          break;
        }
      }
      
      // Check for verse-reference on same line (with dash or space)
      final sameLinePattern = RegExp('^(["\'])([\\s\\S]+?)(["\'])(\\.?)[\\s\\-]+' + verseRefPatternForFilter);
      final sameLineMatch = sameLinePattern.firstMatch(para);
      if (sameLineMatch != null) {
        final refMatch = RegExp(verseRefPatternForFilter).firstMatch(para);
        if (refMatch != null) {
          initialRefForFiltering = refMatch.group(1);
          foundInitialRef = true;
          break;
        }
      }
      
      // Check for standalone reference
      final standaloneRefPattern = RegExp('^' + verseRefPatternForFilter + r'\$');
      if (standaloneRefPattern.hasMatch(para) && initialRefForFiltering == null) {
        initialRefForFiltering = para.trim();
        foundInitialRef = true;
        break;
      }
    }
    
    // PRE-FILTER: Remove duplicate reference paragraphs BEFORE combining
    // Only remove duplicates AFTER we've found the initial reference
    if (foundInitialRef && initialRefForFiltering != null) {
      final escapedRef = initialRefForFiltering.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');
      final refPattern = RegExp('^\\s*' + escapedRef + r'\\s*$', caseSensitive: false);
      
      // Track if we've seen the verse-reference pair paragraph
      bool seenVerseRefPair = false;
      int removedCount = 0;
      
      paragraphs = paragraphs.where((para) {
        final trimmed = para.trim();
        
        // Check if this is the verse-reference pair paragraph (verse\nreference)
        final verseRefPairPattern = RegExp('^(["\'])(.+?)(["\'])\\n' + escapedRef + r'\$');
        if (verseRefPairPattern.hasMatch(trimmed)) {
          seenVerseRefPair = true;
          return true; // Keep the verse-reference pair
        }
        
        // After we've seen the verse-reference pair, remove any paragraphs that are just the reference
        if (seenVerseRefPair) {
          // Check if paragraph is exactly the reference
          if (trimmed == initialRefForFiltering || refPattern.hasMatch(trimmed)) {
            removedCount++;
            if (kDebugMode) print('DEBUG: [PRE-FILTER] Removing duplicate reference paragraph #$removedCount after verse-ref pair: $trimmed');
            return false;
          }
          // Also check if paragraph contains the reference as a standalone line
          final lines = para.split('\n');
          for (final line in lines) {
            final lineTrimmed = line.trim();
            if (lineTrimmed == initialRefForFiltering || refPattern.hasMatch(lineTrimmed)) {
              // If it's a single-line paragraph that's just the reference, remove it
              if (lines.length == 1) {
                removedCount++;
                if (kDebugMode) print('DEBUG: [PRE-FILTER] Removing single-line reference paragraph #$removedCount after verse-ref pair: $trimmed');
                return false;
              }
            }
          }
        }
        
        return true;
      }).toList();
      
      if (kDebugMode) print('DEBUG: [PRE-FILTER] Removed $removedCount duplicate reference paragraphs');
    }
    
    // First pass: Combine consecutive poem lines (short lines, often starting with quote) into single paragraphs
    final combinedParagraphs = <String>[];
    int i = 0;
    while (i < paragraphs.length) {
      String para = paragraphs[i];
      
      // Check if this is a potential poem line (short, may start with quote)
      final isPotentialPoemLine = para.length < 100 && !para.contains('\n');
      final startsWithQuote = para.startsWith('"') || para.startsWith("'");
      
      if (isPotentialPoemLine && startsWithQuote) {
        // Collect consecutive poem lines (short lines that follow)
        final poemLines = <String>[];
        int j = i;
        while (j < paragraphs.length) {
          final currentPara = paragraphs[j];
          final isShortLine = currentPara.length < 100 && !currentPara.contains('\n');
          if (isShortLine) {
            poemLines.add(currentPara.trim());
            j++;
            // Stop if we hit a line that ends with a quote (end of poem)
            if (currentPara.trim().endsWith('"') || currentPara.trim().endsWith("'") ||
                currentPara.trim().endsWith('".') || currentPara.trim().endsWith("'.")) {
              break;
            }
          } else {
            break;
          }
        }
        
        // If we found multiple consecutive poem lines, combine them
        if (poemLines.length > 1) {
          combinedParagraphs.add(poemLines.join('\n'));
          i = j; // Skip all the poem lines we just combined
          continue;
        }
      }
      
      // Not a poem, process normally
      // CRITICAL: Check for verse-reference pair FIRST, before any modifications
      final verseRefPattern = r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+)';
      
      // Pattern 1: Check without period first (most common: "verse"\nreference)
      final verseRefMatchNoPeriod = RegExp('^(["\'])(.+?)(["\'])\\n' + verseRefPattern + r'\$').firstMatch(para);
      // Pattern 2: Check with optional period ("verse".\nreference)
      final verseRefMatchWithPeriod = RegExp('^(["\'])(.+?)(["\']\\.?)\\n' + verseRefPattern + r'\$').firstMatch(para);
      final hasVerseRef = verseRefMatchNoPeriod != null || verseRefMatchWithPeriod != null;
      
      if (hasVerseRef) {
        if (kDebugMode) print('DEBUG: [COMBINING PHASE] Found verse-reference pair: $para');
        // Keep verse-reference pairs intact - don't collapse newlines
        // Add to combined paragraphs as-is
        combinedParagraphs.add(para);
        i++;
        continue;
      }
      
      // Check if this is a poem/song (multiple short lines with quotes)
      final lines = para.split('\n');
      final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).toList();
      final isPoem = nonEmptyLines.length > 1 && 
                     nonEmptyLines.every((line) => line.trim().startsWith('"') || 
                                                      line.trim().startsWith("'")) &&
                     para.length < 400;
      
      if (isPoem) {
        // For poems, keep the line structure but normalize spacing (remove empty lines)
        para = nonEmptyLines.map((line) => line.trim()).join('\n');
      } else {
        // For regular paragraphs, collapse newlines to spaces
        para = para.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }
      
      // Check if this paragraph starts with a quote but doesn't end with one
      final paraStartsWithQuote = para.startsWith('"') || para.startsWith("'");
      final endsWithQuote = para.endsWith('"') || para.endsWith("'") || 
                           para.endsWith('".') || para.endsWith("'.");
      
      if (paraStartsWithQuote && !endsWithQuote && i + 1 < paragraphs.length) {
        // Try to combine with next paragraph
        String nextPara = paragraphs[i + 1]
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (nextPara.endsWith('"') || nextPara.endsWith("'") || 
            nextPara.endsWith('".') || nextPara.endsWith("'.")) {
          para = '$para $nextPara';
          i++; // Skip the next paragraph since we combined it
        }
      }
      
      // Check if paragraph ends without proper sentence-ending punctuation
      // This indicates it might be a sentence split across paragraphs
      if (!hasVerseRef && !isPoem && i + 1 < paragraphs.length) {
        final trimmedPara = para.trim();
        // Check if paragraph ends with proper sentence-ending punctuation
        final endsWithPunctuation = trimmedPara.endsWith('.') || 
                                    trimmedPara.endsWith('!') || 
                                    trimmedPara.endsWith('?') ||
                                    trimmedPara.endsWith('."') ||
                                    trimmedPara.endsWith('!"') ||
                                    trimmedPara.endsWith('?"') ||
                                    trimmedPara.endsWith(".'") ||
                                    trimmedPara.endsWith("!'") ||
                                    trimmedPara.endsWith("?'");
        
        if (!endsWithPunctuation) {
          // Check if next paragraph is a continuation
          String nextPara = paragraphs[i + 1].trim();
          
          // Skip if next paragraph is a verse reference
          final nextIsVerseRef = RegExp(r'^((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+)$').hasMatch(nextPara);
          
          // Skip if next paragraph starts with a quote (likely a new sentence/quote)
          final nextStartsWithQuote = nextPara.startsWith('"') || nextPara.startsWith("'");
          
          if (!nextIsVerseRef && !nextStartsWithQuote) {
            // Check if the last word of current paragraph suggests continuation
            // Words like "owe", "not", "does", "is", "are", "has", "have", "will", "can", "may", etc.
            final lastWords = trimmedPara.split(' ').where((w) => w.isNotEmpty).toList();
            final lastWord = lastWords.isNotEmpty ? lastWords.last.toLowerCase().replaceAll(RegExp(r'[^\w]'), '') : '';
            final continuationWords = ['owe', 'not', 'does', 'is', 'are', 'has', 'have', 'will', 'can', 'may', 
                                      'should', 'could', 'would', 'must', 'might', 'to', 'the', 'a', 'an', 'and', 'or', 'but'];
            final likelyContinuation = continuationWords.contains(lastWord);
            
            // Check if next paragraph starts with a capital letter
            final nextStartsWithCapital = nextPara.isNotEmpty && 
                                       nextPara[0] == nextPara[0].toUpperCase() && 
                                       nextPara[0] != nextPara[0].toLowerCase();
            
            // Get first word of next paragraph (might be capitalized proper noun like "God's")
            final nextFirstWords = nextPara.split(' ').where((w) => w.isNotEmpty).take(2).toList();
            final nextFirstWord = nextFirstWords.isNotEmpty ? nextFirstWords[0].toLowerCase().replaceAll(RegExp(r'[^\w]'), '') : '';
            
            // Check if first word of next paragraph is a common continuation word (even if capitalized)
            final nextIsContinuationWord = ['god', 'his', 'her', 'their', 'our', 'my', 'your', 'its', 'the', 'a', 'an', 
                                           'this', 'that', 'these', 'those', 'what', 'which', 'who', 'whom', 'whose',
                                           'anything', 'something', 'nothing', 'everything'].contains(nextFirstWord);
            
            // Combine if:
            // 1. Current paragraph ends with a continuation word (like "owe", "not", etc.)
            // 2. OR next paragraph doesn't start with capital (continuation of sentence)
            // 3. OR next paragraph starts with a continuation word (even if capitalized like "God's")
            // 4. OR next paragraph is very short (likely a continuation)
            if (likelyContinuation || !nextStartsWithCapital || nextIsContinuationWord || nextPara.length < 50) {
              // Combine the paragraphs - this is likely a sentence continuation
              nextPara = nextPara.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
              para = '$para $nextPara';
              i++; // Skip the next paragraph since we combined it
              // Re-check if the combined paragraph still needs more combining
              // (in case the sentence continues across multiple paragraphs)
              // We'll let the loop continue to check again
            }
          }
        }
      }
      
      combinedParagraphs.add(para);
      i++;
    }
    
    // Build TextSpan list
    final spans = <TextSpan>[];
    bool hasSeenInitialVerseRef = false; // Track if we've seen the initial verse-reference pair
    String? initialReference; // Store the initial reference to remove duplicates
    
    // If we extracted a verse-reference pair earlier, output it FIRST before processing any paragraphs
    if (extractedVerse != null && extractedReference != null) {
      hasSeenInitialVerseRef = true;
      initialReference = extractedReference;
      final displayReference = _normalizeReferenceDisplay(extractedReference);
      // Output verse on its own line (scripture verse)
      spans.add(TextSpan(
        text: '$extractedVerse\n',
        style: GoogleFonts.inter(
          fontStyle: FontStyle.italic,
          fontSize: 16,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      // Output reference on the next line (scripture reference)
      spans.add(TextSpan(
        text: '$displayReference\n\n',
        semanticsLabel: bibleReferenceSemanticsLabel(displayReference) ?? displayReference,
        style: GoogleFonts.inter(
          fontStyle: FontStyle.italic,
          fontSize: 16,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      if (kDebugMode) print('DEBUG: [OUTPUT] Output extracted verse-reference pair first: verse="$extractedVerse", ref="$extractedReference"');
    }
    
    // FIRST PASS: Identify the initial reference from the verse-reference pair
    for (int idx = 0; idx < combinedParagraphs.length; idx++) {
      final para = combinedParagraphs[idx];
      if (para.isEmpty) continue;
      
      // Check if this paragraph contains a verse-reference pair
      final verseRefPattern2 =
          r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+))';
      // Pattern 1: verse with optional period before quote, then newline, then reference
      final verseRefPatternRegex = RegExp('^(["\'])(.+?)(["\']\\.?)\\n' + verseRefPattern2 + r'\$');
      Match? verseRefMatch = verseRefPatternRegex.firstMatch(para);
      bool hasVerseRef = verseRefMatch != null;
      
      // Pattern 1b: Also check without period (more flexible)
      if (!hasVerseRef) {
        final verseRefPatternNoPeriod = RegExp('^(["\'])(.+?)(["\'])\\n' + verseRefPattern2 + r'\$');
        final noPeriodMatch = verseRefPatternNoPeriod.firstMatch(para);
        if (noPeriodMatch != null) {
          hasVerseRef = true;
          verseRefMatch = noPeriodMatch;
        }
      }
      
      // Pattern 2: verse-reference on same line (with dash or space) - split them
      if (!hasVerseRef) {
        final sameLinePattern = RegExp('^(["\'])(.+?)(["\'])(\\.?)[\\s\\-]+' + verseRefPattern2 + r'(.*)$');
        final sameLineMatch = sameLinePattern.firstMatch(para);
        if (sameLineMatch != null) {
          final reference = sameLineMatch.group(5);
          if (reference != null) {
            initialReference = reference.trim();
            break; // Found the initial reference, stop looking
          }
        }
      } else {
        final verseRefParts = para.split('\n');
        if (verseRefParts.length >= 2) {
          initialReference = verseRefParts[1].trim();
          break; // Found the initial reference, stop looking
        }
      }
      
      // Also check if it's a standalone reference
      final simpleVerseRef = RegExp(r'^[A-Z][a-zA-Z]+\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+)$');
      final multiWordVerseRef =
          RegExp(r'^[A-Z][a-zA-Z\s]+(\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+)$');
      final numberedBookPattern = RegExp(r'^\d+\s+[A-Z][a-zA-Z\s]+\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+)$');
      final numberedWithOf =
          RegExp(r'^\d+\s+[A-Z][a-zA-Z\s]+(\s+of\s+[A-Z][a-zA-Z]+)?\s+(?:\d+:\d+(?:\s*[,\u2013\u2014-]\s*\d+)*|\d+)$');
      final isVerseRef = simpleVerseRef.hasMatch(para) ||
          multiWordVerseRef.hasMatch(para) ||
          numberedBookPattern.hasMatch(para) ||
          numberedWithOf.hasMatch(para);
      
      if (isVerseRef && initialReference == null) {
        initialReference = para.trim();
        break;
      }
    }
    
    // Collect all regular body paragraphs into one continuous paragraph
    final bodyParagraphs = <String>[];
    final poemParagraphs = <String>[];
    
    for (int index = 0; index < combinedParagraphs.length; index++) {
      String para = combinedParagraphs[index];
      
      if (para.isEmpty) continue;
      
      // ULTRA-AGGRESSIVE DUPLICATE DETECTION: After we've output the verse-reference pair,
      // skip ANY paragraph that contains the reference as a standalone element
      if (hasSeenInitialVerseRef && initialReference != null) {
        final trimmedPara = para.trim();
        final escapedRef = initialReference.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');
        
        // Check if paragraph is exactly the reference
        if (trimmedPara == initialReference) {
          if (kDebugMode) print('DEBUG: [ULTRA-AGGRESSIVE] Skipping duplicate reference paragraph: $para');
          continue;
        }
        
        // Check if paragraph matches reference pattern (with optional whitespace)
        if (RegExp('^\\s*' + escapedRef + r'\\s*$', caseSensitive: false).hasMatch(trimmedPara)) {
          if (kDebugMode) print('DEBUG: [ULTRA-AGGRESSIVE] Skipping paragraph matching reference pattern: $para');
          continue;
        }
        
        // Check if paragraph starts with the reference (possibly followed by text)
        // This catches cases where the reference appears at the start of a paragraph
        if (RegExp('^\\s*' + escapedRef + r'\\s+', caseSensitive: false).hasMatch(trimmedPara)) {
          // Remove the reference from the start and keep the rest as body text
          para = trimmedPara.replaceFirst(RegExp('^\\s*' + escapedRef + r'\\s+', caseSensitive: false), '').trim();
          if (para.isEmpty) {
            if (kDebugMode) print('DEBUG: [ULTRA-AGGRESSIVE] Paragraph became empty after removing reference, skipping: $trimmedPara');
            continue;
          }
          // Continue processing with the cleaned paragraph
        }
        
        // Check if any line in paragraph is just the reference
        final lines = para.split('\n');
        final filteredLines = <String>[];
        bool foundRefLine = false;
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine == initialReference) {
            foundRefLine = true;
            if (kDebugMode) print('DEBUG: [ULTRA-AGGRESSIVE] Removing reference line from paragraph: $trimmedLine');
            continue; // Skip this line
          }
          // Also check if line matches reference pattern
          if (RegExp('^\\s*' + escapedRef + r'\\s*$', caseSensitive: false).hasMatch(trimmedLine)) {
            foundRefLine = true;
            if (kDebugMode) print('DEBUG: [ULTRA-AGGRESSIVE] Removing reference line (pattern match): $trimmedLine');
            continue; // Skip this line
          }
          filteredLines.add(line);
        }
        if (foundRefLine) {
          para = filteredLines.join('\n').trim();
          if (para.isEmpty) {
            if (kDebugMode) print('DEBUG: [ULTRA-AGGRESSIVE] Paragraph became empty after removing reference lines, skipping');
            continue;
          }
        }
      }
      
      // Check if this paragraph contains a verse-reference pair
      // IMPORTANT: Check this BEFORE any processing that might modify the paragraph
      final verseRefPattern2 = r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+)';
      
      // Pattern 1: verse with optional period, then newline, then reference (most common after formatting)
      // This matches: "verse".\nreference OR "verse"\nreference
      final verseRefPatternRegex = RegExp('^(["\'])([\\s\\S]+?)(["\']\\.?)\\n+' + verseRefPattern2 + r'\$');
      Match? verseRefMatch = verseRefPatternRegex.firstMatch(para);
      bool hasVerseRef = verseRefMatch != null;
      
      // Pattern 1b: Check without period FIRST (handles "verse"\nreference - most common case)
      if (!hasVerseRef) {
        final verseRefPatternNoPeriod = RegExp('^(["\'])([\\s\\S]+?)(["\'])\\n+' + verseRefPattern2 + r'\$');
        final noPeriodMatch = verseRefPatternNoPeriod.firstMatch(para);
        if (noPeriodMatch != null) {
          hasVerseRef = true;
          verseRefMatch = noPeriodMatch;
          if (kDebugMode) print('DEBUG: Found verse-reference pair (no period pattern): $para');
        }
      }
      
      // Pattern 2: verse-reference on same line (with dash or space) - split them
      // This handles cases that weren't formatted yet
      if (!hasVerseRef) {
        final sameLinePattern = RegExp('^(["\'])([\\s\\S]+?)(["\'])(\\.?)[\\s\\-]+' + verseRefPattern2 + r'(.*)$');
        final sameLineMatch = sameLinePattern.firstMatch(para);
        if (sameLineMatch != null) {
          final quoteChar = sameLineMatch.group(1);
          final verseText = sameLineMatch.group(2);
          final period = sameLineMatch.group(4) ?? '';
          final reference = sameLineMatch.group(5);
          final restOfPara = sameLineMatch.group(6) ?? '';
          
          if (quoteChar != null && verseText != null && reference != null) {
            para = '$quoteChar$verseText$period$quoteChar\n$reference$restOfPara';
            hasVerseRef = true;
            verseRefMatch = verseRefPatternRegex.firstMatch(para);
            if (kDebugMode) print('DEBUG: Found verse-reference on same line, split it: $para');
          }
        }
      }
      
      if (hasVerseRef && verseRefMatch != null) {
        if (kDebugMode) print('DEBUG: Detected verse-reference pair: verse="${verseRefMatch.group(2)}", ref="${verseRefMatch.group(4)}"');
      }
      
      // Check if it's a quoted scripture verse
      final startsWithQuote2 = para.startsWith('"') || para.startsWith("'");
      final endsWithQuote2 = para.endsWith('"') || para.endsWith("'") || 
                            para.endsWith('".') || para.endsWith("'.");
      final isQuotedVerse = startsWithQuote2 && endsWithQuote2 && para.length < 600 && index < 8;
      
      // Check if it's a scripture verse reference
      final simpleVerseRef = RegExp(r'^[A-Z][a-zA-Z]+\s+\d+:\d+$');
      final multiWordVerseRef = RegExp(r'^[A-Z][a-zA-Z\s]+(\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+$');
      final numberedBookPattern = RegExp(r'^\d+\s+[A-Z][a-zA-Z\s]+\s+\d+:\d+$');
      final numberedWithOf = RegExp(r'^\d+\s+[A-Z][a-zA-Z\s]+(\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+$');
      
      final isVerseRef = simpleVerseRef.hasMatch(para) ||
          multiWordVerseRef.hasMatch(para) ||
          numberedBookPattern.hasMatch(para) ||
          numberedWithOf.hasMatch(para);
      
      final startsWithQuote3 = para.startsWith('"') || para.startsWith("'");
      final isEarlyQuoted = startsWithQuote3 && index < 2 && para.length < 400 && !para.contains('\n');
      
      // If we've already seen the initial verse-reference, don't treat subsequent references as scripture
      // They should be removed from body text instead
      final isScripture = !hasSeenInitialVerseRef && (isVerseRef || isQuotedVerse || isEarlyQuoted);
      
      // Also check if this paragraph is just the reference we've already seen
      // Check both the full paragraph and individual lines
      if (hasSeenInitialVerseRef && initialReference != null) {
        final trimmedPara = para.trim();
        // Check if the entire paragraph is just the reference
        if (trimmedPara == initialReference) {
          if (kDebugMode) print('DEBUG: Skipping duplicate reference paragraph: $para');
          continue;
        }
        // Check if any line in the paragraph is just the reference
        final lines = para.split('\n');
        final isJustReference = lines.length == 1 && lines[0].trim() == initialReference;
        if (isJustReference) {
          if (kDebugMode) print('DEBUG: Skipping paragraph that is just the reference: $para');
          continue;
        }
        // Check if the paragraph starts with the reference (possibly with whitespace)
        final escapedRef = initialReference.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');
        final startsWithRef = RegExp('^\\s*' + escapedRef + r'\\s*$', caseSensitive: false).hasMatch(trimmedPara);
        if (startsWithRef) {
          if (kDebugMode) print('DEBUG: Skipping paragraph that starts with reference: $para');
          continue;
        }
      }
      
      // Check if this is a poem (multiple lines, often starting with quote, short lines)
      final paraLines = para.split('\n');
      final nonEmptyParaLines = paraLines.where((line) => line.trim().isNotEmpty).toList();
      final firstLineStartsQuote = nonEmptyParaLines.isNotEmpty && 
                                   (nonEmptyParaLines.first.trim().startsWith('"') || 
                                    nonEmptyParaLines.first.trim().startsWith("'"));
      final lastLineEndsQuote = nonEmptyParaLines.isNotEmpty && 
                                (nonEmptyParaLines.last.trim().endsWith('"') || 
                                 nonEmptyParaLines.last.trim().endsWith("'") ||
                                 nonEmptyParaLines.last.trim().endsWith('".') || 
                                 nonEmptyParaLines.last.trim().endsWith("'."));
      final allLinesShort = nonEmptyParaLines.every((line) => line.trim().length < 100);
      final isPoem = !hasVerseRef && 
                     nonEmptyParaLines.length > 1 && 
                     firstLineStartsQuote && 
                     lastLineEndsQuote &&
                     allLinesShort &&
                     para.length < 400;
      
      // Handle verse-reference pairs first
      if (hasVerseRef) {
        final verseRefParts = para.split('\n');
        if (verseRefParts.length >= 2) {
          final verse = verseRefParts[0].trim();
          final reference = verseRefParts[1].trim();
          final displayReference = _normalizeReferenceDisplay(reference);
          // Mark that we've seen the initial verse-reference pair and store the reference
          hasSeenInitialVerseRef = true;
          initialReference = reference;
          // Output verse on its own line (scripture verse)
          spans.add(TextSpan(
            text: '$verse\n',
            style: GoogleFonts.inter(
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ));
          // Output reference on the next line (scripture reference) - ONLY ONCE
          spans.add(TextSpan(
            text: '$displayReference\n\n',
            semanticsLabel: bibleReferenceSemanticsLabel(displayReference) ?? displayReference,
            style: GoogleFonts.inter(
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ));
          // CRITICAL: Skip to next paragraph - we've output the verse-reference pair
          // Also mark that we've output this reference so it never appears again
          continue;
        }
      } else if (isScripture) {
        // Scripture: verse or reference (only if it's the initial one)
        if (!hasSeenInitialVerseRef) {
          hasSeenInitialVerseRef = true;
          if (isVerseRef) {
            initialReference = para.trim();
          }
          final displayPara = isVerseRef ? _normalizeReferenceDisplay(para) : para;
          spans.add(TextSpan(
            text: '$displayPara\n\n',
            semanticsLabel: isVerseRef ? (bibleReferenceSemanticsLabel(displayPara) ?? displayPara) : null,
            style: GoogleFonts.inter(
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ));
        } else {
          // This is a duplicate scripture reference (we've already seen the initial one), skip it
          if (kDebugMode) print('DEBUG: Skipping duplicate scripture reference: $para');
          continue;
        }
      } else if (hasSeenInitialVerseRef && initialReference != null && isVerseRef) {
        // After we've seen the initial verse-reference, check if this paragraph is just a duplicate reference
        // If this is a standalone reference paragraph, skip it
        if (kDebugMode) print('DEBUG: Skipping duplicate reference that appears as separate paragraph: $para');
        continue;
      } else if (isPoem) {
        // Collect poems separately (they appear at the bottom)
        poemParagraphs.add(para);
      } else {
        // Regular body text - remove duplicate references and collect
        if (hasSeenInitialVerseRef && initialReference != null) {
          // Remove references that appear anywhere in the paragraph (not just at start)
          final escapedRef = initialReference.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');
          
          // Remove references that appear at the start of body paragraphs (possibly repeated)
          final startsWithRefPattern = RegExp('^\\s*' + escapedRef + r'(?:\s+' + escapedRef + r')*\s*', caseSensitive: false);
          if (startsWithRefPattern.hasMatch(para)) {
            para = para.replaceFirst(startsWithRefPattern, '').trim();
            if (para.isEmpty) continue;
          }
          
          // Also check for references on their own lines anywhere in the paragraph
          final lines = para.split('\n');
          final filteredLines = <String>[];
          for (final line in lines) {
            var processedLine = line.trim();
            // Skip lines that are exactly the reference
            if (processedLine == initialReference) {
              if (kDebugMode) print('DEBUG: Removing duplicate reference line from body: $processedLine');
              continue;
            }
            // Skip lines that are just the reference repeated (with or without spaces)
            if (RegExp('^\\s*' + escapedRef + r'(?:\s+' + escapedRef + r')*\\s*$', caseSensitive: false).hasMatch(processedLine)) {
              if (kDebugMode) print('DEBUG: Removing duplicate reference line (repeated) from body: $processedLine');
              continue;
            }
            // Also remove the reference if it appears at the start of a line (even if there's more text)
            final lineStartsWithRef = RegExp('^\\s*' + escapedRef + r'\\s+', caseSensitive: false);
            if (lineStartsWithRef.hasMatch(processedLine)) {
              processedLine = processedLine.replaceFirst(lineStartsWithRef, '').trim();
              if (processedLine.isEmpty) {
                if (kDebugMode) print('DEBUG: Removing line that starts with reference from body: $line');
                continue;
              }
            }
            filteredLines.add(processedLine.isEmpty ? line : processedLine);
          }
          para = filteredLines.join('\n').trim();
          if (para.isEmpty) continue;
          
          // Also remove any standalone references that appear in the middle of the paragraph
          // (references surrounded by whitespace or at paragraph boundaries)
          final standaloneRefPattern = RegExp(r'(?:^|\s+)' + escapedRef + r'(?:\s+|$)', caseSensitive: false);
          para = para.replaceAll(standaloneRefPattern, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (para.isEmpty) continue;
        }
        
        // Collect regular body paragraphs (not scripture, not poems)
        bodyParagraphs.add(para);
      }
    }
    
    // Output all body paragraphs (Roboto 18sp w700)
    if (bodyParagraphs.isNotEmpty) {
      final combinedBody = bodyParagraphs.join(' ').trim();
      spans.add(TextSpan(
        text: '$combinedBody\n\n',
        style: GoogleFonts.inter(
          fontSize: 18,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ));
    }
    
    // Output poems at the end (Inter 18sp w700)
    for (final poemPara in poemParagraphs) {
      final paraLines = poemPara.split('\n');
      final nonEmptyParaLines = paraLines.where((line) => line.trim().isNotEmpty).toList();
      for (int i = 0; i < nonEmptyParaLines.length; i++) {
        final line = nonEmptyParaLines[i].trim();
        spans.add(TextSpan(
          text: '$line${i < nonEmptyParaLines.length - 1 ? '\n' : '\n\n'}',
          style: GoogleFonts.inter(
            fontSize: 18,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ));
      }
    }
    
    return spans;
  }
}
