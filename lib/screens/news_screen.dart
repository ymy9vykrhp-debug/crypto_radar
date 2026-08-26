import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../widgets/product_components.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, this.symbol});

  final String? symbol;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Новости', 'News'),
          subtitle: symbol == null
              ? strings.pick(
                  'Центр новостного риска и событий',
                  'News risk and event center',
                )
              : '$symbol · ${strings.pick('только события выбранного актива', 'selected-asset events only')}',
          icon: Icons.article_outlined,
        ),
        const SizedBox(height: 14),
        ProductEmptyState(
          icon: Icons.cloud_off_outlined,
          title: strings.pick(
            'Новостной источник не подключён',
            'News source is not connected',
          ),
          message: strings.pick(
            'Здесь появятся Critical, Important и Info события. Пока News Risk честно отображается как NOT_CONNECTED и не влияет на сигнал.',
            'Critical, Important and Info events will appear here. News Risk currently stays NOT_CONNECTED and does not affect signals.',
          ),
          action: ProductStatusChip(
            label: strings.notConnected,
            color: Theme.of(context).colorScheme.secondary,
            icon: Icons.link_off_rounded,
          ),
        ),
      ],
    );
  }
}
