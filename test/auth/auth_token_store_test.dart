import 'package:nimon/features/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_auth_token_store.dart';

void main() {
  test('InMemoryAuthTokenStore write/read/clear', () async {
    final store = InMemoryAuthTokenStore();
    expect(await store.readTokens(), isNull);

    await store.writeTokens(
      const StoredAuthTokens(accessToken: 'a', refreshToken: 'b'),
    );
    final t = await store.readTokens();
    expect(t?.accessToken, 'a');
    expect(t?.refreshToken, 'b');

    await store.clearTokens();
    expect(await store.readTokens(), isNull);
  });
}
