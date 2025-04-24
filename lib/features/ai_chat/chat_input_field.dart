import 'package:flutter/material.dart';

/// A text input field for chat messages.
///
/// This widget provides a text field for users to type messages and a send button
/// to submit them.
class ChatInputField extends StatefulWidget {
  /// Callback function invoked when the user submits a message.
  final ValueChanged<String> handleSubmitted;

  /// Creates a [ChatInputField].
  ///
  /// The [handleSubmitted] parameter must not be null.
  const ChatInputField({super.key, required this.handleSubmitted});

  @override
  ChatInputFieldState createState() => ChatInputFieldState();
}

/// The state associated with a [ChatInputField].
class ChatInputFieldState extends State<ChatInputField> {
  /// Controller for the text input field.
  final TextEditingController _textController = TextEditingController();

  /// Handles the submission of the text input.
  ///
  /// Clears the text field after submitting the message.
  void _handleSubmitted(String text) {
    widget.handleSubmitted(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).hoverColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            IconButton(icon: const Icon(Icons.send), onPressed: () => _handleSubmitted(_textController.text)),
          ],
        ),
      ),
    );
  }
}
