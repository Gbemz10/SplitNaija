import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around the backend REST API.
///
/// Point [baseUrl] at your deployed backend. When running on an Android
/// emulator against a locally-running backend, use 10.0.2.2 instead of
/// localhost; on a physical device, use your machine's LAN IP.
class ApiClient {
  ApiClient({this.baseUrl = 'http://10.0.2.2:4000'});

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
