import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_providers.g.dart';

@riverpod
Future<PackageInfo> packageInfo(Ref ref) {
  return PackageInfo.fromPlatform();
}
