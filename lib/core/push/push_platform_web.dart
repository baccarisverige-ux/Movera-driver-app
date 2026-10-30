import 'dart:convert';
import 'dart:js_interop';

import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:web/web.dart' as web;

/// The web build: `window.moveraPush` from `web/movera_push.js`.
PushPlatform createPlatformPush() => WebPushPlatform();

@JS('moveraPush')
external _MoveraPush? get _moveraPush;

extension type _MoveraPush._(JSObject _) implements JSObject {
  external bool supported();
  external String permission();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSString?> getToken(String config, String serviceWorker);
  external void setOpenHandler(JSFunction handler);
}

class WebPushPlatform implements PushPlatform {
  bool _launchTaken = false;

  @override
  bool get supported {
    try {
      return _moveraPush?.supported() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  String get platformName => 'web';

  @override
  Future<String> permission() async => _moveraPush?.permission() ?? 'denied';

  @override
  Future<bool> requestPermission() async {
    final push = _moveraPush;
    if (push == null) return false;
    final answer = await push.requestPermission().toDart;
    return answer.toDart == 'granted';
  }

  @override
  Future<String?> token(PushWebConfig config) async {
    final push = _moveraPush;
    if (push == null) return null;
    final token = await push
        .getToken(jsonEncode(config.toJson()), 'firebase-messaging-sw.js')
        .toDart;
    final value = token?.toDart;
    return value == null || value.isEmpty ? null : value;
  }

  @override
  PushOpen? takeLaunchOpen() {
    if (_launchTaken) return null;
    _launchTaken = true;
    final query = Uri.base.queryParameters;
    final id = query['movera_push'];
    if (id == null || id.isEmpty) return null;
    // The query is read once; the address bar keeps the app's own route.
    try {
      final clean = Uri.base.replace(queryParameters: const {}).toString();
      web.window.history.replaceState(null, '', clean.replaceAll('?#', '#'));
    } catch (_) {
      // Keeping the query is harmless.
    }
    return PushOpen(notificationId: id, deepLink: query['movera_link']);
  }

  @override
  void onOpen(void Function(PushOpen open) handler) {
    _moveraPush?.setOpenHandler(
      ((JSString id, JSString link) {
        final deepLink = link.toDart;
        handler(
          PushOpen(
            notificationId: id.toDart,
            deepLink: deepLink.isEmpty ? null : deepLink,
          ),
        );
      }).toJS,
    );
  }
}
