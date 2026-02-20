import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

const _roleOptions = {
  'training_company': 'Training Company',
  'freelance_trainer': 'Freelance Trainer',
  'client': 'Client',
};

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedRole;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      return;
    }
    if (password != confirmPassword) {
      context.read<AuthProvider>().clearError();
      // We need to show error - AuthProvider doesn't have a way to set custom error
      // without signing in. Let me check - we could use a local state for validation errors
      return;
    }
    if (_selectedRole == null) {
      return;
    }

    setState(() => _loading = true);
    context.read<AuthProvider>().clearError();

    try {
      await context.read<AuthProvider>().signUp(email, password, _selectedRole!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 48),
              _buildForm(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(28, 24),
          painter: _TrianglePainter(),
        ),
        const SizedBox(width: 12),
        Text(
          'The Training Triangle',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider auth) {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final passwordMismatch =
        password.isNotEmpty && confirmPassword.isNotEmpty && password != confirmPassword;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign Up',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an account to get started',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Confirm password',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (passwordMismatch) ...[
            const SizedBox(height: 8),
            Text(
              'Passwords do not match',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Select Account Type',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ..._roleOptions.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  value: e.key,
                  groupValue: _selectedRole,
                  onChanged: (v) => setState(() => _selectedRole = v),
                  title: Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              )),
          if (auth.error != null) ...[
            const SizedBox(height: 16),
            Text(
              auth.error!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading || passwordMismatch || _selectedRole == null
                ? null
                : _handleSignUp,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign Up',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Already have an account? Log In',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
