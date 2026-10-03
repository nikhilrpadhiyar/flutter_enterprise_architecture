import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/state/view_status.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/requests/update_profile_request.dart';
import '../../../domain/usecases/get_profile_use_case.dart';
import '../../../domain/usecases/observe_pending_changes_use_case.dart';
import '../../../domain/usecases/update_profile_use_case.dart';
import '../../auth/controllers/session_controller.dart';

/// Presentation state and actions of the profile screen.
class ProfileController extends GetxController {
  /// Creates the controller.
  ProfileController(
    this._getProfile,
    this._updateProfile,
    this._observePendingChanges,
    this._session,
    this._messenger,
    this._logger,
  );

  /// Update id of the profile details and form.
  static const String profileId = 'profile';

  /// Update id of the sign out action.
  static const String signOutId = 'profile_sign_out';

  final GetProfileUseCase _getProfile;
  final UpdateProfileUseCase _updateProfile;
  final ObservePendingChangesUseCase _observePendingChanges;
  final SessionController _session;
  final AppMessenger _messenger;
  final AppLogger _logger;

  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// Text of the phone field.
  final TextEditingController phoneController = TextEditingController();

  StreamSubscription<int>? _pendingSubscription;

  /// Current screen state.
  ViewStatus status = ViewStatus.initial;

  /// The profile, once loaded.
  User? user;

  /// Whether the profile comes from this device because the server could not
  /// be reached.
  bool isStale = false;

  /// Why loading failed.
  String? errorMessage;

  /// Per-field error messages, keyed by field name.
  Map<String, String> fieldErrors = <String, String>{};

  /// Error that belongs to no single field.
  String? formError;

  /// Number of changes made offline that are waiting to be sent.
  int pendingChanges = 0;

  /// Whether a save is running.
  bool get isSaving => status == ViewStatus.submitting;

  /// Explains what signing out does, mentioning waiting changes if any.
  String get signOutMessage => pendingChanges > 0
      ? AppStrings.signOutWithPending(pendingChanges)
      : AppStrings.signOutMessage;

  @override
  void onInit() {
    super.onInit();
    _pendingSubscription = _observePendingChanges().listen((count) {
      pendingChanges = count;
    });
    unawaited(load());
  }

  @override
  void onClose() {
    unawaited(_pendingSubscription?.cancel());
    nameController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  /// Loads the profile into the form.
  Future<void> load() async {
    status = ViewStatus.loading;
    errorMessage = null;
    update(<String>[profileId]);
    try {
      final loaded = await _getProfile();
      _show(loaded.data);
      isStale = loaded.isStale;
      status = ViewStatus.success;
    } on Failure catch (failure) {
      _logger.warning(LogTag.controller, 'profile failed', error: failure);
      status = ViewStatus.error;
      errorMessage = failure.message;
    }
    update(<String>[profileId]);
  }

  /// Clears the error of a field when it is edited.
  void onFieldChanged(String field) {
    if (fieldErrors.remove(field) != null) update(<String>[profileId]);
  }

  /// Saves the name and phone number.
  Future<void> save() async {
    if (isSaving || user == null) return;
    fieldErrors = <String, String>{};
    formError = null;
    status = ViewStatus.submitting;
    update(<String>[profileId]);
    try {
      final saved = await _updateProfile(
        UpdateProfileRequest(
          name: nameController.text,
          phone: phoneController.text,
        ),
      );
      _show(saved);
      _session.setUser(saved);
      _messenger.show(AppStrings.profileUpdated);
    } on ValidationFailure catch (failure) {
      fieldErrors = Map<String, String>.of(failure.fieldErrors);
      formError = failure.fieldErrors.isEmpty ? failure.message : null;
    } on Failure catch (failure) {
      formError = failure.message;
    }
    status = ViewStatus.success;
    update(<String>[profileId]);
  }

  /// Signs out and returns to the sign in screen.
  Future<void> signOut() => _session.signOut();

  void _show(User value) {
    user = value;
    nameController.text = value.name;
    phoneController.text = value.phone ?? '';
  }
}
