import 'package:flutter/material.dart';

enum SetTypeOption { warmUp, normal, failure, drop, remove }

class SetTypeBottomSheet extends StatelessWidget {
  final int setNumber;

  const SetTypeBottomSheet({super.key, required this.setNumber});

  static Future<SetTypeOption?> show(BuildContext context, int setNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<SetTypeOption>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SetTypeBottomSheet(setNumber: setNumber),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  text,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String label,
    required String title,
    required Color labelColor,
    required SetTypeOption value,
    String? infoTitle,
    String? infoText,
    bool isDestructive = false,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: isDark ? 0.08 : 0.04)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Set type badge
            Container(
              width: 40,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.12)
                    : labelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : labelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (infoText != null)
              GestureDetector(
                onTap: () =>
                    _showInfoDialog(context, infoTitle ?? title, infoText),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.question_mark_rounded,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            // Title
            Text(
              'Select Set Type',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to change the type for this set',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
            ),
            const SizedBox(height: 8),

            // Warm Up
            _buildOption(
              context: context,
              label: 'W',
              title: 'Warm Up Set',
              labelColor: Colors.orange,
              value: SetTypeOption.warmUp,
              isDark: isDark,
              infoTitle: 'Warm Up Set',
              infoText:
                  'Warm up sets are used to prepare the body to lift heavier weights. They help increase blood flow and reduce risk of injury.',
            ),

            // Normal
            _buildOption(
              context: context,
              label: setNumber.toString(),
              title: 'Normal Set',
              labelColor: isDark ? Colors.white : Colors.black87,
              value: SetTypeOption.normal,
              isDark: isDark,
              infoTitle: 'Normal (Working) Set',
              infoText:
                  'Normal sets refer to "working sets" — these are the sets that drive strength and muscle growth. Track them accurately for best results.',
            ),

            // Failure
            _buildOption(
              context: context,
              label: 'F',
              title: 'Failure Set',
              labelColor: Colors.red,
              value: SetTypeOption.failure,
              isDark: isDark,
              infoTitle: 'Failure Set',
              infoText:
                  'A failure set is a normal set in which you reached muscular failure and were not able to complete the last rep successfully.\n\nIf you fail on your 11th rep, record 10 reps.',
            ),

            // Drop
            _buildOption(
              context: context,
              label: 'D',
              title: 'Drop Set',
              labelColor: Colors.blue,
              value: SetTypeOption.drop,
              isDark: isDark,
              infoTitle: 'Drop Set',
              infoText:
                  'A technique for continuing an exercise with a lower weight once muscle failure has been achieved at a higher weight. Great for pushing past plateaus.',
            ),

            const SizedBox(height: 4),
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
            ),
            const SizedBox(height: 4),

            // Remove
            _buildOption(
              context: context,
              label: '✕',
              title: 'Remove Set',
              labelColor: Colors.red,
              value: SetTypeOption.remove,
              isDestructive: true,
              isDark: isDark,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
