import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' show PreviewData;

/// A dialog widget that displays received text content with link preview functionality.
/// This widget allows users to view the received text and copy it to the clipboard.
class ReceivedTextDialog extends StatefulWidget {
  /// The text content that was received and will be displayed in the dialog.
  final String receivedText;

  /// Creates a [ReceivedTextDialog] with the specified received text.
  /// 
  /// Parameters:
  /// - [receivedText]: The text content to be displayed in the dialog.
  /// - [key]: An optional key to uniquely identify this widget.
  const ReceivedTextDialog({super.key, required this.receivedText});

  @override
  State<ReceivedTextDialog> createState() => _ReceivedTextDialogState();
}

/// The state for the [ReceivedTextDialog] widget.
/// Handles the preview data state and builds the dialog UI.
class _ReceivedTextDialogState extends State<ReceivedTextDialog> {
  /// Stores the preview data for any links found in the received text.
  PreviewData? _previewData;

  @override
  Widget build(BuildContext context) {
    final previewWidth = MediaQuery.of(context).size.width * 0.7;
    return AlertDialog(
      title: const Text('Text Received'),
      content: SingleChildScrollView(
        child: LinkPreview(
          enableAnimation: true,
          onPreviewDataFetched: (data) {
            if (mounted) {
              setState(() {
                _previewData = data;
              });
            }
          },
          previewData: _previewData,
          text: widget.receivedText,
          width: previewWidth,
          padding: const EdgeInsets.all(8),
          textStyle: Theme.of(context).textTheme.bodyMedium,
          metadataTextStyle: Theme.of(context).textTheme.bodySmall,
          metadataTitleStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Copy to Clipboard'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.receivedText))
                .then((_) {
                  // Optionally show a confirmation message
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text copied to clipboard!')));
                  Navigator.of(context).pop();
                })
                .catchError((error) {
                  print('Error copying text to clipboard: $error');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error copying text.')));
                });
          },
        ),
      ],
    );
  }
}
