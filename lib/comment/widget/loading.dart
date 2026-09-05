import 'package:e1547/client/client.dart';
import 'package:e1547/comment/comment.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class CommentLoadingPage extends StatelessWidget {
  const CommentLoadingPage(this.id, {super.key});

  final int id;

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return QueryBuilder(
      query: client.comments.useGet(id: id),
      builder: (context, state) => LoadingPage(
        isLoading: state.isLoading,
        isError: state.isError,
        isEmpty: state.data == null,
        loadingBuilder: (context, child) => Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text(
              'Comment #{id}'.trArgs({'id': id.toString()}),
            ),
          ),
          body: child(context),
        ),
        onError: Text('Failed to load comment'.tr),
        onEmpty: Text('Comment not found'.tr),
        child: (context) => PostCommentsPage(postId: state.data!.postId),
      ),
    );
  }
}
