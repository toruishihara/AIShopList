import 'dart:convert';
import 'dart:io';

import 'package:ai_shop_list/src/model/shop_item.dart';
import 'package:ai_shop_list/src/repository/chat_repository.dart';
import 'package:ai_shop_list/src/repository/shop_list_repository.dart';
import 'package:ai_shop_list/src/repository/transcription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../model/chat_message.dart';
import '../network/open_ai_client.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAiClient _client;
  late final chatRepo = ChatRepository(_client);
  late final transRepo = TranscriptionRepository(_client);
  final ShopListRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  List<ShopItem> _shopList = [];
  List<ShopItem> get shopList => List.unmodifiable(_shopList);

  ChatViewModel(this._client, this._repository){
    _shopList = _repository.getItems();
    //addShopItem(ShopItem(name: 'Pear', quantity: 1));
    //addShopItem(ShopItem(name: 'Pineapple', quantity: 1));
  }

  void setShopListFromJson(List<dynamic> jsonList) {
    if (kDebugMode) {
      print("Setting shop list from JSON: $jsonList");
    }
    _shopList
      ..clear()
      ..addAll(jsonList.map((j) => ShopItem.fromJson(j as Map<String, dynamic>)));
    _repository.saveAll(_shopList);
    notifyListeners();
  }

  void addShopItem(ShopItem item) {
    _shopList.add(item);
    _repository.addItem(item);
    notifyListeners();
  }

  Future<String?> sendMessage(String text) async {
    _loading = true;
    notifyListeners();

    try {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      final existingList = _shopList.map((item) => item.toJson()).toList();
      final json = await chatRepo.sendMessageWithExisitingList(text, existingList);
      final content = json['choices'][0]['message']['content'] as String;
      final inner = jsonDecode(content) as Map<String, dynamic>;
      final reply = inner['message'] as String;
      final list = inner['list'] as List<dynamic>;
      setShopListFromJson(list);
      if (kDebugMode) {
        print('Reply: $reply');
        print('List: $list');
      }
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
          if (kDebugMode) {
            print("Transcription returned empty text");
          }
        }
      } else {
        if (kDebugMode) {
          print("Recording failed, file is null");
        }
      }
    } catch (e, st) {
      // handle any exceptions from either function
      if (kDebugMode) {
        print("Error in recordAndTranscribe: $e");
      }
      if (kDebugMode) {
        print(st);
      }
    }
  }

  Future<File?> recordToWav() async {
    final record = AudioRecorder();

    if (!await record.hasPermission()) {
      final ok = await record.hasPermission();
      if (kDebugMode) {
        print('Microphone permission: $ok');
      }
      if (!ok) return null;
    }

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
    return await transRepo.transcribe(path);
  }
}
