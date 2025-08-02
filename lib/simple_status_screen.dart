import 'package:flutter/material.dart';
import 'package:traccar_client/simple_location_service.dart';
import 'package:traccar_client/preferences.dart';

import 'l10n/app_localizations.dart';

class SimpleStatusScreen extends StatefulWidget {
  const SimpleStatusScreen({super.key});

  @override
  State<SimpleStatusScreen> createState() => _SimpleStatusScreenState();
}

class _SimpleStatusScreenState extends State<SimpleStatusScreen> {
  Map<String, dynamic>? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await SimpleLocationService.getStatus();
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _status = {'error': error.toString()};
        _isLoading = false;
      });
    }
  }

  Widget _buildStatusCard() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_status == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No status available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Service Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Tracking Active', _status!['tracking']?.toString() ?? 'Unknown'),
            if (_status!.containsKey('latitude') && _status!.containsKey('longitude')) ...[
              _buildStatusRow('Latitude', _status!['latitude']?.toStringAsFixed(6) ?? 'Unknown'),
              _buildStatusRow('Longitude', _status!['longitude']?.toStringAsFixed(6) ?? 'Unknown'),
              _buildStatusRow('Accuracy', '${_status!['accuracy']?.toStringAsFixed(1) ?? 'Unknown'}m'),
            ],
            if (_status!.containsKey('timestamp'))
              _buildStatusRow('Last Update', _status!['timestamp'] ?? 'Unknown'),
            if (_status!.containsKey('error'))
              _buildStatusRow('Error', _status!['error'] ?? 'None', isError: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    final server = Preferences.instance.getString(Preferences.url);
    final deviceId = Preferences.instance.getString(Preferences.id);
    final interval = Preferences.instance.getInt(Preferences.interval) ?? 30;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Server URL', server ?? 'Not configured'),
            _buildStatusRow('Device ID', deviceId ?? 'Not configured'),
            _buildStatusRow('Update Interval', '${interval}s'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statusTitle),
        actions: [
          IconButton(
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildConfigCard(),
            const SizedBox(height: 32),
            Text(
              'Simple Degoogled Traccar Client\nNative GPS Location Service',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}