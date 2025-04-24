import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Represents the status of the model download process.
enum DownloadStatus {
  /// Download has not started yet.
  notStarted,
  /// Download is currently in progress.
  downloading,
  /// Download has completed successfully.
  completed,
  /// An error occurred during download.
  error
}

/// Represents the state of the model download, including status, progress, and error messages.
class ModelDownloadState {
  /// The current status of the download.
  final DownloadStatus status;
  /// The download progress, ranging from 0.0 to 1.0.
  final double progress;
  /// An optional error message if the download failed.
  final String? errorMessage;

  /// Creates a new instance of [ModelDownloadState].
  const ModelDownloadState({this.status = DownloadStatus.notStarted, this.progress = 0.0, this.errorMessage});

  /// Creates a copy of the current state with optional updated values.
  ///
  /// [status] The new download status.
  /// [progress] The new download progress.
  /// [errorMessage] The new error message.
  /// [clearError] If true, clears the existing error message.
  ModelDownloadState copyWith({DownloadStatus? status, double? progress, String? errorMessage, bool clearError = false}) {
    return ModelDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages the state and logic for downloading AI models.
class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  /// Creates a new instance of [ModelDownloadNotifier].
  ModelDownloadNotifier() : super(const ModelDownloadState());

  /// The Dio instance used for network requests.
  final Dio _dio = Dio();
  /// A token to cancel the ongoing download request.
  CancelToken? _cancelToken;

  /// Starts downloading the model from the given [url] and saves it as [filename].
  ///
  /// Checks if the file already exists before starting the download.
  /// Updates the state with progress and status changes.
  /// Handles potential errors during the download process.
  Future<void> downloadModel(String url, String filename) async {
    if (state.status == DownloadStatus.downloading) return; // Prevent multiple downloads
    _cancelToken = CancelToken();
    state = const ModelDownloadState(status: DownloadStatus.downloading, progress: 0.0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$filename';
      final file = File(savePath);
      if (await file.exists()) {
        print("Model file already exists at $savePath");
        state = state.copyWith(status: DownloadStatus.completed, progress: 1.0);
        return;
      }
      print("Starting download from $url to $savePath");
      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            // Check mounted before updating state - Notifier doesn't have mounted,
            // but check if notifier is still active if needed (less common)
            if (mounted) {
              // mounted is a property of StateNotifier
              state = state.copyWith(progress: progress);
            }
          }
        },
      );
      if (mounted) {
        state = state.copyWith(status: DownloadStatus.completed, progress: 1.0);
        print("Download completed.");
      }
    } on DioException catch (e) {
      print("Download error: $e");
      if (mounted) {
        if (CancelToken.isCancel(e)) {
          state = state.copyWith(status: DownloadStatus.notStarted, errorMessage: "Download cancelled.");
          print("Download cancelled.");
        } else {
          state = state.copyWith(status: DownloadStatus.error, errorMessage: "Download failed: ${e.message}");
        }
      }
      _cleanupFailedDownload(filename);
    } catch (e) {
      print("Generic download error: $e");
      if (mounted) {
        state = state.copyWith(status: DownloadStatus.error, errorMessage: "An unexpected error occurred: $e");
      }
      _cleanupFailedDownload(filename);
    } finally {
      _cancelToken = null;
    }
  }

  /// Cleans up partially downloaded files if an error occurs.
  ///
  /// [filename] The name of the file to potentially delete.
  Future<void> _cleanupFailedDownload(String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$filename';
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
        print("Deleted incomplete download file: $savePath");
      }
    } catch (e) {
      print("Error cleaning up failed download: $e");
    }
  }

  /// Cancels the ongoing download if there is one.
  void cancelDownload() {
    _cancelToken?.cancel("Download cancelled by user.");
  }

  /// Resets the download state to its initial values.
  void resetState() {
    if (mounted) {
      state = const ModelDownloadState();
    }
  }

  /// Cleans up resources when the notifier is disposed.
  ///
  /// Cancels any ongoing download.
  @override
  void dispose() {
    cancelDownload();
    super.dispose();
  }
}

/// Provides the [ModelDownloadNotifier] instance to the application.
final modelDownloadProvider = StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  return ModelDownloadNotifier();
});
