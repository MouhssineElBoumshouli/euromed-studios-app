/// The rules UEMF still has to confirm, as adjustable settings
/// (decision 0001). The values below are the "Proposition" defaults
/// from docs/questions-for-uemf.md. An admin changes them in the app;
/// nothing else in the code hard-codes them.
library;

import 'people.dart';

class Policy {
  const Policy({
    this.openingHour = 9,
    this.closingHour = 18,
    this.slotMinutes = 60,
    this.openWeekdays = const {1, 2, 3, 4, 5},
    this.maxAdvanceDays = 30,
    this.weeklyQuotaMinutes = const {RequesterType.student: 120},
    this.qrGraceMinutes = 15,
    this.charterVersion = '1.0',
  });

  /// Q3: opening hours, slot length, booking window.
  final int openingHour;
  final int closingHour;
  final int slotMinutes;

  /// ISO weekdays (1 = Monday).
  final Set<int> openWeekdays;
  final int maxAdvanceDays;

  /// Q4: weekly limit per requester type. Missing = no limit (R-14).
  final Map<RequesterType, int> weeklyQuotaMinutes;

  /// Q10 / P-10: minutes the QR works before and after the slot.
  final int qrGraceMinutes;

  /// Q11 / R-13: current version of the house rules.
  final String charterVersion;

  int? quotaFor(RequesterType t) => weeklyQuotaMinutes[t];
}
