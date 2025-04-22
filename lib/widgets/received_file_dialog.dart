import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:local_send_plus/features/receive/received_file_provider.dart';
import 'package:local_send_plus/models/received_file_info.dart';
import 'package:mime/mime.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';

class ReceivedFileDialog extends ConsumerStatefulWidget {
  final ReceivedFileInfo fileInfo;
  const ReceivedFileDialog({super.key, required this.fileInfo});
  @override
  ConsumerState<ReceivedFileDialog> createState() => _ReceivedFileDialogState();
}

class _ReceivedFileDialogState extends ConsumerState<ReceivedFileDialog> {
  bool _isLoadingThumbnail = true;
  String? _mimeType;
  Uint8List? _thumbnailData;
  @override
  void initState() {
    super.initState();
    _mimeType = lookupMimeType(widget.fileInfo.path);
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    setState(() {
      _isLoadingThumbnail = true;
    });
    Uint8List? data;
    try {
      if (_mimeType?.startsWith('image/') ?? false) {
        final fileBytes = await File(widget.fileInfo.path).readAsBytes();
        data = await _decodeAndResizeImage(fileBytes);
        print('Image thumbnail generated for ${widget.fileInfo.filename}');
      } else if (_mimeType?.startsWith('video/') ?? false) {
        data = await FlutterVideoThumbnailPlus.thumbnailData(video: widget.fileInfo.path, imageFormat: ImageFormat.jpeg, maxWidth: 100, quality: 75);
        print('Video thumbnail generated for ${widget.fileInfo.filename}');
      } else {
        print('Thumbnail generation not supported for MIME type: $_mimeType');
      }
    } catch (e) {
      print('Error generating thumbnail for ${widget.fileInfo.filename}: $e');
      data = null;
    } finally {
      if (mounted) {
        setState(() {
          _thumbnailData = data;
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  static Future<Uint8List?> _decodeAndResizeImage(Uint8List fileBytes) async {
    img.Image? image = img.decodeImage(fileBytes);
    if (image != null) {
      img.Image thumbnail = img.copyResize(image, width: 100);
      return img.encodeJpg(thumbnail, quality: 85);
    }
    return null;
  }

  Future<void> _deleteFile(BuildContext context) async {
    try {
      final file = File(widget.fileInfo.path);
      if (await file.exists()) {
        await file.delete();
        print('File deleted: ${widget.fileInfo.path}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File "${widget.fileInfo.filename}" deleted.')));
        }
      } else {
        print('File not found for deletion: ${widget.fileInfo.path}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File "${widget.fileInfo.filename}" not found.')));
        }
      }
    } catch (e) {
      print('Error deleting file ${widget.fileInfo.path}: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
      }
    } finally {
      ref.read(receivedFileProvider.notifier).clearReceivedFile();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _keepFile(BuildContext context) async {
    String message = 'File "${widget.fileInfo.filename}" kept in Downloads.';
    bool deleteOriginal = false;
    try {
      print('Keep action: Detected MIME type: $_mimeType for ${widget.fileInfo.filename}');
      if (_mimeType != null && (_mimeType!.startsWith('image/') || _mimeType!.startsWith('video/'))) {
        print('Attempting to save ${widget.fileInfo.filename} to gallery...');
        final result = await ImageGallerySaverPlus.saveFile(widget.fileInfo.path);
        print('Gallery save result: $result');
        if (result != null && result['isSuccess'] == true) {
          message = '${_mimeType!.startsWith('image/') ? 'Photo' : 'Video'} "${widget.fileInfo.filename}" saved to gallery.';
          deleteOriginal = true;
        } else {
          message = 'Failed to save "${widget.fileInfo.filename}" to gallery. Kept in Downloads.';
          print('Gallery save failed or returned unexpected result: $result');
        }
      } else {
        print('File type ($_mimeType) is not an image or video. Keeping in Downloads.');
      }
      if (deleteOriginal) {
        try {
          final originalFile = File(widget.fileInfo.path);
          if (await originalFile.exists()) {
            await originalFile.delete();
            print('Deleted original file from Downloads: ${widget.fileInfo.path}');
          }
        } catch (e) {
          print('Error deleting original file ${widget.fileInfo.path} after saving to gallery: $e');
        }
      }
    } catch (e) {
      print('Error during keep/save operation for ${widget.fileInfo.path}: $e');
      message = 'Error processing file: $e. Kept in Downloads.';
    } finally {
      ref.read(receivedFileProvider.notifier).clearReceivedFile();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('File Received'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 100,
            width: 100,
            child:
                _isLoadingThumbnail
                    ? const Center(child: CircularProgressIndicator())
                    : _thumbnailData != null
                    ? Image.memory(
                      _thumbnailData!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error_outline, size: 50, color: Colors.red)),
                    )
                    : const Center(child: Icon(Icons.insert_drive_file, size: 50, color: Colors.grey)),
          ),
          const SizedBox(height: 16),
          Text('Received file: "${widget.fileInfo.filename}".\nKeep it or delete it?', textAlign: TextAlign.center),
        ],
      ),
      actions: <Widget>[
        TextButton(child: const Text('Delete'), onPressed: () => _deleteFile(context)),
        TextButton(child: const Text('Keep'), onPressed: () => _keepFile(context)),
      ],
    );
  }
}
