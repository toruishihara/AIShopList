import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../model/chat_message.dart';
import '../network/open_ai_client.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAiClient _client;

  bool _loading = false;
  bool get loading => _loading;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatViewModel(this._client) {
    // Initialize with default items
    _messages.add(ChatMessage(role: ChatRole.user, text: 'Hello'));
    _messages.add(ChatMessage(role: ChatRole.openai, text: 'Good Bye'));
  }

  Future<String?> sendMessage(String text) async {
    _loading = true;
    notifyListeners();

    try {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      final json = await _client.chat(text);
      final reply = json['choices']?[0]?['message']?['content'] ?? '';
      _messages.add(ChatMessage(role: ChatRole.openai, text: reply));
      _loading = false;
      notifyListeners();
      return reply;
    } catch (e) {
      _messages.add(ChatMessage(role: ChatRole.openai, text: e.toString()));
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> handleMicButton() async {
    try {
      final file = await recordToWav();
      if (file != null) {
        final text = await runTranscription(file.path);
        if (text != null && text.isNotEmpty) {
          final reply = await sendMessage(text);
          if (reply != null && reply.isNotEmpty) {
            final tts = FlutterTts();
            await tts.setLanguage('en-US');
            await tts.setSpeechRate(0.5);
            await tts.speak(reply);
          }
        } else {
          print("Transcription returned empty text");
        }
      } else {
        print("Recording failed, file is null");
      }
    } catch (e, st) {
      // handle any exceptions from either function
      print("Error in recordAndTranscribe: $e");
      print(st);
    }
  }

  /// 5秒だけ録音して WAV ファイルを返す（16kHz / モノラル想定）
  Future<File?> recordToWav() async {
    final record = AudioRecorder();

    // マイク権限
    if (!await record.hasPermission()) {
      final ok = await record.hasPermission();
      if (kDebugMode) {
        print('Microphone permission: $ok');
      }
      if (!ok) return null;
    }

    //final dir = await getTemporaryDirectory();
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }
    if (dir == null) return null;
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    // 16kHz/PCM WAV（Whisper向けによく使われる設定）
    const config = RecordConfig(
      encoder: AudioEncoder.wav, // WAV で保存
      sampleRate: 16000, // 16kHz
      numChannels: 1, // モノラル
      // bitRate は WAV(PCM)では指定不要（無圧縮）
    );

    await record.start(config, path: path);
    await Future.delayed(const Duration(seconds: 5));
    final outPath = await record.stop(); // 録音停止

    if (outPath == null) return null;
    return File(outPath);
  }

  Future<String?> runTranscription(String path) async {
    try {
      final file = File(path); // e.g. /storage/emulated/0/…/sample.wav
      final text = await _client.transcribeWav(
        file,
        language: 'en', // optional
      );
      // use `text` (update state, notify listeners, etc.)
      print(' $text');
      return text;
    } catch (e, st) {
      // handle errors (network, file not found, 401, etc.)
      print('Transcription failed: $e\n$st');
      return null;
    }
  }
}
