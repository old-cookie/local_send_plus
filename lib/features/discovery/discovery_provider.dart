import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/models/device_info.dart';

class DiscoveredDevicesNotifier extends StateNotifier<List<DeviceInfo>> {
  DiscoveredDevicesNotifier() : super([]);
  void addDevice(DeviceInfo device) {
    if (!state.any((d) => d.ip == device.ip && d.port == device.port)) {
      state = [...state, device];
    }
  }

  void removeDevice(DeviceInfo device) {
    state = state.where((d) => d.ip != device.ip || d.port != device.port).toList();
  }

  void clearDevices() {
    Future(() {
      if (mounted) {
        state = [];
      }
    });
  }
}

final discoveredDevicesProvider = StateNotifierProvider<DiscoveredDevicesNotifier, List<DeviceInfo>>((ref) {
  return DiscoveredDevicesNotifier();
});
