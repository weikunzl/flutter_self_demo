import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_realtime_detection/check_image.dart';
import 'package:tflite/tflite.dart';

import 'camera.dart';
import 'models.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage(this.cameras);

  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _model = "";

  @override
  void initState() {
    super.initState();
  }

  loadModel() async {
    String res;
    switch (_model) {
      case yolo:
        res = await Tflite.loadModel(
          model: "assets/yolov2_tiny.tflite",
          labels: "assets/yolov2_tiny.txt",
        );
        break;

      case mobilenet:
        res = await Tflite.loadModel(
            model: "assets/mobilenet_v1_1.0_224.tflite",
            labels: "assets/mobilenet_v1_1.0_224.txt");
        break;

      case posenet:
        res = await Tflite.loadModel(
            model: "assets/posenet_mv1_075_float_from_checkpoints.tflite");
        break;

      default:
        res = await Tflite.loadModel(
            model: "assets/ssd_mobilenet.tflite",
            labels: "assets/ssd_mobilenet.txt");
    }
    print(res);
  }

  onSelect(model) {
    setState(() {
      _model = model;
    });

    loadModel();
  }

  onClickAction(page) {
    if (page == "test_image") {
      Navigator.push(context,
          MaterialPageRoute<void>(builder: (BuildContext context) {
        return Scaffold(
          // Add 6 lines from here...
          appBar: AppBar(
            title: Text('Saved Suggestions'),
          ),
          body: CheckImage(_model),
        );
      }));
    } else if (page == "about")  {
      Navigator.push(context,
          MaterialPageRoute<void>(
              builder: (BuildContext context) {
            return Scaffold(
              // Add 6 lines from here...
              appBar: AppBar(
                title: Text('About Us'),
              ),
              body: Center(
                child: Text("xxxxxxx"),
              ),
            );
          }));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图像识别页面'),
        actions: _model == ""
            ? null
            : <Widget>[
                PopupMenuButton<String>(
                  onSelected: onClickAction,
                  itemBuilder: (context) {
                    List<PopupMenuEntry<String>> menuEntries = [
                      const PopupMenuItem<String>(
                        child: Text("采集结果"),
                        value: "catch_image",
                      ),
                      const PopupMenuItem<String>(
                        child: Text("图片测试"),
                        value: "test_image",
                      ),
                      const PopupMenuItem<String>(
                        child: Text("关于"),
                        value: "about",
                      )
                    ];
                    return menuEntries;
                  },
                )
              ],
      ),
      body: _model == ""
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RaisedButton(
                    child: const Text(ssd),
                    onPressed: () => onSelect(ssd),
                  ),
                  RaisedButton(
                    child: const Text(yolo),
                    onPressed: () => onSelect(yolo),
                  ),
                  RaisedButton(
                    child: const Text(mobilenet),
                    onPressed: () => onSelect(mobilenet),
                  ),
                  RaisedButton(
                    child: const Text(posenet),
                    onPressed: () => onSelect(posenet),
                  ),
                ],
              ),
            )
          : Camera(widget.cameras, _model),
    );
  }
}
