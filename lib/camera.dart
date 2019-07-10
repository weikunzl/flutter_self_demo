import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as math;

import 'bndbox.dart';
import 'models.dart';

typedef void Callback(List<dynamic> list, int h, int w);

class Camera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String model;

  Camera(this.cameras, this.model);

  @override
  _CameraState createState() => new _CameraState();
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

  initController() {
    if (widget.cameras == null || widget.cameras.length < 1) {
      print('No camera is found');
    } else {
      controller = new CameraController(
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

          int startTime = new DateTime.now().millisecondsSinceEpoch;

          if (widget.model == mobilenet) {
            Tflite.runModelOnFrame(
              bytesList: img.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              imageHeight: img.height,
              imageWidth: img.width,
              numResults: 2,
            ).then((recognitions) {
              int endTime = new DateTime.now().millisecondsSinceEpoch;
              print("Detection took ${endTime - startTime}");
              setState(() {
                _recognitions = recognitions;
                _imageHeight = img.height;
                _imageWidth = img.width;
              });

              isDetecting = false;
            });
          } else if (widget.model == posenet) {
            Tflite.runPoseNetOnFrame(
              bytesList: img.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              imageHeight: img.height,
              imageWidth: img.width,
              numResults: 2,
            ).then((recognitions) {
              int endTime = new DateTime.now().millisecondsSinceEpoch;
              print("Detection took ${endTime - startTime}");
              setState(() {
                _recognitions = recognitions;
                _imageHeight = img.height;
                _imageWidth = img.width;
              });

              isDetecting = false;
            });
          } else {
            Tflite.detectObjectOnFrame(
              bytesList: img.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              model: widget.model == yolo ? "YOLO" : "SSDMobileNet",
              imageHeight: img.height,
              imageWidth: img.width,
              imageMean: widget.model == yolo ? 0 : 127.5,
              imageStd: widget.model == yolo ? 255.0 : 127.5,
              numResultsPerClass: 1,
              threshold: widget.model == yolo ? 0.2 : 0.4,
            ).then((recognitions) {
              int endTime = new DateTime.now().millisecondsSinceEpoch;
              print("Detection took ${endTime - startTime}");

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

    var screen = MediaQuery.of(context).size;
    var screenH = math.max(screen.height, screen.width);
    var screenW = math.min(screen.height, screen.width);
    screen = controller.value.previewSize;
    var previewH = math.max(screen.height, screen.width);
    var previewW = math.min(screen.height, screen.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return Stack(
      children: [
        OverflowBox(
          maxHeight:
          screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
          maxWidth:
          screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
          child: CameraPreview(controller),
        ),
        BndBox(
            _recognitions == null ? [] : _recognitions,
            math.max(_imageHeight, _imageWidth),
            math.min(_imageHeight, _imageWidth),
            screen.height,
            screen.width,
            widget.model),
      ],
    );
  }
}
