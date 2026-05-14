import 'dart:io';

import 'package:nimon/core/validation/validation_fallback_messages.dart';

/// Heuristic: transport failures that should surface as generic offline copy,
/// not raw exception strings (HTTP layer uses [SocketException], package:http
/// throws `ClientException`, etc.).
bool isLikelyOfflineFailure(Object error) {
  if (error is SocketException) return true;
  if (error is HttpException) return true;
  final name = error.runtimeType.toString();
  if (name == 'ClientException' || name.contains('ClientException')) {
    return true;
  }
  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception')) return true;
  if (msg.contains('failed host lookup')) return true;
  if (msg.contains('network is unreachable')) return true;
  if (msg.contains('connection refused')) return true;
  if (msg.contains('connection reset')) return true;
  if (msg.contains('timed out')) return true;
  if (msg.contains('timeout')) return true;
  if (msg.contains('no address associated with hostname')) return true;
  return false;
}

/// Returns centralized offline copy when [error] looks like a network fault.
String? offlineUserMessageIfRecognized(Object error) {
  if (!isLikelyOfflineFailure(error)) return null;
  return validationFallbackMessage('network.offline');
}
