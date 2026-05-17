import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/validation/auth_validators.dart';
import 'package:nimon/core/validation/form_validation_adapter.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';

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
  ValidationIssue? _emailIssue;
  ValidationIssue? _passwordIssue;
  ValidationIssue? _confirmIssue;
  ValidationIssue? _bannerIssue;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _clearFieldErrors() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _bannerIssue = null;
      _emailIssue = null;
      _passwordIssue = null;
      _confirmIssue = null;
    });
  }

  /// Sets per-field errors; returns `true` if valid.
  bool _validateFields() {
    final res = validateRegisterFormFields(
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirmPassword.text,
    );
    if (!mounted) return false;
    setState(() {
      _bannerIssue = null;
      _emailIssue = firstBlockingIssueForField(res, 'email');
      _passwordIssue = firstBlockingIssueForField(res, 'password');
      _confirmIssue = firstBlockingIssueForField(res, 'confirmPassword');
    });
    return res.ok;
  }

  Future<void> _onRegister() async {
    if (!mounted) return;
    _clearFieldErrors();
    if (!_validateFields()) {
      return;
    }
    if (!mounted) return;
    final email = normalizeEmailInput(_email.text);
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
    } on HttpValidationFailedException catch (e) {
      if (!mounted) return;
      final byField = blockingIssuesByField(e.issues);
      setState(() {
        _emailIssue = byField['email'];
        _passwordIssue = byField['password'];
        _confirmIssue = byField['confirmPassword'];
        _bannerIssue =
            firstUnhandledBlockingIssue(e.issues, byField.keys.toSet());
        _error = null;
      });
    } on AuthRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerIssue = null;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerIssue = null;
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
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
                if (_emailIssue != null) {
                  setState(() => _emailIssue = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _emailIssue != null
                    ? validationIssueDisplayMessageLocalized(
                        context,
                        _emailIssue!,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _passwordIssue != null
                    ? validationIssueDisplayMessageLocalized(
                        context,
                        _passwordIssue!,
                      )
                    : null,
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_passwordIssue != null || _confirmIssue != null) {
                  setState(() {
                    _passwordIssue = null;
                    _confirmIssue = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                errorText: _confirmIssue != null
                    ? validationIssueDisplayMessageLocalized(
                        context,
                        _confirmIssue!,
                      )
                    : null,
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_confirmIssue != null) {
                  setState(() => _confirmIssue = null);
                }
              },
            ),
            if (_error != null || _bannerIssue != null) ...[
              const SizedBox(height: 8),
              Text(
                _error ??
                    validationIssueDisplayMessageLocalized(
                      context,
                      _bannerIssue!,
                    ),
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
