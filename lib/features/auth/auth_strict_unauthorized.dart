import 'package:http/http.dart' as http;
import 'package:nimon/features/auth/auth_session_expired_bridge.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

/// When strict remote drafts fail with **401**, trigger session expiry UX (if bridge registered).
void notifyIfStrictUnauthorized401(http.Response r) {
  if (!RemoteBackendConfig.strictRemoteDrafts) return;
  if (r.statusCode != 401) return;
  AuthSessionExpiredBridge.instance.notifyExpired();
}
