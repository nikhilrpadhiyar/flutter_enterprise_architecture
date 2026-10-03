import 'package:equatable/equatable.dart';

/// Data returned by a repository together with how trustworthy it is.
///
/// When the network is unavailable a repository returns locally saved data
/// with [isStale] set, so the UI can show it with a "saved data" notice.
final class Loaded<T> extends Equatable {
  /// Creates loaded data.
  const Loaded(this.data, {this.isStale = false, this.fetchedAt});

  /// The data.
  final T data;

  /// Whether [data] comes from local storage because the server could not be
  /// reached.
  final bool isStale;

  /// When the data was last confirmed by the server, if known.
  final DateTime? fetchedAt;

  @override
  List<Object?> get props => <Object?>[data, isStale, fetchedAt];
}
