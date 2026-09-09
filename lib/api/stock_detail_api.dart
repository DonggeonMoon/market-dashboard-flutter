import 'package:http/http.dart' as http;
import '../models/stock_detail.dart';
import '../models/stock_summary.dart';

const _detailBaseUrl = 'https://navercomp.wisereport.co.kr/v2/company/c1010001.aspx';

/// 투자지표/기업개요/재무비율/컨센서스를 HTML 파싱으로 채운 StockDetail을 반환합니다.
/// 페이지 요청 자체가 실패하면 빈 값의 StockDetail을 돌려주고, 개별 필드 파싱이
/// 실패해도 예외를 던지지 않고 그 필드만 null/빈 값으로 둡니다.
Future<StockDetail> fetchStockDetail(StockSummary stock) async {
  String? html;
  try {
    final res = await http.get(
      Uri.parse('$_detailBaseUrl?cmp_cd=${stock.code}'),
      headers: {'User-Agent': 'Mozilla/5.0'},
    );
    if (res.statusCode == 200) html = res.body;
  } catch (e) {
    // ignore: avoid_print
    print('[detail api] failed: ${stock.code}, $e');
    html = null;
  }

  if (html == null) return StockDetail(summary: stock);

  final consensus = _parseConsensus(html);
  return StockDetail(
    summary: stock,
    indicators: _parseIndicators(html, consensus),
    companyOverview: _parseOverview(html),
    financials: _parseFinancials(html),
    consensus: consensus,
  );
}

// ── 공통 유틸 ──────────────────────────────

String? _clean(String? raw) {
  if (raw == null) return null;
  final stripped = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return stripped.isEmpty ? null : stripped;
}

/// id 속성을 가진 태그(em, span 등) 바로 다음의 텍스트를 찾습니다.
/// 예) id="_per" 스펙에 나온 형태를 그대로 시도해봅니다.
String? _byId(String html, String id) {
  final m = RegExp('id="$id"[^>]*>([\\s\\S]*?)<').firstMatch(html);
  return _clean(m?.group(1));
}

/// 상단 요약 영역의 `<dt>라벨 <b class="num">값</b></dt>` 형태에서 값을 찾습니다.
/// id 기반 선택자가 이 페이지에 없을 때의 대체 경로입니다.
String? _byDtLabel(String html, String label) {
  final pattern = RegExp('<dt[^>]*>\\s*${RegExp.escape(label)}\\s*<b[^>]*>([^<]*)</b>');
  return _clean(pattern.firstMatch(html)?.group(1));
}

/// `<th ...>라벨</th>` 형태의 표 헤더 셀 바로 다음에 오는 `<td ...>...</td>` 값 셀을 찾습니다.
/// (단순 문자열 검색은 alt/summary 설명 문구 안의 라벨과 혼동될 수 있어 <th> 태그로 앵커링합니다.)
String? _byLabelCell(String html, String label) {
  final pattern =
      RegExp('<th[^>]*>\\s*${RegExp.escape(label)}\\s*</th>\\s*<td[^>]*>([\\s\\S]*?)</td>');
  return _clean(pattern.firstMatch(html)?.group(1));
}

// ── 투자지표 ──────────────────────────────

StockIndicators _parseIndicators(String html, ConsensusInfo? consensus) {
  try {
    final per = _byId(html, '_per') ?? _byDtLabel(html, 'PER');
    final eps = _byId(html, '_eps') ?? _byDtLabel(html, 'EPS');
    final pbr = _byId(html, '_pbr') ?? _byDtLabel(html, 'PBR');
    final dvr = _byId(html, '_dvr') ?? _byDtLabel(html, '현금배당수익률');
    final marketSum = _byId(html, '_market_sum') ?? _byLabelCell(html, '시가총액');

    // 추정 PER/EPS 전용 id가 없으면 컨센서스 표의 PER/EPS(증권사 추정치)를 재사용합니다.
    final estimatedPer = _byId(html, '_cns_per') ?? consensus?.per;
    final estimatedEps = _byId(html, '_cns_eps') ?? consensus?.eps;

    final bps = _bpsFromPbrRow(html) ?? _byDtLabel(html, 'BPS');

    String? week52High;
    String? week52Low;
    final week52 = _byLabelCell(html, '52Weeks 최고/최저');
    if (week52 != null && week52.contains('/')) {
      final parts = week52.split('/');
      week52High = parts[0].replaceAll('원', '').trim();
      week52Low = parts.length > 1 ? parts[1].replaceAll('원', '').trim() : null;
    }

    final foreignRatio = _byLabelCell(html, '외국인지분율')?.replaceAll('%', '').trim();

    return StockIndicators(
      per: per,
      eps: eps,
      estimatedPer: estimatedPer,
      estimatedEps: estimatedEps,
      pbr: pbr,
      bps: bps,
      dividendYield: dvr,
      week52High: week52High,
      week52Low: week52Low,
      foreignRatio: foreignRatio,
      marketCap: marketSum,
    );
  } catch (e) {
    // ignore: avoid_print
    print('[detail api] indicators parse failed: $e');
    return const StockIndicators();
  }
}

