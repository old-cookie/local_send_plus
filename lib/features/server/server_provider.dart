import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerState {
  final bool isRunning;
  final int? port;
  final String? error;
  const ServerState({this.isRunning = false, this.port, this.error});
  ServerState copyWith({bool? isRunning, int? port, String? error, bool clearError = false}) {
    return ServerState(isRunning: isRunning ?? this.isRunning, port: port ?? this.port, error: clearError ? null : error ?? this.error);
  }
}

class ServerStateNotifier extends StateNotifier<ServerState> {
  ServerStateNotifier() : super(const ServerState());
  void setRunning(int port) {
    state = state.copyWith(isRunning: true, port: port, /* https: https, */ clearError: true);
  }

  void setStopped() {
    state = state.copyWith(isRunning: false, port: null, /* https: false, */ clearError: true);
  }

  void setError(String error) {
    state = state.copyWith(isRunning: false, error: error, port: null /* https: false */);
  }
}

final serverStateProvider = StateNotifierProvider<ServerStateNotifier, ServerState>((ref) {
  return ServerStateNotifier();
});
