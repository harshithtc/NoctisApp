import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() => _status = 'Preparing secure storage...');
      // Initialize auth/session (restore tokens, user, etc.)
      final auth = context.read<AuthProvider>();
      await auth.initialize();

      if (!mounted) return;
      // Route based on authentication state
      if (auth.isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      setState(() => _status = 'Failed to initialize. Retrying...');
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _bootstrap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.nightlight_round, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text('NoctisApp', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(_status, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
