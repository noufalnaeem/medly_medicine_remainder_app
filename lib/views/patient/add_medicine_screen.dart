import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/app_theme.dart';
import '../../../models/medicine.dart';
import '../../../database/db_helper.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';

class AddMedicineScreen extends StatefulWidget {
  final int patientId;
  final Medicine? medicine;

  const AddMedicineScreen({super.key, required this.patientId, this.medicine});

  @override
  _AddMedicineScreenState createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _nameController     = TextEditingController();
  final _purposeController  = TextEditingController();
  final _dosageController   = TextEditingController();
  final _quantityController = TextEditingController(text: '10');

  /// Multiple daily dose slots. At least one required.
  List<TimeOfDay?> _doseSlots = [null];

  bool _isLoading = false;

  // ─── Notification ID scheme ────────────────────────────────────────────────
  // Primary reminder  for slot i:  medId * 1000 + i
  // Patient missed    for slot i:  medId * 1000 + i + 10000
  // Caregiver warned  for slot i:  medId * 1000 + i + 20000
  static int _primaryId   (int medId, int slot) => medId * 1000 + slot;
  static int _missedId    (int medId, int slot) => medId * 1000 + slot + 10000;
  static int _caregiverId (int medId, int slot) => medId * 1000 + slot + 20000;

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      final med = widget.medicine!;
      _nameController.text     = med.name;
      _purposeController.text  = med.purpose;
      _dosageController.text   = med.dosage;
      _quantityController.text = med.quantity.toString();
      // Parse comma-separated schedule
      final slots = med.schedule.split(',').map((s) => _parseTime(s.trim())).toList();
      _doseSlots = slots.isEmpty ? [null] : slots;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _dosageController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String s) {
    try {
      final lower  = s.toLowerCase();
      final parts  = s.trim().split(RegExp(r'[ :]'));
      int hour     = int.parse(parts[0]);
      final int min = int.parse(parts[1]);
      if (lower.contains('pm') && hour < 12) hour += 12;
      if (lower.contains('am') && hour == 12) hour  = 0;
      return TimeOfDay(hour: hour, minute: min);
    } catch (_) { return null; }
  }

  Future<void> _pickSlot(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _doseSlots[index] ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.patientPrimary)),
        child: child!,
      ),
    );
    if (time != null) setState(() => _doseSlots[index] = time);
  }

  void _addSlot() => setState(() => _doseSlots.add(null));

  void _removeSlot(int index) {
    if (_doseSlots.length <= 1) return;
    setState(() => _doseSlots.removeAt(index));
  }

  Future<void> _saveMedicine() async {
    if (_nameController.text.isEmpty) {
      _snack('Medicine name is required');
      return;
    }
    if (_doseSlots.every((t) => t == null)) {
      _snack('Please set at least one dose time');
      return;
    }
    // Remove empty slots
    final validSlots = _doseSlots.where((t) => t != null).cast<TimeOfDay>().toList();

    final qty = int.tryParse(_quantityController.text.trim()) ?? 10;
    setState(() => _isLoading = true);

    // Schedule string: comma-separated formatted times
    final scheduleStr = validSlots.map((t) => t.format(context)).join(',');

    final med = Medicine(
      id: widget.medicine?.id,
      name: _nameController.text.trim(),
      purpose: _purposeController.text.trim(),
      dosage: _dosageController.text.trim(),
      schedule: scheduleStr,
      patientId: widget.patientId,
      quantity: qty,
    );

    int medId;
    if (med.id != null) {
      await DatabaseHelper.instance.updateMedicine(med.toMap());
      medId = med.id!;
      // Cancel ALL old notifications for this medicine (all slots × 3 types)
      for (int s = 0; s < 10; s++) {
        await NotificationService().cancelNotification(_primaryId(medId, s));
        await NotificationService().cancelNotification(_missedId(medId, s));
        await NotificationService().cancelNotification(_caregiverId(medId, s));
      }
    } else {
      medId = await DatabaseHelper.instance.createMedicine(med.toMap());
    }

    // Look up linked caregiver (same device, SQLite)
    final caregiver = await DatabaseHelper.instance.getCaregiverForPatient(widget.patientId);
    final caregiversName = (caregiver?['full_name'] as String?)?.split(' ').first
        ?? (caregiver?['email'] as String?)
        ?? 'Your caregiver';
    final patientUser = await DatabaseHelper.instance.getUser(widget.patientId);
    final patientName = (patientUser?['full_name'] as String?)?.split(' ').first
        ?? 'The patient';

    try {
      await NotificationService().requestPermissions();
      final nowIso = DateTime.now().toIso8601String();

      for (int i = 0; i < validSlots.length; i++) {
        final slot = validSlots[i];
        final payload = jsonEncode({
          'name': med.name, 'dosage': med.dosage,
          'purpose': med.purpose, 'id': medId,
        });

        // ── 1. Primary patient reminder ─────────────────────────────────────
        final primaryTitle = 'Time for Medicine 💊';
        final primaryBody  =
            'It is time to take ${med.name} (${med.dosage}) for ${med.purpose}.';
        await NotificationService().scheduleNotification(
          id:      _primaryId(medId, i),
          title:   primaryTitle,
          body:    primaryBody,
          time:    slot,
          payload: payload,
        );
        // Log in notification history
        await DatabaseHelper.instance.insertNotification(
          AppNotification(
            patientId: widget.patientId,
            title: primaryTitle,
            body: primaryBody,
            timestamp: nowIso,
          ).toMap(),
        );

        // ── 2. Patient missed-dose alert (30 min later) ─────────────────────
        await NotificationService().scheduleNotification(
          id:       _missedId(medId, i),
          title:    '⚠️ Missed Dose Reminder',
          body:     'You may have missed ${med.name} (${med.dosage}) — please take it now.',
          time:     slot,
          payload:  payload,
          offset:   const Duration(minutes: 30),
          skipToday: true,
          isMissed: true,
        );

        // ── 3. Caregiver warning (30 min later, same time) ──────────────────
        await NotificationService().scheduleNotification(
          id:       _caregiverId(medId, i),
          title:    '🚨 Patient Missed Dose',
          body:     '$patientName hasn\'t taken ${med.name} (${med.dosage}) yet. Please check in.',
          time:     slot,
          payload:  null,      // no alarm screen for caregiver
          offset:   const Duration(minutes: 30),
          skipToday: true,
          isMissed: true,
        );
      }
    } catch (e) {
      debugPrint('Notification error: $e');
      if (mounted) {
        _snack('Saved, but could not schedule all alarms.');
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context, true);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicine != null;
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
                          shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEditing ? 'Edit Medicine' : 'Add Medicine',
                          style: GoogleFonts.nunito(
                              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(isEditing ? 'Update details below' : 'Fill in the medicine details',
                          style: GoogleFonts.nunito(
                              fontSize: 13, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.medication_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ),

          // ── Form body ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                children: [
                  _sectionLabel('Medicine Details'),
                  const SizedBox(height: 12),
                  _field(_nameController, 'Medicine Name', Icons.medication_rounded),
                  const SizedBox(height: 14),
                  _field(_purposeController, 'Purpose (e.g. Blood Pressure)',
                      Icons.lightbulb_outline_rounded),
                  const SizedBox(height: 14),
                  _field(_dosageController, 'Dosage (e.g. 1 Pill)', Icons.scale_rounded),
                  const SizedBox(height: 24),

                  _sectionLabel('Inventory'),
                  const SizedBox(height: 12),
                  _quantityField(),
                  const SizedBox(height: 24),

                  // ── Daily Dose Schedule ────────────────────────────────
                  _sectionLabel('Daily Dose Schedule'),
                  const SizedBox(height: 4),
                  Text(
                    'Add one time per dose. You can have multiple doses per day.',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ..._doseSlots.asMap().entries.map((e) => _doseSlotRow(e.key)),
                  const SizedBox(height: 12),
                  // Add dose button
                  GestureDetector(
                    onTap: _addSlot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.patientLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.patientPrimary.withOpacity(0.4),
                            width: 1.5,
                            style: BorderStyle.solid)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_rounded,
                              color: AppTheme.patientPrimary, size: 22),
                          const SizedBox(width: 8),
                          Text('Add another dose time',
                              style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.patientPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  AppTheme.gradientButton(
                    onPressed: _isLoading ? null : _saveMedicine,
                    height: 56,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                isEditing ? 'Update Medicine' : 'Save Medicine',
                                style: GoogleFonts.nunito(
                                    fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          gradient: AppTheme.patientGradient,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: GoogleFonts.nunito(
              fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
    ]);
  }

  // ── Dose slot row ──────────────────────────────────────────────────────────

  Widget _doseSlotRow(int index) {
    final time = _doseSlots[index];
    final isFirst = index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(AppTheme.patientPrimary, opacity: 0.08),
        border: Border.all(
          color: time != null
              ? AppTheme.patientPrimary.withOpacity(0.4)
              : AppTheme.patientPrimary.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Slot number badge
          Container(
            width: 48,
            height: 60,
            decoration: BoxDecoration(
              gradient: time != null ? AppTheme.patientGradient : null,
              color: time == null ? AppTheme.patientLight : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                'D${index + 1}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: time != null ? Colors.white : AppTheme.patientPrimary,
                ),
              ),
            ),
          ),
          // Time selector
          Expanded(
            child: GestureDetector(
              onTap: () => _pickSlot(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dose ${index + 1} time',
                        style: GoogleFonts.nunito(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      time == null ? 'Tap to set time' : time.format(context),
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: time != null ? FontWeight.w800 : FontWeight.w400,
                        color: time != null ? AppTheme.textPrimary : AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Edit icon
          GestureDetector(
            onTap: () => _pickSlot(index),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.access_time_rounded,
                  color: AppTheme.patientPrimary.withOpacity(0.7), size: 22),
            ),
          ),
          // Remove slot button (not for first slot)
          if (!isFirst) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _removeSlot(index),
              child: Container(
                width: 36, height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    color: AppTheme.dangerRed, size: 18),
              ),
            ),
          ] else
            const SizedBox(width: 16),
        ],
      ),
    );
  }

  // ── Text fields ────────────────────────────────────────────────────────────

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(AppTheme.patientPrimary, opacity: 0.08),
      ),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.nunito(fontSize: 15, color: AppTheme.textPrimary),
        decoration: AppTheme.inputDecoration(label: label, icon: icon),
      ),
    );
  }

  Widget _quantityField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(AppTheme.patientPrimary, opacity: 0.08),
      ),
      child: TextField(
        controller: _quantityController,
        keyboardType: TextInputType.number,
        style: GoogleFonts.nunito(fontSize: 15, color: AppTheme.textPrimary),
        decoration: AppTheme.inputDecoration(
          label: 'Pill Count',
          icon: Icons.local_pharmacy_rounded,
          helperText: 'A ⚠️ warning shows when ≤5 pills remain',
        ),
      ),
    );
  }
}
