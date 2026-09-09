import 'package:flutter/material.dart';
import '../api/foreign_stock_api.dart' as foreign_api;
import '../api/stock_detail_api.dart' as detail_api;
import '../api/stock_quote_api.dart';
import '../db/favorites_db.dart' as db;
import '../models/stock_detail.dart';
import '../models/stock_summary.dart';
import '../theme.dart';

const _kNotAvailableForForeign = '해외 종목 미표시';

class StockDetailScreen extends StatefulWidget {
  final StockSummary stock;
  final bool initialIsFavorite;

  const StockDetailScreen({
    super.key,
    required this.stock,
    this.initialIsFavorite = false,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  // DB 조회가 끝나기 전까지 잠깐 보여줄 초기값. _load()가 끝나면 실제 값으로 덮어씁니다.
  late bool _isFavorite = widget.initialIsFavorite;

  bool _loading = true;
  StockDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final isFavoriteFuture = db.isFavorite(widget.stock.code);

    if (widget.stock.isForeign) {
      final results = await Future.wait([
        foreign_api.fetchForeignStockDetail(widget.stock),
        isFavoriteFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as StockDetail;
        _isFavorite = results[1] as bool;
        _loading = false;
      });
      return;
    }

    // 시세, 상세 HTML 파싱, DB 조회는 서로 독립적이라 Future.wait로 동시에 보냅니다.
    final results = await Future.wait([
      fetchStockQuote(widget.stock.code),
      detail_api.fetchStockDetail(widget.stock),
      isFavoriteFuture,
    ]);

    if (!mounted) return;

    final quote = results[0] as StockRealtimeQuote?;
    final parsed = results[1] as StockDetail;
    final isFavorite = results[2] as bool;

    setState(() {
      _detail = StockDetail(
        summary: parsed.summary,
        basicInfo: toBasicInfo(quote),
        indicators: parsed.indicators,
        companyOverview: parsed.companyOverview,
        financials: parsed.financials,
        consensus: parsed.consensus,
      );
      _isFavorite = isFavorite;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    if (_isFavorite) {
      await db.addFavorite(widget.stock);
    } else {
      await db.removeFavorite(widget.stock.code);
    }
  }

  void _handleBack() {
    Navigator.pop(context, _isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 시스템 뒤로가기로 나갈 때도 즐겨찾기 상태를 호출한 화면에 돌려주기 위한 설정.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _isFavorite);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _handleBack,
          ),
          title: Text(
            widget.stock.name,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                color: _isFavorite ? kAccentBlue : kGrayTime,
              ),
              onPressed: _toggleFavorite,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kAccentBlue))
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    kScreenPadding, 12, kScreenPadding, 24),
                children: [
                  Text(
                    '${widget.stock.code} · ${widget.stock.market}',
                    style: const TextStyle(color: kGrayLabel, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '기본정보',
                    child: _BasicInfoView(info: _detail?.basicInfo, isForeign: widget.stock.isForeign),
                  ),
                  _SectionCard(
                    title: '투자지표',
                    child: _IndicatorsView(info: _detail?.indicators, isForeign: widget.stock.isForeign),
                  ),
                  _SectionCard(title: '기업개요', child: _OverviewView(lines: _detail?.companyOverview ?? const [])),
                  _SectionCard(title: '재무비율', child: _FinancialsView(years: _detail?.financials ?? const [])),
                  _SectionCard(
                    title: '컨센서스',
                    child: _ConsensusView(info: _detail?.consensus, isForeign: widget.stock.isForeign),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── 공통 섹션 카드 ──────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 라벨-값 한 줄. 여러 섹션에서 반복되는 모양이라 재사용합니다.
class _KeyValueRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;

  const _KeyValueRow({required this.label, this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: kGrayLabel)),
          Text(
            value ?? '-',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicInfoView extends StatelessWidget {
  final StockBasicInfo? info;
  final bool isForeign;

  const _BasicInfoView({required this.info, this.isForeign = false});

  @override
  Widget build(BuildContext context) {
    final changeColor = info?.isUp == true ? kUpColor : kDownColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(label: '시장', value: info?.market),
        _KeyValueRow(label: '현재가', value: info?.closePrice),
        _KeyValueRow(label: '등락률', value: info?.changeText, valueColor: changeColor),
        _KeyValueRow(label: '시가', value: info?.openPrice),
        _KeyValueRow(label: '고가', value: info?.highPrice),
        _KeyValueRow(label: '저가', value: info?.lowPrice),
        _KeyValueRow(label: '거래량', value: info?.volume),
        _KeyValueRow(label: isForeign ? '거래대금' : '거래대금(백만)', value: info?.tradingValue),
        _KeyValueRow(label: isForeign ? '시가총액' : '시가총액(억)', value: info?.marketCap),
        _KeyValueRow(label: '기준시각', value: info?.updatedAt),
      ],
    );
  }
}

class _IndicatorsView extends StatelessWidget {
  final StockIndicators? info;
  final bool isForeign;

  const _IndicatorsView({required this.info, this.isForeign = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(label: 'PER', value: info?.per),
        _KeyValueRow(label: 'EPS', value: info?.eps),
        _KeyValueRow(label: '추정 PER', value: isForeign ? _kNotAvailableForForeign : info?.estimatedPer),
        _KeyValueRow(label: '추정 EPS', value: isForeign ? _kNotAvailableForForeign : info?.estimatedEps),
        _KeyValueRow(label: 'PBR', value: info?.pbr),
        _KeyValueRow(label: 'BPS', value: info?.bps),
        _KeyValueRow(label: '배당수익률(%)', value: info?.dividendYield),
        _KeyValueRow(label: '52주 최고', value: info?.week52High),
        _KeyValueRow(label: '52주 최저', value: info?.week52Low),
        if (!isForeign) _KeyValueRow(label: '외국인지분율(%)', value: info?.foreignRatio),
        _KeyValueRow(label: isForeign ? '시가총액' : '시가총액(억)', value: info?.marketCap),
      ],
    );
  }
}

class _OverviewView extends StatelessWidget {
  final List<String> lines;

  const _OverviewView({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Text('-', style: TextStyle(fontSize: 13, color: kGrayLabel));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('· $line', style: const TextStyle(fontSize: 13, height: 1.4)),
              ))
          .toList(),
    );
  }
}

