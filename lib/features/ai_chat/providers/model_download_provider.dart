import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum DownloadStatus { notStarted, downloading, completed, error }

class ModelDownloadState {
  final DownloadStatus status;
  final double progress;
  final String? errorMessage;
  const ModelDownloadState({this.status = DownloadStatus.notStarted, this.progress = 0.0, this.errorMessage});
  ModelDownloadState copyWith({DownloadStatus? status, double? progress, String? errorMessage, bool clearError = false}) {
    return ModelDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  ModelDownloadNotifier() : super(const ModelDownloadState());
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
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

  void cancelDownload() {
    _cancelToken?.cancel("Download cancelled by user.");
  }

  void resetState() {
    if (mounted) {
      state = const ModelDownloadState();
    }
  }

  @override
  void dispose() {
    cancelDownload();
    super.dispose();
  }
}

final modelDownloadProvider = StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  return ModelDownloadNotifier();
});
