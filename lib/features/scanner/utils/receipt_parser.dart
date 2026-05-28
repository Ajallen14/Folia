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
    if (calculatedItemsSum > extractedTotal)
      extractedTotal = calculatedItemsSum;

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

    words.sort((a, b) => a['yCenter'].compareTo(b['yCenter']));

    List<List<Map<String, dynamic>>> rows = [];

    for (var word in words) {
      bool placed = false;
      double threshold = word['height'] * 0.5;

      for (var row in rows) {
        double rowY =
            row.map((e) => e['yCenter']).reduce((a, b) => a + b) / row.length;
        if ((word['yCenter'] - rowY).abs() < threshold) {
          row.add(word);
          placed = true;
          break;
        }
      }
      if (!placed) rows.add([word]);
    }

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
      'cgst',
      'sgst',
      'igst',
      'round',
      'discount',
      'thanks',
      'invoice',
    ];

    for (String line in lines) {
      final lowerLine = line.toLowerCase();

      if (excludeKeywords.any((k) => lowerLine.contains(k))) {
        if (lowerLine.startsWith('total') || lowerLine.contains('grand total'))
          continue;
        continue;
      }

      String cleanedLine = line.replaceFirst(RegExp(r'^\d+[\.\)\-]?\s+'), '');

      // A. Extract Prices
      final decimalMatches = decimalRegex.allMatches(cleanedLine).toList();

      // NEW: ORPHAN TEXT RECOVERY
      if (decimalMatches.isEmpty) {
        // If we have no prices, but we already have items in our list, this might be a wrapped name!
        if (items.isNotEmpty && cleanedLine.length < 30) {
          String orphan = cleanedLine.toLowerCase();
          if (!excludeKeywords.any((k) => orphan.contains(k))) {
            // Clean it just like a normal item name
            String cleanOrphan = cleanedLine
                .replaceAll(RegExp(r'[xX\*\/\|\-\+\=\@\:\(\)]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            // If it's actual text (not random numbers), glue it to the previous item!
            if (cleanOrphan.isNotEmpty &&
                RegExp(r'[a-zA-Z]').hasMatch(cleanOrphan)) {
              items.last['item_name'] =
                  (items.last['item_name'] + ' ' + cleanOrphan).trim();
            }
          }
        }
        continue; // Move on to the next line
      }

      List<double> prices = decimalMatches
          .map((m) => _parseAmount(m.group(0)!))
          .toList();
      double totalItemPrice = prices.last;

      String qtyStrippedText = cleanedLine;
      for (var match in decimalMatches)
        qtyStrippedText = qtyStrippedText.replaceFirst(match.group(0)!, ' ');

      // B. Extract Quantity
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

      // C. Extract Name
      String itemName = cleanedLine;
      for (var match in decimalMatches)
        itemName = itemName.replaceFirst(match.group(0)!, '');

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
      'token',
      'cashier',
      'name',
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
    final amountRegex = RegExp(r'\b\d+(?:[.,]\d{2})\b');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('total') ||
          line.contains('amount due') ||
          line.contains('balance') ||
          line.contains('grand total')) {
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
      String clean = amountStr.replaceAll(' ', '').replaceAll(',', '.');
      if (clean.indexOf('.') != clean.lastIndexOf('.'))
        clean = clean.replaceFirst('.', '');
      return double.parse(clean);
    } catch (e) {
      return 0.0;
    }
  }
}
