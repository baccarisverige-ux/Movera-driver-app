import 'package:movera/core/money/money.dart';

class EarningsPeriod {
  const EarningsPeriod({
    required this.periodId,
    required this.label,
    required this.gross,
    required this.commission,
    required this.tips,
    required this.adjustments,
  });

  final String periodId;
  final String label;
  final Money gross;
  final Money commission;
  final Money tips;
  final Money adjustments;

  Money get net => gross - commission + tips + adjustments;
}

abstract interface class EarningsRepository {
  List<EarningsPeriod> get all;

  Future<List<EarningsPeriod>> load();
}

class InMemoryEarningsRepository implements EarningsRepository {
  InMemoryEarningsRepository({List<EarningsPeriod>? seed})
    : _periods = List<EarningsPeriod>.from(seed ?? const []);

  final List<EarningsPeriod> _periods;

  @override
  List<EarningsPeriod> get all => List.unmodifiable(_periods);

  @override
  Future<List<EarningsPeriod>> load() async {
    if (_periods.isEmpty) {
      _periods.add(
        EarningsPeriod(
          periodId: '2026-W38',
          label: 'This week',
          gross: Money.sek(1724.15),
          commission: Money.sek(325.40),
          tips: Money.sek(84.00),
          adjustments: Money.ore(0),
        ),
      );
    }
    return all;
  }
}
