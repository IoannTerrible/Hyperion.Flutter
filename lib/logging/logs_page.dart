import 'package:flutter/material.dart';
import 'package:hyperion_flutter/app_theme.dart';
import 'package:hyperion_flutter/logging/log_entry.dart';
import 'package:hyperion_flutter/logging/log_level.dart';
import 'package:hyperion_flutter/logging/logs_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _searchController = TextEditingController();
  DateTime? _selectedDate;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filtered {
    Iterable<LogEntry> all = LogsService.instance.all.reversed;

    if (_selectedDate != null) {
      final d = _selectedDate!;
      all = all.where((e) =>
          e.timestamp.year == d.year &&
          e.timestamp.month == d.month &&
          e.timestamp.day == d.day);
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      all = all.where((e) =>
          e.message.toLowerCase().contains(q) ||
          e.source.toLowerCase().contains(q));
    }

    return all.toList(growable: false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentLink,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppTheme.background),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Logs',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                        filled: true,
                        fillColor: AppTheme.surface.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate == null
                              ? 'Choose Date'
                              : '${_selectedDate!.day}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _selectedDate = null),
                            child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No logs',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _LogEntryTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final LogEntry entry;

  Color _levelColor() => switch (entry.level) {
        LogLevel.error => AppTheme.statusOffline,
        LogLevel.warn => AppTheme.statusStopped,
        LogLevel.info => AppTheme.textSecondary,
        LogLevel.debug => const Color(0x66A0A0A0),
      };

  String _fmtTime() {
    final t = entry.timestamp;
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          border: Border(
            left: BorderSide(color: _levelColor(), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '[${entry.source}]',
                  style: TextStyle(
                    color: _levelColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmtTime(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              entry.message,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
