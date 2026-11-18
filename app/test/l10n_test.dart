import 'package:euromed_studios/core/l10n/tr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => L.setLanguage('fr'));

  test('French stays as written', () {
    expect(tr('Annuler'), 'Annuler');
  });

  test('English: exact texts, values, plurals and glued pieces', () {
    L.setLanguage('en');
    expect(tr('Annuler'), 'Cancel');
    expect(tr('Bonjour Yasmine,'), 'Hello Yasmine,');
    // The value is a known text too, so it is translated.
    expect(tr('Passer en Montage ?'), 'Move to Editing?');
    expect(tr('3 séances'), '3 sessions');
    expect(tr('1 séance'), '1 session');
    // Pieces glued with " · " are translated one by one.
    expect(
      tr('Ouvert à la réservation · salle partagée'),
      'Open to booking · shared room',
    );
    // Short patterns only take what they are meant to hold.
    expect(tr('Demande ES-2026-0140'), 'Request ES-2026-0140');
    expect(tr('Demande urgente'), 'Demande urgente');
    expect(tr('Reçue il y a 1 j'), 'Received 1 d ago');
    expect(tr('2 matériel'), '2 equipment');
    // Typed text: only an exact known text is translated.
    expect(trExact('Montage final'), 'Montage final');
    // Names and unknown texts are left alone.
    expect(tr('Yasmine Mansouri'), 'Yasmine Mansouri');
    expect(tr(null), isNull);
  });
}
