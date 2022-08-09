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
  String? wifiNameValue;
  String? wifiPasswordValue;

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
    return Scaffold(
        appBar: AppBar(title: const Text('Flutter BLE')),
        body: bluetoothServices == null
            ? Column(
                children: [
                  const SizedBox(height: 20),
                  const Text('Available devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(child: _buildListViewOfDevices()),
                ],
              )
            : _buildControlButtons());
  }

  ListView _buildListViewOfDevices() {
    List<Widget> containers = [];
    for (BluetoothDevice device in _devicesList.where((element) => element.name.isNotEmpty)) {
      containers.add(
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(device.name), Text(device.id.toString())])),
                const Spacer(),
                ElevatedButton(
                  child: const Text('Connect', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () async {
                    if (device.name.contains('GoPro')) {
                      try {
                        await device.connect();
                        controlButtons.addAll([
                          ControlButton(buttonName: 'Record On', onTap: () => writeValue([0x03, 0x01, 0x01, 0x01]), section: 1),
                          ControlButton(buttonName: 'Record Off', onTap: () => writeValue([0x03, 0x01, 0x01, 0x00]), section: 1),
                          ControlButton(buttonName: 'Turn off camera', onTap: () => writeValue([0x01, 0x05]), section: 2),
                          ControlButton(buttonName: 'Fetch Camera WiFi name', onTap: () => readValue('0002'), section: 3),
                          ControlButton(buttonName: 'Fetch Camera Password	', onTap: () => readValue('0003'), section: 3),
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
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(8), children: <Widget>[...containers]);
  }

  Widget _buildControlButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text('Camera control: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Wrap(
            children: controlButtons
                .where((element) => element.section == 1)
                .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: ElevatedButton(onPressed: e.onTap, child: Text(e.buttonName))))
                .toList()),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text('Camera power control: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Wrap(
            children: controlButtons
                .where((element) => element.section == 2)
                .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: ElevatedButton(onPressed: e.onTap, child: Text(e.buttonName))))
                .toList()),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text('Camera WiFi information: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: controlButtons
                .where((element) => element.section == 3)
                .map((e) => Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: ElevatedButton(onPressed: e.onTap, child: Text(e.buttonName))),
                        Text((e.buttonName == 'Fetch Camera WiFi name' ? wifiNameValue : wifiPasswordValue) ?? '', style: const TextStyle(fontSize: 16)),
                      ],
                    ))
                .toList()),
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
      String decodeValue = utf8.decode(utf8Response ?? []);
      if (characteristicUUID == '0002') {
        wifiNameValue = decodeValue;
      } else {
        wifiPasswordValue = decodeValue;
      }
    });
  }
}
