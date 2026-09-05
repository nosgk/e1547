import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class ContextDrawer extends StatelessWidget {
  const ContextDrawer({super.key, this.title, required this.children});

  final Widget? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      // Unifies the interactive rows with the navigation drawer: rounded
      // press feedback, one highlight color, one motion.
      child: ListTileTheme(
        data: ListTileThemeData(
          style: ListTileStyle.list,
          shape: const StadiumBorder(),
          selectedTileColor: colorScheme.secondaryContainer,
          selectedColor: colorScheme.onSecondaryContainer,
        ),
        child: SafeArea(
          child: ListView(
            primary: false,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ).copyWith(bottom: defaultActionListPadding.bottom),
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 18,
                  ),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.titleLarge!,
                    child: title!,
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class ContextDrawerButton extends StatelessWidget {
  const ContextDrawerButton({super.key, this.icon, this.tooltip});

  static String get defaultTooltip => 'Filter'.tr;

  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (!Scaffold.of(context).hasEndDrawer) return const SizedBox();
    return IconButton(
      tooltip: tooltip ?? defaultTooltip,
      icon: Icon(icon ?? Icons.tune),
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}
