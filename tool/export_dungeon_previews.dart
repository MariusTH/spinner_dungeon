import 'dart:io';

import 'package:ssc/game/dungeon_level_generator.dart';
import 'package:ssc/game/dungeon_preview_renderer.dart';

/// Writes PNG map previews to [build/dungeon_previews/].
///
/// Run from repo root: `dart run tool/export_dungeon_previews.dart`
void main() {
  final out = Directory('build/dungeon_previews');
  out.createSync(recursive: true);

  const gen = DungeonLevelGenerator();
  const renderer = DungeonPreviewRenderer();
  final seeds = [1, 42, 99, 2026, 7777];
  var count = 0;

  for (var level = 1; level <= 8; level++) {
    for (final seed in seeds) {
      final dungeon = gen.generateCampaignLevel(
        levelNumber: level,
        seed: seed,
      );
      final bytes = renderer.renderPngBytes(dungeon);
      final file = File('${out.path}/level_${level}_seed_$seed.png');
      file.writeAsBytesSync(bytes);
      count++;
    }
  }

  stdout.writeln('Wrote $count PNGs to ${out.absolute.path}');
}
