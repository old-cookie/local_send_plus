/// Represents information about a file that has been received.
/// 
/// Contains essential details about the received file including its name and storage location.
class ReceivedFileInfo {
  /// The name of the received file, including its extension.
  final String filename;

  /// The absolute path where the file is stored on the device.
  final String path;

  /// Creates a new [ReceivedFileInfo] instance.
  /// 
  /// [filename] The name of the received file.
  /// [path] The storage location of the file.
  ReceivedFileInfo({required this.filename, required this.path});
}
