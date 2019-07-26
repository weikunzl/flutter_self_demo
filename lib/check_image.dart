import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';

class CheckImage extends StatefulWidget {
  const CheckImage(this.model) : super();

  final String model;

  @override
  State<StatefulWidget> createState() => _CheckImageState(model);
}

class _CheckImageState extends State<CheckImage> {
  _CheckImageState(String model) {
    _model = model;
  }

  File _image;
  List<dynamic> _recognitions;
  double _imageHeight;
  double _imageWidth;
  bool _busy = false;
  String _model;

  @override
  void initState() {
    predictImagePicker();
    super.initState();
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    final Float32List convertedBytes =
        Float32List(1 * inputSize * inputSize * 3);
    final Float32List buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        final int pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Uint8List imageToByteListUint8(img.Image image, int inputSize) {
    final Uint8List convertedBytes = Uint8List(1 * inputSize * inputSize * 3);
    final Uint8List buffer = Uint8List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        final int pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel);
        buffer[pixelIndex++] = img.getGreen(pixel);
        buffer[pixelIndex++] = img.getBlue(pixel);
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Future<void> recognizeImage(File image) async {
    final List<dynamic> recognitions = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 6,
      threshold: 0.05,
      imageMean: 127.5,
      imageStd: 127.5,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  Future<void> recognizeImageBinary(File image) async {
    final ByteBuffer imageBytes = (await rootBundle.load(image.path)).buffer;
    final img.Image oriImage = img.decodeJpg(imageBytes.asUint8List());
    final img.Image resizedImage = img.copyResize(oriImage, 224, 224);
    final List<dynamic> recognitions = await Tflite.runModelOnBinary(
      binary: imageToByteListFloat32(resizedImage, 224, 127.5, 127.5),
      numResults: 6,
      threshold: 0.05,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  Future<void> yolov2Tiny(File image) async {
    final List<dynamic> recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      model: 'YOLO',
      threshold: 0.3,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );
    // var imageBytes = (await rootBundle.load(image.path)).buffer;
    // img.Image oriImage = img.decodeJpg(imageBytes.asUint8List());
    // img.Image resizedImage = img.copyResize(oriImage, 416, 416);
    // var recognitions = await Tflite.detectObjectOnBinary(
    //   binary: imageToByteListFloat32(resizedImage, 416, 0.0, 255.0),
    //   model: 'YOLO',
    //   threshold: 0.3,
    //   numResultsPerClass: 1,
    // );
    setState(() {
      _recognitions = recognitions;
    });
  }

  Future<void> ssdMobileNet(File image) async {
    final List<dynamic> recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
    );
    // var imageBytes = (await rootBundle.load(image.path)).buffer;
    // img.Image oriImage = img.decodeJpg(imageBytes.asUint8List());
    // img.Image resizedImage = img.copyResize(oriImage, 300, 300);
    // var recognitions = await Tflite.detectObjectOnBinary(
    //   binary: imageToByteListUint8(resizedImage, 300),
    //   numResultsPerClass: 1,
    // );
    setState(() {
      _recognitions = recognitions;
    });
  }

  Future<void> segmentMobileNet(File image) async {
    final List<dynamic> recognitions = await Tflite.runSegmentationOnImage(
      path: image.path,
      imageMean: 127.5,
      imageStd: 127.5,
    );

    setState(() {
      _recognitions = recognitions;
    });
  }

  Future<void> poseNet(File image) async {
    final List<dynamic> recognitions = await Tflite.runPoseNetOnImage(
      path: image.path,
      numResults: 2,
    );

    print(recognitions);

    setState(() {
      _recognitions = recognitions;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return <Widget>[];
    if (_imageHeight == null || _imageWidth == null) return <Widget>[];

    final double factorX = screen.width;
    final double factorY = _imageHeight / _imageWidth * screen.width;
    const Color blue = Color.fromRGBO(37, 213, 253, 1.0);
    return _recognitions.map((dynamic re) {
      return Positioned(
        left: re['rect']['x'] * factorX,
        top: re['rect']['y'] * factorY,
        width: re['rect']['w'] * factorX,
        height: re['rect']['h'] * factorY,
        child: Container(




          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(
              color: blue,
              width: 2,
            ),
          ),
          child: Text(
            '${re['detectedClass']} ${(re['confidenceInClass'] * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 12.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> renderKeypoints(Size screen) {
    if (_recognitions == null) return <Widget>[];
    if (_imageHeight == null || _imageWidth == null) return <Widget>[];

    final double factorX = screen.width;
    final double factorY = _imageHeight / _imageWidth * screen.width;

    final List<Widget> lists = <Widget>[];
    _recognitions.forEach((dynamic re) {
      final Color color = Color((Random().nextDouble() * 0xFFFFFF).toInt() << 0)
          .withOpacity(1.0);
      final List<Widget> list = re['keypoints'].values.map<Widget>((dynamic k) {
        return Positioned(
          left: k['x'] * factorX - 6,
          top: k['y'] * factorY - 6,
          width: 100,
          height: 12,
          child: Container(
            child: Text(
              '● ${k['part']}',
              style: TextStyle(
                color: color,
                fontSize: 12.0,
              ),
            ),
          ),
        );
      }).toList();

      lists..addAll(list);
    });

    return lists;
  }

  Future<void> predictImagePicker() async {
    final File image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _busy = true;
    });
    predictImage(image);
  }

  Future<void> predictImage(File image) async {
    if (image == null) return;

    switch (_model) {
      case yolo:
        await yolov2Tiny(image);
        break;
      case ssd:
        await ssdMobileNet(image);
        break;
      case posenet:
        await poseNet(image);
        break;
      default:
        await recognizeImage(image);
    }

    FileImage(image)
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool x) {
      setState(() {
        _imageHeight = info.image.height.toDouble();
        _imageWidth = info.image.width.toDouble();
      });
    }));
    setState(() {
      _image = image;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final List<Widget> stackChildren = <Widget>[];

    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
      child: _image == null
          ? const Text('No image selected.')
          : Image.file(_image, fit: BoxFit.fitWidth),
    ));

    if (_model == ssd || _model == yolo) {
      stackChildren.addAll(renderBoxes(size));
    } else if (_model == posenet) {
      stackChildren.addAll(renderKeypoints(size));
    }

    if (_busy) {
      stackChildren.add(const Opacity(
        child: ModalBarrier(dismissible: false, color: Colors.grey),
        opacity: 0.3,
      ));
      stackChildren.add(const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: stackChildren,
      ),
    );
  }
}
