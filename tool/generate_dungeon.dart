#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:ssc/game/dungeon_level_generator.dart';
import 'package:ssc/game/dungeon_preview_renderer.dart';

const String _usage = '''
Usage:
  dart run tool/generate_dungeon.dart --level <int> --seed <int> [options]

Required:
  --level <int>               Dungeon level number (>= 1)
  --seed <int>                Seed for deterministic generation

Options:
  --width <int>               Map width in tiles (>= 28)
  --height <int>              Map height in tiles (>= 28)
  --target-rooms <int>        Desired room count (default: same as campaign)
  --include-monsters <bool>   true/false (default: true)
  --include-items <bool>      true/false (default: campaign — false on level 1)
  --no-monsters               Shortcut for --include-monsters=false
  --no-items                  Shortcut for --include-items=false
  --verbose                   Show generation process logs before JSON output
  --render-image              Save a PNG preview to output/dungeons/
  --output-image <path>       Save PNG preview to this exact file path
  --image-scale <int>         Preview scale in pixels per tile (default: 12)
  -h, --help                  Show this help message
''';

void main(List<String> args) {
  final parsed = _CliOptions.parse(args);

  if (parsed.showHelp) {
    stdout.writeln(_usage.trimRight());
    return;
  }

  if (parsed.errorMessage != null) {
    stderr.writeln(parsed.errorMessage);
    stderr.writeln(_usage.trimRight());
    exitCode = 64;
    return;
  }

  final generator = const DungeonLevelGenerator();
  final dungeon = generator.generateLevel(
    levelNumber: parsed.levelNumber!,
    seed: parsed.seed!,
    width: parsed.width,
    height: parsed.height,
    targetRooms: parsed.targetRooms,
    includeMonsters: parsed.includeMonsters,
    includeItems: parsed.includeItems,
    log: parsed.verbose
        ? (message) => stderr.writeln('[process] $message')
        : null,
  );

  if (parsed.renderImage || parsed.outputImagePath != null) {
    final path =
        parsed.outputImagePath ??
        'output/dungeons/level${parsed.levelNumber}_seed${parsed.seed}.png';
    final renderer = DungeonPreviewRenderer(cellSize: parsed.imageScale);
    final bytes = renderer.renderPngBytes(dungeon);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes, flush: true);
    stderr.writeln('[image] saved ${file.path}');
  }

  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(dungeon.toJson()));
}

class _CliOptions {
  const _CliOptions({
    required this.levelNumber,
    required this.seed,
    required this.width,
    required this.height,
    required this.targetRooms,
    required this.includeMonsters,
    required this.includeItems,
    required this.renderImage,
    required this.outputImagePath,
    required this.imageScale,
    required this.verbose,
    required this.showHelp,
    required this.errorMessage,
  });

  final int? levelNumber;
  final int? seed;
  final int? width;
  final int? height;
  final int? targetRooms;
  final bool includeMonsters;
  final bool includeItems;
  final bool renderImage;
  final String? outputImagePath;
  final int imageScale;
  final bool verbose;
  final bool showHelp;
  final String? errorMessage;

  static _CliOptions parse(List<String> args) {
    int? levelNumber;
    int? seed;
    int? width;
    int? height;
    int? targetRooms;
    var includeMonsters = true;
    var includeItems = true;
    var includeItemsFromUser = false;
    var renderImage = false;
    String? outputImagePath;
    var imageScale = 12;
    var verbose = false;

    for (var i = 0; i < args.length; i += 1) {
      final arg = args[i];

      if (arg == '-h' || arg == '--help') {
        return _CliOptions(
          levelNumber: null,
          seed: null,
          width: null,
          height: null,
          targetRooms: null,
          includeMonsters: includeMonsters,
          includeItems: includeItems,
          renderImage: renderImage,
          outputImagePath: outputImagePath,
          imageScale: imageScale,
          verbose: verbose,
          showHelp: true,
          errorMessage: null,
        );
      }

      if (arg == '--verbose') {
        verbose = true;
        continue;
      }

      if (arg == '--no-monsters') {
        includeMonsters = false;
        continue;
      }

      if (arg == '--no-items') {
        includeItems = false;
        includeItemsFromUser = true;
        continue;
      }

      if (arg == '--render-image') {
        renderImage = true;
        continue;
      }

      if (_isOption(arg, '--level')) {
        final parsed = _readIntOption(args: args, index: i, name: '--level');
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        levelNumber = parsed.value;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--seed')) {
        final parsed = _readIntOption(args: args, index: i, name: '--seed');
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        seed = parsed.value;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--width')) {
        final parsed = _readIntOption(args: args, index: i, name: '--width');
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        width = parsed.value;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--height')) {
        final parsed = _readIntOption(args: args, index: i, name: '--height');
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        height = parsed.value;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--target-rooms')) {
        final parsed = _readIntOption(
          args: args,
          index: i,
          name: '--target-rooms',
        );
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        targetRooms = parsed.value;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--include-monsters')) {
        final parsed = _readBoolOption(
          args: args,
          index: i,
          name: '--include-monsters',
          defaultValue: true,
        );
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        includeMonsters = parsed.value;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--include-items')) {
        final parsed = _readBoolOption(
          args: args,
          index: i,
          name: '--include-items',
          defaultValue: true,
        );
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        includeItems = parsed.value;
        includeItemsFromUser = true;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--output-image')) {
        final parsed = _readStringOption(
          args: args,
          index: i,
          name: '--output-image',
        );
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        outputImagePath = parsed.value;
        renderImage = true;
        i = parsed.nextIndex;
        continue;
      }

      if (_isOption(arg, '--image-scale')) {
        final parsed = _readIntOption(
          args: args,
          index: i,
          name: '--image-scale',
        );
        if (parsed.errorMessage != null) {
          return _error(parsed.errorMessage!);
        }
        imageScale = parsed.value ?? imageScale;
        i = parsed.nextIndex;
        continue;
      }

      return _error('Unknown argument: $arg');
    }

    if (levelNumber == null) {
      return _error('Missing required argument --level');
    }

    if (seed == null) {
      return _error('Missing required argument --seed');
    }

    if (levelNumber < 1) {
      return _error('--level must be >= 1');
    }

    if (width != null && width < 2) {
      return _error('--width must be >= 2');
    }

    if (height != null && height < 2) {
      return _error('--height must be >= 2');
    }

    if (targetRooms != null && targetRooms < 1) {
      return _error('--target-rooms must be >= 1');
    }

    if (imageScale < 6) {
      return _error('--image-scale must be >= 6');
    }

    if (!includeItemsFromUser) {
      includeItems =
          DungeonLevelGenerator.campaignIncludeItemsForLevel(levelNumber);
    }

    return _CliOptions(
      levelNumber: levelNumber,
      seed: seed,
      width: width,
      height: height,
      targetRooms: targetRooms,
      includeMonsters: includeMonsters,
      includeItems: includeItems,
      renderImage: renderImage,
      outputImagePath: outputImagePath,
      imageScale: imageScale,
      verbose: verbose,
      showHelp: false,
      errorMessage: null,
    );
  }

