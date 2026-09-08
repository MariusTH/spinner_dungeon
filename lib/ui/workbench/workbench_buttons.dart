import 'package:flutter/material.dart';

import 'workbench_palette.dart';

class WorkbenchOutlineButton extends StatelessWidget {
  const WorkbenchOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: WorkbenchPalette.woodPlank,
            border: Border.all(color: WorkbenchPalette.ink, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: WorkbenchPalette.parchment,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkbenchPrimaryButton extends StatelessWidget {
  const WorkbenchPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: enabled
                  ? <Color>[
                      WorkbenchPalette.actionHighlight,
                      const Color(0xFFE8C200),
                    ]
                  : <Color>[
                      WorkbenchPalette.woodDark,
                      WorkbenchPalette.wood,
                    ],
            ),
            border: Border.all(
              color: enabled ? WorkbenchPalette.ink : WorkbenchPalette.woodEdge,
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: enabled ? 0.28 : 0.15),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? WorkbenchPalette.ink
                      : WorkbenchPalette.parchment.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
