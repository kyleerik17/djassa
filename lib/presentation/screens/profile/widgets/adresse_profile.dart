import 'package:djassa/core/theme/djassa_theme.dart';
import 'package:djassa/presentation/providers/core_providers.dart';
import 'package:djassa/presentation/screens/profile/widgets/profile_string.dart';
import 'package:flutter/material.dart';



/// Affiche le dialog de sélection ville/commune et retourne `true` si
/// une adresse a été enregistrée (l'appelant peut alors afficher un
/// SnackBar de confirmation via AppSnackbar).
Future<bool> showDeliveryAddressDialog(
  BuildContext context, {
  required String? initialCity,
  required String? initialCommune,
  required Future<void> Function(String city, String commune) onSave,
}) async {
  String? selectedCity = initialCity;
  String? selectedCommune = initialCommune;
  bool showError = false;
  bool saved = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setStateDialog) {
        final communes = selectedCity == null
            ? <String>[]
            : deliveryCitiesCommunes[selectedCity!] ?? <String>[];

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    DjassaTheme.accentOrange.withValues(alpha: .12),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: DjassaTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text(ProfileStrings.addressDialogTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                ProfileStrings.addressDialogDescription,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCity,
                decoration: InputDecoration(
                  labelText: ProfileStrings.addressCityLabel,
                  prefixIcon: const Icon(Icons.location_city_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: deliveryCitiesCommunes.keys
                    .map(
                      (city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setStateDialog(() {
                    selectedCity = value;
                    selectedCommune = null;
                    showError = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    communes.contains(selectedCommune) ? selectedCommune : null,
                decoration: InputDecoration(
                  labelText: ProfileStrings.addressCommuneLabel,
                  prefixIcon: const Icon(Icons.map_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                hint: Text(
                  selectedCity == null
                      ? ProfileStrings.addressCommuneHintNoCity
                      : ProfileStrings.addressCommuneHint,
                ),
                items: communes
                    .map(
                      (commune) => DropdownMenuItem(
                        value: commune,
                        child: Text(commune),
                      ),
                    )
                    .toList(),
                onChanged: selectedCity == null
                    ? null
                    : (value) {
                        setStateDialog(() {
                          selectedCommune = value;
                          showError = false;
                        });
                      },
              ),
              if (showError) ...[
                const SizedBox(height: 8),
                Text(
                  ProfileStrings.addressValidationError,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(ProfileStrings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (selectedCity == null || selectedCommune == null) {
                  setStateDialog(() => showError = true);
                  return;
                }
                await onSave(selectedCity!, selectedCommune!);
                saved = true;
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text(ProfileStrings.save),
            ),
          ],
        );
      },
    ),
  );

  return saved;
}
