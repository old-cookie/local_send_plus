import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/model_download_provider.dart';

/// A widget that displays the progress of downloading the AI model
/// and allows the user to retry or cancel the download.
class ModelDownloadWidget extends ConsumerWidget {
  /// Creates a [ModelDownloadWidget].
  const ModelDownloadWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(modelDownloadProvider);
    final downloadNotifier = ref.read(modelDownloadProvider.notifier);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIndicator(context, downloadState, downloadNotifier),
            const SizedBox(height: 16),
            if (downloadState.status == DownloadStatus.downloading) LinearProgressIndicator(value: downloadState.progress),
            if (downloadState.status == DownloadStatus.error || downloadState.status == DownloadStatus.notStarted)
              const SizedBox(height: 16), // Add space before buttons
            if (downloadState.status == DownloadStatus.error)
              ElevatedButton(
                onPressed: () {
                  downloadNotifier.resetState();
                },
                child: const Text('Retry Download'),
              ),
            if (downloadState.status == DownloadStatus.downloading) const SizedBox(height: 16),
            if (downloadState.status == DownloadStatus.downloading)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  downloadNotifier.cancelDownload();
                },
                child: const Text('Cancel Download', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the appropriate status indicator based on the current [DownloadStatus].
  ///
  /// This includes displaying progress, success messages, error messages,
  /// and providing context-specific actions like retrying a failed download.
  Widget _buildStatusIndicator(BuildContext context, ModelDownloadState state, ModelDownloadNotifier notifier) {
    switch (state.status) {
      case DownloadStatus.notStarted:
        return const Text('Preparing to download model...', textAlign: TextAlign.center);
      case DownloadStatus.downloading:
        final progressPercent = (state.progress * 100).toStringAsFixed(1);
        return Text('Downloading model... ($progressPercent%)', textAlign: TextAlign.center);
      case DownloadStatus.completed:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 40),
            SizedBox(height: 8),
            Text('Model download complete!', textAlign: TextAlign.center),
          ],
        );
      case DownloadStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              'Download Failed: ${state.errorMessage ?? "Unknown error"}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}
