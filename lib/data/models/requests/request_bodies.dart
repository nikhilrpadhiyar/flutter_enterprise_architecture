import '../../../domain/requests/create_task_request.dart';
import '../../../domain/requests/register_request.dart';
import '../../../domain/requests/update_profile_request.dart';
import '../../../domain/requests/update_task_request.dart';
import '../json_reader.dart';

/// JSON bodies sent to the API, built from domain request objects.
abstract final class RequestBodies {
  /// Body of `POST auth/login`.
  static Json login({required String email, required String password}) =>
      <String, Object?>{'email': email, 'password': password};

  /// Body of `POST auth/register`.
  static Json register(RegisterRequest request) => <String, Object?>{
    'name': request.name,
    'email': request.email,
    'password': request.password,
  };

  /// Body of `POST auth/refresh`.
  static Json refresh(String refreshToken) => <String, Object?>{
    'refreshToken': refreshToken,
  };

  /// Body of `PATCH profile`. Only provided fields are sent.
  static Json updateProfile(UpdateProfileRequest request) => <String, Object?>{
    if (request.name != null) 'name': request.name,
    if (request.phone != null) 'phone': request.phone,
  };

  /// Body of `POST tasks`.
  static Json createTask(CreateTaskRequest request) => <String, Object?>{
    'title': request.title,
    'description': request.description,
    'projectId': request.projectId,
    'priority': request.priority.name,
    if (request.assigneeId != null) 'assigneeId': request.assigneeId,
    if (request.dueDate != null)
      'dueDate': request.dueDate!.toUtc().toIso8601String(),
  };

  /// Body of `PATCH tasks/{id}`. Only changed fields are sent; clearing the
  /// deadline sends an explicit null.
  static Json updateTask(UpdateTaskRequest request) => <String, Object?>{
    if (request.title != null) 'title': request.title,
    if (request.description != null) 'description': request.description,
    if (request.status != null) 'status': request.status!.name,
    if (request.priority != null) 'priority': request.priority!.name,
    if (request.assigneeId != null) 'assigneeId': request.assigneeId,
    if (request.clearDueDate)
      'dueDate': null
    else if (request.dueDate != null)
      'dueDate': request.dueDate!.toUtc().toIso8601String(),
  };
}
