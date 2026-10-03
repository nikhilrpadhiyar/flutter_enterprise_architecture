import 'package:equatable/equatable.dart';

/// A file attached to a task.
final class Attachment extends Equatable {
  /// Creates an attachment.
  const Attachment({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.url,
  });

  /// Unique identifier.
  final String id;

  /// File name.
  final String name;

  /// Size in bytes.
  final int sizeBytes;

  /// Download location.
  final String url;

  @override
  List<Object?> get props => <Object?>[id, name, sizeBytes, url];
}
