import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Backend base URL, resolved in priority order:
/// 1. `--dart-define=API_BASE_URL=http://your-value` at build/run time —
///    use this for a physical device (your Mac's LAN IP) or a staging server.
/// 2. Platform default: `10.0.2.2` for the Android emulator (its alias for
///    the host machine), `localhost` everywhere else (iOS Simulator, web).
const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

String _defaultBaseUrl() {
  if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000';
  return 'http://localhost:4000';
}

/// Thin wrapper around the backend REST API.
class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  final String baseUrl;
  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _handle(res);
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? body}) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  /// For endpoints that return a raw JSON array (e.g. GET /expenses/group/:id).
  Future<List<dynamic>> getList(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw ApiException(res.statusCode, res.body.isEmpty ? null : jsonDecode(res.body));
  }

  Map<String, dynamic> _handle(http.Response res) {
    final decoded = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, decoded);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final dynamic body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
