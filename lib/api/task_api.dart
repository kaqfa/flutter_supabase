import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class TaskApiService {
  // Ganti dengan Supabase project Anda
  static const String _baseUrl = 'https://xxx.supabase.co';
  static const String _apiKey = 'xxx';

  String? _accessToken;

  // Build headers untuk API requests
  Map<String, String> _getHeaders(
      {bool includeAuth = true, bool returnRepresentation = false}) {
    final headers = {
      'apikey': _apiKey,
      'Content-Type': 'application/json',
    };

    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    // For create operations, return the created record
    if (returnRepresentation) {
      headers['Prefer'] = 'return=representation';
    }

    return headers;
  }

  // === AUTHENTICATION ===

  // Login user
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        await _saveSession(data);
        return data;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Register user
  Future<Map<String, dynamic>?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/signup'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        await _saveSession(data);
        return data;
      }
      return null;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  // Load saved session
  Future<Map<String, String>?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getString('user_id');
      final email = prefs.getString('user_email');

      if (token != null && userId != null && email != null) {
        _accessToken = token;
        return {
          'token': token,
          'userId': userId,
          'email': email,
        };
      }
      return null;
    } catch (e) {
      print('Load session error: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      _accessToken = null;
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Save session to local storage
  Future<void> _saveSession(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('user_id', data['user']['id'].toString());
      await prefs.setString('user_email', data['user']['email']);
    } catch (e) {
      print('Save session error: $e');
    }
  }

  // === TASK OPERATIONS ===

  // Get all tasks for current user
  Future<List<Task>> getTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rest/v1/tasks?select=*&order=created_at.desc'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        // Handle unauthorized error
        print('Unauthorized: Token may be expired');
        return [];
      }
      return [];
    } catch (e) {
      print('Get tasks error: $e');
      return [];
    }
  }

  // Create new task
  Future<Task?> createTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/tasks'),
        headers: _getHeaders(returnRepresentation: true),
        body: jsonEncode(task.toJson()),
      );

      if (response.statusCode == 201) {
        // Handle empty response
        if (response.body.isEmpty) {
          // Return task with generated ID
          return Task(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: task.title,
            description: task.description,
            completed: false,
            userId: task.userId,
            createdAt: DateTime.now(),
          );
        }

        try {
          final data = jsonDecode(response.body);

          // Handle different response formats
          if (data is List && data.isNotEmpty) {
            return Task.fromJson(Map<String, dynamic>.from(data[0]));
          } else if (data is Map) {
            return Task.fromJson(Map<String, dynamic>.from(data));
          } else {
            return null;
          }
        } catch (parseError) {
          // If parsing fails, return basic task
          return Task(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: task.title,
            description: task.description,
            completed: false,
            userId: task.userId,
            createdAt: DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      print('Create task error: $e');
      return null;
    }
  }

  // Update task (toggle completed)
  Future<bool> updateTask(Task task) async {
    if (task.id == null) return false;

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/rest/v1/tasks?id=eq.${task.id}'),
        headers: _getHeaders(),
        body: jsonEncode(task.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Update task error: $e');
      return false;
    }
  }

  // Delete task
  Future<bool> deleteTask(int taskId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/rest/v1/tasks?id=eq.$taskId'),
        headers: _getHeaders(),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Delete task error: $e');
      return false;
    }
  }
}
