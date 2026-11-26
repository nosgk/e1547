import 'package:e1547/client/client.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/reply/reply.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/topic/topic.dart';
import 'package:flutter/material.dart';

class ReplyLoadingPage extends StatelessWidget {
  const ReplyLoadingPage(this.id, {super.key, this.orderByOldest});

  final int id;
  final bool? orderByOldest;

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    final query = client.replies.useGet(id: id);
    return QueryBuilder(
      query: query,
      builder: (context, state) => LoadingPage(
        isLoading: state.isLoading || state.isInitial,
        isError: state.isError,
        isEmpty: state.data == null,
        loadingBuilder: (context, child) => Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text('Reply #{id}'.trArgs({'id': id.toString()})),
          ),
          body: child(context),
        ),
        skeleton: (context) => TopicRepliesPage(
          topic: const TopicGhost(),
          orderByOldest: orderByOldest,
        ),
        onError: Text('Failed to load reply'.tr),
        onRetry: query.invalidate,
        onEmpty: Text('Reply not found'.tr),
        child: (context) =>
            TopicLoadingPage(state.data!.topicId, orderByOldest: orderByOldest),
      ),
    );
  }
}
