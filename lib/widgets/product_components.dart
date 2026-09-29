import 'package:flutter/material.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class ProductMetricCard extends StatelessWidget {
  const ProductMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.caption,
    this.emphasis = false,
    this.focusHighlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? caption;
  final bool emphasis;
  final bool focusHighlight;

  @override
  Widget build(BuildContext context) {
    final Color effective = color ?? Theme.of(context).colorScheme.primary;
    final Color focusColor = Theme.of(context).colorScheme.primary;
    final RoundedRectangleBorder? focusShape = focusHighlight
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: focusColor, width: 2.2),
          )
        : null;
    return Semantics(
      label: focusHighlight ? '$label. Important decision metric.' : label,
      child: Card(
        color: focusHighlight
            ? Color.alphaBlend(
                focusColor.withValues(alpha: 0.07),
                Theme.of(context).colorScheme.surface,
              )
            : null,
        elevation: focusHighlight ? 4 : 0,
        shadowColor: focusHighlight ? focusColor.withValues(alpha: 0.55) : null,
        shape: focusShape,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 17, color: effective),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: focusHighlight
                            ? FontWeight.w800
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (focusHighlight) ...<Widget>[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.center_focus_strong_rounded,
                      size: 16,
                      color: focusColor,
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    (emphasis
                            ? Theme.of(context).textTheme.headlineSmall
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: effective,
                        ),
              ),
              if (caption != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProductStatusChip extends StatelessWidget {
  const ProductStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductExpandableSection extends StatelessWidget {
  const ProductExpandableSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[child],
      ),
    );
  }
}

class ProductEmptyState extends StatelessWidget {
  const ProductEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
