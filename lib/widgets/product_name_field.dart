import 'package:flutter/material.dart';

import '../data/suggestions.dart';
import '../models/grocery_category.dart';

/// Text field with live product suggestions ("m" -> Mandalina, Muz...).
/// Reports free text plus the picked/exact-matched suggestion.
class ProductNameField extends StatelessWidget {
  final String label;
  final String initialText;
  final void Function(String text, SuggestedProduct? match) onChanged;

  const ProductNameField({
    super.key,
    this.label = 'Ürün adı',
    this.initialText = '',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<SuggestedProduct>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: (o) => o.name,
      optionsBuilder: (value) => searchSuggestions(value.text),
      onSelected: (o) => onChanged(o.name, o),
      fieldViewBuilder:
          (ctx, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textInputAction: TextInputAction.next,
          onChanged: (v) => onChanged(v, exactSuggestion(v)),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (c, i) {
                  final o = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: Icon(o.category.icon,
                        size: 18, color: o.category.tint),
                    title: Text(o.name),
                    subtitle: Text(
                        '${o.category.shortName} • ${o.unit.abbreviation}'),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
