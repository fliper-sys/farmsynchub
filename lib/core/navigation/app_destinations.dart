import 'package:flutter/material.dart';

import '../../providers/app_preferences_provider.dart';

/// A place the user can go to from the bottom bar or the side menu.
///
/// This is the single source of truth for app-wide navigation: the bottom
/// bar, the menu drawer, the route-to-tab mapping and the "restricted
/// feature" check all read from here, so they can never drift apart.
@immutable
class AppDestination {
  /// Creates a destination.
  const AppDestination({
    required this.featureKey,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.en,
    this.ha,
    this.fr,
    this.enHint,
    this.haHint,
    this.frHint,
  });

  /// Key used by admins to restrict a feature for a user
  /// (see `UserProfile.restrictedFeatures`).
  final String featureKey;

  /// go_router path.
  final String route;

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected.
  final IconData selectedIcon;

  /// English label.
  final String en;

  /// Hausa label (falls back to English when null).
  final String? ha;

  /// French label (falls back to English when null).
  final String? fr;

  /// One-line English explanation shown in the menu.
  final String? enHint;

  /// Hausa hint (falls back to English when null).
  final String? haHint;

  /// French hint (falls back to English when null).
  final String? frHint;

  /// Localized label.
  String label(AppLanguage language) => language.tr(en: en, ha: ha, fr: fr);

  /// Localized one-line hint, or an empty string when there is none.
  String hint(AppLanguage language) {
    final String? base = enHint;
    if (base == null) {
      return '';
    }
    return language.tr(en: base, ha: haHint, fr: frHint);
  }
}

/// A titled group of destinations in the menu.
@immutable
class AppDestinationGroup {
  /// Creates a group.
  const AppDestinationGroup({
    required this.en,
    required this.items,
    this.ha,
    this.fr,
  });

  /// English title.
  final String en;

  /// Hausa title.
  final String? ha;

  /// French title.
  final String? fr;

  /// Destinations in this group.
  final List<AppDestination> items;

  /// Localized title.
  String title(AppLanguage language) => language.tr(en: en, ha: ha, fr: fr);
}

/// All app-wide destinations.
abstract final class AppDestinations {
  static const AppDestination home = AppDestination(
    featureKey: 'dashboard',
    route: '/dashboard',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    en: 'Home',
    ha: 'Gida',
    fr: 'Accueil',
    enHint: 'Your farm at a glance',
    frHint: 'Votre ferme en un coup d’œil',
  );

  static const AppDestination farms = AppDestination(
    featureKey: 'farms',
    route: '/farms',
    icon: Icons.agriculture_outlined,
    selectedIcon: Icons.agriculture_rounded,
    en: 'Farms',
    ha: 'Gonaki',
    fr: 'Fermes',
    enHint: 'Your farms, land and weather',
    frHint: 'Vos fermes, terres et météo',
  );

  static const AppDestination crops = AppDestination(
    featureKey: 'crops',
    route: '/crops',
    icon: Icons.grass_outlined,
    selectedIcon: Icons.grass_rounded,
    en: 'Crops',
    ha: 'Amfanin gona',
    fr: 'Cultures',
    enHint: 'Planting, growth and harvest',
    frHint: 'Plantation, croissance et récolte',
  );

  static const AppDestination livestock = AppDestination(
    featureKey: 'livestock',
    route: '/livestock',
    icon: Icons.pets_outlined,
    selectedIcon: Icons.pets,
    en: 'Livestock',
    ha: 'Dabbobi',
    fr: 'Bétail',
    enHint: 'Animals, health and breeding',
    frHint: 'Animaux, santé et reproduction',
  );

  static const AppDestination finance = AppDestination(
    featureKey: 'finance',
    route: '/finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    en: 'Finance',
    ha: 'Kudi',
    fr: 'Finance',
    enHint: 'Income, expenses and balance',
    frHint: 'Revenus, dépenses et solde',
  );

  static const AppDestination farmTasks = AppDestination(
    featureKey: 'farm-tasks',
    route: '/farm-tasks',
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist_rounded,
    en: 'Farm tasks',
    ha: 'Ayyukan gona',
    fr: 'Tâches de la ferme',
    enHint: 'What to do today and this week',
    frHint: 'À faire aujourd’hui et cette semaine',
  );

  static const AppDestination schedule = AppDestination(
    featureKey: 'schedule',
    route: '/schedule',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    en: 'Schedule',
    fr: 'Calendrier',
    enHint: 'Calendar of farm activities',
    frHint: 'Calendrier des activités',
  );

  static const AppDestination inventory = AppDestination(
    featureKey: 'inventory',
    route: '/inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    en: 'Inventory',
    fr: 'Stock',
    enHint: 'Stock and supplies on hand',
    frHint: 'Stock et fournitures disponibles',
  );

  static const AppDestination salesDesk = AppDestination(
    featureKey: 'sales',
    route: '/sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    en: 'Sales desk',
    ha: 'Tebur Tallace-tallace',
    fr: 'Bureau des ventes',
    enHint: 'Record sales and share receipts',
    frHint: 'Enregistrer les ventes et partager les reçus',
  );

