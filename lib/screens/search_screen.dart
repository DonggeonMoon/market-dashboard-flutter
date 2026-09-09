import 'package:flutter/material.dart';
import '../api/naver_search_api.dart';
import '../db/favorites_db.dart' as db;
import '../models/stock_summary.dart';
import '../theme.dart';
import 'stock_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  List<StockSummary> _results = [];
  bool _searched = false;
  bool _loading = false;
  Set<String> _favoriteCodes = {};

  @override
  void initState() {
    super.initState();
    _loadFavoriteCodes();
  }

  Future<void> _loadFavoriteCodes() async {
    final favorites = await db.getFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteCodes = favorites.map((s) => s.code).toSet();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searched = true;
        _results = [];
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    final results = await searchStocks(query);

    if (!mounted) return;
    setState(() {
      _searched = true;
      _loading = false;
      _results = results;
    });
  }

  Future<void> _openDetail(StockSummary stock) async {
    final isFavoriteNow = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(
          stock: stock,
          initialIsFavorite: _favoriteCodes.contains(stock.code),
        ),
      ),
    );

    if (isFavoriteNow == null || !mounted) return;
    setState(() {
      if (isFavoriteNow) {
        _favoriteCodes.add(stock.code);
      } else {
        _favoriteCodes.remove(stock.code);
      }
    });
  }

  Future<void> _toggleFavorite(StockSummary stock) async {
    final willBeFavorite = !_favoriteCodes.contains(stock.code);

    setState(() {
      if (willBeFavorite) {
        _favoriteCodes.add(stock.code);
      } else {
        _favoriteCodes.remove(stock.code);
      }
    });

    if (willBeFavorite) {
      await db.addFavorite(stock.code, stock.name, stock.market);
    } else {
      await db.removeFavorite(stock.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kScreenPadding, 12, kScreenPadding, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: '종목명 또는 코드 검색',
                        filled: true,
                        fillColor: kCardBg,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _runSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('검색'),
                  ),
                ],
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
      return const Center(
        child: CircularProgressIndicator(color: kAccentBlue),
      );
    }
    if (!_searched) {
      return const _CenterHint(text: '종목명 또는 코드를 검색해보세요');
    }
    if (_results.isEmpty) {
      return const _CenterHint(text: '검색 결과가 없습니다');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final stock = _results[index];
        return _SearchResultTile(
          stock: stock,
          isFavorite: _favoriteCodes.contains(stock.code),
          onTap: () => _openDetail(stock),
          onToggleFavorite: () => _toggleFavorite(stock),
        );
      },
    );
  }
}

class _CenterHint extends StatelessWidget {
  final String text;

  const _CenterHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: kGrayLabel, fontSize: 14)),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final StockSummary stock;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _SearchResultTile({
    required this.stock,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        stock.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        '${stock.code} · ${stock.market}',
        style: const TextStyle(color: kGrayLabel, fontSize: 13),
      ),
      trailing: IconButton(
        onPressed: onToggleFavorite,
        icon: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: isFavorite ? kAccentBlue : kGrayTime,
        ),
      ),
    );
  }
}
