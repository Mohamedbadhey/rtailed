import 'package:flutter/material.dart';
import 'package:retail_management/utils/translate.dart';

class VendorsScreen extends StatelessWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'Vendors')),
      ),
      body: Center(
        child: Text(
          t(context, 'Vendors management will be here.'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
} 