import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:4000"; // Android emulator

  // Create Intent
  static Future createIntent(String from, String to, String amount) async {
    final res = await http.post(
      Uri.parse("$baseUrl/intents"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "from": from,
        "to": to,
        "amount": amount,
      }),
    );

    return jsonDecode(res.body);
  }

  // Get Intents
  static Future getIntents() async {
    final res = await http.get(Uri.parse("$baseUrl/intents"));
    return jsonDecode(res.body);
  }

  // Create Batch
  static Future createBatch() async {
    final res = await http.post(Uri.parse("$baseUrl/batches/create"));
    return jsonDecode(res.body);
  }

  // Commit Batch
  static Future commitBatch(int batchId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/batches/commit"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"batchId": batchId}),
    );

    return jsonDecode(res.body);
  }
}