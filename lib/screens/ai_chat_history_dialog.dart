import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ai/chat_session_service.dart';
import '../theme/app_colors.dart';

class AiChatHistoryDialog extends StatefulWidget {
  final String currentSessionId;
  final Function(ChatSession) onSelectSession;
  final VoidCallback onNewChat;
  final Function(String sessionId)? onDeleteSession;

  const AiChatHistoryDialog({
    super.key,
    required this.currentSessionId,
    required this.onSelectSession,
    required this.onNewChat,
    this.onDeleteSession,
  });

  @override
  State<AiChatHistoryDialog> createState() => _AiChatHistoryDialogState();
}

class _AiChatHistoryDialogState extends State<AiChatHistoryDialog> {
  final ChatSessionService _sessionService = ChatSessionService();
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _selectedDate;
  List<ChatSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    await _sessionService.loadSessions();
    _applyFilter();
  }

  void _applyFilter() {
    final filtered = _sessionService.search(
      query: _searchCtrl.text,
      filterDate: _selectedDate,
    );
    if (mounted) {
      setState(() {
        _sessions = filtered;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2023),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilter();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 480),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat Sessions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Filtered by last updated time',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search and Date Filter Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search sessions or messages...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyFilter();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                    ),
                    onChanged: (_) => _applyFilter(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: _selectedDate == null ? 'Filter by date' : 'Change date',
                  style: IconButton.styleFrom(
                    backgroundColor: _selectedDate != null
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : null,
                  ),
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: _selectedDate != null ? AppColors.primary : null,
                  ),
                  onPressed: _pickDate,
                ),
              ],
            ),

            if (_selectedDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Last updated: ${DateFormat.yMMMd().format(_selectedDate!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _clearDateFilter,
                          child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Sessions List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              const Text('No chat sessions found', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                _searchCtrl.text.isNotEmpty || _selectedDate != null
                                    ? 'Try changing your search or date filter.'
                                    : 'Start a conversation with REPP Coach to see it here.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _sessions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = _sessions[i];
                            final isCurrent = s.id == widget.currentSessionId;
                            final dateFormatted = _formatLastUpdated(s.lastUpdatedAt);

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isCurrent
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                child: Icon(
                                  isCurrent ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: isCurrent ? AppColors.primary : Colors.grey,
                                ),
                              ),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isCurrent ? AppColors.primary : null,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    dateFormatted,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${s.messages.length} msgs',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                                tooltip: 'Delete session',
                                onPressed: () async {
                                  final wasCurrent = s.id == widget.currentSessionId;
                                  await _sessionService.deleteSession(s.id);
                                  widget.onDeleteSession?.call(s.id);
                                  if (!context.mounted) return;
                                  if (wasCurrent) {
                                    widget.onNewChat();
                                    Navigator.of(context).pop();
                                  } else {
                                    _applyFilter();
                                  }
                                },
                              ),
                              onTap: () {
                                widget.onSelectSession(s);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
            ),

            const SizedBox(height: 12),

            // Bottom Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    widget.onNewChat();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
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

  String _formatLastUpdated(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
