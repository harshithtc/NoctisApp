import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String userId;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.userId,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _remainingSeconds = 600; // 10 minutes
  Timer? _timer;
  final bool _autoVerifyOnFill = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _collectCode() => _controllers.map((c) => c.text.trim()).join();

  Future<void> _verify() async {
    final code = _collectCode();

    if (code.length != 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();

    final ok = await auth.verifyEmail(
      userId: widget.userId,
      code: code,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Verification failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      // Clear fields and focus first
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    }
  }

  void _onOtpChanged(String value, int index) {
    // Move focus forward on input, backward on delete
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_autoVerifyOnFill) {
      final code = _collectCode();
      if (code.length == 6) {
        _verify();
      }
    }
  }

  Future<void> _handlePaste(int index) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (text.length == 6) {
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = text[i];
      }
      _focusNodes.last.requestFocus();
      if (_autoVerifyOnFill) {
        _verify();
      }
    } else if (text.isNotEmpty) {
      // Fill from current index onward
      var p = 0;
      for (var i = index; i < 6 && p < text.length; i++, p++) {
        _controllers[i].text = text[p];
      }
      final next = (index + text.length).clamp(0, 5);
      _focusNodes[next].requestFocus();
    }
  }

  Future<void> _resendCode() async {
    final auth = context.read<AuthProvider>();

    try {
      final ok = await auth.resendVerificationCode(
        userId: widget.userId,
        email: widget.email,
      );

      if (!mounted) return;

      if (ok) {
        setState(() {
          _remainingSeconds = 600; // 10 minutes
        });
        _startTimer();

        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.error ?? 'Failed to resend code'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend code: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: scheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Check Your Email',
                style: textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'We sent a 6-digit code to',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                widget.email,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // OTP Inputs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: textTheme.headlineMedium,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: index == 0
                            ? IconButton(
                                tooltip: 'Paste code',
                                icon: const Icon(Icons.paste_outlined),
                                onPressed: () => _handlePaste(index),
                              )
                            : null,
                      ),
                      onChanged: (v) => _onOtpChanged(v, index),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Timer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Code expires in ${_formatTime(_remainingSeconds)}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Verify button
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return ElevatedButton(
                    onPressed: auth.isLoading ? null : _verify,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Verify Email'),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Resend code
              TextButton(
                onPressed: _remainingSeconds == 0 ? _resendCode : null,
                child: Text(
                  _remainingSeconds == 0
                      ? 'Resend Code'
                      : 'Resend available in ${_formatTime(_remainingSeconds)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
