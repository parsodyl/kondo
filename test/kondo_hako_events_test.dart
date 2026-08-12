import 'package:flutter_test/flutter_test.dart';
import 'package:kondo/kondo.dart';

void main() {
  group('KondoHakoEvent equality', () {
    test('same type without labels are equal', () {
      const a = InteractorEvent();
      const b = InteractorEvent();
      expect(a, equals(b));
    });

    test('same type with different labels are equal', () {
      const a = InteractorEvent.withLabel('foo');
      const b = InteractorEvent.withLabel('bar');
      expect(a, equals(b));
    });

    test('different types are not equal', () {
      const a = InteractorEvent();
      const b = ReactorEvent();
      expect(a, isNot(equals(b)));
    });
  });

  group('KondoHakoEvent hashCode', () {
    test('same type produces same hashCode', () {
      const a = InteractorEvent();
      const b = InteractorEvent();
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different types produce different hashCode', () {
      const a = InteractorEvent();
      const b = ReactorEvent();
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('InteractorEvent', () {
    test('default constructor has null label', () {
      const event = InteractorEvent();
      expect(event.label, isNull);
    });

    test('withLabel constructor sets label', () {
      const event = InteractorEvent.withLabel('test');
      expect(event.label, 'test');
    });

    test('toString without label', () {
      const event = InteractorEvent();
      expect(event.toString(), 'InteractorEvent');
    });

    test('toString with label', () {
      const event = InteractorEvent.withLabel('fetch');
      expect(event.toString(), 'InteractorEvent{label: fetch}');
    });
  });

  group('ReactorEvent', () {
    test('default constructor has null label', () {
      const event = ReactorEvent();
      expect(event.label, isNull);
    });

    test('withLabel constructor sets label', () {
      const event = ReactorEvent.withLabel('navigate');
      expect(event.label, 'navigate');
    });

    test('toString without label', () {
      const event = ReactorEvent();
      expect(event.toString(), 'ReactorEvent');
    });

    test('toString with label', () {
      const event = ReactorEvent.withLabel('navigate');
      expect(event.toString(), 'ReactorEvent{label: navigate}');
    });
  });
}