/// 스펙: "PBR 행의 두 번째 <em>"이 BPS. id="_pbr"가 포함된 <tr> 안에서
/// <em> 태그를 순서대로 찾아 두 번째 것을 사용합니다.
String? _bpsFromPbrRow(String html) {
  final rowMatch = RegExp(r'<tr>((?:(?!</tr>)[\s\S])*?id="_pbr"[\s\S]*?)</tr>').firstMatch(html);
  if (rowMatch == null) return null;
  final ems = RegExp(r'<em[^>]*>([^<]*)</em>').allMatches(rowMatch.group(1) ?? '').toList();
  if (ems.length < 2) return null;
  return _clean(ems[1].group(1));
}

// ── 기업개요 ──────────────────────────────

List<String> _parseOverview(String html) {
  try {
    final items = RegExp(r'<li class="dot_cmp"[^>]*>([\s\S]*?)</li>').allMatches(html);
    return items
        .map((m) => _clean(m.group(1)))
        .whereType<String>()
        .toList();
  } catch (e) {
    // ignore: avoid_print
    print('[detail api] overview parse failed: $e');
    return [];
  }
}

// ── 재무비율 ──────────────────────────────

List<FinancialYear> _parseFinancials(String html) {
  try {
    final startIdx = html.indexOf('id="finSummary"');
    if (startIdx == -1) return [];
    final endIdx = (startIdx + 30000).clamp(0, html.length);
    final section = html.substring(startIdx, endIdx);

    // 연도 헤더: <th ...>2024</th>, <th ...>2025(E)</th> 형태를 찾습니다.
    final years = RegExp(r'<th[^>]*>\s*(\d{4}(?:/\d{2})?(?:\(E\))?)\s*(?:<[^>]*>)*\s*</th>')
        .allMatches(section)
        .map((m) => m.group(1)!.trim())
        .toList();
    if (years.isEmpty) return [];

    List<String?> rowValues(String label) {
      final labelIdx = section.indexOf(label);
      if (labelIdx == -1) return List<String?>.filled(years.length, null);
      final after = section.substring(labelIdx);
      final cells = RegExp(r'<td[^>]*>([\s\S]*?)</td>')
          .allMatches(after)
          .take(years.length)
          .map((m) => _clean(m.group(1)))
          .toList();
      while (cells.length < years.length) {
        cells.add(null);
      }
      return cells;
    }

    final revenue = rowValues('매출액');
    final operatingProfit = rowValues('영업이익');
    final netProfit = rowValues('당기순이익');
    final operatingMargin = rowValues('영업이익률');
    final netMargin = rowValues('순이익률');
    final roe = rowValues('ROE');
    final roa = rowValues('ROA');
    final debtRatio = rowValues('부채비율');

    return [
      for (var i = 0; i < years.length; i++)
        FinancialYear(
          year: years[i],
          revenue: revenue[i],
          operatingProfit: operatingProfit[i],
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
    print('[detail api] financials parse failed: $e');
    return [];
  }
}

// ── 컨센서스 ──────────────────────────────

ConsensusInfo? _parseConsensus(String html) {
  try {
    final startIdx = html.indexOf('id="cTB15"');
    if (startIdx == -1) return null;
    final endIdx = html.indexOf('</table>', startIdx);
    if (endIdx == -1) return null;
    final section = html.substring(startIdx, endIdx);

    final rows = RegExp(r'<tr>([\s\S]*?)</tr>').allMatches(section).toList();
    if (rows.length < 2) return null;
    // 첫 <tr>은 헤더(투자의견/목표주가/EPS/PER/추정기관수), 마지막 <tr>이 실제 값 행입니다.
    final dataRow = rows.last.group(1) ?? '';
    final cells = RegExp(r'<td[^>]*>([\s\S]*?)</td>')
        .allMatches(dataRow)
        .map((m) => _clean(m.group(1)))
        .toList();
    if (cells.length < 5) return null;

    return ConsensusInfo(
      opinion: cells[0],
      targetPrice: cells[1],
      eps: cells[2],
      per: cells[3],
      analystCount: cells[4],
    );
  } catch (e) {
    // ignore: avoid_print
    print('[detail api] consensus parse failed: $e');
    return null;
  }
}
