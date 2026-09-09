import 'package:flutter/material.dart';
import '../db/favorites_db.dart' as db;
import '../models/stock_summary.dart';
import '../theme.dart';
import 'stock_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

/// public State: RootScreen이 GlobalKey로 이 State를 직접 참조해서
/// 탭을 다시 선택할 때마다 reload()를 호출합니다.
class FavoritesScreenState extends State<FavoritesScreen> {
  List<StockSummary> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
    });
    final favorites = await db.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _openDetail(StockSummary stock) async {
    final isFavoriteNow = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(stock: stock, initialIsFavorite: true),
      ),
    );

    if (isFavoriteNow == false && mounted) {
      setState(() {
        _favorites = _favorites.where((s) => s.code != stock.code).toList();
      });
    }
  }

  Future<void> _removeFavorite(StockSummary stock) async {
    setState(() {
      _favorites = _favorites.where((s) => s.code != stock.code).toList();
    });
    await db.removeFavorite(stock.code);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(kScreenPadding, 16, kScreenPadding, 8),
              child: Text(
                '관심종목',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccentBlue));
    }
    if (_favorites.isEmpty) {
      return const Center(
        child: Text(
          '관심종목이 없습니다\n검색 탭에서 별을 눌러 추가해보세요',
          textAlign: TextAlign.center,
          style: TextStyle(color: kGrayLabel, fontSize: 14),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      color: kAccentBlue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final stock = _favorites[index];
          return ListTile(
            onTap: () => _openDetail(stock),
            title: Text(
              stock.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              '${stock.code} · ${stock.market}',
              style: const TextStyle(color: kGrayLabel, fontSize: 13),
            ),
            trailing: IconButton(
              onPressed: () => _removeFavorite(stock),
              icon: const Icon(Icons.star, color: kAccentBlue),
            ),
          );
        },
      ),
    );
  }
}
