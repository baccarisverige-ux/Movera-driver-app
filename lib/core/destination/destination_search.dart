import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One place the driver can pick as his Destination mode address
/// (G3-D3): a server search answer, one of his last destinations, or a
/// demo place.
@immutable
class DestinationPlace {
  const DestinationPlace({
    required this.id,
    required this.name,
    required this.address,
    this.position,
    this.placeId,
    this.recent = false,
  });

  /// From `AddressSuggestion` (`POST /locations/autocomplete`).
  static DestinationPlace? fromSuggestion(Object? json, int index) {
    if (json is! Map) return null;
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) return null;
    final subtitle = json['subtitle'];
    final lat = json['latitude'];
    final lng = json['longitude'];
    final placeId = json['placeId'];
    return DestinationPlace(
      id: placeId is String && placeId.isNotEmpty
          ? 'place-$placeId'
          : 'search-$index',
      name: title.trim(),
      address: subtitle is String && subtitle.trim().isNotEmpty
          ? '${title.trim()}, ${subtitle.trim()}'
          : title.trim(),
      position: lat is num && lng is num
          ? GeoPoint(lat.toDouble(), lng.toDouble())
          : null,
      placeId: placeId is String && placeId.isNotEmpty ? placeId : null,
    );
  }

  static DestinationPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final address = json['address'];
    final lat = json['lat'];
    final lng = json['lng'];
    if (name is! String || address is! String || lat is! num || lng is! num) {
      return null;
    }
    return DestinationPlace(
      id: 'recent-${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}',
      name: name,
      address: address,
      position: GeoPoint(lat.toDouble(), lng.toDouble()),
      recent: true,
    );
  }

  final String id;

  /// "Stockholm Central", "Gare de Lyon".
  final String name;
  final String address;

  /// Null for a search answer that must be resolved first ([placeId]).
  final GeoPoint? position;
  final String? placeId;

  /// One of the driver's last destinations.
  final bool recent;

  DestinationPlace located(GeoPoint point) => DestinationPlace(
    id: id,
    name: name,
    address: address,
    position: point,
    placeId: placeId,
    recent: recent,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'lat': position?.latitude,
    'lng': position?.longitude,
  };
}

/// Where Destination mode's address search asks (G3-D3).
abstract interface class DestinationSearch {
  /// Places matching [query], near [near] first; empty when none.
  Future<List<DestinationPlace>> search(String query, {GeoPoint? near});

  /// [place] with its position, or null when it cannot be found.
  Future<DestinationPlace?> resolve(DestinationPlace place);
}

/// A live build: `POST /locations/autocomplete`, and `POST
/// /locations/geocode` for an answer without coordinates (contract §10).
/// Works in every country with an open zone (SE and FR).
class ApiDestinationSearch implements DestinationSearch {
  ApiDestinationSearch({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const autocompletePath = '/api/v1/locations/autocomplete';
  static const geocodePath = '/api/v1/locations/geocode';

  @override
  Future<List<DestinationPlace>> search(String query, {GeoPoint? near}) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    try {
      final answer = await _api.post(
        autocompletePath,
        body: {
          'query': text.length > 200 ? text.substring(0, 200) : text,
          if (near != null) 'latitude': near.latitude,
          if (near != null) 'longitude': near.longitude,
          'limit': 8,
        },
      );
      final list = answer['suggestions'];
      if (list is! List) return const [];
      return [
        for (var i = 0; i < list.length; i++)
          ?DestinationPlace.fromSuggestion(list[i], i),
      ];
    } catch (error) {
      DriverLog.warn('destination search failed: $error', name: 'live');
      rethrow;
    }
  }

  @override
  Future<DestinationPlace?> resolve(DestinationPlace place) async {
    if (place.position != null) return place;
    try {
      final found = await _api.post(
        geocodePath,
        body: {
          'query': place.address,
          if (place.placeId != null) 'placeId': place.placeId,
        },
      );
      final lat = found['latitude'];
      final lng = found['longitude'];
      if (lat is! num || lng is! num) return null;
      return place.located(GeoPoint(lat.toDouble(), lng.toDouble()));
    } catch (error) {
      DriverLog.warn('destination geocode failed: $error', name: 'live');
      return null;
    }
  }
}

/// The demo build only (no server): a few sample places to search in.
/// Never used by a live build (G3-D3).
class DemoDestinationSearch implements DestinationSearch {
  const DemoDestinationSearch();

  static const List<DestinationPlace> places = [
    DestinationPlace(
      id: 'stockholm-central',
      name: 'Stockholm Central',
      address: 'Centralplan 15, Stockholm',
      position: GeoPoint(59.3300, 18.0581),
    ),
    DestinationPlace(
      id: 'solna',
      name: 'Solna centrum',
      address: 'Solna Torg, Solna',
      position: GeoPoint(59.3603, 18.0009),
    ),
    DestinationPlace(
      id: 'kista',
      name: 'Kista centrum',
      address: 'Kista Galleria, Stockholm',
      position: GeoPoint(59.4032, 17.9448),
    ),
    DestinationPlace(
      id: 'sodertalje',
      name: 'Södertälje centrum',
      address: 'Storgatan, Södertälje',
      position: GeoPoint(59.1955, 17.6253),
    ),
    DestinationPlace(
      id: 'arlanda',
      name: 'Arlanda Airport',
      address: 'Stockholm Arlanda Airport',
      position: GeoPoint(59.6519, 17.9186),
    ),
    DestinationPlace(
      id: 'bromma',
      name: 'Bromma Airport',
      address: 'Flygplatsinfarten, Bromma',
      position: GeoPoint(59.3544, 17.9422),
    ),
  ];

  /// What the demo shows before anything is typed.
  List<DestinationPlace> get suggestions => places.take(4).toList();

  @override
  Future<List<DestinationPlace>> search(String query, {GeoPoint? near}) async {
    final text = query.trim().toLowerCase();
    return [
      for (final place in places)
        if (place.name.toLowerCase().contains(text) ||
            place.address.toLowerCase().contains(text))
          place,
    ];
  }

  @override
  Future<DestinationPlace?> resolve(DestinationPlace place) async => place;
}

/// The driver's last 5 destinations, kept on the phone (G3-D3).
class RecentDestinations {
  RecentDestinations._();

  static const key = 'driver.destination.recent.v1';
  static const max = 5;

  static Future<List<DestinationPlace>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final item in list) ?DestinationPlace.fromJson(item),
      ].take(max).toList();
    } catch (error) {
      DriverLog.warn('recent destinations unreadable: $error');
      return const [];
    }
  }

  /// Puts [place] first, without a duplicate of the same address.
  static Future<void> remember(DestinationPlace place) async {
    if (place.position == null) return;
    try {
      final known = await load();
      final next = [
        place,
        for (final item in known)
          if (item.address != place.address) item,
      ].take(max).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode([for (final item in next) item.toJson()]),
      );
    } catch (error) {
      DriverLog.warn('recent destinations not saved: $error');
    }
  }
}
