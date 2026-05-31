import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/code_models.dart';
import '../data/codes_api.dart';
import 'codes_list_controller.dart';
import 'codes_providers.dart';

/// Holds one code (keyed by id) for the detail screen, with edit/delete actions.
///
/// `build(id)` fetches the code. [updateLabel]/[updateDestination] apply the
/// change optimistically, call the API, and roll back on error (rethrowing so
/// the screen can SnackBar it); on success they sync the list provider so the
/// dashboard reflects the edit. [delete] removes it and updates the list.
final codeDetailControllerProvider =
    AsyncNotifierProvider.family<CodeDetailController, Code, String>(
      CodeDetailController.new,
    );

class CodeDetailController extends FamilyAsyncNotifier<Code, String> {
  CodesApi get _api => ref.read(codesApiProvider);
  CodesListController get _list =>
      ref.read(codesListControllerProvider.notifier);

  @override
  Future<Code> build(String id) => _api.get(id);

  /// Optimistically sets the label, persists it, rolls back + rethrows on error.
  Future<void> updateLabel(String label) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(label: label));
    try {
      final updated = await _api.update(arg, label: label);
      state = AsyncData(updated);
      _list.replaceCode(updated);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Optimistically sets the dynamic destination, persists it, rolls back +
  /// rethrows on error. No-op for static codes.
  Future<void> updateDestination(String destination) async {
    final previous = state.valueOrNull;
    if (previous == null || previous.dynamicInfo == null) return;
    state = AsyncData(
      previous.copyWith(
        dynamicInfo: previous.dynamicInfo!.copyWith(destination: destination),
      ),
    );
    try {
      final updated = await _api.update(arg, destination: destination);
      state = AsyncData(updated);
      _list.replaceCode(updated);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Deletes the code and removes it from the dashboard list.
  Future<void> delete() async {
    await _api.delete(arg);
    _list.optimisticallyRemoveCode(arg);
  }
}
