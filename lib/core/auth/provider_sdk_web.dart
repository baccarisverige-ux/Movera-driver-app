// The web build of the driver app carries no Google / Apple SDK (web size
// budget, tool/web_budget.json): both providers answer ProviderUnavailable,
// so the buttons say "coming soon" on the web. Phones use provider_sdk.dart.
import 'package:flutter/foundation.dart';

import 'provider_sign_in_config.dart';
import 'provider_token_source.dart';

Future<ProviderIdentityToken?> obtainApple(
  ProviderSignInConfig config, {
  required bool web,
  required TargetPlatform target,
}) async => throw const ProviderUnavailable('apple', 'not on the web build');

Future<ProviderIdentityToken?> obtainGoogle(
  ProviderSignInConfig config, {
  required bool web,
  required TargetPlatform target,
  required Duration webGoogleTimeout,
}) async => throw const ProviderUnavailable('google', 'not on the web build');
