import 'package:flutter/material.dart';

/// Chunky Cartoon / agent.md palette for the physical workbench meta-UI.
abstract final class WorkbenchPalette {
  static const Color deepVoid = Color(0xFF2F2F2F);
  static const Color dungeonStone = Color(0xFF919090);
  static const Color stoneShadow = Color(0xFF27367B);
  static const Color wood = Color(0xFF4F3816);
  static const Color woodLight = Color(0xFF6B4A1F);
  static const Color woodDark = Color(0xFF2E2110);
  static const Color woodEdge = Color(0xFF1A1309);
  static const Color actionHighlight = Color(0xFFFFE100);
  static const Color magicTint = Color(0xFFEBC7FF);
  static const Color ink = Color(0xFF120D08);
  static const Color parchment = Color(0xFFF2E6D4);
  static const Color brass = Color(0xFFC4A35A);
  static const Color brassDark = Color(0xFF7A6228);

  static const LinearGradient woodPlank = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[woodLight, wood, woodDark],
  );
}
