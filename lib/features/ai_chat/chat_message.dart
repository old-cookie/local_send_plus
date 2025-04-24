import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A widget that displays a single chat message.
///
/// It shows the message content and an avatar indicating whether the message
/// is from the user or the AI model.
class ChatMessageWidget extends StatelessWidget {
  /// Creates a chat message widget.
  ///
  /// The [message] parameter is required and contains the data for the message.
  const ChatMessageWidget({super.key, required this.message});

  /// The message data to display.
  final Message message;

  @override
  Widget build(BuildContext context) {
    // Determine the alignment based on whether the message is from the user.
    final alignment = message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start;
    // Determine the background color for the message bubble.
    final bubbleColor = const Color(0x80757575);
    // Determine the maximum width of the message bubble.
    final maxWidth = MediaQuery.of(context).size.width * 0.8;

    return Container(
      // Add vertical margin around the message.
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        // Align the message to the right for user messages, left for AI messages.
        mainAxisAlignment: alignment,
        children: <Widget>[
          // Show the AI avatar on the left if it's not a user message.
          if (!message.isUser) _buildAvatar(),
          // Add spacing between avatar and message bubble.
          const SizedBox(width: 10),
          // Flexible container for the message bubble.
          Expanded(
            child: Container(
              // Constrain the width of the bubble.
              constraints: BoxConstraints(maxWidth: maxWidth),
              // Add padding inside the bubble.
              padding: const EdgeInsets.all(10.0),
              // Style the bubble with background color and rounded corners.
              decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(8.0)),
              // Display the message text using Markdown, or a loading indicator if empty.
              child: message.text.isNotEmpty ? MarkdownBody(data: message.text) : const Center(child: CircularProgressIndicator()),
            ),
          ),
          // Add spacing between message bubble and avatar.
          const SizedBox(width: 10),
          // Show the user avatar on the right if it's a user message.
          if (message.isUser) _buildAvatar(),
        ],
      ),
    );
  }

  /// Builds the avatar widget for the message sender.
  Widget _buildAvatar() {
    // Display a person icon for the user.
    if (message.isUser) {
      return const Icon(Icons.person);
    } else {
      // Display the Gemma logo for the AI model.
      // Use a fallback computer icon if the asset fails to load.
      return CircleAvatar(
        backgroundColor: Colors.blueGrey,
        child: Image.asset(
          'assets/gemma.png',
          errorBuilder: (context, error, stackTrace) {
            // Fallback icon in case of loading error.
            return const Icon(Icons.computer, color: Colors.white);
          },
        ),
      );
    }
  }
}
