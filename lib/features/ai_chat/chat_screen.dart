import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'chat_widget.dart';
import 'loading_widget.dart';
import 'models/model.dart';
import 'providers/model_download_provider.dart';
import 'widgets/model_download_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.model = Model.gemma3GpuLocalAsset});
  final Model model;
  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends ConsumerState<ChatScreen> {
  final _gemma = FlutterGemmaPlugin.instance;
  InferenceChat? _chat;
  final _messages = <Message>[];
  String? _initializationError;
  bool _needsDownloadCheck = true;
  bool _modelReadyForInitialization = false;
  @override
  void dispose() {
    super.dispose();
  }

  Future<String> _getModelPath() async {
    if (widget.model.localModel) {
      return widget.model.url;
    }
    return kIsWeb
        ? widget
            .model
            .url // Web uses URL directly (no download needed here)
        : '${(await getApplicationDocumentsDirectory()).path}/${widget.model.filename}';
  }

  Future<bool> _checkIfModelExists() async {
    if (kIsWeb) return true;
    final path = await _getModelPath();
    return await File(path).exists();
  }

  Future<void> _initializeGemmaChat(String modelPath) async {
    setState(() {
      _initializationError = null;
    });
    print("Initializing Gemma with model path: $modelPath");
    try {
      if (modelPath.startsWith('assets/')) {
        final relativeAssetPath = modelPath.replaceFirst('assets/', '');
        print("Using installModelFromAsset with relative path: $relativeAssetPath");
        await _gemma.modelManager.installModelFromAsset(relativeAssetPath);
        print("Model installed from asset successfully.");
      } else {
        print("Using setModelPath for path: $modelPath");
        await _gemma.modelManager.setModelPath(modelPath);
        print("Model path set successfully.");
      }
      final model = await _gemma.createModel(modelType: widget.model.modelType, preferredBackend: widget.model.preferredBackend, maxTokens: 1024);
      print("Gemma model created.");
      _chat = await model.createChat(
        temperature: widget.model.temperature,
        randomSeed: 1,
        topK: widget.model.topK,
        topP: widget.model.topP,
        tokenBuffer: 256,
      );
      print("Gemma chat created successfully.");
      if (mounted) {
        setState(() {}); // Trigger rebuild to show chat UI
      }
    } catch (e) {
      print("Error initializing Gemma: $e");
      if (mounted) {
        setState(() {
          _initializationError = "Failed to initialize AI model. Error: $e";
          // Keep _modelReadyForInitialization true so error is shown in main UI area
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(modelDownloadProvider);
    final downloadNotifier = ref.read(modelDownloadProvider.notifier);
    if (_needsDownloadCheck && !kIsWeb) {
      _needsDownloadCheck = false;
      Future.microtask(() async {
        if (widget.model.localModel) {
          print("Local asset model selected. Skipping download check.");
          if (mounted) {
            setState(() {
              _modelReadyForInitialization = true;
            });
            final path = await _getModelPath();
            _initializeGemmaChat(path);
          }
          return;
        }
        final modelExists = await _checkIfModelExists();
        if (modelExists) {
          print("Model file found locally.");
          if (mounted) {
            setState(() {
              _modelReadyForInitialization = true;
            });
            final path = await _getModelPath();
            _initializeGemmaChat(path);
          }
        } else {
          print("Model file not found. Starting download...");
          downloadNotifier.downloadModel(widget.model.url, widget.model.filename);
        }
      });
    } else if (kIsWeb && _needsDownloadCheck) {
      _needsDownloadCheck = false;
      Future.microtask(() async {
        if (mounted) {
          setState(() {
            _modelReadyForInitialization = true;
          });
          _initializeGemmaChat(widget.model.url);
        }
      });
    }
    ref.listen<ModelDownloadState>(modelDownloadProvider, (previous, next) {
      if (previous?.status != DownloadStatus.completed && next.status == DownloadStatus.completed) {
        print("Download complete listener triggered.");
        if (mounted) {
          setState(() {
            _modelReadyForInitialization = true;
          });
          Future.microtask(() async {
            final path = await _getModelPath();
            _initializeGemmaChat(path);
          });
        }
      }
      if (previous?.status == DownloadStatus.error && next.status == DownloadStatus.notStarted) {
        print("Retry detected. Re-triggering download.");
        Future.microtask(() {
          downloadNotifier.downloadModel(widget.model.url, widget.model.filename);
        });
      }
    });
    Widget bodyContent;
    if (!_modelReadyForInitialization &&
        (downloadState.status == DownloadStatus.downloading ||
            downloadState.status == DownloadStatus.error ||
            downloadState.status == DownloadStatus.notStarted)) {
      bodyContent = const ModelDownloadWidget();
    } else if (_modelReadyForInitialization && _chat == null && _initializationError == null) {
      bodyContent = const LoadingWidget(message: 'Initializing AI model...');
    } else if (_chat != null) {
      bodyContent = Column(
        children: [
          if (_initializationError != null) _buildErrorBanner(_initializationError!),
          Expanded(
            child: ChatListWidget(
              chat: _chat,
              gemmaHandler: (message) {
                if (!mounted) return;
                setState(() {
                  _messages.add(message);
                });
              },
              humanHandler: (text) {
                if (!mounted) return;
                setState(() {
                  _initializationError = null;
                  _messages.add(Message(text: text, isUser: true));
                });
              },
              errorHandler: (err) {
                if (!mounted) return;
                setState(() {
                  _initializationError = err; // Use the same error state
                });
              },
              messages: _messages,
            ),
          ),
        ],
      );
    } else {
      bodyContent = Center(child: Text(_initializationError ?? 'Preparing model...'));
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'AI Chat (${widget.model.name})',
          style: const TextStyle(fontSize: 20),
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
      body: bodyContent,
    );
  }

  Widget _buildErrorBanner(String errorMessage) {
    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.all(8.0),
      child: Text(errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
    );
  }
}
