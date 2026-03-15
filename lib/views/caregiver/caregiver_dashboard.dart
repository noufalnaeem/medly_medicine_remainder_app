import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../database/db_helper.dart';
import '../login_screen.dart';
import '../role_selection_screen.dart';
import '../../models/medicine.dart';
import '../../models/log.dart';
import '../patient/add_medicine_screen.dart';
import '../../services/notification_service.dart';

class CaregiverDashboard extends StatefulWidget {
  @override
  _CaregiverDashboardState createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  int? _caregiverId;

  String? _linkedCode;
  Map<String, dynamic>? _linkedPatient;
  List<MedicineLog> _allLogs = [];
  List<Medicine> _allMedicines = [];
  List<Map<String, dynamic>> _emergencyContacts = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final session = await AuthService().getSession();
    final cid     = session['userId'] as int?;
    _caregiverId  = cid;

    if (cid != null) {
      _linkedCode = await DatabaseHelper.instance.getLinkedPatientCode(cid);
      if (_linkedCode != null && _linkedCode!.isNotEmpty) {
        _linkedPatient = await DatabaseHelper.instance.getUserByPatientCode(_linkedCode!);
      }
      final contacts = await DatabaseHelper.instance.getEmergencyContacts(cid);
      setState(() => _emergencyContacts = contacts);
    }

