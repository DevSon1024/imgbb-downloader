import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_notifier.dart';
import 'pages/home_page.dart';
import 'pages/downloader_page.dart';
import 'pages/history_page.dart';
import 'pages/menu_page.dart';
import 'pages/downloads_page.dart';
import 'services/download_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('thumbnails');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DownloadService()),
        ChangeNotifierProvider(create: (context) => ThemeNotifier()),
      ],
      child: const ImgBBDownloaderApp(),
    ),
  );
}

class ImgBBDownloaderApp extends StatelessWidget {
  const ImgBBDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'ImgBB Downloader',
          theme: ThemeData(
            primarySwatch: Colors.deepPurple,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.deepPurple,
            useMaterial3: true,
          ),
          themeMode: themeNotifier.themeMode,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  final List<Widget> _pages = [
    const HomePage(),
    const DownloadsPage(),
    const HistoryPage(),
    const MenuPage(),
  ];

  final List<NavigationItem> _navItems = [
    NavigationItem(
        icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    NavigationItem(
        icon: Icons.download_for_offline_outlined,
        activeIcon: Icons.download_for_offline,
        label: 'Downloads'),
    NavigationItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'History'),
    NavigationItem(
        icon: Icons.menu, activeIcon: Icons.menu_open, label: 'Menu'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        height: 70,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildModernNavItem(0),
            _buildModernNavItem(1),
            const SizedBox(width: 56), // Space for FAB
            _buildModernNavItem(2),
            _buildModernNavItem(3),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const DownloaderPage(),
          ));
          if (result == 'view_downloads' && mounted) {
            _onNavItemTapped(1);
          }
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildModernNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: () => _onNavItemTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}