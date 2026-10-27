import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/profile.dart';

/// Closes the keyboard, so a picker and the keyboard never show together.
void _closeKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// The first day a birthday can be picked, and the last (today, UTC).
final DateTime earliestPickableBirthday = DateTime(1900, 1, 2);

DateTime latestPickableBirthday() {
  final now = DateTime.now().toUtc();
  return DateTime(now.year, now.month, now.day);
}

Future<DateTime?> pickBirthday(BuildContext context, DateTime? current) async {
  _closeKeyboard();
  final last = latestPickableBirthday();
  final initial = current == null
      ? DateTime(last.year - 25)
      : DateTime(current.year, current.month, current.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(last) ? last : initial,
    firstDate: earliestPickableBirthday,
    lastDate: last,
    helpText: 'Birthday',
  );
  return picked == null
      ? null
      : DateTime.utc(picked.year, picked.month, picked.day);
}

/// The code of the country picked, or null when the sheet was dismissed.
Future<String?> pickCountry(BuildContext context, String? current) {
  _closeKeyboard();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CountrySheet(selected: current),
  );
}

Future<Gender?> pickGender(BuildContext context, Gender? current) {
  _closeKeyboard();
  return showModalBottomSheet<Gender>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final gender in Gender.values)
            ListTile(
              title: Text(gender.label),
              selected: gender == current,
              trailing: gender == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(gender),
            ),
        ],
      ),
    ),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});

  final String? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Country> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return Country.all;
    return [
      for (final country in Country.all)
        if (country.name.toLowerCase().contains(query) ||
            country.code.toLowerCase() == query)
          country,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            MediaQuery.sizeOf(context).height *
            AppProfileSizes.pickerSheetHeightFactor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _search,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No country found'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final country = matches[index];
                        final selected = country.code == widget.selected;
                        return ListTile(
                          title: Text(country.name),
                          selected: selected,
                          trailing: selected ? const Icon(Icons.check) : null,
                          onTap: () => Navigator.of(context).pop(country.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
