import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/auth_storage.dart';
import '../services/profile_storage.dart';
import '../widgets/pressable_scale.dart';
import 'forgot_password_screen.dart';

enum _AuthMode { signIn, signUp }

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({
    super.key,
    required this.onAuthenticated,
  });

  final VoidCallback onAuthenticated;

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  String? _formError;

  final _signInKey = GlobalKey<FormState>();
  final _signUpKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    final isSignIn = _mode == _AuthMode.signIn;
    final formKey = isSignIn ? _signInKey : _signUpKey;

    final valid = formKey.currentState?.validate() ?? false;
    if (!valid || _busy) return;

    setState(() => _busy = true);
    try {
      if (isSignIn) {
        await AuthStorage.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await AuthStorage.signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        // New account must not inherit a legacy device-wide profile from another user.
        await ProfileStorage.clearLegacyGlobalProfile();
      }

      if (!mounted) return;
      widget.onAuthenticated();
    } on AuthStorageException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      const msg = 'Something went wrong. Please try again.';
      setState(() => _formError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Enter a valid email.';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    return null;
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
                padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ModeChip(
                            label: 'Sign In',
                            selected: _mode == _AuthMode.signIn,
                            onTap: () => _switchMode(_AuthMode.signIn),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeChip(
                            label: 'Sign Up',
                            selected: _mode == _AuthMode.signUp,
                            onTap: () => _switchMode(_AuthMode.signUp),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (_formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          _formError!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _mode == _AuthMode.signIn
                          ? Form(
                              key: _signInKey,
                              child: Column(
                                children: [
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
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: _validatePassword,
                                    enabled: !_busy,
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      const ForgotPasswordScreen(),
                                                  fullscreenDialog: true,
                                                ),
                                              );
                                            },
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Form(
                              key: _signUpKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (v) {
                                      final value = v?.trim() ?? '';
                                      if (value.isEmpty) return 'Name is required.';
                                      return null;
                                    },
                                    enabled: !_busy,
                                  ),
                                  const SizedBox(height: 14),
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
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: _validatePassword,
                                    enabled: !_busy,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _confirmController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please confirm your password.';
                                      if (v != _passwordController.text) return 'Passwords do not match.';
                                      return null;
                                    },
                                    enabled: !_busy,
                                  ),
                                ],
                              ),
                            ),
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
                            : Icon(
                                _mode == _AuthMode.signIn ? Icons.login : Icons.app_registration,
                                size: 18,
                              ),
                        label: Text(
                          _busy
                              ? 'Please wait...'
                              : (_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account'),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Text(
                      _mode == _AuthMode.signIn
                          ? 'By continuing, you accept local demo sign-in.'
                          : 'Your data stays on-device for this prototype.',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
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
                FontAwesomeIcons.leaf,
                color: Color(0xFF2ECC71),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Nutri-Sense',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _mode == _AuthMode.signIn ? 'Welcome back' : 'Create your account',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2ECC71).withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF2ECC71) : const Color(0xFFE5EAF0),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF2ECC71) : const Color(0xFF1A1D29),
          ),
        ),
      ),
    );
  }
}

