import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_speed_test/callbacks_enum.dart';
import 'package:tuple/tuple.dart';

typedef void CancelListening();
typedef void DoneCallback(double transferRate, SpeedUnit unit);
typedef void ProgressCallback(
  double percent,
  double transferRate,
  SpeedUnit unit,
);
typedef void ErrorCallback(String? errorMessage, String? speedTestError);

class InternetSpeedTest {
  static const MethodChannel _channel =
      const MethodChannel('internet_speed_test');

  Map<int, Tuple3<ErrorCallback, ProgressCallback, DoneCallback>>
      _callbacksById = new Map();

  int downloadRate = 0;
  int uploadRate = 0;
  int downloadSteps = 0;
  int uploadSteps = 0;

  Future<void> _methodCallHandler(MethodCall call) async {
    debugPrint('arguments are ${call.arguments}');
    debugPrint('callbacks are $_callbacksById');
    switch (call.method) {
      case 'callListener':
        if (call.arguments["id"] as int ==
            CallbacksEnum.START_DOWNLOAD_TESTING.index) {
          if (call.arguments['type'] == ListenerEnum.COMPLETE.index) {
            downloadSteps++;
            downloadRate +=
                int.parse((call.arguments['transferRate'] ~/ 1000).toString());
            debugPrint('download steps is $downloadSteps --- $downloadRate');
            double average = (downloadRate ~/ downloadSteps).toDouble();
            SpeedUnit unit = SpeedUnit.Kbps;
            average /= 1000;
            unit = SpeedUnit.Mbps;
            _callbacksById[call.arguments["id"]]!.item3(average, unit);
            downloadSteps = 0;
            downloadRate = 0;
            _callbacksById.remove(call.arguments["id"]);
          } else if (call.arguments['type'] == ListenerEnum.ERROR.index) {
            debugPrint(
                'onError : ${call.arguments["speedTestError"]} --- ${call.arguments["errorMessage"]}');

            _callbacksById[call.arguments["id"]]!.item1(
                call.arguments['errorMessage'],
                call.arguments['speedTestError']);
            downloadSteps = 0;
            downloadRate = 0;
            _callbacksById.remove(call.arguments["id"]);
          } else if (call.arguments['type'] == ListenerEnum.PROGRESS.index) {
            double rate = (call.arguments['transferRate'] ~/ 1000).toDouble();
            debugPrint('rate is $rate');
            if (rate != 0) downloadSteps++;
            downloadRate += rate.toInt();
            SpeedUnit unit = SpeedUnit.Kbps;
            rate /= 1000;
            unit = SpeedUnit.Mbps;
            _callbacksById[call.arguments["id"]]!
                .item2(call.arguments['percent'].toDouble(), rate, unit);
          }
        } else if (call.arguments["id"] as int ==
            CallbacksEnum.START_UPLOAD_TESTING.index) {
          if (call.arguments['type'] == ListenerEnum.COMPLETE.index) {
            debugPrint('onComplete : ${call.arguments['transferRate']}');

            uploadSteps++;
            uploadRate +=
                int.parse((call.arguments['transferRate'] ~/ 1000).toString());
            debugPrint('download steps is $uploadSteps --- $uploadRate');
            double average = (uploadRate ~/ uploadSteps).toDouble();
            SpeedUnit unit = SpeedUnit.Kbps;
            average /= 1000;
            unit = SpeedUnit.Mbps;
            _callbacksById[call.arguments["id"]]!.item3(average, unit);
            uploadSteps = 0;
            uploadRate = 0;
            _callbacksById.remove(call.arguments["id"]);
          } else if (call.arguments['type'] == ListenerEnum.ERROR.index) {
            debugPrint(
                'onError : ${call.arguments["speedTestError"]} --- ${call.arguments["errorMessage"]}');
            _callbacksById[call.arguments["id"]]!.item1(
                call.arguments['errorMessage'],
                call.arguments['speedTestError']);
            _callbacksById.remove(call.arguments["id"]);
          } else if (call.arguments['type'] == ListenerEnum.PROGRESS.index) {
            double rate = (call.arguments['transferRate'] ~/ 1000).toDouble();
            debugPrint('rate is $rate');
            if (rate != 0) uploadSteps++;
            uploadRate += rate.toInt();
            SpeedUnit unit = SpeedUnit.Kbps;
            rate /= 1000.0;
            unit = SpeedUnit.Mbps;
            _callbacksById[call.arguments["id"]]!
                .item2(call.arguments['percent'].toDouble(), rate, unit);
          }
        }
        break;
      default:
        debugPrint(
            'TestFairy: Ignoring invoke from native. This normally shouldn\'t happen.');
    }

    await _channel.invokeMethod("cancelListening", call.arguments["id"]);
  }

  Future<CancelListening> _startListening(
      Tuple3<ErrorCallback, ProgressCallback, DoneCallback> callback,
      CallbacksEnum callbacksEnum,
      String testServer,
      {Map<String, dynamic>? args,
      int fileSize = 200000,
      String? token}) async {
    _channel.setMethodCallHandler(_methodCallHandler);
    int currentListenerId = callbacksEnum.index;
    debugPrint('test $currentListenerId');
    _callbacksById[currentListenerId] = callback;
    await _channel.invokeMethod(
      "startListening",
      {
        'id': currentListenerId,
        'args': args,
        'testServer': testServer,
        'fileSize': fileSize,
        'token': token,
      },
    );
    return () {
      _channel.invokeMethod("cancelListening", currentListenerId);
      _callbacksById.remove(currentListenerId);
    };
  }

  Future<CancelListening> startDownloadTesting(
      {required DoneCallback onDone,
      required ProgressCallback onProgress,
      required ErrorCallback onError,
      int fileSize = 200000,
      String testServer = 'http://ipv4.ikoula.testdebit.info/1M.iso'}) async {
    return await _startListening(
      Tuple3(onError, onProgress, onDone),
      CallbacksEnum.START_DOWNLOAD_TESTING,
      testServer,
      fileSize: fileSize,
    );
  }

  Future<CancelListening> startUploadTesting({
    required DoneCallback onDone,
    required ProgressCallback onProgress,
    required ErrorCallback onError,
    int fileSize = 200000,
    String? token,
    String testServer = 'http://ipv4.ikoula.testdebit.info/',
  }) async {
    return await _startListening(
      Tuple3(onError, onProgress, onDone),
      CallbacksEnum.START_UPLOAD_TESTING,
      testServer,
      fileSize: fileSize,
      token: token,
    );
  }
}
