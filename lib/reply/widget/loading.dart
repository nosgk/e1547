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
    return QueryBuilder(
      query: client.replies.useGet(id: id),
      builder: (context, state) => LoadingPage(
        isLoading: state.isLoading,
        isError: state.isError,
        isEmpty: state.data == null,
        loadingBuilder: (context, child) => Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text('Reply #{id}'.trArgs({'id': id.toString()})),
          ),
          body: child(context),
        ),
        onError: Text('Failed to load reply'.tr),
        onEmpty: Text('Reply not found'.tr),
        child: (context) =>
            TopicLoadingPage(state.data!.topicId, orderByOldest: orderByOldest),
      ),
    );
  }
}
