import 'package:flutter/services.dart' show rootBundle;

import 'room_template.dart';
import 'tile_semantics.dart';

/// Loads bundled [RoomTemplate] JSON from `assets/levels/room_templates/`.
class RoomTemplateCatalog {
  RoomTemplateCatalog._();

  static final RoomTemplateCatalog instance = RoomTemplateCatalog._();

  final Map<String, RoomTemplate> _byId = <String, RoomTemplate>{};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    for (final path in kRoomTemplateAssetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final t = RoomTemplate.fromJsonString(raw);
        if (t.tileSemanticsVersion == kTileSemanticsVersion &&
            t.cols > 0 &&
            t.rows > 0 &&
            t.semantics.length == t.cols * t.rows) {
          _byId[t.id] = t;
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  RoomTemplate? byId(String id) => _byId[id];

  Iterable<RoomTemplate> get all => _byId.values;
}

/// Add new template filenames here when committing JSON next to the LDtk export.
const List<String> kRoomTemplateAssetPaths = <String>[
  'assets/levels/room_templates/band_arena.json',
];
