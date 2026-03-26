import 'dart:io';

import 'package:clietn_server_application/auth/auth_scope.dart';
import 'package:clietn_server_application/auth/auth_state.dart';
import 'package:clietn_server_application/devices/devices_service.dart';
import 'package:clietn_server_application/logging/app_logger.dart';
import 'package:flutter/material.dart';

String _deviceName() {
  try {
    final hostname = Platform.localHostname;
    if (hostname.isNotEmpty && hostname != 'localhost' && hostname != '127.0.0.1') {
      return hostname;
    }
  } catch (_) {}
  if (Platform.isAndroid) return 'Android Phone';
  if (Platform.isIOS) return 'iPhone';
  return 'Mobile';
}

class DevicesScope extends StatefulWidget {
  const DevicesScope({
    super.key,
    required this.service,
    required this.child,
  });

  final DevicesService service;
  final Widget child;

  static DevicesService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DevicesScopeInherited>();
    assert(scope != null, 'DevicesScope not found');
    return scope!.service;
  }

  /// Returns the registration version. Dependents are rebuilt when this changes.
  static int versionOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DevicesScopeInherited>();
    return scope?.version ?? 0;
  }

  @override
  State<DevicesScope> createState() => _DevicesScopeState();
}

class _DevicesScopeState extends State<DevicesScope> {
  int _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerDevice());
  }

  Future<void> _registerDevice() async {
    if (!mounted) return;
    final auth = AuthScope.of(context).state;
    if (auth is! Authenticated || auth.isDemo) return;
    final deviceId = auth.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      AppLogger.log('[DevicesScope] _registerDevice: no deviceId, skipping');
      return;
    }
    final name = _deviceName();
    AppLogger.log('[DevicesScope] _registerDevice: deviceId=$deviceId name="$name"');
    await widget.service.registerDevice(deviceId, name);
    // Bump version so dependent pages (DevicePage) know to refresh their data.
    if (mounted) setState(() => _version++);
    AppLogger.log('[DevicesScope] _registerDevice: done, version=$_version');
  }

  @override
  Widget build(BuildContext context) {
    return _DevicesScopeInherited(
      service: widget.service,
      version: _version,
      child: widget.child,
    );
  }
}

class _DevicesScopeInherited extends InheritedWidget {
  const _DevicesScopeInherited({
    required this.service,
    required this.version,
    required super.child,
  });

  final DevicesService service;
  final int version;

  @override
  bool updateShouldNotify(_DevicesScopeInherited oldWidget) =>
      service != oldWidget.service || version != oldWidget.version;
}
