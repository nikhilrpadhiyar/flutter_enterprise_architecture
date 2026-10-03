import 'package:flutter/material.dart';

import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/activity_item.dart';

/// One entry of an activity feed.
class ActivityTile extends StatelessWidget {
  /// Creates a tile.
  const ActivityTile(this.item, {super.key});

  /// The activity to show.
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text('${item.actorName} ${item.message}'),
      subtitle: Text(AppFormatters.dateTime(item.createdAt)),
    );
  }
}
