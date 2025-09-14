import 'package:flutter/material.dart';
import 'simple_settings_screen.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Screen'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SimpleSettingsScreen()),
            );
          },
          child: Text('Go to Settings'),
        ),
      ),
    );
  }
}
