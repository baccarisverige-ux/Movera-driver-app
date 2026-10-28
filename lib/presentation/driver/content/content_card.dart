import 'package:flutter/material.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';

/// One admin text from the Content page (driver-home, driver-event, help):
/// its title, its text in the driver's language and its https image.
class DriverContentCard extends StatelessWidget {
  const DriverContentCard({super.key, required this.item});

  final DriverContentItem item;

  @override
  Widget build(BuildContext context) {
    final image = item.image;
    return Container(
      key: ValueKey<String>('content-card-${item.slot}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E9EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            Image.network(
              image,
              key: ValueKey<String>('content-image-${item.slot}'),
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title.isNotEmpty)
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Color(0xFF111614),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  item.textIn(DriverAppTexts.language),
                  style: const TextStyle(
                    color: Color(0xFF5D6A70),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
