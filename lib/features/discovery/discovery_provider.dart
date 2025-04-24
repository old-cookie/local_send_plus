import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/models/device_info.dart';

/// Manages the list of discovered devices on the network.
///
/// This notifier holds the state of devices found during discovery
/// and provides methods to add, remove, and clear the list.
class DiscoveredDevicesNotifier extends StateNotifier<List<DeviceInfo>> {
  /// Initializes the notifier with an empty list of devices.
  DiscoveredDevicesNotifier() : super([]);

  /// Adds a device to the list if it's not already present.
  ///
  /// Checks if a device with the same IP address and port already exists
  /// before adding the new device to the state.
  void addDevice(DeviceInfo device) {
    if (!state.any((d) => d.ip == device.ip && d.port == device.port)) {
      state = [...state, device];
    }
  }

  /// Removes a device from the list based on its IP address and port.
  void removeDevice(DeviceInfo device) {
    state = state.where((d) => d.ip != device.ip || d.port != device.port).toList();
  }

  /// Clears all devices from the list asynchronously.
  ///
  /// Uses `Future` to ensure the state update happens after the current microtask.
  /// Checks if the notifier is still mounted before clearing the state.
  void clearDevices() {
    Future(() {
      if (mounted) {
        state = [];
      }
    });
  }
}

/// Provider for accessing the [DiscoveredDevicesNotifier].
///
/// This allows other parts of the application to listen to changes
/// in the list of discovered devices and interact with the notifier.
final discoveredDevicesProvider = StateNotifierProvider<DiscoveredDevicesNotifier, List<DeviceInfo>>((ref) {
  return DiscoveredDevicesNotifier();
});
