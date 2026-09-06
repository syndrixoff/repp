import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ai/local_llm_service.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

class AiSetupScreen extends StatefulWidget {
  final bool isFromSettings;
  const AiSetupScreen({super.key, this.isFromSettings = false});

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFromSettings ? AppBar(title: const Text('Setup AI Coach')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 32),
              Text(
                'AI Coach Setup',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enable the local AI coach for smart form feedback and workout planning. This requires downloading a ~1.2GB model to your device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final settings = context.read<SettingsProvider>();
                  await settings.setAiFeatureEnabled(true);
                  await settings.setHasSeenAiSetup(true);

                  // Immediately start downloading the model
                  ModelDownloadService().startDownload();

                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Enable AI Coach & Download',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!widget.isFromSettings)
                TextButton(
                  onPressed: () async {
                    final settings = context.read<SettingsProvider>();
                    await settings.setAiFeatureEnabled(false);
                    await settings.setHasSeenAiSetup(true);
                    if (context.mounted) Navigator.pop(context, false);
                  },
                  child: const Text('Skip for now'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
