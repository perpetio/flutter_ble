import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_ble/control_button.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter BLE Demo',
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  final List<BluetoothDevice> _devicesList = [];
  List<BluetoothService>? bluetoothServices;
  List<ControlButton> controlButtons = [];
  String? readableValue;

  @override
  void initState() {
    initBleList();
    super.initState();
  }

  Future initBleList() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothAdvertise.request();
    flutterBlue.connectedDevices.asStream().listen((devices) {
      for (var device in devices) {
        _addDeviceTolist(device);
      }
    });
    flutterBlue.scanResults.listen((scanResults) {
      for (var result in scanResults) {
        _addDeviceTolist(result.device);
      }
    });
    flutterBlue.startScan();
  }

  void _addDeviceTolist(BluetoothDevice device) {
    if (!_devicesList.contains(device)) {
      setState(() {
        _devicesList.add(device);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Flutter BLE')), body: bluetoothServices == null ? _buildListViewOfDevices() : _buildControlButtons());
  }

  ListView _buildListViewOfDevices() {
    List<Widget> containers = [];
    for (BluetoothDevice device in _devicesList.where((element) => element.name.isNotEmpty)) {
      containers.add(
        SizedBox(
          height: 60,
          child: Row(
            children: <Widget>[
              Expanded(child: Column(children: <Widget>[Text(device.name), Text(device.id.toString())])),
              ElevatedButton(
                child: const Text('Connect', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  if (device.name.contains('GoPro')) {
                    try {
                      await device.connect();
                      controlButtons.addAll([
                        ControlButton(buttonName: 'Record On', onTap: () => writeValue([0x03, 0x01, 0x01, 0x01])),
                        ControlButton(buttonName: 'Record Off', onTap: () => writeValue([0x03, 0x01, 0x01, 0x00])),
                        ControlButton(buttonName: 'Camera sleep', onTap: () => writeValue([0x01, 0x05])),
                        ControlButton(buttonName: 'Show camera WiFi AP SSID', onTap: () => readValue('0002')),
                        ControlButton(buttonName: 'Show camera WiFi AP Password	', onTap: () => readValue('0003')),
                      ]);
                      List<BluetoothService> services = await device.discoverServices();
                      setState(() {
                        bluetoothServices = services;
                      });
                    } catch (e) {
                      await device.disconnect();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(8), children: <Widget>[...containers]);
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        Wrap(
          children: controlButtons
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: ElevatedButton(onPressed: e.onTap, child: Text(e.buttonName)),
                  ))
              .toList(),
        ),
        Center(child: Text(readableValue ?? '')),
      ],
    );
  }

  Future<void> writeValue(List<int> value) async {
    BluetoothService? bluetoothService = bluetoothServices?.firstWhere((element) => element.uuid.toString() == '0000fea6-0000-1000-8000-00805f9b34fb');
    BluetoothCharacteristic? bluetoothCharacteristic =
        bluetoothService?.characteristics.firstWhere((element) => element.uuid.toString() == 'b5f90072-aa8d-11e3-9046-0002a5d5c51b');
    bluetoothCharacteristic?.write(value);
  }

  Future<void> readValue(String characteristicUUID) async {
    BluetoothService? bluetoothService = bluetoothServices?.firstWhere((element) => element.uuid.toString() == 'b5f90001-aa8d-11e3-9046-0002a5d5c51b');

    BluetoothCharacteristic? bluetoothCharacteristic =
        bluetoothService?.characteristics.firstWhere((element) => element.uuid.toString() == 'b5f9$characteristicUUID-aa8d-11e3-9046-0002a5d5c51b');
    List<int>? utf8Response = await bluetoothCharacteristic?.read();
    setState(() {
      readableValue = utf8.decode(utf8Response ?? []);
    });
  }
}
