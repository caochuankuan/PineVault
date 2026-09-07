import 'package:flutter/foundation.dart';

import '../../../data/repositories/webdav_repository.dart';
import '../../../domain/models/webdav_configuration.dart';

enum WebDavSettingsState { idle, loading, testing, clearing }

class WebDavSettingsViewModel extends ChangeNotifier {
  WebDavSettingsViewModel({required WebDavRepository repository})
    : _repository = repository;

  final WebDavRepository _repository;
  WebDavSettingsState _state = WebDavSettingsState.idle;
  WebDavConfiguration? _configuration;
  String? _errorMessage;

  WebDavSettingsState get state => _state;
  WebDavConfiguration? get configuration => _configuration;
  String? get errorMessage => _errorMessage;
  bool get busy => _state != WebDavSettingsState.idle;

  Future<void> load() async {
    _state = WebDavSettingsState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _configuration = await _repository.loadConfiguration();
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _state = WebDavSettingsState.idle;
      notifyListeners();
    }
  }

  Future<bool> testAndSave({
    required String serverUrl,
    required String username,
    required String password,
    required String vaultId,
  }) async {
    _state = WebDavSettingsState.testing;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.testAndSave(
        serverUrl: serverUrl,
        username: username,
        password: password,
        vaultId: vaultId,
      );
      _configuration = await _repository.loadConfiguration();
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _state = WebDavSettingsState.idle;
      notifyListeners();
    }
  }

  Future<bool> clear() async {
    _state = WebDavSettingsState.clearing;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.clearConfiguration();
      _configuration = null;
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _state = WebDavSettingsState.idle;
      notifyListeners();
    }
  }

  String _message(Object error) {
    return error
        .toString()
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Bad state: ', '');
  }
}
