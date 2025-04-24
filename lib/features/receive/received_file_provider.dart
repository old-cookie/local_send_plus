import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/models/received_file_info.dart';

/// Notifier for managing the state of the currently received file.
///
/// This notifier holds the information about the file being received,
/// allowing other parts of the application to react to changes in the
/// received file state.
class ReceivedFileNotifier extends StateNotifier<ReceivedFileInfo?> {
  /// Initializes the notifier with no received file (null state).
  ReceivedFileNotifier() : super(null);

  /// Sets the currently received file information.
  ///
  /// Updates the state with the provided [ReceivedFileInfo].
  /// This typically happens when a new file transfer begins.
  void setReceivedFile(ReceivedFileInfo fileInfo) {
    state = fileInfo;
  }

  /// Clears the received file information.
  ///
  /// Resets the state to null, indicating that no file is currently
  /// being received or the transfer has completed/cancelled.
  void clearReceivedFile() {
    state = null;
  }
}

/// Provider for accessing the [ReceivedFileNotifier].
///
/// This allows widgets and other providers to listen to or read the
/// current [ReceivedFileInfo] state.
final receivedFileProvider = StateNotifierProvider<ReceivedFileNotifier, ReceivedFileInfo?>((ref) {
  return ReceivedFileNotifier();
});
