import 'package:flutter/material.dart';
import '../api/ecos_api.dart' as ecos_api;
import '../api/naver_api.dart' as api;
import '../api/format.dart';
import '../theme.dart';

// ── 데이터 모델 ──────────────────────────────
class IndexData {
  final String label;
  final String? value;
  final String? change;
  final String? updatedAt;

  IndexData({required this.label, this.value, this.change, this.updatedAt});

  bool get isUp => change != null && change!.trim().startsWith('+');
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;

  List<IndexData> _domesticIndex = [
    IndexData(label: '코스피'),
    IndexData(label: '코스닥'),
  ];
  List<IndexData> _overseasIndex = [
    IndexData(label: 'S&P500'),
    IndexData(label: '나스닥'),
    IndexData(label: '니케이225'),
    IndexData(label: '필라델피아반도체'),
  ];
  List<IndexData> _exchangeRates = [
    IndexData(label: '원/달러'),
    IndexData(label: '원/100엔'),
    IndexData(label: '원/위안'),
  ];
  List<IndexData> _commodities = [
    IndexData(label: 'WTI 유가(배럴당)'),
    IndexData(label: '국제 금(온스당)'),
  ];
  List<IndexData> _baseRates = [
    IndexData(label: '한국'),
    IndexData(label: '미국'),
    IndexData(label: '일본'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
          api.fetchKospi(),
          api.fetchKosdaq(),
          api.fetchSP500(),
          api.fetchNasdaq(),
          api.fetchNikkei(),
          api.fetchSox(),
          api.fetchUsdKrw(),
          api.fetchJpyKrw(),
          api.fetchCnyKrw(),
          api.fetchWti(),
          api.fetchGold(),
          ecos_api.fetchKoreaRate(),
          ecos_api.fetchUsRate(),
          ecos_api.fetchJapanRate(),
        ]);

      final kospi = results[0] as api.NaverRealtimeItem?;
      final kosdaq = results[1] as api.NaverRealtimeItem?;
      final sp500 = results[2] as api.NaverRealtimeItem?;
      final nasdaq = results[3] as api.NaverRealtimeItem?;
      final nikkei = results[4] as api.NaverRealtimeItem?;
      final sox = results[5] as api.NaverRealtimeItem?;
      final usd = results[6] as String?;
      final jpy = results[7] as String?;
      final cny = results[8] as String?;
      final wti = results[9] as api.NaverRealtimeItem?;
      final gold = results[10] as api.NaverRealtimeItem?;
      final krRate = results[11] as ecos_api.EcosRow?;
      final usRate = results[12] as ecos_api.EcosRow?;
      final jpRate = results[13] as ecos_api.EcosRow?;

      String? jpyPer100;
      if (jpy != null) {
        final raw = double.tryParse(jpy.replaceAll(',', ''));
        if (raw != null) {
          jpyPer100 = (raw * 100).toStringAsFixed(2);
        }
      }

