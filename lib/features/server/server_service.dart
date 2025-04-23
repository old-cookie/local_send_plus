import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Keep standard dart:io import
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/features/receive/received_file_provider.dart';
import 'package:local_send_plus/features/receive/received_text_provider.dart';
import 'package:local_send_plus/models/received_file_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_send_plus/features/server/server_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

const int _defaultPort = 2706;

class ServerService {
  final Ref _ref;
  HttpServer? _server;
  ServerService(this._ref, {int initialPort = _defaultPort});
  Future<void> startServer() async {
    if (_server != null) {
      print('Server already running on port ${_server!.port}');
      return;
    }
    try {
      final router = Router();
      router.get('/', (Request request) {
        return Response.ok('Hello from LocalSend Plus Server!');
      });
      router.get('/info', _handleInfoRequest);
      router.post('/receive', (Request request) => _handleReceiveRequest(request, _ref));
      router.post('/receive-text', (Request request) => _handleReceiveTextRequest(request, _ref));
      final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
      print('Starting HTTP server...');
      const int fixedPort = 2706;
      print('Starting HTTP server on fixed port $fixedPort...');
      int? actualPort; // Declare here, nullable
      if (!kIsWeb) {
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, fixedPort);
        print('HTTP Server started');
        actualPort = _server!.port; // Assign here
        print('Server listening on port $actualPort (HTTP only)');
        _ref.read(serverStateProvider.notifier).setRunning(actualPort);
      } else {
        print('Warning: Full HTTP server functionality is not available on the web platform.');
        _ref.read(serverStateProvider.notifier).setError('Server not supported on web');
        return;
      }
    } catch (e) {
      print('Error starting server: $e');
      _ref.read(serverStateProvider.notifier).setError(e.toString());
      await stopServer();
    }
  }

  Future<void> stopServer() async {
    if (_server == null) return;
    print('Stopping server...');
    await _server!.close(force: true);
    _server = null;
    _ref.read(serverStateProvider.notifier).setStopped();
    print('Server stopped.');
  }

  int? get runningPort => _server?.port;
  Future<Response> _handleInfoRequest(Request request) async {
    final deviceModel = kIsWeb ? 'web' : Platform.operatingSystem;
    final deviceInfo = {'alias': 'MyDevice', 'version': '1.0.0', 'deviceModel': deviceModel, 'https': false};
    return Response.ok(jsonEncode(deviceInfo), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _handleReceiveRequest(Request request, Ref ref) async {
    if (request.multipart() case var multipart?) {
      String? receivedFileName;
      String? finalFilePath;
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) {
          print('Error: Could not access downloads directory.');
          return Response.internalServerError(body: 'Could not access downloads directory.');
        }
        final targetDirectory = downloadsDir.path;
        print('Saving received files to: $targetDirectory');
        await for (final part in multipart.parts) {
          // Use multipart.parts stream
          final contentDisposition = part.headers['content-disposition'];
          final filenameRegExp = RegExp(r'filename="([^"]*)"');
          final match = filenameRegExp.firstMatch(contentDisposition ?? '');
          receivedFileName = match?.group(1);
          if (receivedFileName != null) {
            receivedFileName = receivedFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
            if (receivedFileName.isEmpty) {
              print('Skipping part with empty sanitized filename.');
              continue;
            }
            finalFilePath = '$targetDirectory${Platform.pathSeparator}$receivedFileName';
            final outputFile = File(finalFilePath);
            print('Receiving file: $receivedFileName to $finalFilePath');
            try {
              await outputFile.parent.create(recursive: true);
            } catch (dirError) {
              print('Error creating directory ${outputFile.parent.path}: $dirError');
              return Response.internalServerError(body: 'Could not create target directory.');
            }
            try {
              final fileSink = outputFile.openWrite();
              await part.pipe(fileSink);
            } catch (writeError) {
              print('Error writing file $finalFilePath: $writeError');
              try {
                if (await outputFile.exists()) await outputFile.delete();
              } catch (_) {}
              return Response.internalServerError(body: 'Error writing file.');
            }
            print('File received successfully: $receivedFileName');
            final fileInfo = ReceivedFileInfo(filename: receivedFileName, path: finalFilePath);
            ref.read(receivedFileProvider.notifier).setReceivedFile(fileInfo);
            break;
          } else {
            print('Skipping part with no filename in content-disposition header.');
          }
        }
        if (receivedFileName == null) {
          return Response.badRequest(body: 'No valid file part found in the request.');
        }
        return Response.ok('File "$receivedFileName" received successfully.');
      } catch (e) {
        print('Error processing multipart request: $e');
        if (finalFilePath != null) {
          try {
            final tempFile = File(finalFilePath);
            if (await tempFile.exists()) {
              await tempFile.delete();
              print('Cleaned up partially written file: $finalFilePath');
            }
          } catch (cleanupError) {
            print('Error cleaning up file $finalFilePath: $cleanupError');
          }
        }
        return Response.internalServerError(body: 'Error processing request: $e');
      }
    } else {
      return Response.badRequest(body: 'Expected a multipart/form-data request.');
    }
  }

  Future<Response> _handleReceiveTextRequest(Request request, Ref ref) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.startsWith('text/plain')) {
        print('Warning: Received text request with unexpected content type: $contentType');
      }
      final receivedText = await request.readAsString(utf8); // Read body as UTF-8 string
      if (receivedText.isEmpty) {
        print('Received empty text message.');
        return Response.badRequest(body: 'Received empty text.');
      }
      print('Received text: "$receivedText"');
      ref.read(receivedTextProvider.notifier).state = receivedText;
      return Response.ok('Text received successfully.');
    } catch (e) {
      print('Error processing text request: $e');
      return Response.internalServerError(body: 'Error processing text request: $e');
    }
  }
}

final serverServiceProvider = Provider.family<ServerService, int>((ref, initialPort) {
  return ServerService(ref, initialPort: initialPort);
});
