import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profile_repository.dart';
import '../models/saved_profile.dart';

class ProfilesCubit extends Cubit<List<SavedProfile>> {
  ProfilesCubit(this._repository) : super(_repository.all());

  final ProfileRepository _repository;

  Future<void> save(SavedProfile profile) async {
    await _repository.save(profile);
    emit(_repository.all());
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    emit(_repository.all());
  }

  SavedProfile? byId(String id) => _repository.byId(id);
}
