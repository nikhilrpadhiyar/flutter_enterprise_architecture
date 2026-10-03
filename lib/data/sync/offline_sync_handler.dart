import 'dart:async';

import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../core/logging/app_logger.dart';
import '../datasources/local/task_local_data_source.dart';
import '../models/json_reader.dart';
import '../models/task_model.dart';
import 'queued_request_guard.dart';

/// Applies the outcome of replayed offline writes to the local database.
///
/// The networking layer replays queued requests on its own and reports each
/// result through callbacks. This class turns those reports into local state:
/// a delivered change becomes synced (a locally created task takes its server
/// id) and a rejected change is flagged as failed. Updates run strictly one
/// after another, in the order they were reported.
class OfflineSyncHandler {
  /// Creates the handler. [clock] is injectable for tests.
  OfflineSyncHandler(this._local, this._logger, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaskLocalDataSource _local;
  final AppLogger _logger;
  final DateTime Function() _clock;

  Future<void> _tail = Future<void>.value();

  /// Completes when every update reported so far has been applied.
  Future<void> get idle => _tail;

  /// Called by the networking layer after a queued request was delivered.
  void onReplayed(
    fnp.QueuedRequest request,
    fnp.NetworkResponse<Object?> response,
  ) => _enqueue(() => _replayed(request, response));

  /// Called by the networking layer when a queued request was given up on.
  void onDropped(fnp.QueuedRequest request, fnp.DropReason reason) =>
      _enqueue(() => _dropped(request, reason));

  void _enqueue(Future<void> Function() job) {
    _tail = _tail.then((_) => job()).catchError((Object error) {
      _logger.warning(
        LogTag.repository,
        'could not apply sync result',
        error: error,
      );
    });
  }

  Future<void> _replayed(
    fnp.QueuedRequest request,
    fnp.NetworkResponse<Object?> response,
  ) async {
    final key = QueuedRequestGuard.idempotencyKeyOf(request.headers);
    if (key == null || !await _local.contains(key)) return;
    final body = fnp.NetworkClient.tryDecodeJson(response.bodyBytes);
    await _local.completeChange(
      key,
      serverTask: body == null ? null : TaskModel.fromJson(asJson(body)),
      now: _clock(),
    );
    _logger.info(
      LogTag.repository,
      'queued change delivered',
      context: <String, Object?>{'path': request.path},
    );
  }

  Future<void> _dropped(
    fnp.QueuedRequest request,
    fnp.DropReason reason,
  ) async {
    final key = QueuedRequestGuard.idempotencyKeyOf(request.headers);
    if (key == null || !await _local.contains(key)) return;
    await _local.failChange(key);
    _logger.warning(
      LogTag.repository,
      'queued change rejected',
      context: <String, Object?>{'path': request.path, 'reason': reason.name},
    );
  }
}
