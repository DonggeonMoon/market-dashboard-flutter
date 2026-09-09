import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_detail.dart';
import '../models/stock_summary.dart';

const _baseUrl = 'https://m.stock.naver.com/front-api';
const _headers = {
  'User-Agent': 'Mozilla/5.0',
  'Referer': 'https://m.stock.naver.com/',
};

Future<Map<String, dynamic>?> _getResult(String path, Map<String, String> query) async {
  try {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['isSuccess'] != true) return null;
    return json['result'] as Map<String, dynamic>?;
  } catch (e) {
    // ignore: avoid_print
    print('[foreign api] $path failed: $e');
    return null;
  }
}

Future<StockDetail> fetchForeignStockDetail(StockSummary stock) async {
  final code = stock.reutersCode;

  final results = await Future.wait([
    _getResult('/stock/foreign/basic', {'code': code, 'endType': 'stock'}),
    _getResult('/stock/foreign/stock/overview', {'code': code}),
    _getResult('/stock/foreign/integration', {'code': code}),
    _getResult('/stock/foreign/stock/finance/table',
        {'code': code, 'category': 'ratios', 'period': 'annual'}),
  ]);

  final basic = results[0];
  final overview = results[1];
  final integration = results[2];
  final finance = results[3];

  return StockDetail(
    summary: stock,
    basicInfo: _parseBasicInfo(basic),
    indicators: _parseIndicators(basic),
    companyOverview: _parseOverview(overview),
    financials: _parseFinancials(finance),
    consensus: _parseConsensus(integration),
  );
}

Map<String, String> _totalInfoMap(Map<String, dynamic>? basic) {
  final list = basic?['stockItemTotalInfos'] as List<dynamic>?;
  if (list == null) return {};
  final map = <String, String>{};
  for (final item in list.whereType<Map<String, dynamic>>()) {
    final code = item['code'] as String?;
    final value = item['value'] as String?;
    if (code != null && value != null) map[code] = value;
  }
  return map;
}

String? _formatLocalTime(String? iso) {
  if (iso == null) return null;
  try {
    final d = DateTime.parse(iso);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  } catch (_) {
    return null;
  }
}

StockBasicInfo _parseBasicInfo(Map<String, dynamic>? basic) {
  if (basic == null) return const StockBasicInfo();
  try {
    final info = _totalInfoMap(basic);
    final exchangeType = basic['stockExchangeType'] as Map<String, dynamic>?;
    final compare = basic['compareToPreviousPrice'] as Map<String, dynamic>?;
    final currencyCode = (basic['currencyType'] as Map<String, dynamic>?)?['code'] as String?;
    final closePrice = basic['closePrice'] as String?;

    final isDown = compare?['name'] == 'FALLING';
    final isUp = compare?['name'] == 'RISING';
    final sign = isDown ? '-' : (isUp ? '+' : '');
    final ratio = (basic['fluctuationsRatio'] as String?)?.replaceAll('-', '');

    return StockBasicInfo(
      market: exchangeType?['nameKor'] as String?,
      closePrice: closePrice != null && currencyCode != null ? '$closePrice $currencyCode' : closePrice,
      changeText: ratio != null ? '$sign$ratio%' : null,
      isUp: !isDown,
      openPrice: info['openPrice'],
      highPrice: info['highPrice'],
      lowPrice: info['lowPrice'],
      volume: info['accumulatedTradingVolume'],
      tradingValue: info['accumulatedTradingValue'],
      marketCap: info['marketValue'],
      updatedAt: _formatLocalTime(basic['localTradedAt'] as String?),
    );
  } catch (e) {
    // ignore: avoid_print
    print('[foreign api] basic info parse failed: $e');
    return const StockBasicInfo();
  }
}

StockIndicators _parseIndicators(Map<String, dynamic>? basic) {
  if (basic == null) return const StockIndicators();
  try {
    final info = _totalInfoMap(basic);
    return StockIndicators(
      per: info['per'],
      eps: info['eps'],
      pbr: info['pbr'],
      bps: info['bps'],
      dividendYield: info['dividendYieldRatio']?.replaceAll('%', ''),
      week52High: info['highPriceOf52Weeks'],
      week52Low: info['lowPriceOf52Weeks'],
      marketCap: info['marketValue'],
    );
  } catch (e) {
    // ignore: avoid_print
    print('[foreign api] indicators parse failed: $e');
    return const StockIndicators();
  }
}

List<String> _parseOverview(Map<String, dynamic>? overview) {
  if (overview == null) return [];
  try {
    final summaries = overview['summaries'] as Map<String, dynamic>?;
    final summary = (summaries?['summary'] ?? overview['summary']) as String?;
    if (summary == null || summary.isEmpty) return [];
    return summary
        .split('<br>')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } catch (e) {
    // ignore: avoid_print
    print('[foreign api] overview parse failed: $e');
    return [];
  }
}

List<FinancialYear> _parseFinancials(Map<String, dynamic>? finance) {
  if (finance == null) return [];
  try {
    final trTitleList = finance['trTitleList'] as List<dynamic>?;
    final rowList = finance['rowList'] as List<dynamic>?;
    if (trTitleList == null || rowList == null) return [];

    final periods = trTitleList
        .whereType<Map<String, dynamic>>()
        .map((t) => (title: t['title'] as String, key: t['key'] as String))
        .toList();
    if (periods.isEmpty) return [];

    List<String?> rowValues(String title) {
      final row = rowList.whereType<Map<String, dynamic>>().where((r) => r['title'] == title);
      final columns = row.isEmpty ? null : row.first['columns'] as Map<String, dynamic>?;
      return periods
          .map((p) => (columns?[p.key] as Map<String, dynamic>?)?['value'] as String?)
          .toList();
    }

    final revenue = rowValues('매출액');
    final netProfit = rowValues('당기순이익');
    final operatingMargin = rowValues('영업이익마진율');
    final netMargin = rowValues('순이익마진율');
    final roe = rowValues('ROE');
    final roa = rowValues('ROA');
    final debtRatio = rowValues('부채비율');

    return [
      for (var i = 0; i < periods.length; i++)
        FinancialYear(
          year: periods[i].title,
          revenue: revenue[i],
          netProfit: netProfit[i],
          operatingMargin: operatingMargin[i],
          netMargin: netMargin[i],
          roe: roe[i],
          roa: roa[i],
          debtRatio: debtRatio[i],
        ),
    ];
  } catch (e) {
    // ignore: avoid_print
    print('[foreign api] financials parse failed: $e');
    return [];
  }
}

ConsensusInfo? _parseConsensus(Map<String, dynamic>? integration) {
  if (integration == null) return null;
  try {
    final info = integration['consensusInfo'] as Map<String, dynamic>?;
    if (info == null) return null;
    final currencyCode = (info['currencyType'] as Map<String, dynamic>?)?['code'] as String?;
    final targetMean = info['priceTargetMean']?.toString();

    return ConsensusInfo(
      opinion: info['recommMean']?.toString(),
      targetPrice: targetMean != null && currencyCode != null ? '$targetMean $currencyCode' : targetMean,
    );
  } catch (e) {
    // ignore: avoid_print
    print('[foreign api] consensus parse failed: $e');
    return null;
  }
}
