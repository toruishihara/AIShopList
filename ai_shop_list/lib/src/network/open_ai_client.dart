import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';

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

    /// NEW: Whisper transcription (wav → text)
  Future<String> transcribeWav(File wavFile, {String? language}) async {
    final uri = Uri.https(_base, '/v1/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_token'
      ..fields['model'] = 'whisper-1'; // model name
    if (language != null && language.isNotEmpty) {
      req.fields['language'] = language; // e.g. "ja", "en"
    }
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        wavFile.path,
        contentType: MediaType('audio', 'wav'),
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode ~/ 100 == 2) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['text'] ?? '').toString();
    }
    throw Exception('OpenAI transcribe error: ${res.statusCode} ${res.body}');
  }
}
