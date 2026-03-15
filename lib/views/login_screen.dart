import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'patient/patient_dashboard.dart';
import 'caregiver/caregiver_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final String selectedRole;
  const LoginScreen({super.key, this.selectedRole = 'patient'});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _authService    = AuthService();
  bool _isLoading      = false;
  bool _obscurePassword = true;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;

  bool get _isCaregiver => widget.selectedRole == 'caregiver';
  LinearGradient get _gradient =>
      _isCaregiver ? AppTheme.caregiverGradient : AppTheme.patientGradient;
  Color get _primary =>
      _isCaregiver ? AppTheme.caregiverPrimary : AppTheme.patientPrimary;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final password   = _passwordCtrl.text;

    if (identifier.isEmpty) { _snack('Please enter your Email or Phone'); return; }
    if (password.isEmpty)   { _snack('Please enter your password');       return; }

    setState(() => _isLoading = true);
    final user = await _authService.login(identifier, password);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (user != null) {
      final route = user.role == 'patient'
          ? MaterialPageRoute(builder: (_) => PatientDashboard())
          : MaterialPageRoute(builder: (_) => CaregiverDashboard());
      Navigator.pushReplacement(context, route);
    } else {
      _snack('Invalid credentials. Please check and try again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(gradient: _gradient),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 36),
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
                      Text(
                        _isCaregiver ? 'Caregiver Login' : 'Patient Login',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Welcome back 👋',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCaregiver
                          ? Icons.supervisor_account_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── White card form ─────────────────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email / Phone
                      _buildField(
                        label: 'Email or Phone',
                        icon: Icons.person_outline_rounded,
                        controller: _identifierCtrl,
                        inputType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // Password
                      _buildField(
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        controller: _passwordCtrl,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Login button
                      AppTheme.gradientButton(
                        onPressed: _isLoading ? null : _login,
                        gradient: _gradient,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Sign In',
                                style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.nunito(
                                color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => SignUpScreen())),
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.nunito(
                                color: _primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
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
        controller: controller,
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
