import '../../systems/spinner_parts.dart';

/// Payload for [LongPressDraggable] / [DragTarget] on the spinner workbench.
class SpinnerPartDragData {
  const SpinnerPartDragData({required this.partId, this.sourceSlot});

  final String partId;
  /// When dragging from a socket, the slot the piece was lifted from.
  final SpinnerPartSlot? sourceSlot;
}
