import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'db/favorites_db.dart' as db;
import 'screens/dashboard_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await db.initDatabase();
  runApp(const MarketDashboardApp());
}

class MarketDashboardApp extends StatelessWidget {
  const MarketDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '금융 대시보드',
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFFFFFFF)),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;

  // 관심종목 탭은 검색/상세 화면에서 즐겨찾기를 바꿔도 자동으로 갱신되지 않으므로,
  // 탭을 다시 선택할 때 이 키로 FavoritesScreenState.reload()를 직접 호출합니다.
  final _favoritesKey = GlobalKey<FavoritesScreenState>();

  // IndexedStack이 화면 상태(검색어, 스크롤 위치 등)를 유지하려면 매 build마다
  // 새로 만들지 않고 같은 위젯 인스턴스를 계속 재사용해야 합니다.
  late final _screens = [
    const DashboardScreen(),
    const SearchScreen(),
    FavoritesScreen(key: _favoritesKey),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      _favoritesKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kAccentBlue,
        unselectedItemColor: kGrayTime,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '검색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            activeIcon: Icon(Icons.star),
            label: '관심종목',
          ),
        ],
      ),
    );
  }
}
