import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_utils.dart';

typedef OnKeyboardInput = void Function(String text);

class TvKeyboard extends StatefulWidget {
  final OnKeyboardInput onInput;
  final VoidCallback onSubmit;
  final String initialText;

  const TvKeyboard({
    super.key,
    required this.onInput,
    required this.onSubmit,
    this.initialText = '',
  });

  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  late List<List<String>> _keyboardLayout;
  int _selectedRow = 0;
  int _selectedCol = 0;
  String _input = '';
  bool _capsLock = false;
  bool _isSymbols = false;

  @override
  void initState() {
    super.initState();
    _input = widget.initialText;
    _initializeKeyboard();
  }

  void _initializeKeyboard() {
    if (_isSymbols) {
      _keyboardLayout = [
        ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'],
        ['-', '_', '=', '+', '[', ']', '{', '}', '|', '\\'],
        [';', ':', '\'', '"', '<', '>', ',', '.', '?', '/'],
        ['SPACE', 'BACKSPACE', 'CLEAR', 'ABC', 'DONE'],
      ];
    } else {
      _keyboardLayout = [
        [
          'Q',
          'W',
          'E',
          'R',
          'T',
          'Y',
          'U',
          'I',
          'O',
          'P',
        ],
        ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
        ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
        ['SPACE', 'BACKSPACE', 'CLEAR', 'SYM', 'CAPS', 'DONE'],
      ];
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      setState(() {
        _selectedRow = (_selectedRow - 1).clamp(0, _keyboardLayout.length - 1);
        _selectedCol = _selectedCol.clamp(
          0,
          _keyboardLayout[_selectedRow].length - 1,
        );
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      setState(() {
        _selectedRow = (_selectedRow + 1).clamp(0, _keyboardLayout.length - 1);
        _selectedCol = _selectedCol.clamp(
          0,
          _keyboardLayout[_selectedRow].length - 1,
        );
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      setState(() {
        _selectedCol =
            (_selectedCol - 1).clamp(0, _keyboardLayout[_selectedRow].length - 1);
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      setState(() {
        _selectedCol =
            (_selectedCol + 1).clamp(0, _keyboardLayout[_selectedRow].length - 1);
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
        event.isKeyPressed(LogicalKeyboardKey.enter)) {
      _pressKey(_keyboardLayout[_selectedRow][_selectedCol]);
    }
  }

  void _pressKey(String key) {
    setState(() {
      if (key == 'SPACE') {
        _input += ' ';
      } else if (key == 'BACKSPACE') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (key == 'CLEAR') {
        _input = '';
      } else if (key == 'CAPS') {
        _capsLock = !_capsLock;
      } else if (key == 'SYM') {
        _isSymbols = !_isSymbols;
        _selectedRow = 0;
        _selectedCol = 0;
        _initializeKeyboard();
        return;
      } else if (key == 'ABC') {
        _isSymbols = false;
        _selectedRow = 0;
        _selectedCol = 0;
        _initializeKeyboard();
        return;
      } else if (key == 'DONE') {
        widget.onSubmit();
        return;
      } else {
        if (!_isSymbols && _capsLock) {
          _input += key;
        } else if (!_isSymbols && !_capsLock) {
          _input += key.toLowerCase();
        } else {
          _input += key;
        }
      }
      widget.onInput(_input);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input display
          Container(
            padding: EdgeInsets.all(TvUtils.responsivePadding(16, context)),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(
                TvUtils.responsivePadding(12, context),
              ),
              border: Border.all(
                color: Colors.grey,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _input.isEmpty ? 'Start typing...' : _input,
                    style: TextStyle(
                      color: _input.isEmpty ? Colors.grey : Colors.white,
                      fontSize: TvUtils.responsiveFontSize(
                        20,
                        context,
                        maxSize: 36,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_input.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() => _input = '');
                      widget.onInput('');
                    },
                    child: Icon(
                      Icons.clear,
                      color: Colors.red,
                      size: TvUtils.responsiveFontSize(24, context, maxSize: 40),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(24, context)),

          // Keyboard
          Container(
            padding: EdgeInsets.all(TvUtils.responsivePadding(16, context)),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(
                TvUtils.responsivePadding(12, context),
              ),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int row = 0; row < _keyboardLayout.length; row++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: row < _keyboardLayout.length - 1
                          ? TvUtils.responsivePadding(8, context)
                          : 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int col = 0;
                            col < _keyboardLayout[row].length;
                            col++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: col < _keyboardLayout[row].length - 1
                                  ? TvUtils.responsivePadding(8, context)
                                  : 0,
                            ),
                            child: _buildKey(
                              _keyboardLayout[row][col],
                              row,
                              col,
                            ),
                          ),
                      ],
                    ),
                  ),

                // Status row
                SizedBox(height: TvUtils.responsivePadding(16, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isSymbols) ...[
                      _buildStatus('CAPS', _capsLock),
                      SizedBox(width: TvUtils.responsivePadding(16, context)),
                    ],
                    _buildStatus(
                      _isSymbols ? 'ABC' : 'SYM',
                      _isSymbols,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String key, int row, int col) {
    final isFocused = _selectedRow == row && _selectedCol == col;
    final isSpecial = [
      'SPACE',
      'BACKSPACE',
      'CLEAR',
      'SYM',
      'ABC',
      'CAPS',
      'DONE'
    ].contains(key);

    double keyWidth;
    if (key == 'SPACE') {
      keyWidth = 150 * TvUtils.getScaleFactor(context);
    } else if (key == 'BACKSPACE' ||
        key == 'CLEAR' ||
        key == 'SYM' ||
        key == 'ABC' ||
        key == 'CAPS' ||
        key == 'DONE') {
      keyWidth = 90 * TvUtils.getScaleFactor(context);
    } else {
      keyWidth = 60 * TvUtils.getScaleFactor(context);
    }

    keyWidth = keyWidth.clamp(40, 200);

    return GestureDetector(
      onTap: () => _pressKey(key),
      child: Container(
        width: keyWidth,
        height: TvUtils.responsiveButtonHeight(context) * 0.6,
        decoration: BoxDecoration(
          color: isFocused
              ? const Color(0xFFE50914)
              : (isSpecial ? Colors.grey[700] : Colors.grey[800]),
          border: Border.all(
            color: isFocused ? Colors.white : Colors.transparent,
            width: isFocused ? 3 : 0,
          ),
          borderRadius: BorderRadius.circular(
            TvUtils.responsivePadding(8, context),
          ),
        ),
        child: Center(
          child: Text(
            key,
            style: TextStyle(
              color: isFocused ? Colors.white : Colors.white70,
              fontSize: TvUtils.responsiveFontSize(
                14,
                context,
                maxSize: 28,
              ),
              fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(String label, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(12, context),
        vertical: TvUtils.responsivePadding(6, context),
      ),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE50914) : Colors.grey[700],
        borderRadius: BorderRadius.circular(
          TvUtils.responsivePadding(6, context),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: TvUtils.responsiveFontSize(
            12,
            context,
            maxSize: 18,
          ),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