class _FinancialsView extends StatelessWidget {
  final List<FinancialYear> years;

  const _FinancialsView({required this.years});

  @override
  Widget build(BuildContext context) {
    if (years.isEmpty) {
      return const Text('-', style: TextStyle(fontSize: 13, color: kGrayLabel));
    }
    final rowLabels = ['매출액', '영업이익', '당기순이익', '영업이익률(%)', '순이익률(%)', 'ROE(%)', 'ROA(%)', '부채비율(%)'];
    List<String?> valuesFor(FinancialYear y) => [
          y.revenue,
          y.operatingProfit,
          y.netProfit,
          y.operatingMargin,
          y.netMargin,
          y.roe,
          y.roa,
          y.debtRatio,
        ];

    // 가로 스크롤 가능한 표: 연도가 늘어나도 화면 밖으로 넘치지 않게 합니다.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 32,
        columnSpacing: 20,
        columns: [
          const DataColumn(label: Text('', style: TextStyle(fontSize: 12))),
          for (final y in years)
            DataColumn(label: Text(y.year, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
        rows: [
          for (var r = 0; r < rowLabels.length; r++)
            DataRow(cells: [
              DataCell(Text(rowLabels[r], style: const TextStyle(fontSize: 12, color: kGrayLabel))),
              for (final y in years)
                DataCell(Text(valuesFor(y)[r] ?? '-', style: const TextStyle(fontSize: 12))),
            ]),
        ],
      ),
    );
  }
}

class _ConsensusView extends StatelessWidget {
  final ConsensusInfo? info;
  final bool isForeign;

  const _ConsensusView({required this.info, this.isForeign = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(label: isForeign ? '추천점수(1~5)' : '투자의견', value: info?.opinion),
        _KeyValueRow(label: '목표주가', value: info?.targetPrice),
        if (!isForeign) _KeyValueRow(label: 'EPS', value: info?.eps),
        if (!isForeign) _KeyValueRow(label: 'PER', value: info?.per),
        _KeyValueRow(label: '추정기관수', value: isForeign ? _kNotAvailableForForeign : info?.analystCount),
      ],
    );
  }
}
