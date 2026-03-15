import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../database/db_helper.dart';
import '../../models/medicine.dart';

class ProgressReportScreen extends StatefulWidget {
  final int patientId;
  const ProgressReportScreen({super.key, required this.patientId});

  @override
  State<ProgressReportScreen> createState() => _ProgressReportScreenState();
}

class _ProgressReportScreenState extends State<ProgressReportScreen> {
  bool _isLoading   = true;
  List<Medicine> _medicines = [];
  Set<int> _takenIds   = {};
  Set<int> _skippedIds = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final medMaps  = await DatabaseHelper.instance
        .getMedicinesByPatient(widget.patientId);
    final medicines = medMaps.map((m) => Medicine.fromMap(m)).toList();

    final todayPrefix = DateTime.now().toIso8601String().substring(0, 10);
    final db         = await DatabaseHelper.instance.database;
    final todayLogs  = await db.query('logs',
        where: 'taken_time LIKE ?', whereArgs: ['$todayPrefix%']);

    final takenIds   = <int>{};
    final skippedIds = <int>{};
    for (final log in todayLogs) {
      final mid = log['medicine_id'] as int;
      if (log['status'] == 'taken')        takenIds.add(mid);
      else if (log['status'] == 'missed') skippedIds.add(mid);
    }
    skippedIds.removeAll(takenIds);

    setState(() {
      _medicines  = medicines;
      _takenIds   = takenIds;
      _skippedIds = skippedIds;
      _isLoading  = false;
    });
  }

  Future<void> _clearAllData() async {
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
            child: const Icon(Icons.delete_forever_rounded,
                color: AppTheme.dangerRed, size: 22),
          ),
          const SizedBox(width: 12),
          Text('Clear All Data',
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'This will permanently delete all medication logs. This cannot be undone.',
          style: GoogleFonts.nunito(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
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
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete All',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await DatabaseHelper.instance.clearAllLogs();
    _loadReport();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All log data cleared.')));
  }

  int get _total => _medicines.length;
  int get _takenCount => _takenIds.length;
  int get _skippedCount => _skippedIds.length;
  int get _pendingCount =>
      _medicines.where((m) => !_takenIds.contains(m.id) && !_skippedIds.contains(m.id)).length;
  double get _adherencePct =>
      _total == 0 ? 0 : (_takenCount / _total) * 100;

  String _statusLabel(Medicine med) {
    if (_takenIds.contains(med.id)) return 'Taken';
    if (_skippedIds.contains(med.id)) return 'Skipped';
    return 'Pending';
  }

  Color _statusColor(Medicine med) {
    if (_takenIds.contains(med.id)) return AppTheme.successGreen;
    if (_skippedIds.contains(med.id)) return AppTheme.warningOrange;
    return AppTheme.textSecondary;
  }

  IconData _statusIcon(Medicine med) {
    if (_takenIds.contains(med.id)) return Icons.check_circle_rounded;
    if (_skippedIds.contains(med.id)) return Icons.cancel_rounded;
    return Icons.radio_button_unchecked_rounded;
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
                      Text('Progress Report',
                          style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text("Today's medication status",
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadReport,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearAllData,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  : _total == 0
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: _loadReport,
                          color: AppTheme.patientPrimary,
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 24, 16, 32),
                            children: [
                              _buildSummaryCard(),
                              const SizedBox(height: 20),
                              _buildColorBar(),
                              const SizedBox(height: 24),
                              Row(children: [
                                Container(
                                  width: 4, height: 18,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.patientGradient,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('Today\'s Medications',
                                    style: GoogleFonts.nunito(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary)),
                              ]),
                              const SizedBox(height: 12),
                              ..._medicines.map(_buildMedicineRow),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final pct   = _adherencePct;
    final color = pct >= 80
        ? AppTheme.successGreen
        : pct >= 50
            ? AppTheme.warningOrange
            : AppTheme.dangerRed;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 90, height: 90,
              child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(
                  value: _total == 0 ? 0 : _takenCount / _total,
                  strokeWidth: 9,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Center(
                  child: Text('${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _takenCount == _total && _total > 0
                        ? 'All done today! 🎉'
                        : 'Today\'s Progress',
                    style: GoogleFonts.nunito(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _statRow(Icons.check_circle_rounded,
                      '$_takenCount / $_total Taken', AppTheme.successGreen),
                  const SizedBox(height: 5),
                  _statRow(Icons.cancel_rounded,
                      '$_skippedCount Skipped', AppTheme.warningOrange),
                  const SizedBox(height: 5),
                  _statRow(Icons.pending_rounded,
                      '$_pendingCount Pending', AppTheme.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 6),
    Text(label,
        style: GoogleFonts.nunito(
            color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  ]);

  Widget _buildColorBar() {
    if (_total == 0) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$_takenCount / $_total taken',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.patientPrimary,
                    fontSize: 14)),
            Text('${_adherencePct.toStringAsFixed(0)}% adherence',
                style: GoogleFonts.nunito(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 16,
            child: Row(children: [
              if (_takenCount > 0)
                Expanded(
                    flex: _takenCount,
                    child: Container(
                      decoration: const BoxDecoration(
                          gradient: AppTheme.successGradient),
                    )),
              if (_skippedCount > 0)
                Expanded(
                    flex: _skippedCount,
                    child: Container(color: AppTheme.warningOrange)),
              if (_pendingCount > 0)
                Expanded(
                    flex: _pendingCount,
                    child: Container(color: AppTheme.textHint.withOpacity(0.35))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _legend(AppTheme.successGreen, 'Taken'),
          const SizedBox(width: 16),
          _legend(AppTheme.warningOrange, 'Skipped'),
          const SizedBox(width: 16),
          _legend(AppTheme.textHint, 'Pending'),
        ]),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(children: [
    Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
            color: c, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 5),
    Text(label,
        style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textSecondary)),
  ]);

  Widget _buildMedicineRow(Medicine med) {
    final color = _statusColor(med);
    final icon  = _statusIcon(med);
    final label = _statusLabel(med);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(med.name,
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: Text(
          '${med.purpose} · ${med.dosage} · ${med.schedule}',
          style: GoogleFonts.nunito(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: AppTheme.statusBadge(label, color),
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
          child: const Icon(Icons.medication_outlined,
              size: 46, color: AppTheme.patientPrimary),
        ),
        const SizedBox(height: 18),
        Text('No medicines found.',
            style: GoogleFonts.nunito(
                fontSize: 16, color: AppTheme.textSecondary)),
      ]),
    );
  }
}
