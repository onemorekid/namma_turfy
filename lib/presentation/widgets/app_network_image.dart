import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildError();
    }

    // On Web, CachedNetworkImage can hit CORS issues when trying to download bytes.
    // Image.network is more reliable as it uses the browser's native <img> tag.
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              Container(
                height: height,
                width: width,
                color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator()),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[AppNetworkImage] WEB ERROR for $imageUrl: $error');
          return _buildError();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            height: height,
            width: width,
            color: Colors.grey[100],
            child: const Center(child: CircularProgressIndicator()),
          ),
      errorWidget: (context, url, error) {
        debugPrint('[AppNetworkImage] MOBILE ERROR for $imageUrl: $error');
        return _buildError();
      },
    );
  }

  Widget _buildError() {
    return errorWidget ??
        Container(
          height: height,
          width: width,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
  }
}
