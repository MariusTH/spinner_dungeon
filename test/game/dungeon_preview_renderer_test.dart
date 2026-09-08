import 'package:flutter_test/flutter_test.dart';
import 'package:ssc/game/dungeon_level_generator.dart';
import 'package:ssc/game/dungeon_preview_renderer.dart';

void main() {
  const generator = DungeonLevelGenerator();
  const renderer = DungeonPreviewRenderer();

  test('renders non-empty PNG bytes for generated dungeon', () {
    final dungeon = generator.generateCampaignLevel(
      levelNumber: 5,
      seed: 2026,
    );
    final bytes = renderer.renderPngBytes(dungeon);

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(100));
    expect(
      bytes.take(8).toList(),
      equals(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
    );
  });
}
