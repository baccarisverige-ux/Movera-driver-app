import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
class DocumentPreview extends StatelessWidget {
 const DocumentPreview({super.key, required this.title});
 final String title;
 @override
 Widget build(BuildContext context) => Scaffold(
 appBar: AppBar(title: Text(title)),
 body: Padding(padding: EdgeInsets.all(24), child: Text(
 tr.docPreviewNotAvailable)),
 );
}
