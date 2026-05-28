import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptParser {
  static Map<String, dynamic> parse(RecognizedText recognizedText) {
    // 1. Use the new Contour Chaining algorithm to un-curve the receipt
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

  /// CONTOUR CHAINING ALGORITHM: Follows the physical curve of the paper!
  static List<String> _rebuildLinesFromWords(RecognizedText recognizedText) {
    List<Map<String, dynamic>> words = [];

    // 1. Extract every single word
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

    // 2. Sort words strictly from Left-to-Right first
    words.sort((a, b) => a['xStart'].compareTo(b['xStart']));

    List<List<Map<String, dynamic>>> rows = [];

    // 3. Connect the dots: Attach each word to the row that ends closest to its Y-coordinate
    for (var word in words) {
      List<Map<String, dynamic>>? bestRow;
      double minDiff = double.infinity;
      double threshold = word['height'] * 0.8;

      for (var row in rows) {
        var lastWord = row.last; // Look ONLY at the most recently added word
        double yDiff = (word['yCenter'] - lastWord['yCenter']).abs();

        if (yDiff < threshold && yDiff < minDiff) {
          minDiff = yDiff;
          bestRow = row;
        }
      }

      if (bestRow != null) {
        bestRow.add(word); // Successfully connected the chain!
      } else {
        rows.add([word]); // Start a new row
      }
    }

    // 4. Now that rows are built, sort them from Top-to-Bottom
    rows.sort((a, b) {
      double aY = a.map((e) => e['yCenter']).reduce((x, y) => x + y) / a.length;
      double bY = b.map((e) => e['yCenter']).reduce((x, y) => x + y) / b.length;
      return aY.compareTo(bY);
    });

    // 5. Ensure words inside each row are ordered Left-to-Right, then join
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
      'guest',
      'signature',
      'served',
      'consume',
      'net',
      'bill',
    ];

    for (String line in lines) {
      final lowerLine = line.toLowerCase();

      if (excludeKeywords.any((k) => lowerLine.contains(k))) {
        if (lowerLine.startsWith('total') ||
            lowerLine.contains('grand total')) {
          continue;
        }
        continue;
      }

      String cleanedLine = line.replaceFirst(RegExp(r'^\d+[\.\)\-]?\s+'), '');

      // Nos processing
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

      // A. Extract Prices
      final decimalMatches = decimalRegex.allMatches(cleanedLine).toList();

      // ORPHAN TEXT RECOVERY
      if (decimalMatches.isEmpty) {
        if (items.isNotEmpty && cleanedLine.length < 30) {
          String orphan = cleanedLine.toLowerCase();
          if (!excludeKeywords.any((k) => orphan.contains(k))) {
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

      // B. Extract Quantity
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

      // C. Extract Name
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
      'gstin',
      'fssai',
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
    return match != null ? match.group(0) : null;
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
