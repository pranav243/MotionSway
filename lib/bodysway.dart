import 'dart:async';
import 'package:flutter/material.dart';
import 'details.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polar/polar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

class BodySway extends StatefulWidget {
  const BodySway({super.key, required this.patient});
  final Patient patient;

  @override
  State<BodySway> createState() => _BodySwayState();
}

class _BodySwayState extends State<BodySway> {
  var username = "";
  var password = "";
  var identifier = "";
  var connectionStatus = "Not Connected";
  final polar = Polar();
  Timer? _timer;
  String timerDisplay = "0:10";
  int _start = 10;
  bool recordingEnded = false;
  int currentRecordingStartIndex = 0;
  StreamSubscription? accSubscription;

  @override
  void dispose() {
    accSubscription?.cancel();

    polar.disconnectFromDevice(identifier);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      identifier = prefs.getString('device_id') ?? 'D0536223';
      username = prefs.getString('username') ?? 'polar';
      password = prefs.getString('password') ?? 'Yq0M@6c\$WX1';
    });
  }

  int toNanosecondsSinceEpoch(DateTime dateTime) {
    final epoch = DateTime.utc(1970, 1, 1);
    final duration = dateTime.toUtc().difference(epoch);
    final nanoseconds = duration.inMicroseconds * 1000;
    return nanoseconds;
  }

  void streamWhenReady() async {
    // print(identifier);
    print('In streamFunction');
    polar.connectToDevice(identifier);

    // polar.batteryLevel.listen((e) => _showSnackBar('Battery: ${e.level}'));
    polar.deviceConnecting.listen((_) {
      if (!mounted) return;

      _showSnackBar('Device $identifier connecting');
    });

    polar.deviceConnected.listen((event) {
      if (!mounted) return;

      _showSnackBar('Device $identifier connected');
      setState(() {
        connectionStatus = "Connected";
      });
    });
    polar.deviceDisconnected.listen((even) {
      if (!mounted) return;

      _showSnackBar('Device $identifier disconnected');
      setState(() {
        connectionStatus = "Not Connected";
        isAccReady = false;
        snackbarShown = false;
      });
    });

    await polar.sdkFeatureReady.firstWhere(
      (e) =>
          e.identifier == identifier &&
          e.feature == PolarSdkFeature.onlineStreaming,
    );
    final availabletypes =
        await polar.getAvailableOnlineStreamDataTypes(identifier);

    if (availabletypes.contains(PolarDataType.acc)) {
      accSubscription = polar
          .startAccStreaming(identifier
              // settings: PolarSensorSetting({PolarSettingType.sampleRate: 200}))
              )
          .listen((data) {
        if (!mounted) return;

        int accx = data.samples.first.x;
        int accy = data.samples.first.y;
        int accz = data.samples.first.z;
        setState(() {
          isAccReady = true;
          checkAllReady();
          this.accX = accx;
          this.accY = accy;
          this.accZ = accz;
          accDataList.add([
            widget.patient.participantID,
            widget.patient.sessionID,
            widget.patient.fname,
            widget.patient.lname,
            widget.patient.age,
            widget.patient.sex,
            widget.patient.weight,
            widget.patient.height,
            stancelist[stance],
            iterlist[iter],
            toNanosecondsSinceEpoch(DateTime.now()).toString(),
            toNanosecondsSinceEpoch(data.samples.first.timeStamp).toString(),
            accX,
            accY,
            accZ
          ]);
        });
      });
    }
  }

  void checkAllReady() {
    if (isAccReady && !snackbarShown) {
      snackbarShown = true;
      _showSnackBar('All sensors are ready. You can start recording now.');
    }
  }

  bool isAccReady = false;
  bool snackbarShown = false;
  int accX = 0;
  int accY = 0;
  int accZ = 0;
  List<List<dynamic>> accDataList = [];
  List<List<dynamic>> finalAccData = [];

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

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

  void updateTimerDisplay() {
    _timer?.cancel();
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          setState(() {
            _start--;
            timerDisplay = "0:${_start.toString().padLeft(2, '0')}";
          });
        }
      },
    );
  }

  void startRecordingAcc() {
    _timer?.cancel();
    print("Recording start");
    accDataList.clear(); // Clear previous HR data when starting new recording
    _start = 10; // Reset the timer to 30 seconds
    timerDisplay = "0:${_start.toString().padLeft(2, '0')}";
    updateTimerDisplay(); // Start the timer update for the display
    setState(() {
      currentRecordingStartIndex = finalAccData.length;
    });
    _timer = Timer(const Duration(seconds: 10), stopRecordingAcc);
  }

  void stopRecordingAcc() {
    // Save HR data to CSV file
    _timer?.cancel();
    finalAccData.addAll(accDataList);
    setState(() {
      recordingEnded = true;
    });
  }

  void saveAccDataToCSV() async {
    try {
      final String dir = (await getExternalStorageDirectory())!.path;
      final String path =
          '$dir/${widget.patient.participantID}_${widget.patient.sessionID}_bodysway_acc.csv';
      final File file = File(path);

      List<List<dynamic>> csvData = [
        [
          'ParticipantID',
          'SessionID',
          'First Name',
          'Last Name',
          'Age',
          'Sex',
          'Weight',
          'Height',
          'Stance',
          'Iteration',
          'Timestamp(Local)',
          'Timestamp(Polar)',
          'AccX',
          'AccY',
          'AccZ'
        ]
      ];

      csvData.addAll(finalAccData);
      // Convert data to CSV format
      String csvString = const ListToCsvConverter().convert(csvData);

      // Write CSV data to file
      await file.writeAsString(csvString);

      // Function to upload the file
      Future<void> uploadFile(String filePath, String fileType) async {
        try {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse("https://param.nimhans.ac.in/dashboard/uploadPEBL.php"),
          );

          request.fields['user_name'] = username; // Replace with your username
          request.fields['upload_password'] = password;
          request.fields['taskname'] = 'bodysway';
          request.fields['subnum'] = widget.patient.participantID;

          // Add the file
          request.files.add(await http.MultipartFile.fromPath(
            'fileToUpload',
            filePath,
          ));

          // Send the request
          var response = await request.send();

          // Handle the response
          if (response.statusCode == 200) {
            print('$fileType data uploaded successfully');
            _showSnackBar('$fileType data uploaded successfully');
          } else {
            print('Error uploading $fileType data: ${response.statusCode}');
            _showSnackBar(
                'Error uploading $fileType data: ${response.statusCode}');
          }
        } catch (e) {
          print('Exception caught during $fileType file upload: $e');
          _showSnackBar('Exception caught during $fileType file upload: $e',
              isError: true);
        }
      }

      // Show directory where files are saved
      _showSnackBar('Data saved to: $dir');

      // Upload the file
      await uploadFile(path, 'ACC');
    } catch (e) {
      print('Exception caught during saving ACC data: $e');
      _showSnackBar('Exception caught during saving ACC data: $e');
    }
  }

  final stancelist = [
    'FeetTogetherEyesClosed',
    'TandemEyesClosedRight',
    'TandemEyesClosedLeft',
    'SingleLegEyesClosedRight',
    'SingleLegEyesClosedLeft'
  ];
  final iterlist = ['Trial', '1', '2', '3'];
  var stance = 0;
  var iter = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        leadingWidth: 0,
        title: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'BodySway',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
                height: ScreenUtil()
                    .setHeight(20)), // Add some space between containers

            Container(
              padding: EdgeInsets.all(ScreenUtil().setHeight(10)),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 5)),
              width: ScreenUtil().setWidth(300),
              height: ScreenUtil().setHeight(180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(ScreenUtil().setHeight(5)),
                    width: ScreenUtil().setWidth(300),
                    height: ScreenUtil().setHeight(30),
                    decoration: const BoxDecoration(color: Colors.red),
                    child: const Text(
                      "Patient Details",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: ScreenUtil().setHeight(10)),
                  Text("ParticipantID: ${widget.patient.participantID}"),
                  Text("SessionID: ${widget.patient.sessionID}"),
                  Text("Name: ${widget.patient.fname} ${widget.patient.lname}"),
                  Text("Age: ${widget.patient.age}"),
                  Text("Sex: ${widget.patient.sex}"),
                  Text("Weight: ${widget.patient.weight}"),
                  Text("Height: ${widget.patient.height}"),
                ],
              ),
            ),
            SizedBox(
                height: ScreenUtil()
                    .setHeight(80)), // Add some space between containers

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(20, 20)),
                  border: Border.all(color: Colors.red, width: 3)),
              width: ScreenUtil().setWidth(340),
              height: ScreenUtil().setHeight(200),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Stance: ${stancelist[stance]}"),
                      Text("Iteration: ${iterlist[iter]}")
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        child: Text(timerDisplay),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          fixedSize: Size(
                            ScreenUtil().setWidth(100),
                            ScreenUtil().setHeight(30),
                          ),
                        ),
                        onPressed: () {
                          if (recordingEnded) {
                            // Remove the data added during the current recording
                            finalAccData.removeRange(currentRecordingStartIndex,
                                finalAccData.length);
                            startRecordingAcc();
                          } else {
                            startRecordingAcc();
                          }
                        },
                        child: Text(recordingEnded ? "Retry" : "Start"),
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            fixedSize: Size(
                              ScreenUtil().setWidth(100),
                              ScreenUtil().setHeight(30),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              if (iter == 3 && stance == 4) {
                                _showSnackBar(
                                    "Done with all experiments. Press Submit.");
                              } else {
                                recordingEnded = false;
                                timerDisplay = "0:10";
                                stance++;
                                if (stance == 5) {
                                  stance = 0;
                                  iter++;
                                }
                              }
                            });
                          },
                          child: const Text("Next"))
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: ScreenUtil().setHeight(10),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                fixedSize: Size(
                  ScreenUtil().setWidth(100),
                  ScreenUtil().setHeight(20),
                ),
              ),
              child: const Text('Submit'),
              onPressed: () async {
                saveAccDataToCSV();
              },
            ),
            SizedBox(
              height: ScreenUtil().setHeight(100),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                fixedSize: Size(
                  ScreenUtil().setWidth(150),
                  ScreenUtil().setHeight(50),
                ),
              ),
              child: const Text('Connect'),
              onPressed: () async {
                if (connectionStatus == "Not Connected") {
                  streamWhenReady();
                }
              },
            ),
            Text("Device Status: $connectionStatus")
          ],
        ),
      ),
    );
  }
}
