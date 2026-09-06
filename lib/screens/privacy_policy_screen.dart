import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Privacy Highlight Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF34D399).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFF34D399), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '100% OFFLINE-FIRST PRIVACY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF34D399),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'REPP is built from the ground up to respect your privacy. No account required, zero tracking cookies, and no cloud servers. Your workout history, camera feed, and AI prompts never leave your device.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Last Updated: September 4, 2026',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          _PrivacySection(
            number: '1',
            title: 'Information We Do NOT Collect',
            content:
                'Because REPP operates offline-first without user accounts, we do NOT collect, store, or sell any of the following:\n\n'
                '• No Names, Email addresses, or Phone numbers.\n'
                '• No GPS Location or Geolocation tracking.\n'
                '• No Credit card or Financial information.\n'
                '• No Advertising IDs, Advertising trackers, or Profiling cookies.\n'
                '• No Server-side database records of your workouts or body metrics.',
          ),

          _PrivacySection(
            number: '2',
            title: 'Camera & Computer Vision Processing',
            content:
                'When you use real-time form guidance or pose detection:\n\n'
                '• Ephemeral Memory Processing: Camera frames are passed into the local pose estimator (Google ML Kit) strictly in volatile memory.\n'
                '• Instant Disposal: Video frames are immediately deleted from RAM after joint landmark coordinates are calculated.\n'
                '• No Biometric Templates: REPP does NOT perform facial recognition, retina scans, fingerprint identification, or store identifiable biometric signatures. Only generic 17-point 2D/3D skeleton coordinates (e.g. knee, shoulder, elbow offsets) are processed.\n'
                '• Zero Transmission: Raw camera feeds are NEVER uploaded to any server, third party, or cloud service.',
          ),

          _PrivacySection(
            number: '3',
            title: 'On-Device AI & Chat Prompts',
            content:
                'REPP executes AI coaching locally on your phone hardware using embedded models (via on-device neural inference engines):\n\n'
                '• Private Inferences: All chat prompts, workout generation requests, and form questions are processed 100% on your device\'s CPU/GPU.\n'
                '• No Cloud Logging: Your interactions with the AI Coach are never transmitted to external APIs, cloud servers, or third-party AI providers.',
          ),

          _PrivacySection(
            number: '4',
            title: 'Model Weight Downloads',
            content:
                'When downloading the optional offline AI model weights (~280MB ONNX file), the App establishes a direct HTTP connection to the public hosting repository (such as Hugging Face):\n\n'
                '• Standard Web Request: This download behaves like downloading any public web file and is subject to the hosting provider\'s standard server connection logs (such as your IP address).\n'
                '• Storage: Downloaded model weights are saved solely to your phone\'s local sandboxed application documents folder.',
          ),

          _PrivacySection(
            number: '5',
            title: 'Local Storage & Data Ownership',
            content:
                'All workout logs, exercise records, custom routines, gamified XP points, and app settings are stored locally on your device in an encrypted SQLite database and local preferences.\n\n'
                '• You Own Your Data: You have complete ownership and control of your workout history.\n'
                '• Data Deletion: You can permanently erase all stored app data at any time via Settings -> Data -> Clear All Data.',
          ),

          _PrivacySection(
            number: '6',
            title: 'Device Permissions',
            content:
                'REPP requests only minimal permissions necessary to provide its core functionality:\n\n'
                '• Camera (Optional): Used solely for live optical pose detection.\n'
                '• Microphone (Optional): Used only if you choose to record an audio query for the AI Coach.\n'
                '• Notifications (Optional): Used exclusively for rest timer alert sounds and workout reminders.',
          ),

          _PrivacySection(
            number: '7',
            title: 'Children\'s Privacy (COPPA & GDPR-K)',
            content:
                'The App is not directed to children under 13 (or under 16 in the European Union). We do not knowingly collect personal data from children.',
          ),

          _PrivacySection(
            number: '8',
            title: 'Changes to this Privacy Policy',
            content:
                'We may occasionally update this Privacy Policy. Any modifications will be reflected on this page with an updated "Last Updated" date.',
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Privacy questions or concerns: privacy@repp-app.local',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _PrivacySection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
