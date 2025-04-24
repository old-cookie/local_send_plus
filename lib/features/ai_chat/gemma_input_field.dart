import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'chat_message.dart';
import 'services/gemma_service.dart';

/// A StatefulWidget that displays the Gemma model's response as it streams in.
///
/// This widget takes the user's messages, sends the latest one to the Gemma
/// service, and displays the response token by token as it arrives.
class GemmaInputField extends StatefulWidget {
  /// Creates a [GemmaInputField].
  ///
  /// Requires [messages] containing the chat history, a [streamHandler] to
  /// process incoming response tokens, an [errorHandler] for error reporting,
  /// and an optional [chat] instance for the Gemma service.
  const GemmaInputField({super.key, required this.messages, required this.streamHandler, required this.errorHandler, this.chat});

  /// The chat instance used for interacting with the Gemma model.
  final InferenceChat? chat;

  /// The list of messages in the current chat session. The last message is
  /// sent to the Gemma model.
  final List<Message> messages;

  /// A callback function that is called with each new [Message] fragment
  /// received from the Gemma model stream.
  final ValueChanged<Message> streamHandler;

  /// A callback function that is called when an error occurs during the
  /// streaming process.
  final ValueChanged<String> errorHandler;
  @override
  GemmaInputFieldState createState() => GemmaInputFieldState();
}

/// The state for the [GemmaInputField] widget.
///
/// Manages the interaction with the [GemmaLocalService] and updates the UI
/// as new message tokens are received.
class GemmaInputFieldState extends State<GemmaInputField> {
  /// The local service instance for interacting with the Gemma model.
  GemmaLocalService? _gemma;

  /// The subscription to the stream of response tokens from the Gemma model.
  StreamSubscription<String?>? _subscription;

  /// The message currently being streamed from the Gemma model.
  var _message = const Message(text: '');

  @override
  void initState() {
    super.initState();
    // Initialize the Gemma service if a chat instance is provided.
    if (widget.chat != null) {
      _gemma = GemmaLocalService(widget.chat!);
      // Start processing the latest message.
      _processMessages();
    } else {
      // Handle the case where the chat service is not available.
      widget.errorHandler("Chat service not available.");
      setState(() {
        _message = const Message(text: 'Error: Chat not initialized.');
      });
    }
  }

  /// Processes the last message in the [widget.messages] list using the
  /// Gemma service and updates the UI with the streamed response.
  void _processMessages() {
    if (_gemma == null) return; // Do nothing if Gemma service is not initialized.
    // Subscribe to the stream of response tokens.
    _subscription = _gemma
        ?.processMessageAsync(widget.messages.last)
        .listen(
          (String token) {
            // Ensure the widget is still mounted before updating the state.
            if (!mounted) return;
            // Append the new token to the current message text.
            setState(() {
              _message = Message(text: '${_message.text}$token');
            });
          },
          onDone: () {
            // Ensure the widget is still mounted.
            if (!mounted) return;
            // If the message is empty after streaming (e.g., error or empty response),
            // display an ellipsis.
            if (_message.text.isEmpty) {
              _message = const Message(text: '...');
            }
            // Pass the complete message to the stream handler.
            widget.streamHandler(_message);
            // Cancel the subscription as the stream is complete.
            _subscription?.cancel();
          },
          onError: (error) {
            print('Error processing message: $error');
            // Ensure the widget is still mounted.
            if (!mounted) return;
            // If the message is empty, set an error message.
            if (_message.text.isEmpty) {
              _message = const Message(text: 'Error processing message.');
            }
            // Pass the potentially partial message (or error message) to the handler.
            widget.streamHandler(_message);
            // Report the error via the error handler callback.
            widget.errorHandler(error.toString());
            // Cancel the subscription due to the error.
            _subscription?.cancel();
          },
        );
  }

  @override
  void dispose() {
    // Cancel the stream subscription when the widget is disposed to prevent memory leaks.
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Display the currently streamed message using ChatMessageWidget.
    // Wrap in SingleChildScrollView in case the message becomes long.
    return SingleChildScrollView(child: ChatMessageWidget(message: _message));
  }
}
