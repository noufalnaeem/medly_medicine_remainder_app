import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _authService  = AuthService();

  String _selectedRole = 'patient';
  bool _isLoading     = false;
  bool _obscurePass   = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email    = _emailCtrl.text.trim();
    final phone    = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (email.isEmpty && phone.isEmpty) { _snack('Please enter Email or Phone'); return; }
    if (password.isEmpty)               { _snack('Please enter a password');     return; }
    if (password.length < 6)            { _snack('Password must be ≥ 6 characters'); return; }
    if (password != confirm)            { _snack('Passwords do not match');       return; }

    setState(() => _isLoading = true);
    try {
      final user =
          User(email: email, phone: phone, role: _selectedRole, password: password);
      await _authService.signUp(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created! Please login.'),
          backgroundColor: AppTheme.successGreen));
      Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  LinearGradient get _gradient =>
      _selectedRole == 'caregiver' ? AppTheme.caregiverGradient : AppTheme.patientGradient;
  Color get _primary =>
      _selectedRole == 'caregiver' ? AppTheme.caregiverPrimary : AppTheme.patientPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(gradient: _gradient),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
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
                      Text('Create Account',
                          style: GoogleFonts.nunito(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Join Medly today ✨',
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8))),
                    ],
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
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildField(_emailCtrl, 'Email', Icons.email_outlined,
                        inputType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _buildField(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                        inputType: TextInputType.phone),
                    const SizedBox(height: 14),
                    // ── Role selector ──────────────────────────────────────
                    _buildRoleSelector(),
                    const SizedBox(height: 14),
                    _buildField(
                      _passwordCtrl,
                      'Password',
                      Icons.lock_outline_rounded,
                      obscure: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.textSecondary),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      _confirmCtrl,
                      'Confirm Password',
                      Icons.lock_outline_rounded,
                      obscure: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.textSecondary),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // ── Create account button ──────────────────────────────
                    AppTheme.gradientButton(
                      onPressed: _isLoading ? null : _signUp,
                      gradient: _gradient,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Create Account',
                              style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(_primary, opacity: 0.08),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _roleChip('patient', Icons.person_rounded, 'Patient'),
          const SizedBox(width: 6),
          _roleChip('caregiver', Icons.supervisor_account_rounded, 'Caregiver'),
        ],
      ),
    );
  }

  Widget _roleChip(String role, IconData icon, String label) {
    final selected = _selectedRole == role;
    final color = role == 'caregiver'
        ? AppTheme.caregiverPrimary
        : AppTheme.patientPrimary;
    final gradient = role == 'caregiver'
        ? AppTheme.caregiverGradient
        : AppTheme.patientGradient;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: selected
              ? BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppTheme.softShadow(color, opacity: 0.3),
                )
              : BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow(_primary, opacity: 0.08),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        obscureText: obscure,
        style: GoogleFonts.nunito(fontSize: 15, color: AppTheme.textPrimary),
        decoration: AppTheme.inputDecoration(
          label: label,
          icon: icon,
          primaryColor: _primary,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
