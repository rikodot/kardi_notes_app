import 'dart:math';
import 'package:flutter/widgets.dart';

import 'data_sync.dart';

//pass by reference workaround
class Any {
  var value;

  Any(this.value);

  bool setValue(var value) {
    this.value = value;
    return true;
  }
}

class Utils {
  static final Random _random = Random.secure();

  static String randomString([int length = 32, bool ignore_similar_chars = false]) {
    String chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if (ignore_similar_chars) { chars = chars.replaceAll(RegExp(r'[01iloILO]'), ''); }
    return List.generate(length, (index) => chars[_random.nextInt(chars.length)]).join();
  }

  static int randomInt([int min = 0, int max = 2147483647]) {
    return min + _random.nextInt(max - min);
  }

  static Size logical_size({bool use_media = false, BuildContext? context = null}) {
    if (context == null || !use_media) { return WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio; }
    else { return MediaQuery.of(context).size; }
  }
  static Size physical_size({bool use_media = false, BuildContext? context = null}) {
    if (context == null || !use_media) { return WidgetsBinding.instance.platformDispatcher.views.first.physicalSize; }
    else { return MediaQuery.of(context).size * MediaQuery.of(context).devicePixelRatio; }
  }

  static int now({bool ms = false}) {
    return DateTime.now().millisecondsSinceEpoch ~/ (ms ? 1 : 1000);
  }
}

class Scaling
{
  static int notes_page_cross_axis_count({bool use_media = false, BuildContext? context = null})
  {
    //how many would we fit into a single row
    double fit = Utils.logical_size(use_media: use_media, context: context).width / HttpHelper.note_mini_width;
    //if we are less then 1, we should fit at least 1
    if (fit < 1) { return 1; }
    //if we are less then 2, but close, fit 2
    if (fit < 2.0 && fit > 1.7) { return 2; }
    //else, fit as many as we can
    return fit.floor();
  }
}