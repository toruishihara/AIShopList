import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAiClient {
  static const _base = 'api.openai.com';
  static const _token = String.fromEnvironment('OPENAI_API_KEY'); // set via --dart-define

  Future<Map<String, dynamic>> chat(String userText) async {
    final uri = Uri.https(_base, '/v1/chat/completions');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': userText}
        ],
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('OpenAI error: ${res.statusCode} ${res.body}');
  }
}
