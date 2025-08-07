import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpService {
  static const Duration _timeout = Duration(seconds: 30);

  static Future<http.Response> get(
      String url, {
        Map<String, String>? headers,
      }) async {
    final defaultHeaders = {
      'User-Agent': 'ViperWallet/1.0',
      'Accept': 'application/json',
      ...?headers,
    };

    try {
      print('HTTP GET: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: defaultHeaders,
      ).timeout(_timeout);

      print('HTTP Response: ${response.statusCode}');
      return response;
    } catch (e) {
      print('HTTP GET Error: $e');
      rethrow;
    }
  }

  static Future<http.Response> post(
      String url, {
        Map<String, String>? headers,
        Object? body,
      }) async {
    final defaultHeaders = {
      'User-Agent': 'ViperWallet/1.0',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    try {
      print('HTTP POST: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: defaultHeaders,
        body: body,
      ).timeout(_timeout);

      print('HTTP Response: ${response.statusCode}');
      return response;
    } catch (e) {
      print('HTTP POST Error: $e');
      rethrow;
    }
  }
}
