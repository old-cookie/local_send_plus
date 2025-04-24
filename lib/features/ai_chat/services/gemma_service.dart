import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Service class for interacting with a local Gemma model via the flutter_gemma package.
///
/// This class encapsulates the logic for sending messages to the Gemma model
/// and processing the responses.
class GemmaLocalService {
  /// The underlying chat instance used for communication with the Gemma model.
  final InferenceChat _chat;

  /// Creates an instance of [GemmaLocalService].
  ///
  /// Requires an [InferenceChat] instance to be provided.
  GemmaLocalService(this._chat);

  /// Adds a message chunk to the current chat query without waiting for a response.
  ///
  /// This is useful for sending parts of a larger message or context.
  Future<void> addQueryChunk(Message message) => _chat.addQueryChunk(message);

  /// Processes a complete message asynchronously and returns a stream of response chunks.
  ///
  /// First, it adds the [message] to the query using [addQueryChunk].
  /// Then, it generates the chat response as a stream of strings.
  Stream<String> processMessageAsync(Message message) async* {
    await _chat.addQueryChunk(message);
    yield* _chat.generateChatResponseAsync();
  }
}
