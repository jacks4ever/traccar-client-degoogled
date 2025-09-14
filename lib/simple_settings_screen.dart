import 'package:flutter/material.dart';

class SimpleSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Simple Settings'),
      ),
      body: Center(
        child: Text('This is the simple settings screen.'),
      ),
    );
  }
}
