import 'package:clietn_server_application/devices/devices_service.dart';
import 'package:flutter/material.dart';

class DevicesScope extends InheritedWidget {
  const DevicesScope({
    super.key,
    required this.service,
    required super.child,
  });

  final DevicesService service;

  static DevicesService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DevicesScope>();
    assert(scope != null, 'DevicesScope not found');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(DevicesScope oldWidget) =>
      service != oldWidget.service;
}
