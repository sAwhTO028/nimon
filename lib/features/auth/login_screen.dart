import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Great!', style: Theme.of(context).textTheme.headlineSmall),
            const Text("Let's get started"),
            const Spacer(),
            Card(
              elevation: 0,
              surfaceTintColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(decoration: const InputDecoration(labelText: 'Email')),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () {}, child: const Text('LOGIN')),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Guest >>'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Sign up with Google'),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
