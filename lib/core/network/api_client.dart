import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../exceptions/exceptions.dart';
import '../../utils/retry.dart';

class ApiClient {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> post(String path) async {
    return retry(() async {
      final uri = Uri.parse('${AppConfig.baseUrl}$path');
      final response = await _client.post(
        uri,
        headers: {'Authorization': 'Bearer ${AppConfig.token}'},
      );
      return _handle(response);
    });
  }

  Future<Map<String, dynamic>> get(String path) async {
    return retry(() async {
      final uri = Uri.parse('${AppConfig.baseUrl}$path');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer ${AppConfig.token}'},
      );
      return _handle(response);
    });
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
  print("Kishore");
  print(res.body);
  print("Kishore");
  return jsonDecode(res.body);
    }
    throw NetworkException('HTTP ${res.statusCode}');
  }

  void dispose() => _client.close();
}