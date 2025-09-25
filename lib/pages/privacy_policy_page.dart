import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for ImgBB Downloader',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last Updated: September 25, 2025',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            const Text(
              'This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You.',
            ),
            const SizedBox(height: 16),
            Text(
              'Information Collection and Use',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'We do not collect any personally identifiable information from our users. The application is designed to function without requiring personal data.',
            ),
            const SizedBox(height: 16),
            Text(
              'Permissions',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The app requires storage permissions to save downloaded images to your device. This permission is used solely for this purpose and we do not access any other files on your device.',
            ),
            const SizedBox(height: 16),
            Text(
              'Third-Party Services',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This application interacts with the ImgBB (imgbb.com) service to fetch images. We are not responsible for the privacy practices of ImgBB. We recommend you review their privacy policy.',
            ),
            const SizedBox(height: 16),
            Text(
              'Data Storage',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Downloaded images are stored locally on your device in a folder you select or the default downloads folder. We do not have access to these images.',
            ),
            const SizedBox(height: 16),
            Text(
              'Changes to This Privacy Policy',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'We may update Our Privacy Policy from time to time. We will notify You of any changes by posting the new Privacy Policy on this page.',
            ),
            const SizedBox(height: 16),
            Text(
              'Contact Us',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'If you have any questions about this Privacy Policy, You can contact us by email: contact.devson@gmail.com',
            ),
          ],
        ),
      ),
    );
  }
}
