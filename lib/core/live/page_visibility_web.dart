import 'dart:async';

import 'package:movera/core/live/page_visibility.dart';
import 'package:web/web.dart' as web;

PageVisibility? platformPageVisibility() => _DocumentVisibility();

class _DocumentVisibility implements PageVisibility {
  @override
  bool get visible => web.document.visibilityState == 'visible';

  @override
  Stream<bool> get changes =>
      web.document.onVisibilityChange.map((_) => visible);
}
