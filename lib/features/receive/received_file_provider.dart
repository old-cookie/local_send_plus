import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/models/received_file_info.dart';

class ReceivedFileNotifier extends StateNotifier<ReceivedFileInfo?> {
  ReceivedFileNotifier() : super(null);
  void setReceivedFile(ReceivedFileInfo fileInfo) {
    state = fileInfo;
  }

  void clearReceivedFile() {
    state = null;
  }
}

final receivedFileProvider = StateNotifierProvider<ReceivedFileNotifier, ReceivedFileInfo?>((ref) {
  return ReceivedFileNotifier();
});
