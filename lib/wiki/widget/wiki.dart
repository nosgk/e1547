import 'package:e1547/markup/markup.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/translate/translate.dart';
import 'package:e1547/wiki/wiki.dart';
import 'package:flutter/material.dart';

class WikiPage extends StatelessWidget {
  const WikiPage({super.key, required this.wiki});

  final Wiki wiki;

  @override
  Widget build(BuildContext context) {
    return TranslatableHost(
      text: wiki.body,
      builder: (context, translation) => AdaptiveScaffold(
        appBar: DefaultAppBar(
          title: Text(tagToName(wiki.title)),
          actions: [
            TranslationButton(entry: translation, compact: true),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Info'.tr,
              onPressed: () => showWikiPrompt(context: context, wiki: wiki),
            ),
          ],
        ),
        body: ListView(
          primary: true,
          padding: defaultActionListPadding.add(
            const EdgeInsets.symmetric(horizontal: 12),
          ),
          children: [
            DText(wiki.body),
            TranslationDisplay(entry: translation),
          ],
        ),
        drawer: const RouterDrawer(),
      ),
    );
  }
}
