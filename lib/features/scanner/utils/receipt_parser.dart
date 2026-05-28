import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptParser {
  static Map<String, dynamic> parse(RecognizedText recognizedText) {
    // 1. Visually stitch the columns back into horizontal rows using Intersection!
    final lines = _reconstructLines(recognizedText);
    final rawText = recognizedText.text;

    // --- DEBUGGING ---
    debugPrint("=== RECONSTRUCTED RECEIPT LINES ===");
    for (var line in lines) {
      debugPrint(line);
    }
    debugPrint("===================================");
    // -----------------

    if (lines.isEmpty) return {};

    final items = _extractItems(lines);
    double extractedTotal = _extractTotal(lines, rawText);

    double calculatedItemsSum = items.fold(
      0.0,
      (sum, item) => sum + item['price'],
    );
    if (calculatedItemsSum > extractedTotal) {
      extractedTotal = calculatedItemsSum;
    }

    return {
      'merchant_name': _extractMerchant(lines),
      'total_amount': extractedTotal,
      'date': _extractDate(rawText),
      'items': items,
    };
  }

  /// BOUNDING BOX INTERSECTION: The ultimate fix for slanted receipt tables.
  static List<String> _reconstructLines(RecognizedText recognizedText) {
    List<Map<String, dynamic>> elements = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        elements.add({
          'text': line.text.trim(),
          'top': line.boundingBox.top,
          'bottom': line.boundingBox.bottom,
          'left': line.boundingBox.left,
        });
      }
    }

    if (elements.isEmpty) return [];

    // 1. Sort all words from Top to Bottom
    elements.sort((a, b) => a['top'].compareTo(b['top']));

    List<List<Map<String, dynamic>>> rows = [];

    // 2. Snap words into rows if their vertical heights overlap
    for (var el in elements) {
      bool addedToRow = false;

      for (var row in rows) {
        // Find the absolute highest and lowest points of the current row
        double rowTop = row
            .map((e) => e['top'])
            .reduce((a, b) => a < b ? a : b);
        double rowBottom = row
            .map((e) => e['bottom'])
            .reduce((a, b) => a > b ? a : b);

        // Calculate the vertical center of the current word
        double elCenter = (el['top'] + el['bottom']) / 2;

        // If the center of the word falls inside the row, it belongs to this row!
        if (elCenter >= rowTop && elCenter <= rowBottom) {
          row.add(el);
          addedToRow = true;
          break;
        }
      }

      if (!addedToRow) {
        rows.add([el]);
      }
    }

    // 3. Sort each row Left to Right, then join with spaces
    List<String> reconstructed = [];
    for (var row in rows) {
      row.sort((a, b) => a['left'].compareTo(b['left']));
      reconstructed.add(row.map((e) => e['text']).join(' '));
    }

    return reconstructed;
  }

  static List<Map<String, dynamic>> _extractItems(List<String> lines) {
    List<Map<String, dynamic>> items = [];

    // Upgraded Regex: Handles spaces inside decimals (e.g., 40 . 00 or 40, 00)
    final decimalRegex = RegExp(r'\b\d+\s*[.,]\s*\d{2}\b');

    final explicitQtyRegex = RegExp(
      r'\b(\d+)\s*[xX]\b|\b[xX]\s*(\d+)\b|\b(?:qty|qty\.|quantity|qnty)[:.]?\s*(\d+)\b',
      caseSensitive: false,
    );
    final standaloneIntRegex = RegExp(r'(?<![a-zA-Z])\b\d+\b(?![a-zA-Z])');

    final excludeKeywords = [
      'total',
      'subtotal',
      'tax',
      'vat',
      'change',
      'cash',
      'card',
      'visa',
      'mastercard',
      'balance',
      'due',
      'amount',
      'summary',
      'particulars',
    ];

    for (String line in lines) {
      final lowerLine = line.toLowerCase();

      if (excludeKeywords.any((keyword) => lowerLine.contains(keyword))) {
        if (lowerLine.startsWith('total') || lowerLine.contains('grand total'))
          continue;
      }

      final decimalMatches = decimalRegex.allMatches(line).toList();
      if (decimalMatches.isEmpty) continue;

      List<double> prices = decimalMatches
          .map((m) => _parseAmount(m.group(0)!))
          .toList();
      double totalItemPrice = prices.last;

      String qtyStrippedText = line;
      for (var match in decimalMatches) {
        qtyStrippedText = qtyStrippedText.replaceFirst(match.group(0)!, ' ');
      }

      int quantity = 1;
      var qtyMatch = explicitQtyRegex.firstMatch(qtyStrippedText);

      if (qtyMatch != null) {
        String? qtyStr =
            qtyMatch.group(1) ?? qtyMatch.group(2) ?? qtyMatch.group(3);
        if (qtyStr != null) quantity = int.tryParse(qtyStr) ?? 1;
      } else {
        final intMatches = standaloneIntRegex
            .allMatches(qtyStrippedText)
            .toList();
        if (intMatches.isNotEmpty) {
          quantity = int.tryParse(intMatches.last.group(0)!) ?? 1;
        }
      }

      // ISOLATE NAME
      String itemName = line;
      for (var match in decimalMatches) {
        itemName = itemName.replaceFirst(match.group(0)!, '');
      }
      if (qtyMatch != null) {
        itemName = itemName.replaceFirst(qtyMatch.group(0)!, '');
      } else {
        final intMatches = standaloneIntRegex.allMatches(itemName).toList();
        if (intMatches.isNotEmpty)
          itemName = itemName.replaceFirst(intMatches.last.group(0)!, '');
      }

      itemName = itemName
          .replaceAll(
            RegExp(
              r'\b(?:qty|rate|price|unit|total|amt|val)[:.]?',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'[xX\*\/\|\-\+\=\@\:\(\)]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // If a valid name survived the cleaning process, save the item!
      if (itemName.isNotEmpty && itemName.length > 1) {
        items.add({
          'name': itemName,
          'quantity': quantity,
          'price': totalItemPrice,
        });
      }
    }

    return items;
  }

  static String _extractMerchant(List<String> lines) {
    final ignoreWords = [
      'date',
      'time',
      'bill',
      'receipt',
      'tax',
      'particulars',
      'qty',
      'amount',
      'rate',
    ];
    for (String line in lines) {
      final lowerLine = line.toLowerCase();
      if (line.length > 3 &&
          !line.contains(RegExp(r'^\d+$')) &&
          !ignoreWords.any((word) => lowerLine.contains(word))) {
        return line;
      }
    }
    return 'Unknown Merchant';
  }

  static double _extractTotal(List<String> lines, String rawText) {
    double highestTotal = 0.0;
    final amountRegex = RegExp(r'\b\d+\s*[.,]\s*\d{2}\b');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('total') ||
          line.contains('amount due') ||
          line.contains('balance')) {
        final match = amountRegex.firstMatch(lines[i]);
        if (match != null) {
          final amount = _parseAmount(match.group(0)!);
          if (amount > highestTotal) highestTotal = amount;
        }
      }
    }
    return highestTotal;
  }

  static String? _extractDate(String rawText) {
    final dateRegex = RegExp(r'\b(\d{1,4}[-/]\d{1,2}[-/]\d{1,4})\b');
    final match = dateRegex.firstMatch(rawText);
    return match != null ? match.group(0) : null;
  }

  static double _parseAmount(String amountStr) {
    try {
      // Clean up random OCR spaces inside decimals (e.g. "40 . 00" -> "40.00")
      String clean = amountStr.replaceAll(' ', '').replaceAll(',', '.');
      if (clean.indexOf('.') != clean.lastIndexOf('.'))
        clean = clean.replaceFirst('.', '');
      return double.parse(clean);
    } catch (e) {
      return 0.0;
    }
  }
}