  static const AppDestination expenses = AppDestination(
    featureKey: 'expenses',
    route: '/expenses',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    en: 'Expenses',
    ha: 'Kashewa',
    fr: 'Dépenses',
    enHint: 'Track what you spend',
    frHint: 'Suivre vos dépenses',
  );

  static const AppDestination procurement = AppDestination(
    featureKey: 'procurement',
    route: '/procurement',
    icon: Icons.shopping_basket_outlined,
    selectedIcon: Icons.shopping_basket_rounded,
    en: 'Procurement',
    ha: 'Sayayya',
    fr: 'Approvisionnement',
    enHint: 'Farm input purchases and orders',
    frHint: 'Achats et commandes d’intrants',
  );

  static const AppDestination marketTrends = AppDestination(
    featureKey: 'market-trends',
    route: '/market-trends',
    icon: Icons.trending_up_outlined,
    selectedIcon: Icons.trending_up_rounded,
    en: 'Market trends',
    ha: 'Yanayin kasuwa',
    fr: 'Tendances du marché',
    enHint: 'Current prices and market insight',
    frHint: 'Prix actuels et analyse du marché',
  );

  static const AppDestination aiAdvisor = AppDestination(
    featureKey: 'ai-advisor',
    route: '/ai-advisor',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    en: 'AI Advisor',
    ha: 'Mai ba da shawara',
    fr: 'Conseiller IA',
    enHint: 'Ask questions or snap a photo to diagnose',
    frHint: 'Posez une question ou diagnostiquez par photo',
  );

  static const AppDestination learn = AppDestination(
    featureKey: 'learn',
    route: '/learn',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
    en: 'Learn',
    ha: 'Koyo',
    fr: 'Apprendre',
    enHint: 'Lessons, practice and certificates',
    frHint: 'Leçons, pratique et certificats',
  );

  static const AppDestination news = AppDestination(
    featureKey: 'news',
    route: '/news',
    icon: Icons.newspaper_outlined,
    selectedIcon: Icons.newspaper_rounded,
    en: 'News',
    ha: 'Labarai',
    fr: 'Actualités',
    enHint: 'Updates for farmers',
    frHint: 'Actualités pour les agriculteurs',
  );

  static const AppDestination notifications = AppDestination(
    featureKey: 'notifications',
    route: '/notifications',
    icon: Icons.notifications_none_rounded,
    selectedIcon: Icons.notifications_rounded,
    en: 'Notifications',
    ha: 'Sanarwa',
    fr: 'Notifications',
    enHint: 'Alerts and reminders',
    frHint: 'Alertes et rappels',
  );

  static const AppDestination profile = AppDestination(
    featureKey: 'profile',
    route: '/profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    en: 'Profile',
    ha: 'Bayanan kaina',
    fr: 'Profil',
    enHint: 'Your account and farmer details',
    frHint: 'Votre compte et vos informations',
  );

  static const AppDestination settings = AppDestination(
    featureKey: 'settings',
    route: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    en: 'Settings',
    ha: 'Saituna',
    fr: 'Paramètres',
    enHint: 'Language, theme and notifications',
    frHint: 'Langue, thème et notifications',
  );

  /// The seven primary tabs of the bottom bar, in order.
  ///
  /// On narrow phones the bar slides sideways so every tab keeps a readable
  /// label. Everything else lives in [menuGroups].
  static const List<AppDestination> tabs = <AppDestination>[
    home,
    farms,
    crops,
    livestock,
    finance,
    news,
    profile,
  ];

  /// Every destination, grouped for the side menu.
  static const List<AppDestinationGroup> menuGroups = <AppDestinationGroup>[
    AppDestinationGroup(
      en: 'My farm',
      fr: 'Ma ferme',
      items: <AppDestination>[
        home,
        farms,
        crops,
        livestock,
        farmTasks,
        schedule,
        inventory,
      ],
    ),
    AppDestinationGroup(
      en: 'Money',
      ha: 'Kudi',
      fr: 'Argent',
      items: <AppDestination>[
        finance,
        salesDesk,
        expenses,
        procurement,
        marketTrends,
      ],
    ),
    AppDestinationGroup(
      en: 'Learn and advice',
      fr: 'Apprendre et conseils',
      items: <AppDestination>[
        aiAdvisor,
        learn,
        news,
      ],
    ),
    AppDestinationGroup(
      en: 'My account',
      fr: 'Mon compte',
      items: <AppDestination>[
        notifications,
        profile,
        settings,
      ],
    ),
  ];

  /// Index of the bottom-bar tab that owns [path], or -1 when the page is not
  /// one of the primary tabs (so no tab is shown as selected).
  static int tabIndexForPath(String path) {
    for (int i = 0; i < tabs.length; i++) {
      if (path == tabs[i].route) {
        return i;
      }
    }
    return -1;
  }

  /// Route of the tab at [index], falling back to Home.
  static String routeForTab(int index) {
    if (index < 0 || index >= tabs.length) {
      return home.route;
    }
    return tabs[index].route;
  }
}
