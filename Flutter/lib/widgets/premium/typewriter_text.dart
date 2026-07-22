/// Typewriter reveal — text appears progressively like a live AI stream.
/// Total duration is capped so long outputs never make the user wait; a tap
/// skips straight to the full text. Honours reduce-motion (instant reveal).
library;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.maxDuration = const Duration(milliseconds: 1400),
    this.selectable = true,
  });

  final String text;
  final TextStyle? style;

  /// The whole reveal never takes longer than this, however long the text.
  final Duration maxDuration;

  /// Render as [SelectableText] so users can copy parts of the result.
  final bool selectable;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: widget.maxDuration,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _anim.value = 1;
      } else {
        _anim.forward();
      }
    });
  }

  @override
  void didUpdateWidget(TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      if (Motion.reduced(context)) {
        _anim.value = 1;
      } else {
        _anim.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _skip() {
    if (!_anim.isCompleted) _anim.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = Motion.easeOut.transform(_anim.value);
          final count = (widget.text.length * t).round();
          final visible = widget.text.substring(0, count.clamp(0, widget.text.length));
          final done = _anim.isCompleted;
          final display = done ? visible : '$visible▌';
          return widget.selectable && done
              ? SelectableText(display, style: widget.style)
              : Text(display, style: widget.style);
        },
      ),
    );
  }
}
