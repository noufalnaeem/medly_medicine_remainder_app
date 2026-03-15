import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../database/db_helper.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isSaving  = false;

  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _ageCtrl       = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _cgNameCtrl    = TextEditingController();
  final _cgPhoneCtrl   = TextEditingController();

  String  _role       = '';
  String? _patientCode;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneCtrl, _ageCtrl,
      _conditionCtrl, _cgNameCtrl, _cgPhoneCtrl,
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = await DatabaseHelper.instance.getUser(widget.userId);
    if (user != null && mounted) {
      _nameCtrl.text      = (user['full_name']      as String?) ?? '';
      _emailCtrl.text     = (user['email']          as String?) ?? '';
      _phoneCtrl.text     = (user['phone']          as String?) ?? '';
      _ageCtrl.text       = (user['age']            as String?) ?? '';
      _conditionCtrl.text = (user['condition']      as String?) ?? '';
      _cgNameCtrl.text    = (user['caregiver_name'] as String?) ?? '';
      _cgPhoneCtrl.text   = (user['caregiver_phone'] as String?) ?? '';
      _role               = (user['role']           as String?) ?? '';
      _patientCode        = (user['patient_code']   as String?);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.updateProfile(widget.userId, {
        'full_name':      _nameCtrl.text.trim(),
        'email':          _emailCtrl.text.trim(),
        'phone':          _phoneCtrl.text.trim(),
        'age':            _ageCtrl.text.trim(),
        'condition':      _conditionCtrl.text.trim(),
        'caregiver_name': _cgNameCtrl.text.trim(),
        'caregiver_phone': _cgPhoneCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile saved!'),
          backgroundColor: AppTheme.successGreen));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.dangerRed));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.patientPrimary));
    }

    final initials = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text.trim().split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        children: [
          // ── Avatar + patient code ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.patientGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.softShadow(AppTheme.patientPrimary, opacity: 0.3),
            ),
            child: Column(
              children: [
                // Avatar circle
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: GoogleFonts.nunito(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text
                      : 'Your Profile',
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _role.toUpperCase(),
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                // Patient code
                if (_role == 'patient' && _patientCode != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Patient Code',
                                style: GoogleFonts.nunito(
                                    fontSize: 11, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(
                              _patientCode!,
                              style: GoogleFonts.nunito(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 4),
                            ),
                            Text('Share with your caregiver',
                                style: GoogleFonts.nunito(
                                    fontSize: 10, color: Colors.white60)),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: _patientCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Patient code copied!'),
                                  backgroundColor: AppTheme.successGreen,
                                  duration: Duration(seconds: 2)),
                            );
                          },
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.copy_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Personal Info ──────────────────────────────────────────────
          _sectionHeader(Icons.person_rounded, 'Personal Information'),
          const SizedBox(height: 12),
          _field(_nameCtrl, 'Full Name', Icons.badge_rounded),
          const SizedBox(height: 12),
          _field(_emailCtrl, 'Email', Icons.email_rounded,
              inputType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(_phoneCtrl, 'Phone Number', Icons.phone_rounded,
              inputType: TextInputType.phone),
          const SizedBox(height: 12),
          _field(_ageCtrl, 'Age', Icons.cake_rounded,
              inputType: TextInputType.number),
          const SizedBox(height: 12),
          _field(_conditionCtrl, 'Medical Condition / Notes',
              Icons.medical_information_rounded,
              maxLines: 3),

          const SizedBox(height: 24),

          // ── Caregiver Info ─────────────────────────────────────────────
          _sectionHeader(Icons.supervisor_account_rounded, 'Caregiver Details'),
          const SizedBox(height: 12),
          _field(_cgNameCtrl, 'Caregiver Name', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _field(_cgPhoneCtrl, 'Caregiver Phone',
              Icons.phone_in_talk_rounded,
              inputType: TextInputType.phone),

          const SizedBox(height: 36),

          // ── Save button ────────────────────────────────────────────────
          AppTheme.gradientButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Save Profile',
                          style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
            height: 56,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          gradient: AppTheme.patientGradient,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, color: AppTheme.patientPrimary, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: AppTheme.patientPrimary.withOpacity(0.2))),
    ]);
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(AppTheme.patientPrimary, opacity: 0.07),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        maxLines: maxLines,
        style: GoogleFonts.nunito(fontSize: 15, color: AppTheme.textPrimary),
        decoration: AppTheme.inputDecoration(label: label, icon: icon),
      ),
    );
  }
}
