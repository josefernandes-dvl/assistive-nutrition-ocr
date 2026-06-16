import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/scan_result.dart';

class AppProvider extends ChangeNotifier {
  UserProfile _profile = const UserProfile(
    name: '',
    disorders: [],
  );

  final List<ScanResult> _scanHistory = [];
  bool _isLoading = false;

  UserProfile get profile => _profile;
  List<ScanResult> get scanHistory => List.unmodifiable(_scanHistory);
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile.name.isNotEmpty;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void addDisorder(String disorder) {
    if (!_profile.disorders.contains(disorder)) {
      _profile = _profile.copyWith(
        disorders: [..._profile.disorders, disorder],
      );
      notifyListeners();
    }
  }

  void removeDisorder(String disorder) {
    _profile = _profile.copyWith(
      disorders: _profile.disorders.where((d) => d != disorder).toList(),
    );
    notifyListeners();
  }

  void addScanResult(ScanResult result) {
    _scanHistory.insert(0, result);
    notifyListeners();
  }

  void clearHistory() {
    _scanHistory.clear();
    notifyListeners();
  }
}
