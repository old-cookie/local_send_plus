import 'dart:io'; // Used for file system operations like checking if a model file exists.
import 'package:flutter/foundation.dart'; // Provides kIsWeb constant to check if running on the web.
import 'package:flutter/material.dart'; // Flutter framework core widgets.
import 'package:flutter_gemma/core/chat.dart'; // Core chat functionalities from the flutter_gemma package.
import 'package:flutter_gemma/flutter_gemma.dart'; // Main entry point for the flutter_gemma package.
import 'package:flutter_riverpod/flutter_riverpod.dart'; // State management library.
import 'package:path_provider/path_provider.dart'; // Used to get the application's documents directory path.
import 'chat_widget.dart'; // Custom widget for displaying the chat interface.
import 'loading_widget.dart'; // Custom widget for showing loading indicators.
import 'models/model.dart'; // Defines the Model class used for AI model configuration.
import 'providers/model_download_provider.dart'; // Provider for managing model download state.
import 'widgets/model_download_widget.dart'; // Custom widget for displaying model download progress.


/// A screen widget that provides a chat interface with a Gemma AI model.
///
/// This widget handles model download (if necessary), initialization,
/// and interaction with the AI model through a chat interface.
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
///
/// Manages the lifecycle of the Gemma chat instance, handles model download
/// checks, initialization, and updates the UI based on the chat state.
class ChatScreenState extends ConsumerState<ChatScreen> {
  /// Instance of the Flutter Gemma plugin.
  final _gemma = FlutterGemmaPlugin.instance;

  /// The active chat instance with the Gemma model. Null until initialized.
  InferenceChat? _chat;

  /// List of messages exchanged in the chat.
  final _messages = <Message>[];

  /// Stores any error message that occurs during model initialization.
  String? _initializationError;

  /// Flag to indicate if a download check is needed. Set to true initially.
  bool _needsDownloadCheck = true;

  /// Flag to indicate if the model is ready for initialization (downloaded or local).
  bool _modelReadyForInitialization = false;

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
    // Reset any previous initialization error.
    if (!mounted) return; // Ensure the widget is still in the tree.
    setState(() {
      _initializationError = null;
    });
    print("Initializing Gemma with model path: $modelPath");
    try {
      // Check if the model path points to an asset.
      if (modelPath.startsWith('assets/')) {
        // Extract the relative path for the asset installer.
        final relativeAssetPath = modelPath.replaceFirst('assets/', '');
        print("Using installModelFromAsset with relative path: $relativeAssetPath");
        // Install the model from the app's assets.
        await _gemma.modelManager.installModelFromAsset(relativeAssetPath);
        print("Model installed from asset successfully.");
      } else {
        // If not an asset, assume it's a path to a downloaded file.
        print("Using setModelPath for path: $modelPath");
        // Set the path for the model manager.
        await _gemma.modelManager.setModelPath(modelPath);
        print("Model path set successfully.");
      }

      // Create the Gemma model instance with specified configurations.
      final model = await _gemma.createModel(
          modelType: widget.model.modelType,
          preferredBackend: widget.model.preferredBackend,
          maxTokens: 1024 // Maximum tokens for model responses.
          );
      print("Gemma model created.");

      // Create the chat session using the model instance.
      _chat = await model.createChat(
        temperature: widget.model.temperature, // Controls response randomness.
        randomSeed: 1, // Seed for reproducibility.
        topK: widget.model.topK, // Limits sampling to top K likely tokens.
        topP: widget.model.topP, // Uses nucleus sampling based on probability mass.
        tokenBuffer: 256, // Buffer size for token processing.
      );
      print("Gemma chat created successfully.");

      // Update the UI if the widget is still mounted.
      if (mounted) {
        setState(() {}); // Trigger rebuild to show the chat UI.
      }
    } catch (e) {
      // Handle any errors during initialization.
      print("Error initializing Gemma: $e");
      if (mounted) {
        setState(() {
          _initializationError = "Failed to initialize AI model. Error: $e";
          // Keep _modelReadyForInitialization true so the error is shown in the main UI area,
          // replacing the loading indicator or download widget.
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
          print("Local asset model selected. Skipping download check.");
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
          print("Model file found locally.");
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
          print("Model file not found. Starting download...");
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
        print("Download complete listener triggered.");
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
        print("Retry detected. Re-triggering download.");
        // Re-trigger the download.
        Future.microtask(() {
          downloadNotifier.downloadModel(widget.model.url, widget.model.filename);
        });
      }
    });

    // Determine the main content widget based on the current state.
    Widget bodyContent;
    if (!_modelReadyForInitialization &&
        (downloadState.status == DownloadStatus.downloading ||
            downloadState.status == DownloadStatus.error ||
            downloadState.status == DownloadStatus.notStarted)) {
      // Show download widget if model isn't ready and download is in progress, failed, or not started.
      bodyContent = const ModelDownloadWidget();
    } else if (_modelReadyForInitialization && _chat == null && _initializationError == null) {
      // Show loading indicator while initializing the model after download/check.
      bodyContent = const LoadingWidget(message: 'Initializing AI model...');
    } else if (_chat != null) {
      // Show the chat interface if the chat is initialized.
      bodyContent = Column(
        children: [
          // Display an error banner if initialization failed previously but chat is now available (e.g., after retry).
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
