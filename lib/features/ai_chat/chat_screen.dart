import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'chat_widget.dart';
import 'loading_widget.dart';
import 'models/model.dart';
import 'providers/model_download_provider.dart';
import 'widgets/model_download_widget.dart';

/// A screen widget that provides a chat interface with a Gemma AI model.
class ChatScreen extends ConsumerStatefulWidget {
  /// Creates a [ChatScreen].
  ///
  /// [model] specifies the AI model configuration to use. Defaults to
  /// [Model.gemma3GpuLocalAsset] if not provided.
  const ChatScreen({super.key, this.model = Model.gemma3GpuLocalAsset});

  /// The AI model configuration to use for the chat.
  final Model model;

  @override
  ChatScreenState createState() => ChatScreenState();
}

/// The state associated with the [ChatScreen] widget.
class ChatScreenState extends ConsumerState<ChatScreen> {
  final _logger = Logger('ChatScreen');
  final _gemma = FlutterGemmaPlugin.instance;

  /// The active chat instance with the Gemma model. Null until initialized.
  InferenceChat? _chat;

  /// List of messages exchanged in the chat, displayed in the UI.
  final _messages = <Message>[];

  /// Stores any error message that occurs during model initialization or chat.
  String? _initializationError;

  /// Flag to indicate if a download check is needed. Set to true initially.
  bool _needsDownloadCheck = true;

  /// Flag to indicate if the model is ready for initialization (downloaded or local).
  bool _modelReadyForInitialization = false;

  /// Flag to indicate if the initial prompt processing is complete.
  bool _hasInitialPromptResponse = false;

  /// Flag to indicate overall initialization state (download + model load + initial prompt).
  bool _isInitializing = true; // Start as true

  /// The initial system prompt for the AI assistant.
  final String _initialPrompt = """
You are the AI assistant for LocalSend Plus, a powerful cross-platform file and text sharing application. Your role is strictly limited to helping users with LocalSend Plus functionality.

STRICT BOUNDARIES:
- Only respond to questions and topics related to LocalSend Plus
- Do not engage in general conversation or small talk
- Do not provide information about other apps or services
- Do not answer questions about topics outside of LocalSend Plus features
- If asked about anything unrelated to LocalSend Plus, respond: "I can only assist with LocalSend Plus functionality. Please ask questions related to the app's features."

Core Knowledge:
1. File Sharing Capabilities
- Guide users through sending various file types (images, videos, documents)
- Explain the built-in media editing features:
  * Photo editing before sending
  * Video editing (non-web platforms)
  * File selection and preview capabilities
- Explain supported file formats and any size limitations

2. Device Discovery & Connectivity
- Help users understand different connection methods:
  * Automatic network discovery
  * QR code scanning/generation
  * NFC sharing (on supported devices)
  * Manual IP address connection
- Guide users through the device favorites system
- Troubleshoot connection issues

3. Text Sharing Features
- Explain text sharing capabilities
- Guide users through the text input interface
- Help with retry mechanisms if messages fail
- Explain UTF-8 encoding and text handling

4. Security and Privacy
- Explain the app's security features
- Guide users through secure file transfers
- Help with encryption understanding

5. Special Features
- AI Chat functionality using Gemma model
- Media editing capabilities
- Device management
- Settings customization

Interaction Style:
- Be concise and direct in explanations
- Focus solely on app functionality
- Provide step-by-step guidance when needed
- Explain technical concepts in user-friendly terms
- Stay within the scope of LocalSend Plus features

Common Tasks to Assist With:
1. Device Connection
2. File Operations
3. Text Sharing
4. Device Management
5. Troubleshooting

IMPORTANT: Your responses must ONLY relate to LocalSend Plus functionality. Decline to answer any questions or engage in discussion about other topics.
""";


  @override
  void dispose() {
    // Consider disposing the _chat instance here if necessary,
    // although the plugin might handle its own resource cleanup.
    // _chat?.close(); // Example if a close method exists
    super.dispose();
  }

  /// Determines the local path or URL for the selected AI model.
  ///
  /// For local models (assets or downloaded), it returns the file path.
  /// For web, it returns the model URL directly.
  Future<String> _getModelPath() async {
    // If the model is marked as local (e.g., included in assets).
    if (widget.model.localModel) {
      return widget.model.url; // The 'url' field holds the asset path for local models.
    }
    // If running on the web, use the URL directly (no download).
    return kIsWeb
        ? widget.model.url
        // For non-web platforms, construct the path in the app's documents directory.
        : '${(await getApplicationDocumentsDirectory()).path}/${widget.model.filename}';
  }

  /// Checks if the model file exists locally (for non-web platforms).
  Future<bool> _checkIfModelExists() async {
    // Web doesn't involve local file checks for models loaded via URL.
    if (kIsWeb) return true;
    final path = await _getModelPath();
    // Check if a file exists at the determined path.
    return await File(path).exists();
  }

