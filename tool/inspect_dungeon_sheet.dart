import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// Edge-density heatmap for sprite sheet layout discovery.
void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : 'assets/2ddungeonassetpackwithoutoutline/dungeon0018.png';
  final bytes = File(path).readAsBytesSync();
  final im = img.decodePng(bytes)!;
  print('size: ${im.width} x ${im.height}');
  final div = args.length > 1 ? int.tryParse(args[1]) ?? 16 : 16;
  final cw = im.width ~/ div;
  final ch = im.height ~/ div;

  double lum(img.Pixel p) =>
      (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;

  for (var gy = 0; gy < div; gy++) {
    for (var gx = 0; gx < div; gx++) {
      var edge = 0.0;
      var n = 0;
      final x0 = gx * cw;
      final y0 = gy * ch;
      final x1 = min((gx + 1) * cw, im.width) - 1;
      final y1 = min((gy + 1) * ch, im.height) - 1;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final a = lum(im.getPixel(x, y));
          final b = lum(im.getPixel(x + 1, y));
          final c = lum(im.getPixel(x, y + 1));
          edge += (a - b).abs() + (a - c).abs();
          n++;
        }
      }
      final avg = n > 0 ? edge / n : 0.0;
      stdout.write(avg > 0.08 ? '##' : avg > 0.035 ? '..' : '  ');
    }
    print('');
  }
}
