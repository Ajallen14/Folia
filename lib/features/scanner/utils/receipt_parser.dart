import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptParser {
  static Map<String, dynamic> parse(RecognizedText recognizedText) {
    final lines = _rebuildLinesFromWords(recognizedText);
    final rawText = recognizedText.text;

    // --- DEBUGGING ---
    debugPrint("=== REBUILT RECEIPT LINES ===");
    for (var line in lines) debugPrint(line);
    debugPrint("=============================");
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

  static List<String> _rebuildLinesFromWords(RecognizedText recognizedText) {
    List<Map<String, dynamic>> words = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        for (TextElement element in line.elements) {
          words.add({
            'text': element.text.trim(),
            'yCenter':
                element.boundingBox.top + (element.boundingBox.height / 2),
            'xStart': element.boundingBox.left,
            'height': element.boundingBox.height,
          });
        }
      }
    }

    if (words.isEmpty) return [];

    words.sort((a, b) => a['xStart'].compareTo(b['xStart']));

    List<List<Map<String, dynamic>>> rows = [];

    for (var word in words) {
      List<Map<String, dynamic>>? bestRow;
      double minDiff = double.infinity;
      double threshold = word['height'] * 0.8;

      for (var row in rows) {
        var lastWord = row.last;
        double yDiff = (word['yCenter'] - lastWord['yCenter']).abs();

        if (yDiff < threshold && yDiff < minDiff) {
          minDiff = yDiff;
          bestRow = row;
        }
      }

      if (bestRow != null) {
        bestRow.add(word);
      } else {
        rows.add([word]);
      }
    }

    rows.sort((a, b) {
      double aY = a.map((e) => e['yCenter']).reduce((x, y) => x + y) / a.length;
      double bY = b.map((e) => e['yCenter']).reduce((x, y) => x + y) / b.length;
      return aY.compareTo(bY);
    });

    List<String> reconstructed = [];
    for (var row in rows) {
      row.sort((a, b) => a['xStart'].compareTo(b['xStart']));
      reconstructed.add(row.map((e) => e['text']).join(' '));
    }

    return reconstructed;
  }

  static List<Map<String, dynamic>> _extractItems(List<String> lines) {
    List<Map<String, dynamic>> items = [];

    final decimalRegex = RegExp(r'\b\d+\s*[.,]\s*\d{2}\b');
    final explicitQtyRegex = RegExp(
      r'\b(\d+)\s*[xX]\b|\b[xX]\s*(\d+)\b|\b(?:qty|qty\.|quantity|qnty)[:.]?\s*(\d+)\b',
      caseSensitive: false,
    );
    final standaloneIntRegex = RegExp(r'(?<![a-zA-Z])\b\d+\b(?![a-zA-Z])');

    final excludeRegex = RegExp(
      r'\b(total|subtotal|sub|tax|vat|change|cash|card|visa|mastercard|balance|due|amount|summary|cgst|sgst|igst|round|roundoff|discount|thanks|thank|invoice|guest|signature|served|consume|net|bill|fssai|lic|visit|again)\b',
      caseSensitive: false,
    );

    bool hasReachedTotals = false;

    for (String line in lines) {
      // If we see a total, tax, or footer word...
      if (excludeRegex.hasMatch(line)) {
        // THE FIX: Only drop the gate if we have actually started adding food items!
        // This stops headers like "Bill No" or "Amount" from triggering the gate too early.
        if (items.isNotEmpty) {
          hasReachedTotals = true;
        }
        continue;
      }

      String cleanedLine = line.replaceFirst(RegExp(r'^\d+[\.\)\-]?\s+'), '');

      double? foundDecimalQty;
      final nosRegex = RegExp(
        r'\b(\d+(?:\.\d+)?)\s*(?:nos\.?|qty\.?)\b',
        caseSensitive: false,
      );
      final nosMatch = nosRegex.firstMatch(cleanedLine);

      if (nosMatch != null) {
        foundDecimalQty = double.tryParse(nosMatch.group(1)!);
        cleanedLine = cleanedLine.replaceFirst(nosMatch.group(0)!, ' ');
      }

      cleanedLine = cleanedLine.replaceAll(
        RegExp(r'\bnos\.?\b', caseSensitive: false),
        ' ',
      );

      final decimalMatches = decimalRegex.allMatches(cleanedLine).toList();

      if (decimalMatches.isEmpty) {
        if (!hasReachedTotals && items.isNotEmpty && cleanedLine.length < 40) {
          if (!excludeRegex.hasMatch(cleanedLine)) {
            String cleanOrphan = cleanedLine
                .replaceAll(RegExp(r'[xX\*\/\|\-\+\=\@\:\(\)]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            if (cleanOrphan.isNotEmpty &&
                RegExp(r'[a-zA-Z]').hasMatch(cleanOrphan)) {
              items.last['item_name'] =
                  (items.last['item_name'] + ' ' + cleanOrphan).trim();
            }
          }
        }
        continue;
      }

      List<double> prices = decimalMatches
          .map((m) => _parseAmount(m.group(0)!))
          .toList();
      double totalItemPrice = prices.last;

      String qtyStrippedText = cleanedLine;
      for (var match in decimalMatches) {
        qtyStrippedText = qtyStrippedText.replaceFirst(match.group(0)!, ' ');
      }

      int quantity = 1;

      if (foundDecimalQty != null) {
        quantity = foundDecimalQty.toInt();
      } else {
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
      }

      String itemName = cleanedLine;
      for (var match in decimalMatches) {
        itemName = itemName.replaceFirst(match.group(0)!, '');
      }

      var qtyMatch = explicitQtyRegex.firstMatch(itemName);
      if (qtyMatch != null) {
        itemName = itemName.replaceFirst(qtyMatch.group(0)!, '');
      } else {
        final intMatches = standaloneIntRegex.allMatches(itemName).toList();
        if (intMatches.isNotEmpty) {
          itemName = itemName.replaceFirst(intMatches.last.group(0)!, '');
        }
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

      if (itemName.isNotEmpty &&
          itemName.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(itemName)) {
        items.add({
          'item_name': itemName,
          'quantity': quantity,
          'price': totalItemPrice,
        });
      }
    }

    return items;
  }

  static String _extractMerchant(List<String> lines) {
    final ignoreRegex = RegExp(
      r'\b(date|time|bill|receipt|tax|particulars|qty|amount|rate|token|cashier|name|gstin|fssai|sac|lic)\b',
      caseSensitive: false,
    );

    for (String line in lines) {
      if (line.length > 3 &&
          !line.contains(RegExp(r'^\d+$')) &&
          !ignoreRegex.hasMatch(line)) {
        return line;
      }
    }
    return 'Unknown Merchant';
  }

  static double _extractTotal(List<String> lines, String rawText) {
    double highestTotal = 0.0;
    final amountRegex = RegExp(r'\b\d+(?:[.,]\d{2})\b');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('total') ||
          line.contains('amount due') ||
          line.contains('balance') ||
          line.contains('grand total') ||
          line.contains('net amount')) {
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
    return match?.group(0);
  }

  static double _parseAmount(String amountStr) {
    try {
      String clean = amountStr.replaceAll(' ', '').replaceAll(',', '.');
      if (clean.indexOf('.') != clean.lastIndexOf('.')) {
        clean = clean.replaceFirst('.', '');
      }
      return double.parse(clean);
    } catch (e) {
      return 0.0;
    }
  }
}