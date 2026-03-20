import 'package:flutter/material.dart';

import '../services/auth_storage.dart';
import '../widgets/pressable_scale.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _confirmation;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Enter a valid email.';
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _confirmation = null;
      _resetToken = null;
    });

    try {
      final valid = _formKey.currentState?.validate() ?? false;
      if (!valid) return;

      final token = await AuthStorage.requestPasswordReset(
        email: _emailController.text,
      );

      if (!mounted) return;
      setState(() {
        _confirmation =
            'If an account exists, a password reset link has been sent to your email.';
        _resetToken = token;
      });
    } on AuthStorageException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(compact)),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _validateEmail,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: 18),
                      PressableScale(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.mail_outline, size: 18),
                          label: Text(_busy ? 'Sending...' : 'Send reset link'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      if (_confirmation != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _confirmation!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: compact ? 12 : 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _resetToken == null
                              ? null
                            : () async {
                                final nav = Navigator.of(context);
                                final success = await nav.push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => ResetPasswordScreen(
                                      token: _resetToken!,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                if (success == true) {
                                  // Return to the Sign In page.
                                  nav.pop();
                                }
                              },
                          icon: const Icon(Icons.lock_reset, size: 18),
                          label: const Text('Set New Password'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Back to Sign In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool compact) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 20, compact ? 16 : 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user,
                color: Color(0xFF2ECC71),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email to receive a reset link.',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

