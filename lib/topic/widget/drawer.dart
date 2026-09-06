import 'package:e1547/shared/shared.dart';
import 'package:e1547/topic/topic.dart';
import 'package:flutter/material.dart';

class TopicListDrawer extends StatelessWidget {
  const TopicListDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TopicFilter>();
    return ContextDrawer(
      title: Text('Topics'.tr),
      children: [
        SectionHeader(
          indent: SectionHeader.listTileIndent,
          title: 'Quick sort'.tr,
        ),
        Builder(
          builder: (context) {
            final params = context.watch<TopicParamsController>().value;
            return Column(
              children: [
                for (final order in TopicOrder.values)
                  ListTile(
                    leading: Icon(switch (order) {
                      TopicOrder.sticky => Icons.reply_all_outlined,
                      TopicOrder.newest => Icons.event_outlined,
                      TopicOrder.oldest => Icons.history_outlined,
                    }),
                    title: Text(switch (order) {
                      TopicOrder.sticky => 'Latest replies'.tr,
                      TopicOrder.newest => 'Newest topics'.tr,
                      TopicOrder.oldest => 'Oldest topics'.tr,
                    }),
                    trailing: params.order == order
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      context.read<TopicParamsController>().value = params
                          .copyWith(order: order);
                    },
                  ),
              ],
            );
          },
        ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.sell),
          title: Text('Hide tags edits'.tr),
          subtitle: Text(
            controller.value.hideTagEditing ? 'hidden'.tr : 'visible'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: controller.value.hideTagEditing,
          onChanged: (value) {
            controller.value = (hideTagEditing: value);
            Scaffold.of(context).closeEndDrawer();
          },
        ),
      ],
    );
  }
}
