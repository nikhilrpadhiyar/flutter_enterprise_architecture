import '../../domain/entities/assignee.dart';
import 'json_reader.dart';

/// API representation of an [Assignee].
class AssigneeModel {
  /// Creates a model.
  const AssigneeModel({required this.id, required this.name});

  /// Parses the API assignee object.
  factory AssigneeModel.fromJson(Json json) =>
      AssigneeModel(id: json.string('id'), name: json.string('name'));

  /// User identifier.
  final String id;

  /// Display name.
  final String name;

  /// Builds a model from a domain entity.
  factory AssigneeModel.fromEntity(Assignee assignee) =>
      AssigneeModel(id: assignee.id, name: assignee.name);

  /// Serialises to the API shape, for local storage.
  Json toJson() => <String, Object?>{'id': id, 'name': name};

  /// Converts to the domain entity.
  Assignee toEntity() => Assignee(id: id, name: name);
}
