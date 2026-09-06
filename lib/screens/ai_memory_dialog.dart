import 'package:flutter/material.dart';
import '../ai/memory/user_memory_service.dart';
import '../theme/app_colors.dart';

class AiMemoryDialog extends StatefulWidget {
  const AiMemoryDialog({super.key});

  @override
  State<AiMemoryDialog> createState() => _AiMemoryDialogState();
}

class _AiMemoryDialogState extends State<AiMemoryDialog> {
  final UserMemoryService _memoryService = UserMemoryService();
  UserMemoryProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await _memoryService.getProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 520, maxWidth: 460),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Persistent Coach Memory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_profile == null || _profile!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notes_rounded, size: 40, color: Colors.grey.shade600),
                      const SizedBox(height: 8),
                      const Text(
                        'No memories saved yet.',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tell the coach about your workout goals, injuries, or home equipment, and it will remember them automatically!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_profile!.goal != null && _profile!.goal!.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Primary Goal', Icons.flag_rounded),
                        _buildChipGroup([_profile!.goal!], color: AppColors.primary),
                        const SizedBox(height: 14),
                      ],
                      if (_profile!.injuries.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Injuries & Joint Limitations', Icons.healing_rounded),
                        _buildChipGroup(_profile!.injuries, color: Colors.redAccent),
                        const SizedBox(height: 14),
                      ],
                      if (_profile!.equipment.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Available Equipment', Icons.fitness_center_rounded),
                        _buildChipGroup(_profile!.equipment, color: Colors.teal),
                        const SizedBox(height: 14),
                      ],
                      if (_profile!.preferences.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Preferences', Icons.tune_rounded),
                        _buildChipGroup(_profile!.preferences, color: Colors.purpleAccent),
                        const SizedBox(height: 14),
                      ],
                      if (_profile!.customNotes.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Custom Notes', Icons.sticky_note_2_rounded),
                        ..._profile!.customNotes.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• ${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                            )),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_profile != null && !_profile!.isEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: () async {
                      await _memoryService.clearMemory();
                      if (mounted) {
                        setState(() {
                          _profile = UserMemoryProfile();
                        });
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Clear Memory', style: TextStyle(fontSize: 12)),
                  )
                else
                  const SizedBox.shrink(),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup(List<String> items, {required Color color}) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}
