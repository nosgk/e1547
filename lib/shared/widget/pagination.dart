import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class PagedChildBuilderRetryButton extends StatelessWidget {
  const PagedChildBuilderRetryButton(this.onRetry, {super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (onRetry == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextButton(onPressed: onRetry, child: Text('Try again'.tr)),
    );
  }
}

PagedChildBuilderDelegate<T> defaultPagedChildBuilderDelegate<T>({
  required ItemWidgetBuilder<T> itemBuilder,
  VoidCallback? onRetry,
  Widget? onEmpty,
  Widget? onError,
  Widget? onEnd,
  Widget Function(BuildContext context, Widget child)? pageBuilder,
}) {
  pageBuilder ??= (context, child) => child;
  return PagedChildBuilderDelegate<T>(
    itemBuilder: itemBuilder,
    firstPageProgressIndicatorBuilder: (context) => pageBuilder!(
      context,
      const Material(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [HexagonalLoadingIndicator()],
        ),
      ),
    ),
    newPageProgressIndicatorBuilder: (context) => pageBuilder!(
      context,
      const LoadMoreFooter(state: HexagonState.loading),
    ),
    noItemsFoundIndicatorBuilder: (context) => pageBuilder!(
      context,
      IconMessage(
        icon: const Icon(Icons.clear),
        title: onEmpty ?? Text('Nothing to see here'.tr),
      ),
    ),
    firstPageErrorIndicatorBuilder: (context) => pageBuilder!(
      context,
      IconMessage(
        icon: const Icon(Icons.warning_amber_outlined),
        title: onError ?? Text('Failed to load'.tr),
        action: PagedChildBuilderRetryButton(onRetry),
      ),
    ),
    newPageErrorIndicatorBuilder: (context) => pageBuilder!(
      context,
      LoadMoreFooter(
        state: HexagonState.failed,
        label: onError ?? Text('Failed to load'.tr),
        onRetry: onRetry,
      ),
    ),
    noMoreItemsIndicatorBuilder: onEnd == null
        ? null
        : (context) => pageBuilder!(
            context,
            LoadMoreFooter(state: HexagonState.end, label: onEnd),
          ),
  );
}
