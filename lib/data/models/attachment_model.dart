import '../../domain/entities/attachment.dart';
import 'json_reader.dart';

/// API representation of an [Attachment].
class AttachmentModel {
  /// Creates a model.
  const AttachmentModel({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.url,
  });

  /// Parses the API attachment object.
  factory AttachmentModel.fromJson(Json json) => AttachmentModel(
    id: json.string('id'),
    name: json.string('name'),
    sizeBytes: json.integer('sizeBytes'),
    url: json.string('url'),
  );

  /// Unique identifier.
  final String id;

  /// File name.
  final String name;

  /// Size in bytes.
  final int sizeBytes;

  /// Download location.
  final String url;

  /// Builds a model from a domain entity.
  factory AttachmentModel.fromEntity(Attachment attachment) => AttachmentModel(
    id: attachment.id,
    name: attachment.name,
    sizeBytes: attachment.sizeBytes,
    url: attachment.url,
  );

  /// Serialises to the API shape, for local storage.
  Json toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'sizeBytes': sizeBytes,
    'url': url,
  };

  /// Converts to the domain entity.
  Attachment toEntity() =>
      Attachment(id: id, name: name, sizeBytes: sizeBytes, url: url);
}
