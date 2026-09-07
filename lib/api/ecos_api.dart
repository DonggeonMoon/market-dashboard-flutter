import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

const _statCode = '902Y006';

class EcosRow {
  final String time;
  final String dataValue;

  EcosRow({required this.time, required this.dataValue});

  factory EcosRow.fromJson(Map<String, dynamic> json) {
    return EcosRow(
      time: json['TIME'] as String,
      dataValue: json['DATA_VALUE'] as String,
    );
  }
}

({String start, String end}) _getYearMonthRange() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final end = '${now.year}${two(now.month)}';
  final startDate = DateTime(now.year, now.month - 6, 1);
  final start = '${startDate.year}${two(startDate.month)}';
  return (start: start, end: end);
}

Future<EcosRow?> _fetchBaseRate(String countryCode) async {
  final apiKey = dotenv.env['ECOS_API_KEY'];
  if (apiKey == null) return null;

  final range = _getYearMonthRange();
  final url =
      'https://ecos.bok.or.kr/api/StatisticSearch/$apiKey/json/kr/1/12/'
      '$_statCode/M/${range.start}/${range.end}/$countryCode';

  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = json['StatisticSearch']?['row'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) return null;
    return EcosRow.fromJson(rows.last as Map<String, dynamic>);
  } catch (e) {
    // ignore: avoid_print
    print('[ecos api] failed: $countryCode, $e');
    return null;
  }
}

String formatEcosTime(String time) {
  final year = time.substring(0, 4);
  final month = time.substring(4, 6);
  return '$year-$month';
}

Future<EcosRow?> fetchKoreaRate() => _fetchBaseRate('KR');
Future<EcosRow?> fetchUsRate() => _fetchBaseRate('US');
Future<EcosRow?> fetchJapanRate() => _fetchBaseRate('JP');
