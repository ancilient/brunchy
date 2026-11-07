import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import 'choose_stall_state.dart';

class ChooseStallCubit extends Cubit<ChooseStallState> {
  final AuthRepository _authRepository;

  ChooseStallCubit(this._authRepository) : super(const ChooseStallInitial());

  Future<void> loadStalls(String canteenId) async {
    emit(const ChooseStallLoading());
    try {
      // [API-003] GET /canteens/{canteenId}/stalls
      final stalls = await _authRepository.getStalls(canteenId);
      if (stalls.isEmpty) {
        emit(const ChooseStallEmpty());
      } else {
        emit(ChooseStallLoaded(stalls));
      }
    } on AppException catch (e) {
      emit(ChooseStallError(e.message));
    } catch (_) {
      emit(const ChooseStallError('Failed to load stalls. Please try again.'));
    }
  }

  Future<void> selectStall(String stallId, {bool forceTakeover = false}) async {
    final today = DateFormatter.todayKey();
    try {
      // [API-004] POST /vendor/session/stall
      await _authRepository.selectStall(
        stallId: stallId,
        date: today,
        forceTakeover: forceTakeover,
      );
      await _authRepository.saveStallSession(stallId: stallId, date: today);
      final currentState = state;
      if (currentState is ChooseStallLoaded) {
        final stall = currentState.stalls.firstWhere((s) => s.id == stallId);
        emit(StallSelected(stall));
      }
    } on AppException catch (e) {
      if (e.code == 'STALL_ALREADY_CLAIMED') {
        final claimedBy = e.message.replaceAll('Stall already claimed by ', '');
        emit(StallClaimConflict(claimedBy: claimedBy, stallId: stallId));
      } else {
        emit(ChooseStallError(e.message));
      }
    } catch (_) {
      emit(const ChooseStallError('Failed to select stall. Please try again.'));
    }
  }

  void retryLoad(String canteenId) => loadStalls(canteenId);
}

