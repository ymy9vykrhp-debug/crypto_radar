import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/navigation_models.dart';
import '../models/signal_models.dart';
import '../services/journal_controller.dart';
import '../widgets/product_components.dart';
import '../widgets/signal_table.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({
    super.key,
    required this.controller,
    this.selectedSymbol,
  });

  final JournalController controller;
  final String? selectedSymbol;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = context.strings;
        final List<RadarSignal> signals = controller.signals;
        final int active = signals
            .where((RadarSignal signal) => signal.status.isActive)
            .length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            SectionHeading(
              title: strings.appSection(AppSection.signals),
              subtitle: strings.pick(
                'Уникальные live-сигналы без повторов каждые 15 секунд',
                'Unique live signals without 15-second duplicates',
              ),
              icon: Icons.notifications_active_outlined,
              trailing: ProductStatusChip(
                label: '${strings.active}: $active',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.sensors_rounded,
              ),
            ),
            const SizedBox(height: 14),
            SignalTable(signals: signals),
            const SizedBox(height: 14),
            ProductExpandableSection(
              title: strings.pick('Центр уведомлений', 'Alert Center'),
              icon: Icons.notifications_outlined,
              child: Column(
                children: <Widget>[
                  _AlertCategory(
                    icon: Icons.error_outline_rounded,
                    label: 'Critical',
                    count: 0,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  _AlertCategory(
                    icon: Icons.warning_amber_rounded,
                    label: 'Important',
                    count: 0,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _AlertCategory(
                    icon: Icons.info_outline_rounded,
                    label: 'Info',
                    count: 0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertCategory extends StatelessWidget {
  const _AlertCategory({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: ProductStatusChip(label: count.toString(), color: color),
    );
  }
}
