import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'bouncing_dots.dart';
import 'empty_state.dart';

/// Wraps the loading/error/data states a screen goes through while fetching
/// from the API, so screens don't each hand-roll the same three branches.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.loading,
    required this.error,
    required this.data,
    required this.builder,
    this.onRetry,
  });

  final bool loading;
  final Object? error;
  final T? data;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: BouncingDots(color: kBrandPurple, size: 10));
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        message: describeApiError(error!),
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      );
    }
    return builder(context, data as T);
  }
}

/// Turns an [ApiException] (or any other error) into a message fit to show
/// a user, pulling the backend's `{ error: "message" }` body when present.
String describeApiError(Object error) {
  if (error is ApiException) {
    final body = error.body;
    if (body is Map && body['error'] is String) return body['error'] as String;
    return 'Something went wrong (${error.statusCode}).';
  }
  return 'Something went wrong. Check your connection and try again.';
}

void showApiError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(describeApiError(error))),
  );
}