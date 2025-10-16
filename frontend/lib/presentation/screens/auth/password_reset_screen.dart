import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordReset() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _loading = true;
      _submitted = false;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.resetPassword(email: _emailController.text.trim());

    if (!mounted) return; // <- Fixes context usage warning

    setState(() {
      _loading = false;
      _submitted = result;
    });

    if (!result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Password reset failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final insets = MediaQuery.of(context).viewPadding;
    final view = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24 + insets.top,
              24,
              24 + insets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: view.width < 420 ? view.width : 420,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Forgot your password?',
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your email and we’ll send you instructions to reset your password.',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _sendPasswordReset,
                          child: const Text('Send Reset Email'),
                        ),
                  if (_submitted)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'If your email is found, you’ll receive an email with reset instructions shortly.',
                        style: textTheme.bodySmall?.copyWith(color: scheme.secondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
