import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';
import 'loading_animation.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });
    final items = await HistoryService.load();
    setState(() {
      _history = items;
      _isLoading = false;
    });
  }

  Future<void> _deleteEntry(int index) async {
    await HistoryService.remove(index);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text("Are you sure you want to delete all search history?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryService.clear();
      _loadHistory();
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = dateTime.toLocal();
    final isToday = now.year == localDateTime.year &&
                    now.month == localDateTime.month &&
                    now.day == localDateTime.day;
                    
    final isYesterday = now.year == localDateTime.year &&
                        now.month == localDateTime.month &&
                        now.subtract(const Duration(days: 1)).day == localDateTime.day;
                        
    final hour = localDateTime.hour.toString().padLeft(2, '0');
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    
    if (isToday) {
      return "Today $hour:$minute";
    } else if (isYesterday) {
      return "Yesterday $hour:$minute";
    } else {
      final month = localDateTime.month.toString().padLeft(2, '0');
      final day = localDateTime.day.toString().padLeft(2, '0');
      return "${localDateTime.year}-$month-$day $hour:$minute";
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch $urlString")),
        );
      }
    }
  }

  Widget _platformIcon({
    required FaIconData icon,
    required Color color,
    required String? url,
    required String tooltip,
  }) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return IconButton(
      onPressed: () => _launchUrl(url),
      tooltip: tooltip,
      icon: FaIcon(icon, size: 18, color: color),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: GlowingLoadingIndicator(
          title: "Loading search history...",
          subtitle: "Retrieving your recent searches...",
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 80,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  "No searches yet",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Start identifying music to build your history.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header / Clear option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Search History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text("Clear All"),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),

            // History List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  final guess = item.results.isNotEmpty ? item.results.first : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 1,
                    shadowColor: Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: (guess?.links?.youtube != null && guess!.links!.youtube!.isNotEmpty)
                          ? () => _launchUrl(guess.links!.youtube!)
                          : null,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Column Album Art Container
                            Container(
                              width: 100,
                              height: 100,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: guess?.cover != null && guess!.cover!.isNotEmpty
                                  ? Image.network(
                                      guess.cover!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(Icons.music_note_rounded, size: 32, color: theme.colorScheme.primary),
                                    )
                                  : Icon(Icons.music_note_rounded, size: 32, color: theme.colorScheme.primary),
                            ),
                            // Right Content
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "🎵 ${guess?.title ?? 'Unknown Title'}",
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                guess?.artist ?? 'Unknown Artist',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Album: ${guess?.album ?? 'Unknown Album'}",
                                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Trailing delete button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                          onPressed: () => _deleteEntry(index),
                                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                                          tooltip: "Delete Search",
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Divider(
                                        height: 1,
                                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Left: source + timestamp stacked
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    item.isUrl ? Icons.link_rounded : Icons.audio_file_rounded,
                                                    size: 12,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      item.input,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTimestamp(item.timestamp),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme.colorScheme.onSurfaceVariant
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right: platform icons
                                        if (guess?.links != null) ...[
                                          const SizedBox(width: 8),
                                          _platformIcon(
                                            icon: FontAwesomeIcons.spotify,
                                            color: const Color(0xFF1DB954),
                                            url: guess!.links!.spotify,
                                            tooltip: 'Search on Spotify',
                                          ),
                                          _platformIcon(
                                            icon: FontAwesomeIcons.apple,
                                            color: const Color(0xFFFA243C),
                                            url: guess.links!.appleMusic,
                                            tooltip: 'Open in Apple Music',
                                          ),
                                          _platformIcon(
                                            icon: FontAwesomeIcons.youtube,
                                            color: const Color(0xFFFF0000),
                                            url: guess.links!.youtube,
                                            tooltip: 'Open in YouTube',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Optional footer showing item count
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Text(
                "Showing ${_history.length} / 20 stored searches",
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
