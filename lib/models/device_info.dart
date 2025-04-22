import 'package:flutter/foundation.dart';

@immutable
class DeviceInfo {
  final String ip;
  final int port;
  final String alias;
  final String? deviceId;
  const DeviceInfo({required this.ip, required this.port, required this.alias, this.deviceId});
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(ip: json['ip'] as String, port: json['port'] as int, alias: json['alias'] as String, deviceId: json['deviceId'] as String?);
  }
  Map<String, dynamic> toJson() {
    return {'ip': ip, 'port': port, 'alias': alias, 'deviceId': deviceId};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port &&
          alias == other.alias &&
          deviceId == other.deviceId;
  @override
  int get hashCode => ip.hashCode ^ port.hashCode ^ alias.hashCode ^ deviceId.hashCode;
  @override
  String toString() {
    return 'DeviceInfo{ip: $ip, port: $port, alias: $alias, deviceId: $deviceId}'; // Removed fields
  }
}
