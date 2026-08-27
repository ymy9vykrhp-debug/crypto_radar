import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/navigation_models.dart';

IconData appSectionIcon(AppSection section) {
  switch (section) {
    case AppSection.home:
      return Icons.dashboard_outlined;
    case AppSection.market:
      return Icons.show_chart_rounded;
    case AppSection.signals:
      return Icons.notifications_active_outlined;
    case AppSection.journal:
      return Icons.menu_book_outlined;
    case AppSection.research:
      return Icons.science_outlined;
    case AppSection.news:
      return Icons.article_outlined;
    case AppSection.help:
      return Icons.support_agent_outlined;
    case AppSection.integrations:
      return Icons.hub_outlined;
    case AppSection.settings:
      return Icons.settings_outlined;
  }
}

IconData workspaceSectionIcon(WorkspaceSection section) {
  switch (section) {
    case WorkspaceSection.overview:
      return Icons.space_dashboard_outlined;
    case WorkspaceSection.chart:
      return Icons.candlestick_chart_outlined;
    case WorkspaceSection.structure:
      return Icons.account_tree_outlined;
    case WorkspaceSection.levels:
      return Icons.horizontal_rule_rounded;
    case WorkspaceSection.volume:
      return Icons.bar_chart_rounded;
    case WorkspaceSection.signal:
      return Icons.adjust_rounded;
    case WorkspaceSection.why:
      return Icons.help_outline_rounded;
    case WorkspaceSection.journal:
      return Icons.history_rounded;
    case WorkspaceSection.news:
      return Icons.newspaper_outlined;
  }
}

class ProductNavigationRail extends StatelessWidget {
  const ProductNavigationRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return NavigationRail(
      extended: true,
      minExtendedWidth: 220,
      selectedIndex: selected.index,
      onDestinationSelected: (int index) =>
          onSelected(AppSection.values[index]),
      leading: const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.radar_rounded),
            SizedBox(width: 10),
            Text(
              'Crypto Radar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
      ),
      destinations: AppSection.values
          .map<NavigationRailDestination>(
            (AppSection section) => NavigationRailDestination(
              icon: Icon(appSectionIcon(section)),
              selectedIcon: Icon(appSectionIcon(section)),
              label: Text(strings.appSection(section)),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ProductNavigationDrawer extends StatelessWidget {
  const ProductNavigationDrawer({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return NavigationDrawer(
      selectedIndex: selected.index,
      onDestinationSelected: (int index) {
        Navigator.of(context).pop();
        onSelected(AppSection.values[index]);
      },
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 16, 18),
          child: Row(
            children: <Widget>[
              Icon(Icons.radar_rounded),
              SizedBox(width: 10),
              Text(
                'Crypto Radar',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
        ),
        ...AppSection.values.map<NavigationDrawerDestination>(
          (AppSection section) => NavigationDrawerDestination(
            icon: Icon(appSectionIcon(section)),
            selectedIcon: Icon(appSectionIcon(section)),
            label: Text(strings.appSection(section)),
          ),
        ),
      ],
    );
  }
}