    if (_linkedPatient != null) {
      final patientId  = _linkedPatient!['id'] as int;
      final medMaps    = await DatabaseHelper.instance.getMedicinesForPatient(patientId);
      final logMaps    = await DatabaseHelper.instance.getAllLogs();
      final medicineIds = medMaps.map((m) => m['id'] as int).toSet();
      setState(() {
        _allMedicines = medMaps.map((m) => Medicine.fromMap(m)).toList();
        _allLogs      = logMaps
            .map((m) => MedicineLog.fromMap(m))
            .where((l) => medicineIds.contains(l.medicineId))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() { _allMedicines = []; _allLogs = []; _isLoading = false; });
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
  }

  // ─── Link patient ──────────────────────────────────────────────────────────

  Future<void> _linkPatient() async {
    final ctrl = TextEditingController(text: _linkedCode ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.caregiverLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link_rounded,
                color: AppTheme.caregiverPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Text('Link Patient',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 8-character patient code:',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.softShadow(
                    AppTheme.caregiverPrimary, opacity: 0.08),
              ),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3),
                decoration: AppTheme.inputDecoration(
                  label: 'Patient Code',
                  icon: Icons.qr_code_rounded,
                  primaryColor: AppTheme.caregiverPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.caregiverPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Link', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final patient = await DatabaseHelper.instance
        .getUserByPatientCode(result.toUpperCase());
    if (patient == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No patient found with that code.'),
          backgroundColor: AppTheme.dangerRed));
      return;
    }
    await DatabaseHelper.instance
        .setLinkedPatientCode(_caregiverId!, result.toUpperCase());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Linked to: ${patient['full_name'] ?? patient['email'] ?? 'Patient'}'),
        backgroundColor: AppTheme.caregiverPrimary));
    _loadData();
  }

  // ─── Medicine management ───────────────────────────────────────────────────

  Future<void> _addMedicine() async {
    if (_linkedPatient == null) return;
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) =>
            AddMedicineScreen(patientId: _linkedPatient!['id'] as int)));
    if (!mounted) return;
    _loadData();
  }

  Future<void> _editMedicine(Medicine med) async {
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) =>
            AddMedicineScreen(patientId: med.patientId, medicine: med)));
    if (!mounted) return;
    _loadData();
  }

  Future<void> _deleteMedicine(Medicine med) async {
    final confirm = await _confirmDialog(
        ctx: context,
        title: 'Delete Medicine',
        message: 'Delete "${med.name}" from patient\'s medicines?',
        confirmText: 'Delete',
        confirmColor: AppTheme.dangerRed,
        icon: Icons.delete_rounded,
        iconColor: AppTheme.dangerRed);
    if (confirm != true) return;
    if (med.id != null) {
      await DatabaseHelper.instance.deleteMedicine(med.id!);
      await NotificationService().cancelNotification(med.id!);
      await NotificationService().cancelNotification(med.id! + 10000);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${med.name} deleted')));
    _loadData();
  }

  // ─── Emergency contacts ────────────────────────────────────────────────────

  Future<void> _addOrEditContact({Map<String, dynamic>? contact}) async {
    final nameCtrl  = TextEditingController(text: contact?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: contact?['phone'] ?? '');
    final relCtrl   = TextEditingController(text: contact?['relationship'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.red.shade50, shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_rounded,
                color: Colors.red.shade700, size: 22),
          ),
          const SizedBox(width: 12),
          Text(contact == null ? 'Add Contact' : 'Edit Contact',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'Full Name *', Icons.person_outline),
              const SizedBox(height: 12),
              _dialogField(phoneCtrl, 'Phone Number *', Icons.phone_outlined,
                  inputType: TextInputType.phone),
              const SizedBox(height: 12),
              _dialogField(relCtrl, 'Relationship (e.g. Doctor)',
                  Icons.people_outline),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Save', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name  = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and phone are required.')));
      return;
    }
    if (contact == null) {
      await DatabaseHelper.instance.insertEmergencyContact({
        'caregiver_id': _caregiverId,
        'name': name,
        'phone': phone,
        'relationship': relCtrl.text.trim(),
      });
    } else {
      await DatabaseHelper.instance
          .updateEmergencyContact(contact['id'] as int, {
        'name': name, 'phone': phone, 'relationship': relCtrl.text.trim(),
      });
    }
    if (!mounted) return;
    _loadData();
  }

  Future<void> _deleteContact(int id, String name) async {
    final confirm = await _confirmDialog(
        ctx: context,
        title: 'Remove Contact',
        message: 'Remove "$name" from emergency contacts?',
        confirmText: 'Remove',
        confirmColor: AppTheme.dangerRed,
        icon: Icons.delete_rounded,
        iconColor: AppTheme.dangerRed);
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteEmergencyContact(id);
    if (!mounted) return;
    _loadData();
  }

  Future<void> _callContact(String phone) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: phone.trim()),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open dialler.')));
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<bool?> _confirmDialog({
    required BuildContext ctx,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(message, style: GoogleFonts.nunito(color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel', style: GoogleFonts.nunito(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmText, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl, String label, IconData icon, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        style: GoogleFonts.nunito(fontSize: 14),
        decoration: AppTheme.inputDecoration(
            label: label, icon: icon,
            primaryColor: AppTheme.caregiverPrimary),
      ),
    );
  }

  // ─── Computed ──────────────────────────────────────────────────────────────

  double get _adherencePct {
    final total = _allLogs.length;
    if (total == 0) return 0;
    return (_allLogs.where((l) => l.status == 'taken').length / total) * 100;
  }

  List<MedicineLog> get _missedLogs =>
      _allLogs.where((l) => l.status == 'missed').toList();

  List<Medicine> get _lowStockMeds =>
      _allMedicines.where((m) => m.quantity <= 5).toList();

  String _medNameForId(int id) {
    try { return _allMedicines.firstWhere((m) => m.id == id).name; }
    catch (_) { return 'Medicine #$id'; }
  }

  String _formatTs(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final h    = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final m    = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year}  $h:$m $ampm';
    } catch (_) { return iso; }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.caregiverPrimary))
          : _linkedPatient == null
              ? _buildNoPatientLinked()
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [_buildSliverHeader()],
                  body: Column(
                    children: [
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMissedDosesList(),
                            _buildMedicationsList(),
                            _buildEmergencyContactsList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _linkedPatient == null
          ? FloatingActionButton.extended(
              onPressed: _linkPatient,
              icon: const Icon(Icons.link_rounded),
              label: Text('Link Patient',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              backgroundColor: AppTheme.caregiverPrimary,
              foregroundColor: Colors.white,
            )
          : AnimatedBuilder(
              animation: _tabController,
              builder: (_, __) {
                if (_tabController.index == 0) return const SizedBox.shrink();
                if (_tabController.index == 1) {
                  return FloatingActionButton.extended(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Add Medicine',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    backgroundColor: AppTheme.caregiverPrimary,
                    foregroundColor: Colors.white,
                  );
                }
                return FloatingActionButton.extended(
                  onPressed: () => _addOrEditContact(),
                  icon: const Icon(Icons.person_add_rounded),
                  label: Text('Add Contact',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                );
              },
            ),
    );
  }

  // ── Sliver Header ──────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    final pct = _adherencePct;
    final adherenceColor = pct >= 80
        ? Colors.greenAccent
        : pct >= 50
            ? Colors.orangeAccent
            : Colors.redAccent;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.caregiverPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Care Dashboard',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          if (_linkedPatient != null)
            Text(
              'Patient: ${_linkedPatient!['full_name'] ?? _linkedPatient!['email'] ?? _linkedCode}',
              style: GoogleFonts.nunito(fontSize: 11, color: Colors.white70),
            ),
        ],
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'Link Patient',
            onPressed: _linkPatient),
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData),
        IconButton(
            icon: const Icon(Icons.logout_rounded), onPressed: _logout),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.caregiverGradient),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 56),
                // Adherence card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      // Donut ring
                      SizedBox(
                        width: 72, height: 72,
                        child: Stack(fit: StackFit.expand, children: [
                          CircularProgressIndicator(
                            value: _adherencePct / 100,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                adherenceColor),
                          ),
                          Center(
                            child: Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Adherence Rate',
                                style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                              '${_allLogs.where((l) => l.status == 'taken').length} taken · '
                              '${_missedLogs.length} missed · '
                              '${_allLogs.length} total',
                              style: GoogleFonts.nunito(
                                  fontSize: 12, color: Colors.white70),
                            ),
                            if (_lowStockMeds.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.4)),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 12, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${_lowStockMeds.length} need refill',
                                      style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange)),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.caregiverGradientV,
        boxShadow: [BoxShadow(
            color: Color(0x2200695C), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding:
            const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle:
            GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: [
          Tab(
            icon: Badge(
              isLabelVisible: _missedLogs.isNotEmpty,
              label: Text('${_missedLogs.length}',
                  style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.warning_amber_rounded, size: 20),
            ),
            text: 'Missed',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: _lowStockMeds.isNotEmpty,
              label: Text('${_lowStockMeds.length}',
                  style: const TextStyle(fontSize: 10)),
              backgroundColor: Colors.red,
              child: const Icon(Icons.medication_rounded, size: 20),
            ),
            text: 'Medicines',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: _emergencyContacts.isNotEmpty,
              label: Text('${_emergencyContacts.length}',
                  style: const TextStyle(fontSize: 10)),
              backgroundColor: Colors.red.shade700,
              child: const Icon(Icons.contacts_rounded, size: 20),
            ),
            text: 'Emergency',
          ),
        ],
      ),
    );
  }

  // ── No patient linked ──────────────────────────────────────────────────────

  Widget _buildNoPatientLinked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                gradient: AppTheme.caregiverGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.softShadow(
                    AppTheme.caregiverPrimary, opacity: 0.35),
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 56, color: Colors.white),
            ),
            const SizedBox(height: 28),
            Text('No Patient Linked',
                style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            Text(
              'Ask your patient for their 8-character code\nand tap the button below to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Missed Doses ────────────────────────────────────────────────────

  Widget _buildMissedDosesList() {
    if (_missedLogs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              gradient: AppTheme.successGradient, shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow(AppTheme.successGreen, opacity: 0.3),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 18),
          Text('No missed doses! 🎉',
              style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successGreen)),
          const SizedBox(height: 6),
          Text('Patient is on track with their medication.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _missedLogs.length,
      itemBuilder: (ctx, i) {
        final log = _missedLogs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
            border: const Border(
                left: BorderSide(color: AppTheme.dangerRed, width: 4)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.dangerGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.white, size: 22),
            ),
            title: Text(_medNameForId(log.medicineId),
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            subtitle: Text(_formatTs(log.takenTime),
                style: GoogleFonts.nunito(
                    color: AppTheme.textSecondary, fontSize: 12)),
            trailing: AppTheme.statusBadge('MISSED', AppTheme.dangerRed),
          ),
        );
      },
    );
  }

  // ── Tab 2: Medicines ───────────────────────────────────────────────────────

  Widget _buildMedicationsList() {
    if (_allMedicines.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: AppTheme.caregiverLight, shape: BoxShape.circle),
            child: const Icon(Icons.medication_outlined,
                size: 46, color: AppTheme.caregiverPrimary),
          ),
          const SizedBox(height: 18),
          Text('No medicines yet.',
              style: GoogleFonts.nunito(
                  fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text('Tap + to add a medicine for the patient.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: AppTheme.textHint)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _allMedicines.length,
      itemBuilder: (ctx, i) {
        final med   = _allMedicines[i];
        final isLow = med.quantity <= 5;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow,
            border: Border(
              left: BorderSide(
                color: isLow ? AppTheme.dangerRed : AppTheme.caregiverPrimary,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: isLow
                        ? AppTheme.dangerGradient
                        : AppTheme.caregiverGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${med.purpose} · ${med.dosage} · ${med.schedule}',
                          style: GoogleFonts.nunito(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.local_pharmacy_rounded,
                            size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('${med.quantity} pills remaining',
                            style: GoogleFonts.nunito(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        if (isLow) ...[
                          const SizedBox(width: 8),
                          AppTheme.statusBadge('Refill!', AppTheme.dangerRed),
                        ],
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: AppTheme.caregiverPrimary, size: 20),
                  tooltip: 'Edit',
                  onPressed: () => _editMedicine(med),
                ),
                IconButton(
                  icon: Icon(Icons.delete_rounded,
                      color: Colors.red.shade400, size: 20),
                  tooltip: 'Delete',
                  onPressed: () => _deleteMedicine(med),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 3: Emergency Contacts ──────────────────────────────────────────────

  Widget _buildEmergencyContactsList() {
    if (_emergencyContacts.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.contact_phone_outlined,
                size: 46, color: Colors.red.shade400),
          ),
          const SizedBox(height: 18),
          Text('No emergency contacts yet.',
              style: GoogleFonts.nunito(
                  fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text('Tap + to add an emergency contact.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textHint)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _emergencyContacts.length,
      itemBuilder: (ctx, i) {
        final c       = _emergencyContacts[i];
        final name    = c['name'] as String? ?? '';
        final phone   = c['phone'] as String? ?? '';
        final rel     = c['relationship'] as String? ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: AppTheme.dangerGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initial,
                        style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (rel.isNotEmpty)
                        Text(rel,
                            style: GoogleFonts.nunito(
                                color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(phone,
                          style: GoogleFonts.nunito(
                              color: AppTheme.caregiverPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                // Call button
                GestureDetector(
                  onTap: () => _callContact(phone),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: AppTheme.successGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.softShadow(
                          AppTheme.successGreen, opacity: 0.35),
                    ),
                    child: const Icon(Icons.call_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // More options
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppTheme.textSecondary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) {
                    if (v == 'edit') _addOrEditContact(contact: c);
                    else if (v == 'delete')
                      _deleteContact(c['id'] as int, name);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_rounded,
                            color: AppTheme.caregiverPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text('Edit',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded,
                            color: AppTheme.dangerRed, size: 18),
                        const SizedBox(width: 8),
                        Text('Remove',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.dangerRed)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
