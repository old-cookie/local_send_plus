import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'crop_page.dart';

typedef ExportConfig = FFmpegVideoEditorExecute;

class VideoEditorScreen extends StatefulWidget {
  final File file;
  const VideoEditorScreen({super.key, required this.file});
  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isGeneratingConfig = ValueNotifier<bool>(false);
  final double height = 60;
  late final VideoEditorController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(widget.file, minDuration: const Duration(seconds: 1), maxDuration: const Duration(seconds: 30));
    _controller.initialize(aspectRatio: 9 / 16).then((_) => setState(() {})).catchError((error) {
      if (mounted) {
        Navigator.pop(context, null);
        _showErrorSnackBar("Error initializing video editor: $error");
      }
    }, test: (e) => e is VideoMinDurationError);
  }

  @override
  void dispose() {
    _exportingProgress.dispose();
    _isGeneratingConfig.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
    }
  }

  Future<ExportConfig?> _getVideoExportConfig() async {
    if (!_controller.initialized) {
      _showErrorSnackBar("Editor not initialized.");
      return null;
    }
    _isGeneratingConfig.value = true;
    final config = VideoFFmpegVideoEditorConfig(_controller);

    try {
      final executeConfig = await config.getExecuteConfig();
      return executeConfig;
    } catch (e) {
      _showErrorSnackBar("Error creating video export configuration: $e");
      return null;
    } finally {
      if (mounted) {
        _isGeneratingConfig.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body:
            !_controller.initialized
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _topNavBar(),
                          Expanded(
                            child: DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: TabBarView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CropGridViewer.preview(controller: _controller),
                                            AnimatedBuilder(
                                              animation: _controller.video,
                                              builder:
                                                  (_, __) => AnimatedOpacity(
                                                    opacity: _controller.isPlaying ? 0 : 1,
                                                    duration: kThemeAnimationDuration,
                                                    child: GestureDetector(
                                                      onTap: _controller.video.play,
                                                      child: Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                                        child: const Icon(Icons.play_arrow, color: Colors.black),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                        CoverViewer(controller: _controller),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 200,
                                    margin: const EdgeInsets.only(top: 10),
                                    child: Column(
                                      children: [
                                        TabBar(
                                          indicatorColor: Colors.white,
                                          tabs: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [Padding(padding: EdgeInsets.all(5), child: Icon(Icons.content_cut)), Text('Trim')],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [Padding(padding: EdgeInsets.all(5), child: Icon(Icons.video_label)), Text('Cover')],
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: TabBarView(
                                            physics: const NeverScrollableScrollPhysics(),
                                            children: [
                                              Column(mainAxisAlignment: MainAxisAlignment.center, children: _trimSlider()),
                                              _coverSelection(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      ValueListenableBuilder(
                        valueListenable: _isGeneratingConfig,
                        builder:
                            (_, bool generating, __) =>
                                generating
                                    ? Container(
                                      color: Colors.black.withOpacity(0.7),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 10),
                                            Text("Preparing export...", style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _topNavBar() {
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: IconButton(onPressed: () => Navigator.pop(context, null), icon: const Icon(Icons.close), tooltip: 'Discard changes and exit'),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: IconButton(
                onPressed: () => _controller.rotate90Degrees(RotateDirection.left),
                icon: const Icon(Icons.rotate_left),
                tooltip: 'Rotate counter-clockwise',
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () => _controller.rotate90Degrees(RotateDirection.right),
                icon: const Icon(Icons.rotate_right),
                tooltip: 'Rotate clockwise',
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute<void>(builder: (context) => CropPage(controller: _controller)));
                },
                icon: const Icon(Icons.crop),
                tooltip: 'Crop video',
              ),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: IconButton(
                onPressed: () async {
                  final config = await _getVideoExportConfig();
                  if (config != null && mounted) {
                    Navigator.pop(context, config);
                  }
                },
                icon: const Icon(Icons.check),
                tooltip: 'Confirm and prepare export',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatter(Duration duration) =>
      [duration.inMinutes.remainder(60).toString().padLeft(2, '0'), duration.inSeconds.remainder(60).toString().padLeft(2, '0')].join(":");
  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([_controller, _controller.video]),
        builder: (_, __) {
          final pos = _controller.videoPosition.inSeconds;
          final start = _controller.startTrim.inSeconds;
          final end = _controller.endTrim.inSeconds;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: height / 4),
            child: Row(
              children: [
                Text(formatter(Duration(seconds: pos))),
                const Expanded(child: SizedBox()),
                AnimatedOpacity(
                  opacity: _controller.isTrimming ? 1 : 0,
                  duration: kThemeAnimationDuration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(formatter(Duration(seconds: start))), const SizedBox(width: 10), Text(formatter(Duration(seconds: end)))],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(vertical: height / 4),
        child: TrimSlider(
          controller: _controller,
          height: height,
          horizontalMargin: height / 4,
          child: TrimTimeline(controller: _controller, padding: const EdgeInsets.only(top: 10)),
        ),
      ),
    ];
  }

  Widget _coverSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CoverSelection(
            controller: _controller,
            size: height + 10,
            quantity: 8,
            selectedCoverBuilder: (cover, size) {
              return Stack(
                alignment: Alignment.center,
                children: [cover, Icon(Icons.check_circle, color: Colors.white.withOpacity(0.7), size: size.width / 2)],
              );
            },
          ),
        ],
      ),
    );
  }
}
