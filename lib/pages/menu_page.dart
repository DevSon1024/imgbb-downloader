import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_settings_page.dart';
import 'storage_setting_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMenuItem(
            context: context, // Corrected
            icon: CupertinoIcons.settings,
            title: 'App Settings',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsPage())),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context: context, // Corrected
            icon: CupertinoIcons.folder,
            title: 'Storage Settings',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageSettingPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleMedium),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}