import 'package:flutter/material.dart';

/// Wraps [child] with tactile press feedback: a quick scale-down on
/// touch-down, back to full size on release/cancel. Use around anything
/// tappable that should feel physical rather than flat — a card, a row, a
/// tab button — in addition to (not instead of) its own ripple/InkWell.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child, this.borderRadius});

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
