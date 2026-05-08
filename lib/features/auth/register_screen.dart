import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/register_validation.dart';

/// Registration with confirm password; same session flow as login after success.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _submitting = false;
  String? _error;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _clearFieldErrors() {
    setState(() {
      _error = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });
  }

  /// Sets per-field errors; returns `true` if valid.
  bool _validateFields() {
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirmPassword.text;

    setState(() {
      _emailError = email.isEmpty ? kRegisterEmailEmpty : null;
      _passwordError = password.length < kRegisterMinPasswordLength
          ? kRegisterPasswordMinLength
          : null;
      _confirmError = password != confirm ? kRegisterPasswordMismatch : null;
    });

    return _emailError == null &&
        _passwordError == null &&
        _confirmError == null;
  }

  Future<void> _onRegister() async {
    _clearFieldErrors();
    if (!_validateFields()) {
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _submitting = true;
    });
    try {
      await ref.read(authSessionProvider.notifier).register(
            email: email,
            password: password,
          );
      if (!mounted) return;
      context.go('/mono');
    } on AuthRepositoryException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errColor = theme.colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _passwordError,
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_passwordError != null || _confirmError != null) {
                  setState(() {
                    _passwordError = null;
                    _confirmError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                errorText: _confirmError,
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: errColor, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _onRegister,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            ),
            TextButton(
              onPressed: _submitting ? null : () => context.pop(),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
