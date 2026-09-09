import 'stock_summary.dart';

class StockBasicInfo {
  final String? market;
  final String? closePrice;
  final String? changeText;
  final bool isUp;
  final String? openPrice;
  final String? highPrice;
  final String? lowPrice;
  final String? volume;
  final String? tradingValue;
  final String? marketCap;
  final String? updatedAt;

  const StockBasicInfo({
    this.market,
    this.closePrice,
    this.changeText,
    this.isUp = true,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.volume,
    this.tradingValue,
    this.marketCap,
    this.updatedAt,
  });
}

class StockIndicators {
  final String? per;
  final String? eps;
  final String? estimatedPer;
  final String? estimatedEps;
  final String? pbr;
  final String? bps;
  final String? dividendYield;
  final String? week52High;
  final String? week52Low;
  final String? foreignRatio;
  final String? marketCap;

  const StockIndicators({
    this.per,
    this.eps,
    this.estimatedPer,
    this.estimatedEps,
    this.pbr,
    this.bps,
    this.dividendYield,
    this.week52High,
    this.week52Low,
    this.foreignRatio,
    this.marketCap,
  });
}

/// 재무비율 표의 한 개 연도 컬럼
class FinancialYear {
  final String year;
  final String? revenue;
  final String? operatingProfit;
  final String? netProfit;
  final String? operatingMargin;
  final String? netMargin;
  final String? roe;
  final String? roa;
  final String? debtRatio;

  const FinancialYear({
    required this.year,
    this.revenue,
    this.operatingProfit,
    this.netProfit,
    this.operatingMargin,
    this.netMargin,
    this.roe,
    this.roa,
    this.debtRatio,
  });
}

/// 컨센서스 (증권사 평균 의견)
class ConsensusInfo {
  final String? opinion;
  final String? targetPrice;
  final String? eps;
  final String? per;
  final String? analystCount;

  const ConsensusInfo({
    this.opinion,
    this.targetPrice,
    this.eps,
    this.per,
    this.analystCount,
  });
}

/// 상세 화면 전체가 필요로 하는 데이터를 한 데 묶은 모델.
class StockDetail {
  final StockSummary summary;
  final StockBasicInfo? basicInfo;
  final StockIndicators? indicators;
  final List<String> companyOverview;
  final List<FinancialYear> financials;
  final ConsensusInfo? consensus;

  const StockDetail({
    required this.summary,
    this.basicInfo,
    this.indicators,
    this.companyOverview = const [],
    this.financials = const [],
    this.consensus,
  });
}
