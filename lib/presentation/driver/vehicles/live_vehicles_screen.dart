import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/account/add_car_screen.dart';
import 'package:movera/presentation/driver/account/fleet_actions.dart';
import 'package:movera/presentation/driver/account/fleet_car_card.dart';
import 'package:movera/presentation/driver/account/join_fleet_screen.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Vehicles, live: the fleet's cars (`GET /driver/vehicles`) with the one
/// this driver drives; the owner adds cars here too. A driver account
/// without a fleet sees that the fleet's vehicle details are awaited.
class LiveVehiclesScreen extends StatefulWidget {
  const LiveVehiclesScreen({super.key, required this.account});

  final DriverAccountSession account;

  @override
  State<LiveVehiclesScreen> createState() => _LiveVehiclesScreenState();
}

class _LiveVehiclesScreenState extends State<LiveVehiclesScreen> {
  List<FleetVehicle> _cars = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    widget.account.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    widget.account.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cars = await widget.account.repository.vehicles();
      if (!mounted) return;
      setState(() => _cars = cars);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(error, fallback: tr.acctTryAgain),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(FleetVehicle vehicle) async {
    setState(() => _busyId = vehicle.vehicleId);
    try {
      if (await pickFleetCar(context, widget.account, vehicle)) await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _addCar() async {
    await pushSingle(
      context,
      RightToLeftTransition(AddCarScreen(account: widget.account)),
    );
    if (mounted) await _load();
  }

  Future<void> _join() async {
    await pushSingle(
      context,
      RightToLeftTransition(JoinFleetScreen(account: widget.account)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.account.account;
    final owner = me?.fleet?.isOwner ?? false;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.vehicles,
        onBack: () => maybePopOwned(context),
        actions: [
          if (owner)
            IconButton(
              key: const ValueKey('vehicles-add'),
              tooltip: tr.fleetAddCar,
              onPressed: _addCar,
              icon: const Icon(Icons.add_rounded, color: AccountStyle.ink),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AccountStyle.ink,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (_loading)
                const LinearProgressIndicator(color: AccountStyle.ink),
              if (_error != null) ...[
                AccountErrorLine(_error!),
                const SizedBox(height: 10),
                AccountButton(
                  label: tr.retry,
                  outlined: true,
                  onPressed: _load,
                ),
              ],
              if (me != null && me.awaitsFleet) ...[
                Text(
                  tr.holdWaitingFleetVehicle,
                  key: const ValueKey('vehicles-awaiting-fleet'),
                  style: AccountStyle.rowTitle(),
                ),
                const SizedBox(height: 6),
                Text(tr.fleetVehiclesAwait, style: AccountStyle.hint()),
                const SizedBox(height: 16),
                AccountButton(
                  key: const ValueKey('vehicles-join'),
                  label: tr.fleetJoinLink,
                  outlined: true,
                  onPressed: _join,
                ),
              ] else if (!_loading && _cars.isEmpty && _error == null)
                Text(
                  owner ? tr.fleetNoCars : tr.fleetNoCarsMember,
                  style: AccountStyle.hint(),
                ),
              for (final car in _cars) ...[
                FleetCarCard(
                  vehicle: car,
                  myDriverId: me?.driverId ?? '',
                  busy: _busyId == car.vehicleId,
                  onPick: () => _pick(car),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
