import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';

class AuthenticatedNavigation extends StatelessWidget {
  const AuthenticatedNavigation({required this.selected, super.key});
  final int selected;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final labels = [copy.homeNav, copy.careerNav, copy.settingsNav];
    final destinations = ['/home', '/career', '/settings'];
    const icons = [
      Icons.home_outlined,
      Icons.badge_outlined,
      Icons.settings_outlined,
    ];
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (index) {
        if (index != selected) context.go(destinations[index]);
      },
      backgroundColor: TokensV0.surfaceCard,
      indicatorColor: TokensV0.surfaceContainerLow,
      destinations: [
        for (var index = 0; index < labels.length; index++)
          NavigationDestination(
            key: Key('nav-${['home', 'career', 'settings'][index]}'),
            icon: Icon(icons[index]),
            selectedIcon: Icon(icons[index], color: TokensV0.primary),
            label: labels[index],
          ),
      ],
    );
  }
}
