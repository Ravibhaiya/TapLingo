import 'package:flutter/material.dart';
import 'package:taplingo/models/library_item.dart';

/// Step 1 of the add flow: name the novel/manga, then Search.
class AddItemDialog extends StatefulWidget {
  final LibraryType type;

  const AddItemDialog({super.key, required this.type});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.type == LibraryType.novel ? 'novel' : 'manga';

    return AlertDialog(
      title: Text('Name this $label'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.type == LibraryType.novel
                ? 'e.g. The Beginning After The End'
                : 'e.g. Solo Leveling',
            prefixIcon: const Icon(Icons.search),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Please enter a name';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Search'),
        ),
      ],
    );
  }
}
