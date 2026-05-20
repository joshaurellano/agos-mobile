import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  String?    _error;
  bool       _isLoading = true;

  UserModel? get currentUser => _currentUser;
  String?    get error       => _error;
  bool       get isLoading   => _isLoading;

  AuthService() {
    _init();
  }

  void _init() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _fetchProfile(session.user.id);
      } else {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final data = await SupabaseService.fetchProfile(userId);
      if (data != null) _currentUser = UserModel.fromMap(data);
    } catch (e) {
      _currentUser = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    notifyListeners();
    final email = '$username@agos.local';
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (_) {
      _error = 'Invalid username or password.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createUser(Map<String, dynamic> payload) async {
    _error = null;
    notifyListeners();
    try {
      final ok = await SupabaseService.createUser(payload);
      if (!ok) {
        _error = 'Something went wrong creating the user.';
        notifyListeners();
      }
      return ok;
    } catch (_) {
      _error = 'Something went wrong.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}