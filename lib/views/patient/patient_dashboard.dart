import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../database/db_helper.dart';
import '../login_screen.dart';
import 'add_medicine_screen.dart';
import '../../models/medicine.dart';
import 'notification_screen.dart';
import 'progress_report_screen.dart';
import 'profile_screen.dart';
import '../alarm_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class PatientDashboard extends StatefulWidget {
  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with SingleTickerProviderStateMixin {
  int? _patientId;
  List<Medicine> _medicines = [];
  Set<int> _takenTodayIds = {};
  String? _caregiverPhone;
  bool _isLoading = true;
  late TabController _tabController;
  String _greeting = 'Hello';
  String _userName = '';

  Timer? _alarmTimer;
  // Key: "medicineId_slotIndex" — tracks each slot fired today independently
  final Set<String> _alarmFiredKeys = {};
  String _lastAlarmDate = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _updateGreeting();
    _alarmTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _checkAlarms());
  }

  void _updateGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) _greeting = 'Good morning';
    else if (h < 17) _greeting = 'Good afternoon';
    else _greeting = 'Good evening';
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _checkAlarms() {
    if (_medicines.isEmpty) return;
    final now   = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    if (today != _lastAlarmDate) { _alarmFiredKeys.clear(); _lastAlarmDate = today; }

    for (final med in _medicines) {
      if (med.id == null) continue;
      // Support multiple comma-separated dose times
      final slots = med.schedule.split(',');
      for (int i = 0; i < slots.length; i++) {
        final key = '${med.id}_$i';
        if (_alarmFiredKeys.contains(key)) continue;
        final schedTime = _parseSingleTime(slots[i].trim());
        if (schedTime == null) continue;
        final schedMin = schedTime.hour * 60 + schedTime.minute;
        final nowMin   = now.hour * 60 + now.minute;
        final diff     = nowMin - schedMin;
        if (diff >= 0 && diff < 2) {
          _alarmFiredKeys.add(key);
          _showAlarmScreen(med, slotLabel: slots.length > 1 ? 'Dose ${i + 1}' : null);
        }
      }
    }
  }

  TimeOfDay? _parseSingleTime(String s) {
    try {
      final lower  = s.toLowerCase();
      final parts  = s.trim().split(RegExp(r'[ :]+'));
      int hour     = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);
      if (lower.contains('pm') && hour < 12) hour += 12;
      if (lower.contains('am') && hour == 12) hour  = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) { return null; }
  }

  void _showAlarmScreen(Medicine med, {String? slotLabel}) {
    if (!mounted) return;
    final payload = jsonEncode({
      'name': med.name,
      'dosage': slotLabel != null ? '${med.dosage} ($slotLabel)' : med.dosage,
      'purpose': med.purpose,
      'id': med.id,
    });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlarmScreen.fromPayload(payload),
      fullscreenDialog: true,
    ));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final session   = await AuthService().getSession();
    final patientId = session['userId'];
    if (patientId != null) {
      final medMaps = await DatabaseHelper.instance.getMedicinesByPatient(patientId);
      final todayPrefix = DateTime.now().toIso8601String().substring(0, 10);
      final db = await DatabaseHelper.instance.database;
      final todayLogs = await db.query('logs',
          where: 'taken_time LIKE ?', whereArgs: ['$todayPrefix%']);
      final takenTodayIds = todayLogs.map((l) => l['medicine_id'] as int).toSet();
      final caregiverPhone = await DatabaseHelper.instance.getCaregiverPhone(patientId);
      final user = await DatabaseHelper.instance.getUser(patientId);
      NotificationService().setPatientId(patientId);
      setState(() {
        _patientId      = patientId;
        _medicines      = medMaps.map((m) => Medicine.fromMap(m)).toList();
        _takenTodayIds  = takenTodayIds;
        _caregiverPhone = caregiverPhone;
        _userName       = (user?['full_name'] as String?)?.split(' ').first ?? '';
        _isLoading      = false;
      });
      _checkAlarms();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  Future<void> _callCaregiver() async {
    final phone = _caregiverPhone;
    if (phone == null || phone.trim().isEmpty) { await _setCaregiverPhone(); return; }
    try {
      await launchUrl(Uri(scheme: 'tel', path: phone.trim()),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open dialer.')));
    }
  }

  Future<void> _setCaregiverPhone() async {
    final ctrl   = TextEditingController(text: _caregiverPhone ?? '');
    final saved  = await showDialog<String>(
      context: context,
      builder: (ctx) => _premiumDialog(
        ctx: ctx,
        title: 'Emergency Contact',
        icon: Icons.phone_in_talk_rounded,
        iconColor: AppTheme.dangerRed,
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.nunito(fontSize: 15),
          decoration: AppTheme.inputDecoration(
            label: 'Caregiver phone number',
            icon: Icons.phone_rounded,
            primaryColor: AppTheme.patientPrimary,
          ),
        ),
        confirmText: 'Save',
        confirmColor: AppTheme.patientPrimary,
        onConfirm: () => Navigator.pop(ctx, ctrl.text.trim()),
      ),
    );
    if (saved != null && saved.isNotEmpty && _patientId != null) {
      await DatabaseHelper.instance.setCaregiverPhone(_patientId!, saved);
      setState(() => _caregiverPhone = saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Caregiver number saved.')));
    }
  }

  Future<void> _markMedicine(int medicineId, String status) async {
    await DatabaseHelper.instance.createLog({
      'medicine_id': medicineId,
      'taken_time': DateTime.now().toIso8601String(),
      'status': status,
    });
    if (status == 'taken') {
      await DatabaseHelper.instance.decrementQuantity(medicineId);
      // Cancel all per-slot missed & caregiver notifications for today
      // (they were set for skipToday=true, so tomorrow's are untouched)
      for (int s = 0; s < 10; s++) {
        await NotificationService().cancelNotification(medicineId * 1000 + s + 10000);
        await NotificationService().cancelNotification(medicineId * 1000 + s + 20000);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status == 'taken' ? '✓ Marked as taken!' : '✗ Dose skipped'),
      backgroundColor:
          status == 'taken' ? AppTheme.successGreen : AppTheme.warningOrange,
    ));
    _loadData();
  }

  Future<void> _deleteMedicine(Medicine med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _premiumDialog(
        ctx: ctx,
        title: 'Delete Medicine',
        icon: Icons.delete_rounded,
        iconColor: AppTheme.dangerRed,
        content: Text(
          'Delete "${med.name}" from your medicines? This cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
        ),
        confirmText: 'Delete',
        confirmColor: AppTheme.dangerRed,
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirm != true) return;
    if (med.id != null) {
      await DatabaseHelper.instance.deleteMedicine(med.id!);
      // Cancel all slot-based notification IDs (primary + missed + caregiver)
      for (int s = 0; s < 10; s++) {
        await NotificationService().cancelNotification(med.id! * 1000 + s);
        await NotificationService().cancelNotification(med.id! * 1000 + s + 10000);
        await NotificationService().cancelNotification(med.id! * 1000 + s + 20000);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${med.name} deleted')));
      _loadData();
    }
  }

  /// Build a column of gradient time chips, one per dose slot
  List<Widget> _buildScheduleChips(String schedule) {
    final slots = schedule.split(',').map((s) => s.trim()).toList();
    if (slots.length == 1) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: AppTheme.patientGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(slots[0],
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
        ),
      ];
    }
    return slots.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: AppTheme.patientGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('D${e.key + 1} ',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900, color: Colors.white70, fontSize: 11)),
          Text(e.value,
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12)),
        ]),
      ),
    )).toList();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────


  Widget _premiumDialog({
    required BuildContext ctx,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required String confirmText,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      title: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
      ]),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style: GoogleFonts.nunito(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(confirmText,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [_buildSliverHeader()],
              body: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTodayChecklist(),
                        _buildMedicinesList(),
                        ProfileScreen(userId: _patientId!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SOS button
          _buildSOSFab(),
          const SizedBox(height: 12),
          // Add medicine
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () async {
              if (_patientId == null) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddMedicineScreen(patientId: _patientId!)));
              if (!mounted) return;
              _loadData();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text('Add Medicine',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            backgroundColor: AppTheme.patientPrimary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        ],
      ),
    );
  }

  // ── Sliver Header ──────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    final pending = _medicines.where((m) => !_takenTodayIds.contains(m.id)).length;
    final taken   = _medicines.length - pending;
    final today   = DateFormat('EEEE, d MMM').format(DateTime.now());

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.patientPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded),
          tooltip: 'Progress Report',
          onPressed: _patientId == null
              ? null
              : () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProgressReportScreen(patientId: _patientId!))),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifications',
          onPressed: _patientId == null
              ? null
              : () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => NotificationScreen(patientId: _patientId!))),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _logout,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.patientGradient),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_greeting${_userName.isNotEmpty ? ', $_userName' : ''} 👋',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 16),
                // Quick stats row
                Row(
                  children: [
                    _statChip(Icons.medication_rounded,
                        '${_medicines.length} Medicines', Colors.white, Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 10),
                    _statChip(Icons.check_circle_rounded,
                        '$taken Taken today', Colors.greenAccent, Colors.white.withOpacity(0.15)),
                    const SizedBox(width: 10),
                    _statChip(Icons.pending_rounded,
                        '$pending Pending', Colors.orangeAccent, Colors.white.withOpacity(0.15)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color iconColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.patientGradientV,
        boxShadow: [BoxShadow(color: Color(0x293949AB), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle:
            GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.today_rounded, size: 20), text: "Today's Doses"),
          Tab(icon: Icon(Icons.medication_rounded, size: 20), text: 'Medicines'),
          Tab(icon: Icon(Icons.person_rounded, size: 20), text: 'Profile'),
        ],
      ),
    );
  }

  // ── SOS FAB ────────────────────────────────────────────────────────────────

  Widget _buildSOSFab() {
    return FloatingActionButton.extended(
      heroTag: 'sos',
      onPressed: _callCaregiver,
      icon: const Icon(Icons.call_rounded),
      label: Text('SOS',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
      backgroundColor: AppTheme.dangerRed,
      foregroundColor: Colors.white,
      elevation: 6,
    );
  }

  // ── Tab 1: Today's Checklist ───────────────────────────────────────────────

  Widget _buildTodayChecklist() {
    if (_medicines.isEmpty) {
      return _emptyState(Icons.medication_outlined,
          'No medicines yet.\nTap + to add your first one.');
    }
    final pending = _medicines.where((m) => !_takenTodayIds.contains(m.id)).toList();
    if (pending.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: AppTheme.successGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow(AppTheme.successGreen, opacity: 0.3),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 20),
          Text('All done for today! 🎉',
              style: GoogleFonts.nunito(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.successGreen)),
          const SizedBox(height: 8),
          Text('Your next doses will appear tomorrow.',
              style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: pending.length,
      itemBuilder: (ctx, i) => _checklistCard(pending[i]),
    );
  }

  Widget _checklistCard(Medicine med) {
    final isLow = med.quantity <= 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: isLow
              ? AppTheme.dangerRed.withOpacity(0.25)
              : AppTheme.patientPrimary.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: isLow
                        ? AppTheme.dangerGradient
                        : AppTheme.patientGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.softShadow(
                      isLow ? AppTheme.dangerRed : AppTheme.patientPrimary,
                      opacity: 0.3,
                    ),
                  ),
                  child: const Icon(Icons.medication_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      Text('${med.purpose} · ${med.dosage}',
                          style: GoogleFonts.nunito(
                              fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Show one chip per dose slot
                    ..._buildScheduleChips(med.schedule),
                    if (isLow) ...[
                      const SizedBox(height: 6),
                      AppTheme.statusBadge('Low stock!', AppTheme.dangerRed),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: AppTheme.patientPrimary.withOpacity(0.08)),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTheme.gradientButton(
                    onPressed: () => _markMedicine(med.id!, 'taken'),
                    gradient: AppTheme.successGradient,
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Mark as Taken',
                            style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => _markMedicine(med.id!, 'missed'),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.warningOrange.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_rounded,
                              color: AppTheme.warningOrange, size: 18),
                          const SizedBox(width: 6),
                          Text('Skip',
                              style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.warningOrange)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Medicines List ──────────────────────────────────────────────────

  Widget _buildMedicinesList() {
    if (_medicines.isEmpty) {
      return _emptyState(Icons.medication_outlined,
          'No medicines added yet.\nTap + to add one.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _medicines.length,
      itemBuilder: (ctx, i) {
        final med   = _medicines[i];
        final isLow = med.quantity <= 5;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow,
            border: Border(
              left: BorderSide(
                color: isLow ? AppTheme.dangerRed : AppTheme.patientPrimary,
                width: 4,
              ),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: isLow
                    ? AppTheme.dangerGradient
                    : AppTheme.patientGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication_rounded,
                  color: Colors.white, size: 24),
            ),
            title: Text(med.name,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('${med.purpose} · ${med.dosage}',
                    style: GoogleFonts.nunito(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text(med.schedule,
                      style: GoogleFonts.nunito(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  AppTheme.statusBadge(
                    '${med.quantity} pills',
                    isLow ? AppTheme.dangerRed : AppTheme.patientPrimary,
                  ),
                ]),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (v) async {
                if (v == 'edit') {
                  if (_patientId == null) return;
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AddMedicineScreen(
                          patientId: _patientId!, medicine: med)));
                  if (!mounted) return;
                  _loadData();
                } else if (v == 'delete') {
                  _deleteMedicine(med);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_rounded,
                        color: AppTheme.patientPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text('Edit',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded,
                        color: AppTheme.dangerRed, size: 18),
                    const SizedBox(width: 8),
                    Text('Delete',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.dangerRed)),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppTheme.patientLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 46, color: AppTheme.patientPrimary),
        ),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
              fontSize: 16, color: AppTheme.textSecondary, height: 1.5),
        ),
      ]),
    );
  }
}
