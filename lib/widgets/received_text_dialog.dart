import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' show PreviewData;

class ReceivedTextDialog extends StatefulWidget {
  final String receivedText;
  const ReceivedTextDialog({super.key, required this.receivedText});
  @override
  State<ReceivedTextDialog> createState() => _ReceivedTextDialogState();
}

class _ReceivedTextDialogState extends State<ReceivedTextDialog> {
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
