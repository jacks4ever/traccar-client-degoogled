import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/qr_code_screen.dart';

import 'l10n/app_localizations.dart';
import 'preferences.dart';

class SimpleSettingsScreen extends StatefulWidget {
  const SimpleSettingsScreen({super.key});

  @override
  State<SimpleSettingsScreen> createState() => _SimpleSettingsScreenState();
}

class _SimpleSettingsScreenState extends State<SimpleSettingsScreen> {
  Future<void> _editSetting(String title, String key, bool isInt) async {
    final initialValue = isInt
        ? Preferences.instance.getInt(key)?.toString() ?? '0'
        : Preferences.instance.getString(key) ?? '';

    final controller = TextEditingController(text: initialValue);
    final errorMessage = AppLocalizations.of(context)!.invalidValue;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: isInt ? TextInputType.number : TextInputType.text,
          inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(AppLocalizations.of(context)!.okButton),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      if (isInt) {
        final value = int.tryParse(result);
        if (value != null) {
          await Preferences.instance.setInt(key, value);
          setState(() {});
        } else {
          messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } else {
        await Preferences.instance.setString(key, result);
        setState(() {});
      }
    }
  }

  Future<void> _resetSettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetTitle),
        content: Text(AppLocalizations.of(context)!.resetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.resetButton),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await Preferences.instance.clear();
      setState(() {});
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.resetMessage),
          ),
        );
      }
    }
  }

  Widget _buildBasicSettings() {
    return Column(
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.serverLabel),
          subtitle: Text(Preferences.instance.getString(Preferences.url) ?? ''),
          trailing: const Icon(Icons.edit),
          onTap: () => _editSetting(
            AppLocalizations.of(context)!.serverLabel,
            Preferences.url,
            false,
          ),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.idLabel),
          subtitle: Text(Preferences.instance.getString(Preferences.id) ?? ''),
          trailing: const Icon(Icons.edit),
          onTap: () => _editSetting(
            AppLocalizations.of(context)!.idLabel,
            Preferences.id,
            false,
          ),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.intervalLabel),
          subtitle: Text('${Preferences.instance.getInt(Preferences.interval) ?? 30}s'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editSetting(
            AppLocalizations.of(context)!.intervalLabel,
            Preferences.interval,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettings() {
    return Column(
      children: [
        const Divider(),
        ListTile(
          title: const Text('Distance Filter'),
          subtitle: Text('${Preferences.instance.getInt(Preferences.distance) ?? 0}m'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editSetting(
            'Distance Filter (meters)',
            Preferences.distance,
            true,
          ),
        ),
        ListTile(
          title: const Text('Angle Filter'),
          subtitle: Text('${Preferences.instance.getInt(Preferences.angle) ?? 0}°'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editSetting(
            'Angle Filter (degrees)',
            Preferences.angle,
            true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QrCodeScreen()),
              );
            },
            icon: const Icon(Icons.qr_code),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Basic Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _buildBasicSettings(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Advanced Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _buildAdvancedSettings(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.resetTitle),
                    subtitle: const Text('Reset all settings to default values'),
                    trailing: const Icon(Icons.restore),
                    onTap: _resetSettings,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Simple Degoogled Traccar Client\nVersion 9.5.2',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}