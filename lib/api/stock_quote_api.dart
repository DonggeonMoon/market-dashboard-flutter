import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_detail.dart';

const _quoteBaseUrl = 'https://polling.finance.naver.com/api/realtime/domestic/stock';

class StockRealtimeQuote {
  final String? market;
  final String? closePrice;
  final String? changeRatio; // fluctuationsRatio
  final String? direction; // RISING / FALLING / UNCHANGED
  final String? openPrice;
  final String? highPrice;
  final String? lowPrice;
  final String? volume;
  final String? tradingValue;
  final String? marketCapRaw;
  final String? localTradedAt;

  const StockRealtimeQuote({
    this.market,
    this.closePrice,
    this.changeRatio,
    this.direction,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.volume,
    this.tradingValue,
    this.marketCapRaw,
    this.localTradedAt,
  });

  factory StockRealtimeQuote.fromJson(Map<String, dynamic> json) {
    final exchangeType = json['stockExchangeType'] as Map<String, dynamic>?;
    final compareToPreviousPrice = json['compareToPreviousPrice'] as Map<String, dynamic>?;
    return StockRealtimeQuote(
      market: exchangeType?['nameKor'] as String?,
      closePrice: json['closePrice'] as String?,
      changeRatio: json['fluctuationsRatio'] as String?,
      direction: compareToPreviousPrice?['name'] as String?,
      openPrice: json['openPrice'] as String?,
      highPrice: json['highPrice'] as String?,
      lowPrice: json['lowPrice'] as String?,
      volume: json['accumulatedTradingVolume'] as String?,
      tradingValue: json['accumulatedTradingValue'] as String?,
      marketCapRaw: json['marketValueFullRaw'] as String?,
      localTradedAt: json['localTradedAt'] as String?,
    );
  }
}

Future<StockRealtimeQuote?> fetchStockQuote(String code) async {
  try {
    final res = await http.get(Uri.parse('$_quoteBaseUrl/$code'));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final datas = json['datas'] as List<dynamic>?;
    if (datas == null || datas.isEmpty) return null;
    return StockRealtimeQuote.fromJson(datas[0] as Map<String, dynamic>);
  } catch (e) {
    // ignore: avoid_print
    print('[quote api] failed: $code, $e');
    return null;
  }
}

String? _toEokUnit(String? wonRaw) {
  final v = wonRaw == null ? null : int.tryParse(wonRaw);
  if (v == null) return null;
  return (v / 100000000).round().toString();
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

/// 실시간 시세 응답을 상세 화면이 바로 쓸 수 있는 StockBasicInfo로 변환합니다.
StockBasicInfo toBasicInfo(StockRealtimeQuote? q) {
  if (q == null) return const StockBasicInfo();
  final isDown = q.direction == 'FALLING';
  final isUp = q.direction == 'RISING';
  final sign = q.direction != null
      ? (isDown ? '-' : (isUp ? '+' : ''))
      : ((q.changeRatio ?? '').startsWith('-') ? '-' : '');
  final ratio = (q.changeRatio ?? '').replaceAll('-', '');
  return StockBasicInfo(
    market: q.market,
    closePrice: q.closePrice,
    changeText: q.changeRatio != null ? '$sign$ratio%' : null,
    isUp: !isDown,
    openPrice: q.openPrice,
    highPrice: q.highPrice,
    lowPrice: q.lowPrice,
    volume: q.volume,
    tradingValue: q.tradingValue,
    marketCap: _toEokUnit(q.marketCapRaw),
    updatedAt: _formatLocalTime(q.localTradedAt),
  );
}
