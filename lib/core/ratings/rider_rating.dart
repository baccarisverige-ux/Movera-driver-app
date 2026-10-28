import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// Contract v0.9.0 `contract.json#ratings.tags` (owner real-data decision,
/// part 3): one fixed list of tag codes, the same in every country. A driver
/// may give the rider these (`aboutRider`); the words are the app's own.
abstract final class RiderRatingTags {
  static const aboutRider = <String>['on_time', 'polite', 'clear_pickup'];

  /// `contract.json#ratings.tags.maxPerRating`.
  static const maxPerRating = 5;

  /// `RatingRequest.comment` maxLength.
  static const commentMaxLength = 2000;

  static String label(String code) => switch (code) {
    'on_time' => tr.ratingTagOnTime,
    'polite' => tr.ratingTagPolite,
    'clear_pickup' => tr.ratingTagClearPickup,
    _ => code,
  };
}

/// What happened to the driver's rating of the rider.
enum RiderRatingOutcome { sent, demo, failed }

/// Sends the driver's rating of the rider: `POST /trips/{tripId}/rating`
/// with whole stars, the tags from the fixed list and an optional comment.
class RiderRatingSender {
  RiderRatingSender({ApiClient? api}) : _api = api;

  /// The live build's signed client; null in the demo, where nothing is
  /// sent (and the screen says so).
  factory RiderRatingSender.fromApp() =>
      RiderRatingSender(api: LiveDriverServices.instance?.api);

  final ApiClient? _api;

  bool get live => _api != null;

  /// The body the contract takes; throws [ArgumentError] for a value the
  /// server would refuse.
  static Map<String, Object> body({
    required int stars,
    List<String> tags = const <String>[],
    String? comment,
  }) {
    if (stars < 1 || stars > 5) throw ArgumentError.value(stars, 'stars');
    if (tags.any((tag) => !RiderRatingTags.aboutRider.contains(tag)) ||
        tags.toSet().length != tags.length ||
        tags.length > RiderRatingTags.maxPerRating) {
      throw ArgumentError.value(tags, 'tags');
    }
    final note = comment?.trim() ?? '';
    if (note.length > RiderRatingTags.commentMaxLength) {
      throw ArgumentError.value(comment, 'comment');
    }
    return {
      'stars': stars,
      if (tags.isNotEmpty) 'tags': tags,
      if (note.isNotEmpty) 'comment': note,
    };
  }

  Future<RiderRatingOutcome> send({
    required String tripId,
    required int stars,
    List<String> tags = const <String>[],
    String? comment,
  }) async {
    final payload = body(stars: stars, tags: tags, comment: comment);
    final api = _api;
    if (api == null || tripId.trim().isEmpty) return RiderRatingOutcome.demo;
    try {
      await api.post(
        '/api/v1/trips/${Uri.encodeComponent(tripId)}/rating',
        body: payload,
        idempotencyKey: 'rating-${ApiClient.randomKey()}',
      );
      return RiderRatingOutcome.sent;
    } catch (_) {
      return RiderRatingOutcome.failed;
    }
  }
}
