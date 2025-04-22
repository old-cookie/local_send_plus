import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'chat_message.dart';
import 'services/gemma_service.dart';

class GemmaInputField extends StatefulWidget {
  const GemmaInputField({super.key, required this.messages, required this.streamHandler, required this.errorHandler, this.chat});
  final InferenceChat? chat;
  final List<Message> messages;
  final ValueChanged<Message> streamHandler;
  final ValueChanged<String> errorHandler;
  @override
  GemmaInputFieldState createState() => GemmaInputFieldState();
}

class GemmaInputFieldState extends State<GemmaInputField> {
  GemmaLocalService? _gemma;
  StreamSubscription<String?>? _subscription;
  var _message = const Message(text: '');
  @override
  void initState() {
    super.initState();
    if (widget.chat != null) {
      _gemma = GemmaLocalService(widget.chat!);
      _processMessages();
    } else {
      widget.errorHandler("Chat service not available.");
      setState(() {
        _message = const Message(text: 'Error: Chat not initialized.');
      });
    }
  }

  void _processMessages() {
    if (_gemma == null) return;
    _subscription = _gemma
        ?.processMessageAsync(widget.messages.last)
        .listen(
          (String token) {
            if (!mounted) return;
            setState(() {
              _message = Message(text: '${_message.text}$token');
            });
          },
          onDone: () {
            if (!mounted) return;
            if (_message.text.isEmpty) {
              _message = const Message(text: '...');
            }
            widget.streamHandler(_message);
            _subscription?.cancel();
          },
          onError: (error) {
            print('Error processing message: $error');
            if (!mounted) return;
            if (_message.text.isEmpty) {
              _message = const Message(text: 'Error processing message.');
            }
            widget.streamHandler(_message);
            widget.errorHandler(error.toString());
            _subscription?.cancel();
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: ChatMessageWidget(message: _message));
  }
}
