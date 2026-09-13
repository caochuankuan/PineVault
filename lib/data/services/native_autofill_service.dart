import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAutofillService {
  static const _channel = MethodChannel(
    'app.pinevault.client/autofill_settings',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isEnabled() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('isEnabled') ?? false;
  }

  static Future<bool> isBackgroundAllowed() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('isBackgroundAllowed') ?? false;
  }

  static Future<void> requestBackgroundAccess() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('requestBackgroundAccess');
  }

  static Future<void> enable() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('enable');
  }

  static Future<void> disable() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('disable');
  }
}

class NativeAutofillRequest {
  const NativeAutofillRequest({
    required this.packageNames,
    required this.webDomains,
  });

  final List<String> packageNames;
  final List<String> webDomains;
}

class NativeAutofillAuth {
  static const _channel = MethodChannel('app.pinevault.client/autofill_auth');

  static Future<NativeAutofillRequest> request() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('request');
    return NativeAutofillRequest(
      packageNames: List<String>.from(
        result?['packageNames'] as List? ?? const [],
      ),
      webDomains: List<String>.from(result?['webDomains'] as List? ?? const []),
    );
  }

  static Future<void> complete({
    required String label,
    required String username,
    required String password,
  }) async {
    await _channel.invokeMethod<void>('complete', {
      'label': label,
      'username': username,
      'password': password,
    });
  }

  static Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
