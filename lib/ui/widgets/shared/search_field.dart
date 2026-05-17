import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final IconData? trailingIcon;

  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialValue = '',
    this.trailingIcon,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(kButtonRadius),
        border: Border.all(color: palette.border),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
        style: Theme.of(context).textTheme.bodyMedium,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: palette.mutedForeground,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: palette.mutedForeground,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                )
              : widget.trailingIcon == null
              ? null
              : Icon(
                  widget.trailingIcon,
                  size: 20,
                  color: palette.mutedForeground,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
