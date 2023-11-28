import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class ReceiveSharingIntent {
  static const MethodChannel _mChannel =
  const MethodChannel('receive_sharing_intent/messages');
  static const EventChannel _eChannelMedia =
  const EventChannel("receive_sharing_intent/events-media");
  static const EventChannel _eChannelLink =
  const EventChannel("receive_sharing_intent/events-text");

  static Stream<List<SharedMediaFile>>? _streamMedia;
  static Stream<String>? _streamLink;

  /// 返回一个 [Future]，它完成以下操作之一：
  ///
  ///   *成功调用时最初存储的媒体 uri（可能为 null）；
  ///   *如果平台插件中调用失败，则抛出 [PlatformException]。
  ///
  /// 笔记。 iOS 上返回的媒体（仅限 iOS）已复制到临时文件夹中。
  /// 所以，使用完后需要删除该文件
  static Future<List<SharedMediaFile>> getInitialMedia() async {
    final json = await _mChannel.invokeMethod('getInitialMedia');
    if (json == null) return [];
    final encoded = jsonDecode(json);
    return encoded
        .map<SharedMediaFile>((file) => SharedMediaFile.fromJson(file))
        .toList();
  }

  /// 返回一个 [Future]，它完成以下操作之一：
  ///
  ///   *成功调用时最初存储的链接（可能为空）；
  ///   *如果平台插件中调用失败，则抛出 [PlatformException]。
  static Future<String?> getInitialText() async {
    return await _mChannel.invokeMethod('getInitialText');
  }

  /// 一种便捷方法，它将最初存储的链接作为新的 [Uri] 对象返回。
  ///
  /// 如果链接作为 URI 或 URI 引用无效，则会抛出 [FormatException]。
  static Future<Uri?> getInitialTextAsUri() async {
    final data = await getInitialText();
    if (data == null) return null;
    return Uri.parse(data);
  }

  /// 设置广播流以接收传入的媒体共享更改事件。
  ///
  /// 返回一个广播 [Stream]，它向侦听器发出事件，如下所示：
  ///
  ///   *每个成功的解码数据（[List]）事件（可能为空）
  ///   从平台插件收到的事件；
  ///   *每个错误事件包含一个 [PlatformException] 的错误事件
  ///   从平台插件收到。
  ///
  /// 流激活或停用期间发生的错误通过“FlutterError”工具报告。仅当流侦听器计数从 0 更改为 1 时，才会发生流激活。仅当流侦听器计数从 1 更改为 0 时，才会发生流停用。
  ///
  /// 如果应用程序是由链接意图或用户活动启动的，则流将不会发出初始的 -而是查询“getInitialMedia”。
  static Stream<List<SharedMediaFile>> getMediaStream() {
    if (_streamMedia == null) {
      final stream =
      _eChannelMedia.receiveBroadcastStream("media").cast<String?>();
      _streamMedia = stream.transform<List<SharedMediaFile>>(
        new StreamTransformer<String?, List<SharedMediaFile>>.fromHandlers(
          handleData: (String? data, EventSink<List<SharedMediaFile>> sink) {
            if (data == null) {
              sink.add([]);
            } else {
              final encoded = jsonDecode(data);
              sink.add(encoded
                  .map<SharedMediaFile>(
                      (file) => SharedMediaFile.fromJson(file))
                  .toList());
            }
          },
        ),
      );
    }
    return _streamMedia!;
  }

  /// 设置广播流以接收传入的链接更改事件。
  ///
  /// 返回一个广播 [Stream]，它向侦听器发出事件，如下所示：
  ///
  ///   *每个成功的解码数据（[String]）事件（可能为空）
  ///   从平台插件收到的事件；
  ///   *每个错误事件包含一个 [PlatformException] 的错误事件
  ///   从平台插件收到。
  ///
  /// 流激活或停用期间发生的错误通过“FlutterError”工具报告。仅当流侦听器计数从 0 更改为 1 时，才会发生流激活。仅当流侦听器计数从 1 更改为 0 时，才会发生流停用。
  ///
  /// 如果应用程序是由链接意图或用户活动启动的，则流将不会发出初始的 -而是查询“getInitialText”。
  static Stream<String> getTextStream() {
    if (_streamLink == null) {
      _streamLink = _eChannelLink.receiveBroadcastStream("text").cast<String>();
    }
    return _streamLink!;
  }

  /// 将流方便地转换为“Stream<Uri>”。
  ///
  /// 如果该值作为 URI 或 URI 引用无效，则会抛出 [FormatException]。
  ///
  /// 有关错误/异常详细信息，请参阅“getTextStream”。
  ///
  /// 如果应用程序是由共享意图或用户活动启动的，则流将不会发出该初始 uri -而是查询“getInitialTextAsUri”。
  static Stream<Uri> getTextStreamAsUri() {
    return getTextStream().transform<Uri>(
      new StreamTransformer<String, Uri>.fromHandlers(
        handleData: (String data, EventSink<Uri> sink) {
          sink.add(Uri.parse(data));
        },
      ),
    );
  }

  /// 如果您已经使用了回调并且不希望再次使用相同的回调，请调用此方法
  static void reset() {
    _mChannel.invokeMethod('reset').then((_) {});
  }
}

class SharedMediaFile {
  /// 图像或视频路径。
  /// 笔记。仅适用于 iOS，文件始终被复制
  final String path;

  /// 视频缩略图
  final String? thumbnail;

  /// 视频时长（以毫秒为单位）
  final int? duration;

  /// 无论是视频、图像还是文件
  final SharedMediaType type;

  SharedMediaFile(this.path, this.thumbnail, this.duration, this.type);

  SharedMediaFile.fromJson(Map<String, dynamic> json)
      : path = json['path'],
        thumbnail = json['thumbnail'],
        duration = json['duration'],
        type = SharedMediaType.values[json['type']];
}

enum SharedMediaType { IMAGE, VIDEO, FILE }
