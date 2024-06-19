import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'home1.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings.dart';

class PatientDetails extends StatefulWidget {
  const PatientDetails({super.key});

  @override
  State<PatientDetails> createState() => _PatientDetailsState();
}

class Patient {
  String participantID = "";
  String sessionID = "";
  String fname = '';
  String lname = '';
  String sex = 'Male';
  int age = 0;
  double weight = 0.0;
  double height = 0.0;
}

class _PatientDetailsState extends State<PatientDetails> {
  final Permission _bluetoothScanPermission = Permission.bluetoothScan;
  final Permission _bluetoothConnectPermission = Permission.bluetoothConnect;
  final Permission _locationPermission = Permission.location;

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> status = await [
      _bluetoothScanPermission,
      _bluetoothConnectPermission,
      _locationPermission,
    ].request();
    // print(status[_locationPermission]);
    // print(status[_bluetoothScanPermission]);
    // print(status[_bluetoothConnectPermission]);

    if (status[_locationPermission] == PermissionStatus.granted &&
        status[_bluetoothScanPermission] == PermissionStatus.granted &&
        status[_bluetoothConnectPermission] == PermissionStatus.granted) {
      // print('All permissions granted!');
    } else {
      _showSnackBar('Permissions not granted!', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        action: isError
            ? SnackBarAction(
                label: 'Dismiss',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  var patient = Patient();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        leadingWidth: 0,
        title: Container(
          padding: EdgeInsets.fromLTRB(ScreenUtil().setWidth(30), 0, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Participant Details',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            color: Colors.red,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(ScreenUtil().setHeight(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'Participant ID',
                  ),
                  onChanged: (value) {
                    setState(() {
                      patient.participantID = value;
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'Session ID',
                  ),
                  onChanged: (value) {
                    setState(() {
                      patient.sessionID = value;
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'First Name',
                  ),
                  onChanged: (value) {
                    setState(() {
                      patient.fname = value;
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'Last Name',
                  ),
                  onChanged: (value) {
                    setState(() {
                      patient.lname = value;
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                DropdownButtonFormField<String>(
                  value: 'Male',
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        patient.sex = newValue;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Sex',
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                  items: <String>['Male', 'Female', 'Other']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'Age',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      patient.age = int.parse(value);
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'Weight (kg)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      patient.weight = double.parse(value);
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(20)),
                TextField(
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: Colors.black),
                    labelText: 'Height (cm)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      patient.height = double.parse(value);
                    });
                  },
                ),
                SizedBox(height: ScreenUtil().setHeight(40)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      fixedSize: Size(ScreenUtil().setWidth(200),
                          ScreenUtil().setHeight(50))),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Home1(patient: patient)),
                    );
                  },
                  child: const Text(
                    'Submit',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