  /// Initializes the Gemma chat instance with the specified model path.
  ///
  /// Handles both loading models from assets and from downloaded files.
  /// Updates the state with the chat instance or an error message.
  Future<void> _initializeGemmaChat(String modelPath) async {
    // Reset errors and set initializing state
    if (!mounted) return;
    setState(() {
      _initializationError = null;
      _isInitializing = true; // Mark as initializing
      _hasInitialPromptResponse = false; // Reset prompt response flag
    });
    _logger.info("Initializing Gemma with model path: $modelPath");
    try {
      // Check if the model path points to an asset.
      if (modelPath.startsWith('assets/')) {
        // Extract the relative path for the asset installer.
        final relativeAssetPath = modelPath.replaceFirst('assets/', '');
        _logger.info("Using installModelFromAsset with relative path: $relativeAssetPath");
        // Install the model from the app's assets.
        await _gemma.modelManager.installModelFromAsset(relativeAssetPath);
        _logger.info("Model installed from asset successfully.");
      } else {
        // If not an asset, assume it's a path to a downloaded file.
        _logger.info("Using setModelPath for path: $modelPath");
        // Set the path for the model manager.
        await _gemma.modelManager.setModelPath(modelPath);
        _logger.info("Model path set successfully.");
      }

      // Create the Gemma model instance with specified configurations.
      final model = await _gemma.createModel(
        modelType: widget.model.modelType,
        preferredBackend: widget.model.preferredBackend,
        maxTokens: 1024, // Maximum tokens for model responses.
      );
      _logger.info("Gemma model created.");

      // Create the chat session using the model instance.
      _chat = await model.createChat(
        temperature: widget.model.temperature, // Controls response randomness.
        randomSeed: 1, // Seed for reproducibility.
        topK: widget.model.topK, // Limits sampling to top K likely tokens.
        topP: widget.model.topP, // Uses nucleus sampling based on probability mass.
        tokenBuffer: 256, // Buffer size for token processing.
      );
      _logger.info("Gemma chat created successfully.");

      // Send the initial system prompt but don't display it
      try {
        _logger.info("Sending initial system prompt...");
        // Add the initial prompt as a query chunk.
        final initialPromptMessage = Message(text: _initialPrompt, isUser: false); // Create Message object
        await _chat!.addQueryChunk(initialPromptMessage);
        // Generate the response stream and drain it to discard the output.
        // This "warms up" the model with the context.
        await _chat!.generateChatResponseAsync().drain(); // Use addQueryChunk + generateChatResponseAsync
        _logger.info("Initial system prompt processed successfully.");
        if (mounted) {
          setState(() {
            _hasInitialPromptResponse = true; // Mark prompt as processed
            _isInitializing = false; // Mark overall initialization complete
          });
        }
      } catch (e) {
        _logger.severe("Error sending initial prompt", e);
        if (mounted) {
          setState(() {
            _initializationError = "Failed to initialize AI assistant. Error: $e";
            _isInitializing = false; // Still finish initializing, but show error
          });
        }
      }
    } catch (e) {
      // Handle any errors during model/chat creation.
      _logger.severe("Error initializing Gemma", e);
      if (mounted) {
        setState(() {
          _initializationError = "Failed to initialize AI model. Error: $e";
          _isInitializing = false; // Mark initialization as finished (with error)
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state of the model download provider.
    final downloadState = ref.watch(modelDownloadProvider);
    // Get the notifier to trigger download actions.
    final downloadNotifier = ref.read(modelDownloadProvider.notifier);

    // Perform download check only once when the widget builds.
    if (_needsDownloadCheck && !kIsWeb) {
      _needsDownloadCheck = false; // Prevent repeated checks.
      // Use Future.microtask to avoid calling setState during build.
      Future.microtask(() async {
        // Handle local asset models directly.
        if (widget.model.localModel) {
          _logger.info("Local asset model selected. Skipping download check.");
          if (mounted) {
            setState(() {
              _modelReadyForInitialization = true; // Mark as ready.
            });
            // Get the asset path and initialize.
            final path = await _getModelPath();
            await _initializeGemmaChat(path); // Use await here
          }
          return; // Exit early for local models.
        }

        // Check if the model file already exists locally.
        final modelExists = await _checkIfModelExists();
        if (modelExists) {
          _logger.info("Model file found locally.");
          if (mounted) {
            setState(() {
              _modelReadyForInitialization = true; // Mark as ready.
            });
            // Get the local file path and initialize.
            final path = await _getModelPath();
            await _initializeGemmaChat(path); // Use await here
          }
        } else {
          // If the model doesn't exist, start the download.
          _logger.info("Model file not found. Starting download...");
          downloadNotifier.downloadModel(widget.model.url, widget.model.filename);
        }
      });
    } else if (kIsWeb && _needsDownloadCheck) {
      // Handle initialization for web platform (no download needed).
      _needsDownloadCheck = false;
      Future.microtask(() async {
        if (mounted) {
          setState(() {
            _modelReadyForInitialization = true; // Mark as ready.
          });
          // Initialize directly with the model URL.
          await _initializeGemmaChat(widget.model.url); // Use await here
        }
      });
    }

    // Listen to changes in the download provider state.
    ref.listen<ModelDownloadState>(modelDownloadProvider, (previous, next) {
      // When download completes successfully.
      if (previous?.status != DownloadStatus.completed && next.status == DownloadStatus.completed) {
        _logger.info("Download complete listener triggered.");
        if (mounted) {
          setState(() {
            _modelReadyForInitialization = true; // Mark as ready.
          });
          // Initialize the chat after download.
          Future.microtask(() async {
            final path = await _getModelPath();
            await _initializeGemmaChat(path); // Use await here
          });
        }
      }
      // Handle retry logic if a download error occurred and was reset.
      if (previous?.status == DownloadStatus.error && next.status == DownloadStatus.notStarted) {
        _logger.info("Retry detected. Re-triggering download.");
        // Re-trigger the download.
        Future.microtask(() {
          downloadNotifier.downloadModel(widget.model.url, widget.model.filename);
        });
      }
    });

    // Determine the main content widget based on the current state.
    Widget bodyContent;

    // Show download widget if model isn't ready and download is needed/in progress/failed.
    if (!_modelReadyForInitialization &&
        !widget.model.localModel && // Only show download for remote models
        !kIsWeb && // Don't show download for web
        (downloadState.status == DownloadStatus.downloading ||
            downloadState.status == DownloadStatus.error ||
            downloadState.status == DownloadStatus.notStarted)) {
      bodyContent = const ModelDownloadWidget();
    }
    // Show loading indicator during the entire initialization process (model load + initial prompt).
    else if (_isInitializing || (_modelReadyForInitialization && !_hasInitialPromptResponse && _initializationError == null)) {
       bodyContent = LoadingWidget(
         message: !_modelReadyForInitialization
             ? 'Preparing model...'
             : 'Initializing AI Assistant...',
       );
    }
    // Show error if initialization failed.
    else if (_initializationError != null && _chat == null) {
       bodyContent = Center(child: Text(_initializationError!));
    }
    // Show the chat interface if initialization is complete (including prompt) and chat is ready.
    else if (_chat != null && _hasInitialPromptResponse) {
      bodyContent = Column(
        children: [
          // Display an error banner if an error occurred during initialization or chat.
          // Or if an error occurs during chat interaction.
          if (_initializationError != null) _buildErrorBanner(_initializationError!),
          Expanded(
            // The main chat list and input widget.
            child: ChatListWidget(
              chat: _chat, // Pass the initialized chat instance.
              // Callback for when the AI sends a message.
              gemmaHandler: (message) {
                if (!mounted) return;
                setState(() {
                  _messages.add(message); // Add AI message to the list.
                });
              },
              // Callback for when the user sends a message.
              humanHandler: (text) {
                if (!mounted) return;
                setState(() {
                  _initializationError = null; // Clear previous errors on new user input.
                  _messages.add(Message(text: text, isUser: true)); // Add user message.
                });
              },
              // Callback for errors during chat interaction.
              errorHandler: (err) {
                if (!mounted) return;
                setState(() {
                  _initializationError = err; // Display chat interaction errors.
                });
              },
              messages: _messages, // Pass the current list of messages.
            ),
          ),
        ],
      );
    } else {
      // Show initialization error message or a generic "preparing" message.
      bodyContent = Center(child: Text(_initializationError ?? 'Preparing model...'));
    }

    // Build the main Scaffold structure.
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'AI Chat (${widget.model.name})', // Display model name in title.
          style: const TextStyle(fontSize: 20),
          softWrap: true, // Allow text wrapping.
          overflow: TextOverflow.ellipsis, // Handle long titles.
          maxLines: 2, // Limit title lines.
        ),
      ),
      body: bodyContent, // Display the determined body content.
    );
  }

  /// Builds a red banner widget to display error messages at the top of the chat.
  Widget _buildErrorBanner(String errorMessage) {
    return Container(
      width: double.infinity, // Span full width.
      color: Colors.red, // Error indication color.
      padding: const EdgeInsets.all(8.0), // Padding around the text.
      child: Text(
        errorMessage,
        style: const TextStyle(color: Colors.white), // White text for contrast.
        textAlign: TextAlign.center, // Center the error message.
      ),
    );
  }
}
