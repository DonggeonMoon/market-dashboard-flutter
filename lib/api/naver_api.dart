import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://polling.finance.naver.com/api/realtime';

class NaverRealtimeItem {
  final String closePrice;
  final String fluctuationsRatio;
  final String? fluctuationsTypeName; // RISING / FALLING
  final String? localTradedAt;

  NaverRealtimeItem({
    required this.closePrice,
    required this.fluctuationsRatio,
    this.fluctuationsTypeName,
    this.localTradedAt,
  });

  factory NaverRealtimeItem.fromJson(Map<String, dynamic> json) {
    final fluctuationsType = json['fluctuationsType'] as Map<String, dynamic>?;
    final compareToPreviousPrice = json['compareToPreviousPrice'] as Map<String, dynamic>?;
    return NaverRealtimeItem(
      closePrice: json['closePrice'] as String,
      fluctuationsRatio: json['fluctuationsRatio'] as String,
      fluctuationsTypeName: (fluctuationsType?['name'] ?? compareToPreviousPrice?['name']) as String?,
      localTradedAt: json['localTradedAt'] as String?,
    );
  }
}

Future<NaverRealtimeItem?> _fetchRealtime(String path) async {
  try {
    final res = await http.get(Uri.parse('$_baseUrl/$path'));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final datas = json['datas'] as List<dynamic>?;
    if (datas == null || datas.isEmpty) return null;
    return NaverRealtimeItem.fromJson(datas[0] as Map<String, dynamic>);
  } catch (e) {
    // ignore: avoid_print
    print('[naver api] failed: $path, $e');
    return null;
  }
}

// ── 지수 ──────────────────────────────
Future<NaverRealtimeItem?> fetchKospi() => _fetchRealtime('domestic/index/KOSPI');
Future<NaverRealtimeItem?> fetchKosdaq() => _fetchRealtime('domestic/index/KOSDAQ');
Future<NaverRealtimeItem?> fetchSP500() => _fetchRealtime('worldstock/index/.INX');
Future<NaverRealtimeItem?> fetchNasdaq() => _fetchRealtime('worldstock/index/.IXIC');
Future<NaverRealtimeItem?> fetchNikkei() => _fetchRealtime('worldstock/index/.N225');
Future<NaverRealtimeItem?> fetchSox() => _fetchRealtime('worldstock/index/.SOX');

// ── 원자재 ──────────────────────────────
Future<NaverRealtimeItem?> fetchWti() => _fetchRealtime('marketindex/energy/CLcv1');
Future<NaverRealtimeItem?> fetchGold() => _fetchRealtime('marketindex/metals/GCcv1');

// ── 환율 (네이버 검색 계산기 API — 별도 구조) ──────────────────────────────
Future<String?> _fetchFx(String currencyCode) async {
  final url =
      'https://m.search.naver.com/p/csearch/content/qapirender.nhn'
      '?key=calculator&pkid=141&q=환율&where=m&u1=keb&u6=standardUnit&u7=0'
      '&u3=$currencyCode&u4=KRW&u8=down&u2=1';
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final country = json['country'] as List<dynamic>?;
    if (country == null || country.length < 2) return null;
    return country[1]['value'] as String?;
  } catch (e) {
    // ignore: avoid_print
    print('[naver fx api] failed: $currencyCode, $e');
    return null;
  }
}

Future<String?> fetchUsdKrw() => _fetchFx('USD');
Future<String?> fetchJpyKrw() => _fetchFx('JPY');
Future<String?> fetchCnyKrw() => _fetchFx('CNY');