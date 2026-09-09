import 'naver_api.dart';

String? toValueText(NaverRealtimeItem? item) => item?.closePrice;

String? toChangeText(NaverRealtimeItem? item) {
  if (item == null) return null;
  final isDown = item.fluctuationsTypeName == 'FALLING';
  final sign = item.fluctuationsTypeName != null
      ? (isDown ? '-' : '+')
      : (item.fluctuationsRatio.startsWith('-') ? '-' : '+');
  final cleanRatio = item.fluctuationsRatio.replaceAll('-', '');
  return '$sign$cleanRatio%';
}

String? toTimeText(NaverRealtimeItem? item) {
  if (item?.localTradedAt == null) return null;
  try {
    final d = DateTime.parse(item!.localTradedAt!);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  } catch (_) {
    return null;
  }
}