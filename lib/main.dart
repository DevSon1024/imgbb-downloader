import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/downloader_page.dart';
import 'pages/history_page.dart';
import 'pages/menu_page.dart';
import 'pages/downloads_page.dart';
import 'services/download_service.dart';

// Data class for navigation items
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

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DownloadService(),
      child: const ImgBBDownloaderApp(),
    ),
  );
}

class ImgBBDownloaderApp extends StatelessWidget {
  const ImgBBDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImgBB Downloader',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final AnimationController _fabAnimationController;

  final List<Widget> _pages = [
    const HomePage(),
    const DownloadsPage(),
    const HistoryPage(),
    const MenuPage(),
  ];

  final List<NavigationItem> _navItems = [
    NavigationItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    NavigationItem(icon: Icons.download_for_offline_outlined, activeIcon: Icons.download_for_offline, label: 'Downloads'),
    NavigationItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
    NavigationItem(icon: Icons.menu, activeIcon: Icons.menu, label: 'Menu'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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
        margin: const EdgeInsets.all(16),
        height: 80,
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
      floatingActionButton: _buildModernFAB(),
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
              size: isSelected ? 26 : 24,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    final theme = Theme.of(context);
    return FloatingActionButton(
      heroTag: 'main_fab',
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 4,
      onPressed: () async {
        final result = await Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const DownloaderPage(),
        ));
        if (result == 'view_downloads' && mounted) {
          _onNavItemTapped(1); // Navigate to Downloads page
        }
      },
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}