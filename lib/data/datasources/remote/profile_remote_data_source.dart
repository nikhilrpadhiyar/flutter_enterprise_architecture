import 'package:flutter_network_plus/flutter_network_plus.dart' as fnp;

import '../../../domain/requests/update_profile_request.dart';
import '../../models/requests/request_bodies.dart';
import '../../models/user_model.dart';
import 'api_endpoints.dart';
import 'remote_outcome.dart';
import 'remote_requester.dart';

/// The signed-in user's profile endpoints.
class ProfileRemoteDataSource {
  /// Creates the data source.
  ProfileRemoteDataSource(this._requester);

  final RemoteRequester _requester;

  /// Loads the profile.
  Future<RemoteData<UserModel>> getProfile() => _requester.read<UserModel>(
    ApiEndpoints.profile,
    decoder: UserModel.fromJson,
  );

  /// Saves profile changes.
  Future<UserModel> updateProfile(UpdateProfileRequest request) =>
      _requester.write<UserModel>(
        fnp.HttpMethod.patch,
        ApiEndpoints.profile,
        body: RequestBodies.updateProfile(request),
        decoder: UserModel.fromJson,
      );
}
