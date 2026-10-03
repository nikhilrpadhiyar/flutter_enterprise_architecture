import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../models/json_reader.dart';
import 'network_failure_mapper.dart';
import 'remote_outcome.dart';

/// Thin adapter between `flutter_network_plus` results and the app's
/// [Failure] model.
///
/// It adds no networking behaviour of its own. It only picks the cache and
/// queue options for each kind of call and converts failed results into
/// thrown failures so data sources stay short.
class RemoteRequester {
  /// Creates a requester over [client].
  RemoteRequester(this._client, this._logger);

  final fnp.NetworkClient _client;
  final AppLogger _logger;

  /// Reads [path] with the network first and the response cache as a
  /// fallback when the server cannot be reached.
  Future<RemoteData<T>> read<T>(
    String path, {
    required fnp.Decoder<T> decoder,
    Map<String, Object?> query = const <String, Object?>{},
    fnp.CachePolicy policy = fnp.CachePolicy.networkFirst,
  }) async {
    final result = await _client.send<T>(
      fnp.NetworkRequest(
        method: fnp.HttpMethod.get,
        path: path,
        queryParameters: query,
        cachePolicy: policy,
      ),
      decoder: decoder,
    );
    return switch (result) {
      fnp.NetworkSuccess<T>(:final value, :final response) => RemoteData<T>(
        value,
        fromCache: response.fromCache,
      ),
      fnp.NetworkFailure<T>(:final exception) => throw _fail(path, exception),
    };
  }

  /// Sends a write that must reach the server now.
  ///
  /// Set [authRequired] to false for sign in and registration.
  Future<T> write<T>(
    fnp.HttpMethod method,
    String path, {
    required fnp.Decoder<T> decoder,
    Object? body,
    bool authRequired = true,
  }) async {
    final result = await _client.send<T>(
      fnp.NetworkRequest(
        method: method,
        path: path,
        body: fnp.NetworkClient.wrapBody(body),
        authRequired: authRequired,
      ),
      decoder: decoder,
    );
    return switch (result) {
      fnp.NetworkSuccess<T>(:final value) => value,
      fnp.NetworkFailure<T>(:final exception) => throw _fail(path, exception),
    };
  }

  /// Sends a write that is saved and retried later when offline.
  ///
  /// The [idempotencyKey] lets the server ignore a duplicate delivery and
  /// allows the networking layer to retry the request safely.
  Future<MutationOutcome<T>> writeQueued<T>(
    fnp.HttpMethod method,
    String path, {
    required fnp.Decoder<T> decoder,
    required String idempotencyKey,
    Object? body,
  }) async {
    final result = await _client.send<T>(
      fnp.NetworkRequest(
        method: method,
        path: path,
        body: fnp.NetworkClient.wrapBody(body),
        headers: <String, String>{_idempotencyHeader: idempotencyKey},
        queueIfOffline: true,
      ),
      decoder: decoder,
    );
    return switch (result) {
      fnp.NetworkSuccess<T>(:final value) => Applied<T>(value),
      fnp.NetworkFailure<T>(:final exception)
          when NetworkFailureMapper.isQueuedForSync(exception) =>
        Queued<T>(),
      fnp.NetworkFailure<T>(:final exception) => throw _fail(path, exception),
    };
  }

  /// Like [writeQueued] for endpoints that return no body.
  Future<MutationOutcome<void>> writeQueuedVoid(
    fnp.HttpMethod method,
    String path, {
    required String idempotencyKey,
  }) async {
    final outcome = await writeQueued<Object?>(
      method,
      path,
      decoder: (Object? json) => json,
      idempotencyKey: idempotencyKey,
    );
    return switch (outcome) {
      Applied<Object?>() => const Applied<void>(null),
      Queued<Object?>() => const Queued<void>(),
    };
  }

  /// Parses a JSON object with [parse], for use as a decoder.
  static fnp.Decoder<T> decoderFor<T>(T Function(Json json) parse) =>
      (Object? raw) => parse(asJson(raw));

  Failure _fail(String path, fnp.NetworkException exception) {
    final failure = NetworkFailureMapper.map(exception);
    _logger.warning(
      LogTag.repository,
      'request failed',
      context: <String, Object?>{
        'path': path,
        'failure': failure.runtimeType.toString(),
      },
    );
    return failure;
  }

  static const String _idempotencyHeader = 'Idempotency-Key';
}
