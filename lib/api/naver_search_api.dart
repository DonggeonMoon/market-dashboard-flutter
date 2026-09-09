import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_summary.dart';

const _searchUrl = 'https://m.stock.naver.com/front-api/search/autoComplete';

Future<List<StockSummary>> searchStocks(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  try {
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'query': trimmed,
      'target': 'stock',
    });
    final res = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0',
      'Referer': 'https://m.stock.naver.com/',
    });
    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final result = json['result'] as Map<String, dynamic>?;
    final items = result?['items'] as List<dynamic>?;
    if (items == null) return [];

    return items
        .whereType<Map<String, dynamic>>()
        .where((item) => item['isEtf'] != true)
        .map((item) => StockSummary(
              code: item['code'] as String,
              name: item['name'] as String,
              market: item['typeName'] as String? ?? '',
              reutersCode: item['reutersCode'] as String?,
              isForeign: item['nationCode'] != 'KOR',
            ))
        .toList();
  } catch (e) {
    // ignore: avoid_print
    print('[search api] failed: $query, $e');
    return [];
  }
}
