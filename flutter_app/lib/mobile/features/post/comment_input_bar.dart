import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../core/theme/mobile_colors.dart';

/// 评论输入框组件
/// 固定在底部，支持表情。[trailing] (the post's like / favorite / share, handoff
/// A2) shows while the field is idle; typing swaps it for 发送.
class CommentInputBar extends StatefulWidget {
  final Function(String) onSubmit;
  final String? placeholder;
  final bool autofocus;
  final ScrollController? scrollController;
  final VoidCallback? onEmojiToggle;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onTextFieldTap;
  final List<Widget> trailing;

  const CommentInputBar({
    super.key,
    required this.onSubmit,
    this.placeholder = '温柔地回应一下',
    this.autofocus = false,
    this.scrollController,
    this.onEmojiToggle,
    this.onFocusChanged,
    this.onTextFieldTap,
    this.trailing = const <Widget>[],
  });

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    if (_focusNode.hasFocus && widget.scrollController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollController!.hasClients) {
          widget.scrollController!.animateTo(
            widget.scrollController!.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSubmit(text);
    _controller.clear();
    setState(() {
      _hasText = false;
    });
  }

  /// 供父组件调用，插入表情到输入框
  void insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void requestFocus() {
    _focusNode.requestFocus();
  }

  void unfocus() {
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final ZxTokens t = ZxTokens.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool idle = !_hasText && !_focused && widget.trailing.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120, minHeight: 44),
              decoration: BoxDecoration(
                color: t.bgSunk,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onEmojiToggle,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 2, 11),
                      child: Icon(
                        Icons.sentiment_satisfied_outlined,
                        color: t.text3,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      onTap: widget.onTextFieldTap,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      style: ZxType.body.copyWith(color: t.text),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        hintText: widget.placeholder,
                        hintStyle: ZxType.body.copyWith(color: t.text3),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          6,
                          12,
                          14,
                          12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (idle)
            ...widget.trailing
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ZxButton(
                label: '发送',
                small: true,
                onPressed: _hasText ? _submit : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// 表情选择面板，从页面底部弹出
class EmojiPickerBar extends StatelessWidget {
  final void Function(String emoji) onEmojiTap;

  const EmojiPickerBar({super.key, required this.onEmojiTap});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '😮‍💨',
      '🤥',
      '😌',
      '😔',
      '😪',
      '🤤',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '😵',
      '🤯',
      '🤠',
      '🥳',
      '😎',
      '🤓',
      '😕',
      '😟',
      '🙁',
      '😮',
      '😯',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😢',
      '😭',
      '😱',
      '👍',
      '👎',
      '👏',
      '🙌',
      '🤝',
      '🙏',
      '💪',
      '🤘',
    ];

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onEmojiTap(emojis[index]),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }
}
