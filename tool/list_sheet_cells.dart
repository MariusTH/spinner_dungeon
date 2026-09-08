import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

/// List 256x256 cells in 2048 sheet with edge activity (likely sprites).
void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : 'assets/2ddungeonassetpackwithoutoutline/dungeon0018.png';
  final cell = args.length > 1 ? int.tryParse(args[1]) ?? 256 : 256;
  final bytes = File(path).readAsBytesSync();
  final im = img.decodePng(bytes)!;

  double lum(img.Pixel p) =>
      (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;

  double cellEdgeScore(int x0, int y0, int cw, int ch) {
    final x1 = min(x0 + cw, im.width) - 1;
    final y1 = min(y0 + ch, im.height) - 1;
    if (x1 <= x0 || y1 <= y0) {
      return 0;
    }
    var edge = 0.0;
    var n = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final a = lum(im.getPixel(x, y));
        final b = lum(im.getPixel(x + 1, y));
        final c = lum(im.getPixel(x, y + 1));
        edge += (a - b).abs() + (a - c).abs();
        n++;
      }
    }
    return n > 0 ? edge / n : 0;
  }

  final cols = im.width ~/ cell;
  final rows = im.height ~/ cell;
  print('cells ${cols}x$rows of ${cell}x$cell');
  final hot = <String>[];
  final printGrid = cols <= 24;
  for (var gy = 0; gy < rows; gy++) {
    for (var gx = 0; gx < cols; gx++) {
      final s = cellEdgeScore(gx * cell, gy * cell, cell, cell);
      if (s > 0.025) {
        hot.add('($gx,$gy) s=${s.toStringAsFixed(4)}');
      }
      if (printGrid) {
        stdout.write(s > 0.025 ? '*' : (s > 0.012 ? '.' : ' '));
      }
    }
    if (printGrid) {
      print('');
    }
  }
  print('--- hot (${hot.length}) cell=$cell ---');
  for (final h in hot) {
    print(h);
  }
  print('--- dart ---');
  stdout.write('const _cells = <(int,int)>[');
  var first = true;
  for (final h in hot) {
    final m = RegExp(r'\((\d+),(\d+)\)').firstMatch(h);
    if (m == null) {
      continue;
    }
    if (!first) {
      stdout.write(',');
    }
    first = false;
    stdout.write('(${m[1]},${m[2]})');
  }
  print('];');
}