  static _CliOptions _error(String message) {
    return _CliOptions(
      levelNumber: null,
      seed: null,
      width: null,
      height: null,
      targetRooms: null,
      includeMonsters: true,
      includeItems: true,
      renderImage: false,
      outputImagePath: null,
      imageScale: 12,
      verbose: false,
      showHelp: false,
      errorMessage: message,
    );
  }
}

bool _isOption(String arg, String name) {
  return arg == name || arg.startsWith('$name=');
}

_ParsedIntOption _readIntOption({
  required List<String> args,
  required int index,
  required String name,
}) {
  final inlineValue = _readInlineValue(args[index], name);
  if (inlineValue != null) {
    final parsed = int.tryParse(inlineValue);
    if (parsed == null) {
      return _ParsedIntOption.error('Invalid integer for $name: $inlineValue');
    }
    return _ParsedIntOption(value: parsed, nextIndex: index);
  }

  if (index + 1 >= args.length) {
    return _ParsedIntOption.error('Missing value for $name');
  }

  final rawValue = args[index + 1];
  final parsed = int.tryParse(rawValue);
  if (parsed == null) {
    return _ParsedIntOption.error('Invalid integer for $name: $rawValue');
  }

  return _ParsedIntOption(value: parsed, nextIndex: index + 1);
}

_ParsedBoolOption _readBoolOption({
  required List<String> args,
  required int index,
  required String name,
  required bool defaultValue,
}) {
  final inlineValue = _readInlineValue(args[index], name);
  if (inlineValue != null) {
    final parsed = _parseBool(inlineValue);
    if (parsed == null) {
      return _ParsedBoolOption.error('Invalid boolean for $name: $inlineValue');
    }
    return _ParsedBoolOption(value: parsed, nextIndex: index);
  }

  if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
    return _ParsedBoolOption(value: defaultValue, nextIndex: index);
  }

  final rawValue = args[index + 1];
  final parsed = _parseBool(rawValue);
  if (parsed == null) {
    return _ParsedBoolOption.error('Invalid boolean for $name: $rawValue');
  }

  return _ParsedBoolOption(value: parsed, nextIndex: index + 1);
}

_ParsedStringOption _readStringOption({
  required List<String> args,
  required int index,
  required String name,
}) {
  final inlineValue = _readInlineValue(args[index], name);
  if (inlineValue != null) {
    if (inlineValue.trim().isEmpty) {
      return _ParsedStringOption.error('Missing value for $name');
    }
    return _ParsedStringOption(value: inlineValue, nextIndex: index);
  }

  if (index + 1 >= args.length) {
    return _ParsedStringOption.error('Missing value for $name');
  }

  final rawValue = args[index + 1];
  if (rawValue.trim().isEmpty) {
    return _ParsedStringOption.error('Missing value for $name');
  }
  return _ParsedStringOption(value: rawValue, nextIndex: index + 1);
}

String? _readInlineValue(String argument, String name) {
  final prefix = '$name=';
  if (argument.startsWith(prefix)) {
    return argument.substring(prefix.length);
  }
  return null;
}

bool? _parseBool(String value) {
  final normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'true':
    case '1':
    case 'yes':
    case 'on':
      return true;
    case 'false':
    case '0':
    case 'no':
    case 'off':
      return false;
    default:
      return null;
  }
}

class _ParsedIntOption {
  const _ParsedIntOption({
    required this.value,
    required this.nextIndex,
    this.errorMessage,
  });

  factory _ParsedIntOption.error(String message) {
    return _ParsedIntOption(value: null, nextIndex: 0, errorMessage: message);
  }

  final int? value;
  final int nextIndex;
  final String? errorMessage;
}

class _ParsedBoolOption {
  const _ParsedBoolOption({
    required this.value,
    required this.nextIndex,
    this.errorMessage,
  });

  factory _ParsedBoolOption.error(String message) {
    return _ParsedBoolOption(value: false, nextIndex: 0, errorMessage: message);
  }

  final bool value;
  final int nextIndex;
  final String? errorMessage;
}

class _ParsedStringOption {
  const _ParsedStringOption({
    required this.value,
    required this.nextIndex,
    this.errorMessage,
  });

  factory _ParsedStringOption.error(String message) {
    return _ParsedStringOption(
      value: null,
      nextIndex: 0,
      errorMessage: message,
    );
  }

  final String? value;
  final int nextIndex;
  final String? errorMessage;
}
