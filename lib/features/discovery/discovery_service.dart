import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_send_plus/features/discovery/discovery_provider.dart';
import 'package:local_send_plus/models/device_info.dart';
import 'package:local_send_plus/providers/settings_provider.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService(ref);
});

class DiscoveryService {
  final Ref _ref;
  RawDatagramSocket? _socket;
  Timer? _discoveryTimer;
  bool _isDiscovering = false;
  final Set<String> _localIPs = {};
  final Map<String, Timer> _deviceExpiryTimers = {};
  final Duration _deviceTimeout = const Duration(seconds: 15);
  final Duration _discoveryInterval = const Duration(seconds: 5);
  final String _multicastAddress = '224.0.0.1';
  DiscoveryService(this._ref);
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    const int listenPort = 2706; // Use fixed port
    await _updateLocalIPs();
    if (_localIPs.isEmpty) {
      print("Warning: Could not determine local IP addresses. Self-discovery filtering might not work.");
    }
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
      _socket!.joinMulticast(InternetAddress(_multicastAddress));
      _socket!.listen(
        _handleResponse,
        onError: (error) {
          print('Discovery socket error: $error');
          stopDiscovery();
        },
        onDone: () {
          print('Discovery socket closed.');
          _isDiscovering = false;
        },
      );
      _isDiscovering = true;
      print('Discovery started on port $listenPort, joined multicast group $_multicastAddress');
      await _sendDiscoveryPacket();
      _discoveryTimer = Timer.periodic(_discoveryInterval, (timer) async {
        if (!_isDiscovering) {
          timer.cancel();
          return;
        }
        await _sendDiscoveryPacket();
      });
    } catch (e) {
      print('Failed to start discovery: $e');
      _isDiscovering = false;
      await stopDiscovery();
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering && _socket == null && _discoveryTimer == null) return;
    print('Stopping discovery...');
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _socket?.close();
    _socket = null;
    _deviceExpiryTimers.values.forEach((timer) => timer.cancel());
    _deviceExpiryTimers.clear();
    _ref.read(discoveredDevicesProvider.notifier).clearDevices();
    print('Discovery stopped.');
  }

  Future<void> _sendDiscoveryPacket() async {
    if (_socket == null || !_isDiscovering) return;
    final String alias = _ref.read(deviceAliasProvider);
    const int port = 2706;
    final message = jsonEncode({'alias': alias, 'port': port, 'type': 'discovery_request'});
    final data = utf8.encode(message);
    try {
      _socket!.send(data, InternetAddress(_multicastAddress), port);
    } catch (e) {
      print('Error sending discovery packet: $e');
    }
  }

  void _handleResponse(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram == null) return;
      try {
        final message = utf8.decode(datagram.data);
        final data = jsonDecode(message);
        final String senderIp = datagram.address.address;
        final int senderPort = data['port'];
        final String senderAlias = data['alias'];
        const int localPort = 2706;
        if (senderPort == localPort && _isOwnIp(senderIp)) {
          return;
        }
        if (data['type'] == 'discovery_request' || data['type'] == 'discovery_response') {
          final deviceInfo = DeviceInfo(ip: senderIp, port: senderPort, alias: senderAlias);
          final deviceKey = '${deviceInfo.ip}:${deviceInfo.port}';
          _deviceExpiryTimers[deviceKey]?.cancel();
          _ref.read(discoveredDevicesProvider.notifier).addDevice(deviceInfo);
          _deviceExpiryTimers[deviceKey] = Timer(_deviceTimeout, () {
            print('Device ${deviceInfo.alias} ($deviceKey) timed out.');
            _ref.read(discoveredDevicesProvider.notifier).removeDevice(deviceInfo);
            _deviceExpiryTimers.remove(deviceKey);
          });
        }
      } catch (e) {
        print('Error processing received packet from ${datagram.address.address}: $e');
      }
    }
  }

  bool _isOwnIp(String ip) {
    return _localIPs.contains(ip);
  }

  Future<void> _updateLocalIPs() async {
    _localIPs.clear();
    try {
      for (var interface in await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4)) {
        for (var addr in interface.addresses) {
          _localIPs.add(addr.address);
        }
      }
      print("Local IPs updated: $_localIPs");
    } catch (e) {
      print("Error fetching local IPs: $e");
    }
  }
}
