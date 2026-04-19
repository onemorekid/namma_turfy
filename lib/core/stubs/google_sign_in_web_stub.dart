// Stub for non-web platforms. google_sign_in_web uses dart:js_interop which is
// unavailable on Android/iOS. The login_screen.dart guards all calls to
// renderButton() behind `if (kIsWeb)`, so this stub is never actually invoked.
import 'package:flutter/widgets.dart';

Widget renderButton({Object? configuration}) => const SizedBox.shrink();
