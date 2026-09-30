import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

/// The signup screen — reached from the "Sign up" link on the login screen.
///
/// Like login, auth is mock-only: a valid form routes to the dashboard. The
/// "Already have an account? Log in" link at the bottom navigates back to the
/// login screen, giving the two screens the toggle behaviour the brief asked
/// for.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _submitting = false);
    context.goNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create account', style: textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Start capturing calls in a few seconds.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      label: 'Name',
                      controller: _nameController,
                      hintText: 'Your name',
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      hintText: 'At least 8 characters',
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.lock_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a password';
                        }
                        if (value.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Confirm password',
                      controller: _confirmController,
                      hintText: 'Re-enter your password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Create account',
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: textTheme.bodySmall,
                        ),
                        GestureDetector(
                          onTap: () => context.goNamed(AppRoutes.login),
                          child: Text(
                            'Log in',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
