import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Open [url] outside the app. Returns void on purpose: a tap handler must
/// not hold a Future, or its error is lost.
void openExternalUrl(Uri url) {
  unawaited(
    launchUrl(url, mode: LaunchMode.externalApplication).then<void>(
      (opened) {
        if (!opened) debugPrint('No app opened ${url.host}');
      },
      onError: (Object e, StackTrace s) {
        // The message of the error can hold the full address, which names
        // a person. Log only the kind of error.
        final kind = e is PlatformException ? e.code : e.runtimeType;
        debugPrint('Opening ${url.host} failed: $kind\n$s');
      },
    ),
  );
}
