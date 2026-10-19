import 'package:flutter/material.dart';
class DocumentPreview extends StatelessWidget {
 const DocumentPreview({super.key, required this.title});
 final String title;
 @override
 Widget build(BuildContext context) => Scaffold(
 appBar: AppBar(title: Text(title)),
 body: const Padding(padding: EdgeInsets.all(24), child: Text(
 'Not available yet — sample page. Sending this document is not part of '
 'the app yet. No document was uploaded or reviewed.')),
 );
}
