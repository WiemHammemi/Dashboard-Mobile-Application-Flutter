
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BluetoothDashboard(),
    );
  }
}

class BluetoothDashboard extends StatefulWidget {
  @override
  _BluetoothDashboardState createState() => _BluetoothDashboardState();
}

class _BluetoothDashboardState extends State<BluetoothDashboard> {
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  bool _isConnecting = false;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _deviceConnected;

  // Mesures reçues
  String temperature = '0';
  String humidity = '0';
  String gasLevel = '0';
  bool alert = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });
    _bluetooth.onStateChanged().listen((state) {
      setState(() {
        _bluetoothState = state.isEnabled;
      });
    });

    // Vérification périodique des seuils
    Timer.periodic(Duration(seconds: 1), (timer) => _checkThresholds());
  }

  void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }


void _handleDataReceived(Uint8List data) {
  String receivedData = String.fromCharCodes(data).trim();
  List<String> keyValuePairs = receivedData.split(',');

  for (String pair in keyValuePairs) {
    List<String> keyValue = pair.split(':');
    if (keyValue.length == 2) {
      String key = keyValue[0];
      String value = keyValue[1];

      setState(() {
        if (key == 'Temp') {
          temperature = value;
        } else if (key == 'Hum') {
          humidity = value;
        } else if (key == 'Gas') {
          gasLevel = value;
        }
      });
    }
  }
}

void _connectToDevice(BluetoothDevice device) async {
  setState(() => _isConnecting = true);

  try {
    _connection = await BluetoothConnection.toAddress(device.address);
    _deviceConnected = device;

    _connection?.input?.listen(_handleDataReceived).onDone(() {
      // Reset values and handle disconnection
      setState(() {
        temperature = '0';
        humidity = '0';
        gasLevel = '0';
        _deviceConnected = null;
      });
    });

    setState(() => _isConnecting = false);
  } catch (e) {
    setState(() => _isConnecting = false);
    debugPrint('Erreur lors de la connexion : $e');
  }
}

  void _checkThresholds() {
    List<String> alerts = [];

    if (double.tryParse(temperature)! > 35) {
      alerts.add('Température (${temperature}˚C)');
    }
    if (double.tryParse(humidity)! > 70) {
      alerts.add('Humidité (${humidity}%)');
    }
    if (double.tryParse(gasLevel)! > 300) {
      alerts.add('Gaz (${gasLevel} ppm)');
    }

    if (alerts.isNotEmpty && !alert) {
      setState(() => alert = true);
      _showAlert(alerts);
    }
  }

  void _showAlert(List<String> alerts) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text(
                'Alerte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(color: Colors.redAccent, thickness: 1.2),
              SizedBox(height: 10),
              Text(
                'Les seuils suivants ont été dépassés :',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              ...alerts.map((alert) => Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert,
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                    ],
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => alert = false);
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  
  Widget _buildCircularSlider(String label, String value, String unit, String trackColor, String progressColor, {double maxValue = 100}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SleekCircularSlider(
        appearance: CircularSliderAppearance(
          customWidths: CustomSliderWidths(trackWidth: 4, progressBarWidth: 20, shadowWidth: 40),
          customColors: CustomSliderColors(
            trackColor: HexColor(trackColor),
            progressBarColor: HexColor(progressColor),
            shadowColor: HexColor(progressColor),
            shadowMaxOpacity: 0.5,
            shadowStep: 20,
          ),
          infoProperties: InfoProperties(
            bottomLabelStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
            bottomLabelText: label,
            mainLabelStyle: TextStyle(fontSize: 30.0, fontWeight: FontWeight.w600, color: Colors.black),
            modifier: (double val) => "$value $unit",
          ),
          startAngle: 90,
          angleRange: 360,
          size: 150.0,
          animationEnabled: true,
        ),
        min: 0,
        max: maxValue,
        initialValue: double.tryParse(value) ?? 0,
      ),
    );
  }

  Widget _controlBT() {
    return Card(
      margin: const EdgeInsets.all(10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          _bluetoothState ? Icons.bluetooth : Icons.bluetooth_disabled,
          color: _bluetoothState ? Colors.blue : Colors.grey,
          size: 30,
        ),
        title: Text(
          _bluetoothState ? "Bluetooth activé" : "Bluetooth désactivé",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: Switch(
          value: _bluetoothState,
          onChanged: (bool value) async {
            if (value) {
              await _bluetooth.requestEnable();
            } else {
              await _bluetooth.requestDisable();
            }
          },
        ),
      ),
    );
  }

  Widget _infoDevice() {
    return Card(
      margin: const EdgeInsets.all(10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.devices,
          color: Colors.green,
          size: 30,
        ),
        title: Text(
          "Connecté à: ${_deviceConnected?.name ?? "Aucun"}",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: _connection?.isConnected ?? false
            ? ElevatedButton(
                onPressed: () async {
                  await _connection?.finish();
                  setState(() => _deviceConnected = null);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Déconnecter", style: TextStyle(color: Colors.white)),
              )
            : ElevatedButton(
                onPressed: _getDevices,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Voir dispositifs", style: TextStyle(color: Colors.white)),
              ),
      ),
    );
  }

  void _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    setState(() => _devices = res);
  }

  Widget _listDevices() {
    return Card(
      margin: const EdgeInsets.all(10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              "Appareils disponibles",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _isConnecting
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    for (final device in _devices)
                      ListTile(
                        title: Text(
                          device.name ?? device.address,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            _connectToDevice(device);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Connecter', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Dashboard Bluetooth'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _controlBT(),
            _infoDevice(),
            _buildCircularSlider("Température", temperature, "˚C", "#ef6c00", "#ffb74d"),
            _buildCircularSlider("Humidité", humidity, "%", "#0277bd", "#4FC3F7"),
            _buildCircularSlider("Gaz", gasLevel, "ppm", "#8e44ad", "#9b59b6", maxValue: 1000),
            _listDevices(),
          ],
        ),
      ),
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