      setState(() {
        _domesticIndex = [
          IndexData(label: '코스피', value: toValueText(kospi), change: toChangeText(kospi), updatedAt: toTimeText(kospi)),
          IndexData(label: '코스닥', value: toValueText(kosdaq), change: toChangeText(kosdaq), updatedAt: toTimeText(kosdaq)),
        ];
        _overseasIndex = [
          IndexData(label: 'S&P500', value: toValueText(sp500), change: toChangeText(sp500), updatedAt: toTimeText(sp500)),
          IndexData(label: '나스닥', value: toValueText(nasdaq), change: toChangeText(nasdaq), updatedAt: toTimeText(nasdaq)),
          IndexData(label: '니케이225', value: toValueText(nikkei), change: toChangeText(nikkei), updatedAt: toTimeText(nikkei)),
          IndexData(label: '필라델피아반도체', value: toValueText(sox), change: toChangeText(sox), updatedAt: toTimeText(sox)),
        ];
        _exchangeRates = [
          IndexData(label: '원/달러', value: usd != null ? '$usd원' : null),
          IndexData(label: '원/100엔', value: jpyPer100 != null ? '$jpyPer100원' : null),
          IndexData(label: '원/위안', value: cny != null ? '$cny원' : null),
        ];
        _commodities = [
          IndexData(
            label: 'WTI 유가(배럴당)',
            value: toValueText(wti) != null ? '${toValueText(wti)} USD' : null,
            change: toChangeText(wti),
            updatedAt: toTimeText(wti),
          ),
          IndexData(
            label: '국제 금(온스당)',
            value: toValueText(gold) != null ? '${toValueText(gold)} USD' : null,
            change: toChangeText(gold),
            updatedAt: toTimeText(gold),
          ),
        ];
        _baseRates = [
          IndexData(
            label: '한국',
            value: krRate != null ? '${krRate.dataValue}%' : null,
            updatedAt: krRate != null ? ecos_api.formatEcosTime(krRate.time) : null,
          ),
          IndexData(
            label: '미국',
            value: usRate != null ? '${usRate.dataValue}%' : null,
            updatedAt: usRate != null ? ecos_api.formatEcosTime(usRate.time) : null,
          ),
          IndexData(
            label: '일본',
            value: jpRate != null ? '${jpRate.dataValue}%' : null,
            updatedAt: jpRate != null ? ecos_api.formatEcosTime(jpRate.time) : null,
          ),
        ];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            _TopBar(loading: _loading, onRefresh: _loadData),
            if (_loading) const _ProgressBar(),
            if (_error != null) _ErrorText(message: _error!),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final usableWidth = constraints.maxWidth - kScreenPadding * 2;
                  final columns = ((usableWidth + kCardGap) / (kMinCardWidth + kCardGap))
                      .floor()
                      .clamp(1, 999);
                  final cardWidth =
                      (usableWidth - kCardGap * (columns - 1)) / columns;

                  return RefreshIndicator(
                      onRefresh: _loadData,
                      color: kAccentBlue,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            kScreenPadding, 0, kScreenPadding, 24),
                        children: [
                          _Section(
                            title: '국내 지수',
                            child: _CardGrid(items: _domesticIndex, cardWidth: cardWidth),
                          ),
                          _Section(
                            title: '해외 지수',
                            child: _CardGrid(items: _overseasIndex, cardWidth: cardWidth),
                          ),
                          _Section(
                            title: '환율',
                            child: _CardGrid(items: _exchangeRates, cardWidth: cardWidth),
                          ),
                          _Section(
                            title: '원자재',
                            child: _CardGrid(items: _commodities, cardWidth: cardWidth),
                          ),
                          _Section(
                            title: '기준금리',
                            child: _CardGrid(items: _baseRates, cardWidth: cardWidth),
                          ),
                        ],
                      )
                    );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상단바 ──────────────────────────────
class _TopBar extends StatelessWidget {
  final bool loading;
  final VoidCallback onRefresh;

  const _TopBar({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPadding, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '금융 대시보드',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: Icon(
              loading ? Icons.more_horiz : Icons.refresh,
              color: kAccentBlue,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: LinearProgressIndicator(
        minHeight: 2,
        backgroundColor: Color(0xFFE0E0E0),
        valueColor: AlwaysStoppedAnimation<Color>(kAccentBlue),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kScreenPadding, 6, kScreenPadding, 0),
      child: Text(message, style: const TextStyle(color: kErrorRed, fontSize: 13)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  final List<IndexData> items;
  final double cardWidth;

  const _CardGrid({required this.items, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kCardGap,
      runSpacing: kCardGap,
      children: items
          .map((item) => _MarketCard(data: item, width: cardWidth))
          .toList(),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final IndexData data;
  final double width;

  const _MarketCard({required this.data, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label, style: const TextStyle(fontSize: 13, color: kGrayLabel)),
          const SizedBox(height: 4),
          Text(
            data.value ?? '불러오는 중',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          if (data.change != null) ...[
            const SizedBox(height: 4),
            Text(
              data.change!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: data.isUp ? kUpColor : kDownColor,
              ),
            ),
          ],
          if (data.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(data.updatedAt!, style: const TextStyle(fontSize: 11, color: kGrayTime)),
          ],
        ],
      ),
    );
  }
}
