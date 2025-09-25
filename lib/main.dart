import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/downloader_page.dart';
import 'pages/history_page.dart';
import 'pages/menu_page.dart';
import 'pages/downloads_page.dart';
import 'services/download_service.dart';

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
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Widget> _pages = [
    const HomePage(),
    const DownloadsPage(),
    const HistoryPage(),
    const MenuPage(),
  ];

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
    if (index == 2) { // The placeholder for FAB
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DownloaderPage()));
      return;
    }

    int pageIndex = index > 2 ? index - 1 : index;
    _pageController.jumpToPage(pageIndex);

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_outlined, "Home", 0),
            _buildNavItem(Icons.download_for_offline_outlined, "Downloads", 1),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(Icons.history, "History", 3),
            _buildNavItem(Icons.menu, "Menu", 4),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onNavItemTapped(2),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
      onPressed: () => _onNavItemTapped(index),
      tooltip: label,
    );
  }
}