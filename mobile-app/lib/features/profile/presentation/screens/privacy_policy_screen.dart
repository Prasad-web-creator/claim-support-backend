import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy for ClaimSupport',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last Updated: July 24, 2026',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Introduction',
              'Welcome to ClaimSupport. Your privacy is critically important to us. This Privacy Policy outlines the types of personal information that is received and collected and how it is used.',
            ),
            _buildSection(
              '2. Information We Collect',
              'When you use ClaimSupport to analyze your medical bills and insurance policies, we collect:\n\n'
              '• Personal Identification Information (Name, Email)\n'
              '• Uploaded Documents (Policies, Prescriptions, Bills)\n'
              '• App Activity and Usage Data',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use your information exclusively to provide the core services of the app. Your medical documents are processed by our AI analysis engine strictly to determine your claim eligibility and coverage status. We do not sell your personal data to third parties.',
            ),
            _buildSection(
              '4. Data Security',
              'We implement state-of-the-art security measures to maintain the safety of your personal information when you upload or access your medical documents. All sensitive information is encrypted via Secure Socket Layer (SSL) technology.',
            ),
            _buildSection(
              '5. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at privacy@claimsupport.com.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
