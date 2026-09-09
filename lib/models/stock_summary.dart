/// 검색 결과, 관심종목 목록, 상세 화면 진입에 공통으로 쓰는 종목 식별 정보.
class StockSummary {
  final String code;
  final String name;
  final String market;

  final String reutersCode;
  final bool isForeign;

  const StockSummary({
    required this.code,
    required this.name,
    required this.market,
    String? reutersCode,
    this.isForeign = false,
  }) : reutersCode = reutersCode ?? code;
}
