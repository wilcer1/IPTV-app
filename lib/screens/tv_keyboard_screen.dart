import 'package:flutter/material.dart';

/// A fully Flutter-rendered on-screen keyboard for text entry on Android TV.
///
/// Android's native soft keyboard doesn't respond to D-pad input on real TV
/// hardware (an unfixed Flutter engine bug: flutter/flutter#125541,
/// #177360), so this bypasses it entirely — every key here is an ordinary
/// focusable widget, navigated by Flutter's own directional focus system,
/// which already works correctly with the remote elsewhere in this app.
class TvKeyboardScreen extends StatefulWidget {
  final String initialText;
  final bool obscureText;
  final String? title;

  const TvKeyboardScreen({
    super.key,
    required this.initialText,
    this.obscureText = false,
    this.title,
  });

  @override
  State<TvKeyboardScreen> createState() => _TvKeyboardScreenState();
}

class _TvKeyboardScreenState extends State<TvKeyboardScreen> {
  static const _lettersRows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
  static const _symbolsRows = ['1234567890', '@#\$_&-+()/*"', ':;!?~.,\'%='];

  late String _text;
  bool _shift = false;
  bool _symbols = false;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
  }

  void _append(String char) {
    setState(() {
      _text += _shift ? char.toUpperCase() : char;
      _shift = false;
    });
  }

  void _backspace() {
    if (_text.isEmpty) return;
    setState(() => _text = _text.substring(0, _text.length - 1));
  }

  void _done() => Navigator.of(context).pop(_text);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = _symbols ? _symbolsRows : _lettersRows;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Enter text')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.obscureText ? '•' * _text.length : _text,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 24),
              FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < rows.length; r++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var c = 0; c < rows[r].length; c++)
                              _KeyButton(
                                label: _shift && !_symbols
                                    ? rows[r][c].toUpperCase()
                                    : rows[r][c],
                                onTap: () => _append(rows[r][c]),
                                autofocus: r == 0 && c == 0,
                              ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _KeyButton(
                          label: _symbols ? 'ABC' : (_shift ? '⇧' : 'abc'),
                          wide: true,
                          selected: _shift && !_symbols,
                          onTap: () => setState(() {
                            if (_symbols) {
                              _symbols = false;
                            } else {
                              _shift = !_shift;
                            }
                          }),
                        ),
                        _KeyButton(
                          label: _symbols ? '123' : '#+=',
                          wide: true,
                          onTap: () => setState(() => _symbols = !_symbols),
                        ),
                        _KeyButton(label: 'space', wide: true, onTap: () => _append(' ')),
                        _KeyButton(label: '⌫', wide: true, onTap: _backspace),
                        _KeyButton(
                          label: 'Done',
                          wide: true,
                          selected: true,
                          onTap: _done,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final bool wide;
  final bool selected;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.wide = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        width: wide ? 76 : 44,
        height: 44,
        child: Material(
          color: selected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            autofocus: autofocus,
            borderRadius: BorderRadius.circular(8),
            focusColor: colorScheme.primary.withValues(alpha: 0.5),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
