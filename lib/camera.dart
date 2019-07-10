import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';

import 'bndbox.dart';
import 'models.dart';

typedef Callback = void Function(List<dynamic> list, int h, int w);

class Camera extends StatefulWidget {
  const Camera(this.cameras, this.model);

  final List<CameraDescription> cameras;
  final String model;

  @override
  _CameraState createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  CameraController controller;
  bool isDetecting = false;
  bool leaveCamera = false;

  List<dynamic> _recognitions;
  int _imageHeight = 0;
  int _imageWidth = 0;

  @override
  void initState() {
    super.initState();
    initController();
  }

  @override
  void deactivate() {
    super.deactivate();
    leaveCamera = !leaveCamera;
    if (!leaveCamera) {
      initController();
    } else {
      controller?.dispose();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void initController() {
    if (widget.cameras == null || widget.cameras.isEmpty) {
      print('No camera is found');
    } else {
      controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
      );
    }
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((CameraImage img) {
        if (!isDetecting) {
          isDetecting = true;

          final int startTime = DateTime.now().millisecondsSinceEpoch;

          if (widget.model == mobilenet) {
            Tflite.runModelOnFrame(
              bytesList: img.planes.map((Plane plane) {
                return plane.bytes;
              }).toList(),
              imageHeight: img.height,
              imageWidth: img.width,
              numResults: 2,
            ).then((List<dynamic> recognitions) {
              final int endTime = DateTime.now().millisecondsSinceEpoch;
              print('Detection took ${endTime - startTime}');
              setState(() {
                _recognitions = recognitions;
                _imageHeight = img.height;
                _imageWidth = img.width;
              });

              isDetecting = false;
            });
          } else if (widget.model == posenet) {
            Tflite.runPoseNetOnFrame(
              bytesList: img.planes.map((Plane plane) {
                return plane.bytes;
              }).toList(),
              imageHeight: img.height,
              imageWidth: img.width,
              numResults: 2,
            ).then((List<dynamic> recognitions) {
              final int endTime = DateTime.now().millisecondsSinceEpoch;
              print('Detection took ${endTime - startTime}');
              setState(() {
                _recognitions = recognitions;
                _imageHeight = img.height;
                _imageWidth = img.width;
              });

              isDetecting = false;
            });
          } else {
            Tflite.detectObjectOnFrame(
              bytesList: img.planes.map((Plane plane) {
                return plane.bytes;
              }).toList(),
              model: widget.model == yolo ? 'YOLO' : 'SSDMobileNet',
              imageHeight: img.height,
              imageWidth: img.width,
              imageMean: widget.model == yolo ? 0 : 127.5,
              imageStd: widget.model == yolo ? 255.0 : 127.5,
              numResultsPerClass: 1,
              threshold: widget.model == yolo ? 0.2 : 0.4,
            ).then((List<dynamic> recognitions) {
              final int endTime = DateTime.now().millisecondsSinceEpoch;
              print('Detection took ${endTime - startTime}');

              setState(() {
                _recognitions = recognitions;
                _imageHeight = img.height;
                _imageWidth = img.width;
              });

              isDetecting = false;
            });
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    Size screen = MediaQuery.of(context).size;
    final double screenH = math.max(screen.height, screen.width);
    final double screenW = math.min(screen.height, screen.width);
    screen = controller.value.previewSize;
    final double previewH = math.max(screen.height, screen.width);
    final double previewW = math.min(screen.height, screen.width);
    final double screenRatio = screenH / screenW;
    final double previewRatio = previewH / previewW;

    final double maxHeight =
        screenRatio > previewRatio ? screenH : screenW / previewW * previewH;
    final double maxWidth =
        screenRatio > previewRatio ? screenH / previewH * previewW : screenW;
    return Stack(
      children: <Widget>[
        OverflowBox(
          maxHeight: maxHeight,
          maxWidth: maxWidth,
          child: CameraPreview(controller),
        ),
        BndBox(
            _recognitions ?? <dynamic>[],
            math.max(_imageHeight, _imageWidth),
            math.min(_imageHeight, _imageWidth),
            screen.height,
            screen.width,
            widget.model)
      ],
    );
  }
}
