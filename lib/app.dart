import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:image/image.dart' as img;

class RunModelByImageDemo extends StatefulWidget {
  const RunModelByImageDemo({Key? key}) : super(key: key);

  @override
  _RunModelByImageDemoState createState() => _RunModelByImageDemoState();
}

class _RunModelByImageDemoState extends State<RunModelByImageDemo> {
  late ModelObjectDetection _objectModelYoloV8;

  String? textToShow;
  List? _prediction;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  List<ResultObjectDetection?> objDetect = [];

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  //load your model
  Future loadModel() async {
    String pathObjectDetectionModelYolov8 = "assets/best.torchscript";
    String labelPath = "assets/labels.txt";
    try {
      _objectModelYoloV8 = await PytorchLite.loadObjectDetectionModel(
          pathObjectDetectionModelYolov8, 6, 640, 640,
          labelPath: labelPath,
          objectDetectionModelType: ObjectDetectionModelType.yolov8);
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  Future runObjectDetection() async {
    //pick a random image

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    Stopwatch stopwatch = Stopwatch()..start();

    objDetect = await _objectModelYoloV8.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.1,
        iOUThreshold: 0.3);
    textToShow = inferenceTimeAsString(stopwatch);

    print('object executed in ${stopwatch.elapsed.inMilliseconds} ms');
    for (var element in objDetect) {
      print({
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });
    }

    setState(() {
      //this.objDetect = objDetect;
      _image = File(image.path);
    });
  }

  String inferenceTimeAsString(Stopwatch stopwatch) =>
      "Inference Took ${stopwatch.elapsed.inMilliseconds} ms";

/*
  //run a custom model with number inputs
  Future runCustomModel() async {
    _prediction = await _customModel!
        .getPrediction([1, 2, 3, 4], [1, 2, 2], DType.float32);

    setState(() {});
  }
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Run model with Image'), centerTitle: true),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (objDetect.isNotEmpty)
            Expanded(
              child: _image == null
                  ? const Text('No image selected.')
                  : _objectModelYoloV8.renderBoxesOnImage(_image!, objDetect),
            )
          else
            Container(
              child: _image == null
                  ? const Text('No image selected.')
                  : Image.file(_image!),
            ),
          Center(
            child: Visibility(
              visible: textToShow != null,
              child: Text("$textToShow", maxLines: 3),
            ),
          ),
          TextButton(
            onPressed: runObjectDetection,
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              "Run object detection",
              style: TextStyle(color: Colors.white),
            ),
          ),
          Center(
            child: Visibility(
              visible: _prediction != null,
              child: Text(_prediction != null ? "${_prediction![0]}" : ""),
            ),
          )
        ],
      ),
    );
  }

  Widget renderBoxes(File image, List<ResultObjectDetection?> recognitions,
      {Color? boxesColor, bool showPercentage = true}) {
    return FutureBuilder(
        future: img.decodeImageFile(image.path),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();

          return LayoutBuilder(builder: (context, constraints) {
            debugPrint(
                'Max height: ${constraints.maxHeight}, max width: ${constraints.maxWidth}');
            debugPrint(
                'Max height: ${snap.data!.height.toDouble()}, max width: ${constraints.maxWidth}');
            debugPrint(
                'image height: ${snap.data!.height.toDouble()}, image width: ${snap.data!.width.toDouble()}');

            // Calculate the scaling factors for the boxes based on the layout constraints
            final aspectRatio = snap.data!.width / snap.data!.height;

            double factorX = constraints.maxWidth;
            double factorY = snap.data!.height.toDouble();

            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: factorX,
                  height: factorY,
                  child: Image.file(image, fit: BoxFit.fill),
                ),
                ...recognitions.map((re) {
                  if (re == null) {
                    return Container();
                  }
                  Color usedColor;
                  if (boxesColor == null) {
                    //change colors for each label
                    usedColor = Colors.primaries[
                        ((re.className ?? re.classIndex.toString()).length +
                                (re.className ?? re.classIndex.toString())
                                    .codeUnitAt(0) +
                                re.classIndex) %
                            Colors.primaries.length];
                  } else {
                    usedColor = boxesColor;
                  }

                  return Positioned(
                    left: re.rect.left * factorX,
                    top: re.rect.top * factorY - 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 20,
                          alignment: Alignment.centerRight,
                          color: usedColor,
                          child: Text(
                            "${re.className ?? re.classIndex.toString()}_${showPercentage ? "${(re.score * 100).toStringAsFixed(2)}%" : ""}",
                          ),
                        ),
                        Container(
                          width: re.rect.width.toDouble() * factorX,
                          height: re.rect.height.toDouble() * factorY,
                          decoration: BoxDecoration(
                              border: Border.all(color: usedColor, width: 3),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(2))),
                          child: Container(),
                        ),
                      ],
                    ),
                  );
                }).toList()
              ],
            );
          });
        });
  }
}
