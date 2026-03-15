import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../database/db_helper.dart';
import '../../models/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  final int patientId;
  const NotificationScreen({super.key, required this.patientId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final maps =
        await DatabaseHelper.instance.getNotificationsByPatient(widget.patientId);
    setState(() {
      _notifications = maps.map((m) => AppNotification.fromMap(m)).toList();
      _isLoading     = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_sweep_rounded,
                color: AppTheme.dangerRed, size: 22),
          ),
          const SizedBox(width: 12),
          Text('Clear History',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Delete all notification history? This cannot be undone.',
          style: GoogleFonts.nunito(
              fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear All',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteAllNotifications(widget.patientId);
    if (!mounted) return;
    _loadNotifications();
  }

  Future<void> _deleteOne(AppNotification n) async {
    if (n.id == null) return;
    await DatabaseHelper.instance.deleteNotification(n.id!);
    if (!mounted) return;
    setState(() => _notifications.removeWhere((item) => item.id == n.id));
  }

  String _formatTimestamp(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min  = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.patientGradient),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications',
                          style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Reminder & alert history',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                  const Spacer(),
                  if (_notifications.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAll,
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_sweep_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.patientPrimary))
                  : _notifications.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                          itemCount: _notifications.length,
                          itemBuilder: (ctx, i) {
                            final n         = _notifications[i];
                            final isMissed  = n.title.toLowerCase().contains('missed');
                            final dotColor  = isMissed
                                ? AppTheme.warningOrange
                                : AppTheme.patientPrimary;
                            final iconColor = dotColor;
                            final icon      = isMissed
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_active_rounded;

                            return Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _deleteOne(n),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.dangerGradient,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: const Icon(Icons.delete_rounded,
                                    color: Colors.white, size: 26),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppTheme.cardShadow,
                                  border: Border(
                                    left: BorderSide(color: dotColor, width: 4),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: iconColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(icon,
                                            color: iconColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(n.title,
                                                style: GoogleFonts.nunito(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                    color: AppTheme.textPrimary)),
                                            const SizedBox(height: 3),
                                            Text(n.body,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.nunito(
                                                    fontSize: 13,
                                                    color: AppTheme.textSecondary,
                                                    height: 1.3)),
                                            const SizedBox(height: 6),
                                            // Timestamp chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.patientPrimary
                                                    .withOpacity(0.07),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                const Icon(
                                                    Icons.access_time_rounded,
                                                    size: 11,
                                                    color: AppTheme.textHint),
                                                const SizedBox(width: 4),
                                                Text(
                                                    _formatTimestamp(
                                                        n.timestamp),
                                                    style: GoogleFonts.nunito(
                                                        fontSize: 10,
                                                        color: AppTheme.textHint,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ]),
                                            ),
                                          ],
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
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppTheme.patientLight, shape: BoxShape.circle),
          child: const Icon(Icons.notifications_off_outlined,
              size: 42, color: AppTheme.patientPrimary),
        ),
        const SizedBox(height: 18),
        Text('No notifications yet.',
            style: GoogleFonts.nunito(
                fontSize: 16, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Text('Reminders and alerts will appear here.',
            style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textHint)),
      ]),
    );
  }
}
