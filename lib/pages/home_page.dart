import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:camooz/main.dart';
import 'package:camooz/pages/preview_page.dart';
import 'package:camooz/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:blurrycontainer/blurrycontainer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  CameraImage? _cameraImage;
  bool _isCameraInitialized = false;
  List<DetectedObject> detectedObjects = [];
  double _currentZoomLevel = 1.0;
  bool startStream = false;
  List<DetectedObject>? objects;
  bool autoFocus = false;
  bool isDetectingObjects = false;
  int frame = 0;
  late AnimationController _animationControllerFocus;
  late Animation<double> _animationFocus;

  @override
  void initState() {
    initializeCamera(cameras[0]);
    _animationControllerFocus = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationFocus =
        Tween<double>(begin: 0, end: 1).animate(_animationControllerFocus);
    super.initState();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animationControllerFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initializeCamera(cameraController.description);
    }
  }

  Future<void> initializeCamera(CameraDescription cameraDescription) async {
    final previousCameraController = _cameraController;

    final CameraController controller = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await previousCameraController?.dispose();

    if (mounted) {
      setState(() => _cameraController = controller);
    }

    controller.addListener(() => mounted ? setState(() {}) : {});

    controller.initialize().then((_) {
      if (!mounted) return;

      setState(() => _isCameraInitialized = controller.value.isInitialized);

      controller.setExposureOffset(0);
    });
  }

  Future takePicture() async {
    if (!_cameraController!.value.isInitialized) {
      return null;
    }
    if (_cameraController!.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController!.setFlashMode(FlashMode.off);
      final rawImage = await _cameraController!.takePicture();

      _cameraController!.setZoomLevel(_currentZoomLevel = 1.0);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPage(picture: rawImage),
          ),
        );
      }
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
              children: [
                ClipRect(
                  clipper: _MediaSizeClipper(size),
                  child: Transform.scale(
                    alignment: Alignment.topCenter,
                    scale: 1 /
                        (_cameraController!.value.aspectRatio *
                            size.aspectRatio),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BlurryContainer(
                    height: size.height * 0.15,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    color: Colors.black.withOpacity(0.2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: takePicture,
                          child: Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                                border: Border.all(
                                  color: Colors.yellow,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _animationControllerFocus.reset();
                            _animationControllerFocus.forward();
                            if (!startStream) {
                              AppSnackbar.show(context, "Detecting Objects");
                            }
                            setState(() {
                              autoFocus = !autoFocus;
                              startStream = !startStream;
                              startImageStream();
                            });
                          },
                          icon: AnimatedBuilder(
                            animation: _animationFocus,
                            builder: (BuildContext context, Widget? child) {
                              return Transform.scale(
                                scale: _animationFocus.value * 0.1 + 1,
                                child: Icon(
                                  autoFocus && startStream
                                      ? Icons.center_focus_strong_rounded
                                      : Icons.center_focus_strong_outlined,
                                  color: autoFocus && startStream
                                      ? Colors.yellow
                                      : Colors.white,
                                ),
                              );
                            },
                          ),
                          iconSize: 32,
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  void startImageStream() {
    if (startStream) {
      _cameraController!.startImageStream((imageFromStream) {
        frame++;
        if (frame % 30 == 0 && startStream) {
          frame = 0;
          if (!isDetectingObjects) {
            isDetectingObjects = true;
            _cameraImage = imageFromStream;
            detectObjectOnCamera();
            isDetectingObjects = false;
          }
        } else if (!startStream) {
          _cameraController!.stopImageStream();
        }
      });
    } else {
      _cameraController!.stopImageStream();
    }
  }

  void zoomToDetectedObject(Rect boundingBox) async {
    double objectHeight = boundingBox.height;
    double objectWidth = boundingBox.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double minZoom = await _cameraController!.getMinZoomLevel();
    double maxZoom = await _cameraController!.getMaxZoomLevel();
    double currentZoom = _currentZoomLevel;

    double scaleY = objectHeight / screenHeight * screenWidth;
    double scaleX = objectWidth / screenWidth * screenHeight;

    double scale = max(scaleY, scaleX);
    scale = min(scale * 1.5, 2.0);

    double newZoom = scale * currentZoom + minZoom;

    if (currentZoom != newZoom) {
      if (newZoom > maxZoom && currentZoom == maxZoom) {
        AppSnackbar.show(context, "Max zoom reached");
      } else {
        final animationController = AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
        );
        final zoomTween = Tween<double>(
            begin: currentZoom, end: min(max(newZoom, minZoom), maxZoom));
        animationController.forward();
        animationController.addListener(() async {
          double newZoom = zoomTween.evaluate(animationController);
          await _cameraController!.setZoomLevel(newZoom);
          setState(() => _currentZoomLevel = newZoom);
          if (animationController.isCompleted) takePicture();
        });
      }
    }
  }

  void detectObjectOnCamera() async {
    final inputImage = InputImage.fromBytes(
      bytes: _concatenatePlanes(_cameraImage!.planes),
      inputImageData: InputImageData(
        planeData: _cameraImage!.planes.map(
          (Plane plane) {
            return InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width,
            );
          },
        ).toList(),
        inputImageFormat: InputImageFormat.yuv420,
        size: Size(
            _cameraImage!.width.toDouble(), _cameraImage!.height.toDouble()),
        imageRotation: InputImageRotation.rotation90deg,
      ),
    );
    final objectDetector = GoogleMlKit.vision.objectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );

    objects = await objectDetector.processImage(inputImage);

    if (objects!.isNotEmpty) {
      setState(() {
        detectedObjects = objects!;
        isDetectingObjects = false;
        final boundingBox = objects!.first.boundingBox;
        zoomToDetectedObject(boundingBox);
        startStream = false;
        autoFocus = false;
        objects;
      });
    } else {
      setState(() {
        isDetectingObjects = false;
        startStream = true;
        autoFocus = true;
        objects;
      });
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }
}

class _MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const _MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}
