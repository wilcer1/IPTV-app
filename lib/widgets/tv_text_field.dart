import 'package:flutter/material.dart';

import '../screens/tv_keyboard_screen.dart';
import '../services/device_info.dart';

/// Drop-in replacement for [TextField] that, on Android TV, opens
/// [TvKeyboardScreen] instead of the OS's D-pad-broken native keyboard.
/// Everywhere else it behaves exactly like a plain [TextField].
class TvTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextStyle? style;
  final TextAlign textAlign;
  final String? keyboardTitle;

  const TvTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.style,
    this.textAlign = TextAlign.start,
    this.keyboardTitle,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final bool _isTv = DeviceInfo.isTvSync;
  bool _hasFocus = false;

  Future<void> _openKeyboard() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TvKeyboardScreen(
          initialText: widget.controller.text,
          obscureText: widget.obscureText,
          title: widget.keyboardTitle,
        ),
      ),
    );
    if (result != null) {
      widget.controller.text = result;
      widget.onChanged?.call(result);
      widget.onSubmitted?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTv) {
      return TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: widget.decoration,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        autofocus: widget.autofocus,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(14),
          onTap: _openKeyboard,
          onFocusChange: (focused) => setState(() => _hasFocus = focused),
          child: InputDecorator(
            decoration: widget.decoration ?? const InputDecoration(),
            isFocused: _hasFocus,
            child: Text(
              widget.obscureText
                  ? '•' * widget.controller.text.length
                  : widget.controller.text,
              style: widget.style,
              textAlign: widget.textAlign,
            ),
          ),
        );
      },
    );
  }
}
