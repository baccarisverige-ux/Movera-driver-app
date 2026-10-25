import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/vehicles/live_vehicles_screen.dart';
import 'package:movera/presentation/driver/add%20vehicle/add_vehicle.dart';

class DriverVehicles extends StatefulWidget {
  const DriverVehicles({super.key});

  @override
  State<DriverVehicles> createState() => _DriverVehiclesState();
}

class _DriverVehiclesState extends State<DriverVehicles> {
  final _store = LocalVehicleStore();
  List<Map<String, dynamic>> _vehicles = [];
  bool _failed = false;
  bool _loading = true;
  bool _restoring = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted || _restoring) return;
    _restoring = true;
    setState(() => _loading = true);
    try {
      final rows = await _store.list();
      if (mounted) {
        setState(() {
          _vehicles = rows;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _restoring = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  @override
  Widget build(BuildContext context) {
    // Round 4 (live): the fleet's cars from the server, with the pick.
    if (DriverRuntimeConfig.current.authRequired) {
      final session = accountSessionOf(context);
      if (session != null) return LiveVehiclesScreen(account: session);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        title: Text(
          tr.vehicles,
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: tr.addVehicle,
            onPressed: _loading || _failed
                ? null
                : () async {
                    await pushSingle(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AddVehicle(),
                      ),
                    );
                    if (mounted) {
                      await _load();
                    }
                  },
            icon: const Icon(Icons.add_rounded, color: _ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            TextButton(
              onPressed: _loading ? null : _load,
              child: Text(tr.vehCouldNotLoadDrafts),
            ),
          Text(tr.vehLocalDraftsNotVerified),
          for (final vehicle in _vehicles)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 26,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vehicle['plate'] as String,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr.vehTripsOnly,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _loading || _failed
                          ? null
                          : () async {
                              await pushSingle(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => VehicleDocuments(
                                    vehicleId: vehicle['id'] as String,
                                    make: vehicle['make'] as String,
                                    model: vehicle['model'] as String,
                                    year: vehicle['year'] as String,
                                    plate: vehicle['plate'] as String,
                                  ),
                                ),
                              );
                              if (mounted) {
                                await _load();
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF4F6F7),
                        foregroundColor: _ink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr.vehManageVehicles,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.vehExploreOpportunities,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  tr.vehConnectFleetPartner,
                  style: TextStyle(
                    color: Color(0xFFD5DCE0),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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
