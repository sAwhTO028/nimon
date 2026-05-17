import 'package:flutter/foundation.dart';
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
import 'package:nimon/features/auth/auth_session_state.dart';

/// Email/password entry. **Guest** stays local-only (no Bearer token); remote drafts
/// require login or backend dev fallback (see M1b report).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _submitting = false;
  String? _error;
  ValidationIssue? _emailIssue;
  ValidationIssue? _passwordIssue;
  ValidationIssue? _bannerIssue;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!mounted) return;
    final loginRes = validateLoginFields(
      email: _email.text,
      password: _password.text,
    );
    setState(() {
      _error = null;
      _bannerIssue = null;
      _emailIssue = firstBlockingIssueForField(loginRes, 'email');
      _passwordIssue = firstBlockingIssueForField(loginRes, 'password');
    });
    if (!loginRes.ok) return;

    if (!mounted) return;
    final email = normalizeEmailInput(_email.text);
    final password = _password.text;
    setState(() {
      _submitting = true;
    });
    try {
      await ref.read(authSessionProvider.notifier).login(
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
        _bannerIssue =
            firstUnhandledBlockingIssue(e.issues, byField.keys.toSet());
        _error = null;
      });
    } on AuthRepositoryException catch (_) {
      if (!mounted) return;
      setState(() {
        _bannerIssue = null;
        _error = validationMessageKeyLocalized(context, 'auth.login.failed');
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final session = ref.watch(authSessionProvider);
    final sessionBusy =
        session is AuthSessionUnknown || session is AuthSessionLoading;
    const horizontal = 24.0;
    const topPad = 24.0;
    const bottomPad = 24.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: horizontal),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                0,
                topPad,
                0,
                bottomInset + bottomPad,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - topPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Great!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text("Let's get started"),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      surfaceTintColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                              autofillHints: const [AutofillHints.password],
                              onChanged: (_) {
                                if (_passwordIssue != null) {
                                  setState(() => _passwordIssue = null);
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
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _submitting ? null : _onLogin,
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('LOGIN'),
                            ),
                            TextButton(
                              onPressed: _submitting || sessionBusy
                                  ? null
                                  : () {
                                      final s = ref.read(authSessionProvider);
                                      debugPrint(
                                        '[GuestEntry] authState=${s.runtimeType} action=goMono',
                                      );
                                      if (s is AuthSessionUnknown ||
                                          s is AuthSessionLoading) {
                                        return;
                                      }
                                      context.go('/mono');
                                    },
                              child: const Text('Guest >>'),
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/register'),
                              child: const Text('Create account'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Google sign-in coming soon'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.g_mobiledata),
                              label: const Text('Sign up with Google'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
