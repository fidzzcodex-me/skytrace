import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/request.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';

class HeaderEditor extends StatefulWidget {
  const HeaderEditor({super.key, required this.initial, required this.addLabel});

  final List<HeaderPair> initial;
  final String addLabel;

  @override
  State<HeaderEditor> createState() => HeaderEditorState();
}

class HeaderEditorState extends State<HeaderEditor> {
  final List<TextEditingController> _names = [];
  final List<TextEditingController> _values = [];

  @override
  void initState() {
    super.initState();
    for (final h in widget.initial) {
      _names.add(TextEditingController(text: h.name));
      _values.add(TextEditingController(text: h.value));
    }
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    for (final c in _values) {
      c.dispose();
    }
    super.dispose();
  }

  List<HeaderPair> get headers {
    final out = <HeaderPair>[];
    for (var i = 0; i < _names.length; i++) {
      final name = _names[i].text.trim();
      if (name.isEmpty) continue;
      out.add(HeaderPair(name, _values[i].text));
    }
    return out;
  }

  void _add() {
    setState(() {
      _names.add(TextEditingController());
      _values.add(TextEditingController());
    });
  }

  void _remove(int i) {
    setState(() {
      _names.removeAt(i).dispose();
      _values.removeAt(i).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _names.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _names[i],
                    style: AppText.mono(p),
                    decoration: AppComponents.input(p, hint: 'Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _values[i],
                    style: AppText.mono(p),
                    decoration: AppComponents.input(p, hint: 'Value'),
                  ),
                ),
                IconButton(
                  onPressed: () => _remove(i),
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 14, color: AppColors.errorRed),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _add,
          icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
          label: Text(widget.addLabel),
        ),
      ],
    );
  }
}
