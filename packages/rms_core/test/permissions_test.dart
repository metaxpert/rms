import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

/// Permission gating exists to avoid dead ends, not to enforce anything — the
/// server re-checks every call. That makes both directions of error real: a
/// button that 403s wastes a waiter's time at a table, and a button hidden by a
/// guess denies someone their own job.
void main() {
  group('Permissions', () {
    test('grants exactly what the token lists', () {
      const permissions = Permissions({RestaurantPermissions.orderWrite});

      expect(permissions.canTakeOrders, isTrue);
      expect(permissions.canPrint, isFalse);
    });

    test('a tenant admin wildcard grants everything', () {
      const permissions = Permissions({'*'});

      expect(permissions.canTakeOrders, isTrue);
      expect(permissions.canPrint, isTrue);
      expect(permissions.has('restaurant:anything:at:all'), isTrue);
    });

    test('a token with no permission claim is not locked out', () {
      // A claim shape we did not expect must not stop a waiter working
      // mid-service. The server still refuses whatever they may not do.
      const permissions = Permissions({});

      expect(permissions.isUnknown, isTrue);
      expect(permissions.canTakeOrders, isTrue);
      expect(permissions.canPrint, isTrue);
    });

    test('an unrelated permission grants nothing here', () {
      const permissions = Permissions({'finance:journal:post'});

      expect(permissions.canTakeOrders, isFalse);
      expect(permissions.canPrint, isFalse);
    });

    test('operating covers taking orders', () {
      expect(
        const Permissions({RestaurantPermissions.operate}).canOperate,
        isTrue,
      );
      expect(
        const Permissions({RestaurantPermissions.orderWrite}).canOperate,
        isTrue,
      );
      expect(
        const Permissions({RestaurantPermissions.menuWrite}).canOperate,
        isFalse,
      );
    });

    test('the names are the backend\'s, verbatim', () {
      // Written once here so no screen types one as a literal and no screen
      // invents one that does not exist.
      expect(RestaurantPermissions.operate, 'restaurant:operate');
      expect(RestaurantPermissions.orderWrite, 'restaurant:order:write');
      expect(RestaurantPermissions.print, 'restaurant:print');
      expect(RestaurantPermissions.kdsOperate, 'restaurant:kds:operate');
      expect(
        RestaurantPermissions.deliveryDispatch,
        'restaurant:delivery:dispatch',
      );
    });

    test('two sets with the same grants are equal', () {
      expect(
        const Permissions({'a', 'b'}),
        const Permissions({'b', 'a'}),
      );
    });
  });
}
