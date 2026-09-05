import 'package:e1547/client/client.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/reply/reply.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/topic/topic.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

class TopicRepliesPage extends StatelessWidget {
  const TopicRepliesPage({super.key, required this.topic, this.orderByOldest});

  final Topic topic;
  final bool? orderByOldest;

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return TranslatableHost(
      text: topic.title,
      builder: (context, translation) => FilterControllerProvider(
        create: (_) => ReplyFilter(client),
        keys: (_) => [client],
        child: ChangeNotifierProvider(
          create: (_) => ReplyParamsController(
            ReplyParams(
              topicId: topic.id,
              order: (orderByOldest ?? true)
                  ? ReplyOrder.oldest
                  : ReplyOrder.newest,
            ),
          ),
          builder: (context, _) => TopicHistoryConnector(
            topic: topic,
            child: AdaptiveScaffold(
              appBar: DefaultAppBar(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslationOriginal(
                      category: TranslationCategory.topicTitle,
                      entry: translation,
                      original: Text(
                        topic.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      replacementBuilder: (context, text) => Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TranslationDisplay(
                      entry: translation,
                      compact: true,
                      category: TranslationCategory.topicTitle,
                    ),
                  ],
                ),
                actions: [
                  TranslationButton(
                    entry: translation,
                    compact: true,
                    category: TranslationCategory.topicTitle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Info'.tr,
                    onPressed: () =>
                        showTopicPrompt(context: context, topic: topic),
                  ),
                  const ContextDrawerButton(),
                ],
              ),
              drawer: const RouterDrawer(),
              endDrawer: const ReplyListDrawer(),
              floatingActionButton: client.hasLogin && !topic.locked
                  ? ReplyCreateFab(topicId: topic.id)
                  : null,
              body: const ReplyList(),
            ),
          ),
        ),
      ),
    );
  }
}
