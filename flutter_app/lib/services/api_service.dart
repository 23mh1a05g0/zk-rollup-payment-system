import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Read base URL at compile-time via --dart-define=API_BASE_URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Future<Map<String, dynamic>> getDeposit(String address) async {
    final response = await http.get(Uri.parse('$baseUrl/deposits/$address'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get deposit: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getRollupState() async {
    final response = await http.get(Uri.parse('$baseUrl/state'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get rollup state: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> submitIntent(
      String from, String to, String amountWei) async {
    final response = await http.post(
      Uri.parse('$baseUrl/intents'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fromAddress': from,
        'toAddress': to,
        'amountWei': amountWei,
      }),
    );
    // Note: can return 400 with {"error": "Insufficient on-chain deposit"}
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getIntents({String? address, String? status}) async {
    String url = '$baseUrl/intents';
    List<String> queryParams = [];
    if (address != null && address.isNotEmpty) {
      queryParams.add('address=$address');
    }
    if (status != null && status.isNotEmpty) {
      queryParams.add('status=$status');
    }
    if (queryParams.isNotEmpty) {
      url += '?' + queryParams.join('&');
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['intents'] as List<dynamic>;
    } else {
      throw Exception('Failed to get intents: ${response.body}');
    }
  }

  Future<List<dynamic>> getBatches() async {
    final response = await http.get(Uri.parse('$baseUrl/batches'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['batches'] as List<dynamic>;
    } else {
      throw Exception('Failed to get batches: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getBatchDetail(int batchIndex) async {
    final response = await http.get(Uri.parse('$baseUrl/batches/$batchIndex'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get batch detail: ${response.body}');
    }
  }
}