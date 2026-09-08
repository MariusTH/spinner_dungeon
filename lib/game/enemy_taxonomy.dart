import 'package:flutter/material.dart';

enum EnemyType { turret, walker, boss, paddle, hedgehog, pulser }

enum EnemyArchetype {
  standard,
  absorber,
  blower,
  sucker,
  blocker,
  spiked,
  stalker,
}

enum EnemyMarkerShape { triangle, square, circle, hexagon }

class EnemyMarkerGlyph {
  const EnemyMarkerGlyph({required this.primary, this.secondary});

  final EnemyMarkerShape primary;
  final EnemyMarkerShape? secondary;
}

class EnemyMarkerTaxonomy {
  const EnemyMarkerTaxonomy({
    required this.typeGlyph,
    required this.archetypeGlyph,
    required this.bodyColor,
    required this.typeColor,
    required this.archetypeColor,
  });

  final EnemyMarkerGlyph typeGlyph;
  final EnemyMarkerGlyph archetypeGlyph;
  final Color bodyColor;
  final Color typeColor;
  final Color archetypeColor;
}

abstract final class EnemyTaxonomy {
  static EnemyMarkerTaxonomy markerFor({
    required EnemyType type,
    required EnemyArchetype archetype,
  }) {
    final bodyColor = bodyColorForType(type);
    return EnemyMarkerTaxonomy(
      typeGlyph: typeGlyphFor(type),
      archetypeGlyph: archetypeGlyphFor(archetype),
      bodyColor: bodyColor,
      typeColor: Color.alphaBlend(const Color(0x44FFFFFF), bodyColor),
      archetypeColor: archetypeColorFor(archetype),
    );
  }

  static Color bodyColorForType(EnemyType type) {
    switch (type) {
      case EnemyType.turret:
        return const Color(0xFFE06161);
      case EnemyType.walker:
        return const Color(0xFFF0B248);
      case EnemyType.boss:
        return const Color(0xFFE87E4E);
      case EnemyType.paddle:
        return const Color(0xFFE35B5B);
      case EnemyType.hedgehog:
        return const Color(0xFF8A9F56);
      case EnemyType.pulser:
        return const Color(0xFF9B5FD6);
    }
  }

  static Color archetypeColorFor(EnemyArchetype archetype) {
    return switch (archetype) {
      EnemyArchetype.standard => const Color(0xFF8B8B8B),
      EnemyArchetype.absorber => const Color(0xFF59D8A8),
      EnemyArchetype.blower => const Color(0xFF6BC7FF),
      EnemyArchetype.sucker => const Color(0xFFB18BFF),
      EnemyArchetype.blocker => const Color(0xFFBFC5CC),
      EnemyArchetype.spiked => const Color(0xFFFF8C6B),
      EnemyArchetype.stalker => const Color(0xFFFF5C5C),
    };
  }

  static EnemyMarkerGlyph typeGlyphFor(EnemyType type) {
    return switch (type) {
      EnemyType.turret => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.triangle,
      ),
      EnemyType.walker => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.square,
      ),
      EnemyType.boss => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.hexagon,
      ),
      EnemyType.paddle => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.circle,
      ),
      EnemyType.hedgehog => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.triangle,
        secondary: EnemyMarkerShape.circle,
      ),
      EnemyType.pulser => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.hexagon,
        secondary: EnemyMarkerShape.circle,
      ),
    };
  }

  static EnemyMarkerGlyph archetypeGlyphFor(EnemyArchetype archetype) {
    return switch (archetype) {
      EnemyArchetype.standard => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.circle,
      ),
      EnemyArchetype.absorber => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.square,
        secondary: EnemyMarkerShape.circle,
      ),
      EnemyArchetype.blower => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.triangle,
      ),
      EnemyArchetype.sucker => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.hexagon,
      ),
      EnemyArchetype.blocker => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.square,
      ),
      EnemyArchetype.spiked => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.triangle,
        secondary: EnemyMarkerShape.hexagon,
      ),
      EnemyArchetype.stalker => const EnemyMarkerGlyph(
        primary: EnemyMarkerShape.triangle,
        secondary: EnemyMarkerShape.square,
      ),
    };
  }
}
