import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// A sample image preview. Camera capture and ID submission are not connected.
class TakeIdPhoto extends StatelessWidget {
  const TakeIdPhoto({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr.idPhotoPreview),
      leading: IconButton(
        tooltip: tr.back,
        onPressed: () => popOwned(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          tr.idPhotoSampleOnly,
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 24),
        Image.asset(AppAssets.id, height: 226, fit: BoxFit.contain),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('id-preview-return'),
          onPressed: () {
            if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
              return;
            }
            // driver-r3-10: in the app, Sign in or Starter is the first
            // route here, not Home; "Return to home" opens Home itself.
            final runtime = DriverRuntimeScope.maybeOf(context);
            if (runtime == null) {
              Navigator.of(context).popUntil((route) => route.isFirst);
              return;
            }
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => runtime.homeBuilder()),
              (_) => false,
            );
          },
          child: Text(tr.returnToHome),
        ),
        TextButton(
          onPressed: null,
          child: Text(tr.retakeUnavailablePreview),
        ),
      ],
    ),
  );
}
