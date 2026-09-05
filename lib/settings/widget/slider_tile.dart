import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeric slider setting row: an icon and title on the left, a slider with
/// a drag label and a compact manual-entry field for exact values on the
/// right, plus an optional reset action.
///
/// Values are edited in the display unit; [format] renders the stored value
/// for the slider label and [parse] converts typed text back to a stored
/// value (e.g. font scale is stored as a factor but shown and typed as %).
/// Typed values outside [min]…[max] are clamped; invalid text restores the
/// current value.
class SliderSettingTile extends StatefulWidget {
  const SliderSettingTile({
    super.key,
    required this.title,
    required this.icon,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.format,
    required this.parse,
    this.divisions,
    this.suffix,
    this.onReset,
  });

  final String title;
  final IconData icon;

  /// Stored-value range.
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  /// Snap steps of the slider; the text field stays continuous.
  final int? divisions;

  /// Renders the stored value for the slider label and the text field while
  /// it is not being edited.
  final String Function(double value) format;

  /// Converts typed text to a stored value; null when the text is not a
  /// number.
  final double? Function(String text) parse;

  /// Unit suffix shown inside the text field (e.g. "dp", "%").
  final String? suffix;
  final VoidCallback? onReset;

  @override
  State<SliderSettingTile> createState() => _SliderSettingTileState();
}

class _SliderSettingTileState extends State<SliderSettingTile> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.format(widget.value),
  );
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      _editing = true;
    } else if (_editing) {
      _editing = false;
      _commit(_controller.text);
    }
  }

  void _commit(String text) {
    final parsed = widget.parse(text.trim());
    if (parsed == null) {
      _sync();
      return;
    }
    final clamped = parsed.clamp(widget.min, widget.max);
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    } else {
      _sync();
    }
  }

  void _sync() {
    final text = widget.format(widget.value);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void didUpdateWidget(covariant SliderSettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.value != oldWidget.value) {
      _sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon),
      title: Text(widget.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: widget.value.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                label: widget.format(widget.value),
                onChanged: (value) {
                  _editing = false;
                  widget.onChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 84,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textAlign: TextAlign.end,
                textAlignVertical: TextAlignVertical.center,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: widget.suffix,
                  suffixStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: dimTextColor(context),
                  ),
                ),
                onSubmitted: (text) {
                  // Mark the edit as finished so the pending focus loss
                  // does not commit the same text a second time.
                  _editing = false;
                  _commit(text);
                },
              ),
            ),
          ],
        ),
      ),
      trailing: widget.onReset == null
          ? null
          : IconButton(
              tooltip: 'Restore defaults'.tr,
              icon: const Icon(Icons.restart_alt),
              onPressed: widget.onReset,
            ),
    );
  }
}
