import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// The published site (uploaded games live under it, in games/).
const siteHome = 'https://ritikyadavintexas.github.io/zoya7/';

/// The full address of [path] on the site: the one this page came from on the
/// web (the game or the admin panel), the published one in the phone app.
String siteUrl(String path) {
  if (!kIsWeb) return '$siteHome$path';
  final p = Uri.base.path;
  final admin = p.indexOf('/admin/');
  final root = admin >= 0 ? p.substring(0, admin + 1) : p.substring(0, p.lastIndexOf('/') + 1);
  return '${Uri.base.origin}$root$path';
}

/// A game's lobby art: from the app's own assets, or (an uploaded game) from the site.
Widget gameImage(String path,
    {BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center, double? width, double? height, String? semanticLabel}) {
  if (path.startsWith('assets/')) {
    return Image.asset(path, fit: fit, alignment: alignment, width: width, height: height, semanticLabel: semanticLabel);
  }
  return Image.network(
    siteUrl(path),
    fit: fit,
    alignment: alignment,
    width: width,
    height: height,
    semanticLabel: semanticLabel,
    errorBuilder: (_, __, ___) => SizedBox(width: width, height: height, child: const ColoredBox(color: Color(0xFF1C140C))),
  );
}
