import 'package:farmsynchub/core/navigation/app_destinations.dart';
import 'package:farmsynchub/providers/app_preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDestinations', () {
    test('bottom bar has seven tabs, Home first, News and Profile included', () {
      expect(AppDestinations.tabs.length, 7);
      expect(AppDestinations.tabs.first.route, '/dashboard');
      expect(AppDestinations.tabs[5].route, '/news');
      expect(AppDestinations.tabs[6].route, '/profile');
    });

    test('tabIndexForPath maps tab routes and ignores other pages', () {
      expect(AppDestinations.tabIndexForPath('/dashboard'), 0);
      expect(AppDestinations.tabIndexForPath('/crops'), 2);
      expect(AppDestinations.tabIndexForPath('/finance'), 4);
      expect(AppDestinations.tabIndexForPath('/news'), 5);
      expect(AppDestinations.tabIndexForPath('/profile'), 6);
      // Pages reached from the menu must not light up a tab.
      expect(AppDestinations.tabIndexForPath('/settings'), -1);
      expect(AppDestinations.tabIndexForPath('/learn'), -1);
      expect(AppDestinations.tabIndexForPath('/unknown'), -1);
    });

    test('routeForTab round-trips and falls back to Home', () {
      for (int i = 0; i < AppDestinations.tabs.length; i++) {
        expect(
          AppDestinations.tabIndexForPath(AppDestinations.routeForTab(i)),
          i,
        );
      }
      expect(AppDestinations.routeForTab(-1), '/dashboard');
      expect(AppDestinations.routeForTab(99), '/dashboard');
    });

    test('every tab is also listed in the menu', () {
      final Set<String> menuRoutes = <String>{
        for (final AppDestinationGroup group in AppDestinations.menuGroups)
          for (final AppDestination item in group.items) item.route,
      };
      for (final AppDestination tab in AppDestinations.tabs) {
        expect(menuRoutes, contains(tab.route));
      }
    });

    test('menu has no duplicate routes or feature keys', () {
      final List<AppDestination> all = <AppDestination>[
        for (final AppDestinationGroup group in AppDestinations.menuGroups)
          ...group.items,
      ];
      expect(all.map((AppDestination d) => d.route).toSet().length, all.length);
      expect(
        all.map((AppDestination d) => d.featureKey).toSet().length,
        all.length,
      );
    });

    test('labels fall back to English when a translation is missing', () {
      expect(AppDestinations.schedule.label(AppLanguage.hausa), 'Schedule');
      expect(AppDestinations.home.label(AppLanguage.hausa), 'Gida');
      expect(AppDestinations.home.label(AppLanguage.french), 'Accueil');
    });
  });
}
