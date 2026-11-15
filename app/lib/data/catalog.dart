/// The studios and equipment the app shows. Their descriptions and photos
/// ship with the app; what an admin can change (a studio open to booking,
/// an item's stock) comes from the server and overrides them (I4, I5).
library;

import '../domain/bookings.dart';
import '../domain/studios.dart';
import 'demo_world.dart';

abstract final class Catalog {
  static List<Studio> _studios = DemoWorld.studios;
  static List<EquipmentItem> _equipment = DemoWorld.equipment;

  static List<Studio> get studios => _studios;
  static List<EquipmentItem> get equipment => _equipment;

  /// Applies the server's values (unknown ids are ignored).
  static void apply({
    Map<String, bool>? bookable,
    Map<String, int>? stock,
  }) {
    if (bookable != null) {
      _studios = [
        for (final s in DemoWorld.studios)
          bookable.containsKey(s.id) ? s.withBookable(bookable[s.id]!) : s,
      ];
    }
    if (stock != null) {
      _equipment = [
        for (final e in DemoWorld.equipment)
          stock.containsKey(e.id) ? e.withStock(stock[e.id]!) : e,
      ];
    }
  }

  /// Offline: one change by the admin.
  static void setBookable(String id, bool value) => _studios = [
        for (final s in _studios) s.id == id ? s.withBookable(value) : s,
      ];

  static void setStock(String id, int value) => _equipment = [
        for (final e in _equipment) e.id == id ? e.withStock(value) : e,
      ];
}
