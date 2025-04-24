import 'package:flutter/material.dart';

/// A widget that displays a loading indicator with an optional message and progress percentage.
class LoadingWidget extends StatelessWidget {
  /// The message to display below the loading indicator.
  final String message;

  /// The progress percentage to display (optional).
  final int? progress;

  /// Creates a [LoadingWidget].
  ///
  /// The [message] parameter is required.
  /// The [progress] parameter is optional.
  const LoadingWidget({required this.message, this.progress, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          // Align the content slightly below the center vertically.
          alignment: const Alignment(0, 1 / 3),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take up minimal vertical space.
            children: [
              // Display the circular progress indicator.
              const CircularProgressIndicator(),
              const SizedBox(height: 16), // Add vertical spacing.
              // Display the loading message.
              Text(message),
              // Conditionally display the progress percentage if available.
              if (progress != null) ...[
                const SizedBox(height: 8), // Add vertical spacing.
                Text('$progress%'), // Display the progress percentage.
              ],
            ],
          ),
        );
      },
    );
  }
}
