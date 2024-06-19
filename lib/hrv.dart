import 'dart:async';
import 'package:flutter/material.dart';
import 'details.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polar/polar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'package:permission_handler/permission_handler.dart';


class HRV extends StatefulWidget {
  const HRV({super.key, required this.patient});
  final Patient patient;

  @override
  State<HRV> createState() => _HRVState();
}

class _HRVState extends State<HRV> {
  var username = "";
  var password = "";
  var identifier = "";
  var connectionStatus = "Not Connected";
  int phase = 0;
  bool recordingEnded = false;
  bool recordingStarted = false;
  int _start = 300;
  List<List<dynamic>> accDataList = [];
  List<List<dynamic>> hrDataList = [];
  List<List<dynamic>> ecgDataList = [];
  List<List<dynamic>> finalecgData = [];
  List<List<dynamic>> finalaccData = [];
  List<List<dynamic>> finalhrData = [];
  StreamSubscription? hrSubscription;
  StreamSubscription? ecgSubscription;
  StreamSubscription? accSubscription;
  bool isHrReady = false;
  bool isAccReady = false;
  bool isEcgReady = false;
  bool snackbarShown = false;

  Timer? _timer;

  final polar = Polar();

  String timerDisplay = "5:00";

  final phaselist = ['Baseline', 'Rest', 'Handgrip', 'Recovery'];
  @override
  void dispose() {
    accSubscription?.cancel();
    ecgSubscription?.cancel();
    hrSubscription?.cancel();

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
        isHrReady = false;
        isAccReady = false;
        isEcgReady = false;
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

    if (availabletypes.contains(PolarDataType.ecg)) {
      ecgSubscription = polar.startEcgStreaming(identifier).listen((data) {
        if (!mounted) return;
        // print("ecgrunning");
        setState(() {
          isEcgReady = true;

          // Prepare common data for each entry
          List<dynamic> commonData = [
            widget.patient.participantID,
            widget.patient.sessionID,
            widget.patient.fname,
            widget.patient.lname,
            widget.patient.age,
            widget.patient.sex,
            widget.patient.weight,
            widget.patient.height,
            phaselist[phase],
            toNanosecondsSinceEpoch(DateTime.now()).toString(),
            toNanosecondsSinceEpoch(data.samples.first.timeStamp).toString()
          ];

          // Iterate over each sample to add individual sample data
          List<dynamic> voltageValues =
              data.samples.map((sample) => sample.voltage).toList();

          // Add the common data and voltage values to the ecgDataList
          commonData.addAll(voltageValues);
          ecgDataList.add(commonData);
        });
      });
    }

    if (availabletypes.contains(PolarDataType.hr)) {
      hrSubscription = polar.startHrStreaming(identifier).listen((data) {
        if (!mounted) return;
        // print("hrrunning");
        DateTime now = DateTime.now();
        int hr = data.samples.first.hr;
        var time = toNanosecondsSinceEpoch(now).toString();
        setState(() {
          isHrReady = true;
          checkAllReady();
          // Prepare common data for each entry
          List<dynamic> commonData2 = [
            widget.patient.participantID,
            widget.patient.sessionID,
            widget.patient.fname,
            widget.patient.lname,
            widget.patient.age,
            widget.patient.sex,
            widget.patient.weight,
            widget.patient.height,
            phaselist[phase],
            // DateFormat("yyyy-MM-dd HH:mm:ss.S")
            //     .format(DateTime.now())
            //     .toString(),
            time,
            data.samples.first.hr
          ];

          // Iterate over each sample to add individual sample data
          // List<dynamic> rrValues =
          //     data.samples.first.rrsMs.map((sample) => sample).toList();

          // // Add the common data and voltage values to the ecgDataList
          // commonData2.addAll(rrValues);
          List<dynamic> rrValues = data.samples.first.rrsMs.take(2).toList();

// Add the common data and the first two RR values to the commonData2 list
          commonData2.addAll(rrValues);
          hrDataList.add(commonData2);
        });
      });
    }

    if (availabletypes.contains(PolarDataType.acc)) {
      accSubscription = polar
          .startAccStreaming(identifier
              // settings: PolarSensorSetting({PolarSettingType.sampleRate: 200}))
              )
          .listen((data) {
        if (!mounted) return;
        // print("Acc running");
        int accx = data.samples.first.x;
        int accy = data.samples.first.y;
        int accz = data.samples.first.z;
        setState(() {
          isAccReady = true;
          checkAllReady();
          accDataList.add([
            widget.patient.participantID,
            widget.patient.sessionID,
            widget.patient.fname,
            widget.patient.lname,
            widget.patient.age,
            widget.patient.sex,
            widget.patient.weight,
            widget.patient.height,
            phaselist[phase],
            toNanosecondsSinceEpoch(DateTime.now()).toString(),
            toNanosecondsSinceEpoch(data.samples.first.timeStamp).toString(),
            accx,
            accy,
            accz
          ]);
        });
      });
    }
  }

  void checkAllReady() {
    if (isHrReady && isAccReady && isEcgReady && !snackbarShown) {
      snackbarShown = true;
      _showSnackBar('All sensors are ready. You can start recording now.');
    }
  }

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
        if (_start == 0 || recordingStarted == false) {
          setState(() {
            timer.cancel();
            recordingStarted = false;
            timerDisplay = "0:00";
          });
        } else {
          setState(() {
            _start--;
            timerDisplay =
                "${(_start ~/ 60).toString().padLeft(1, '0')}:${(_start % 60).toString().padLeft(2, '0')}";
          });
        }
      },
    );
  }

  void startRecording() {
    _timer?.cancel();
    print("Recording start");
    hrDataList.clear();
    accDataList.clear();
    ecgDataList.clear();
    _start = 300; // Reset the timer to 300 seconds
    timerDisplay =
        "${(_start ~/ 60).toString().padLeft(1, '0')}:${(_start % 60).toString().padLeft(2, '0')}";
    updateTimerDisplay(); // Start the timer update for the display

    _timer = Timer(const Duration(seconds: 300), stopRecording);
  }

  void stopRecording() {
    _timer?.cancel();
    finalaccData.addAll(accDataList);
    finalecgData.addAll(ecgDataList);
    finalhrData.addAll(hrDataList);
    setState(() {
      recordingStarted = false;
    });
  }

  void saveData() async {
    

    final String dir = (await getExternalStorageDirectory())!.path;

    // Prepare the first CSV file (ECG)
    final String path1 =
        '$dir/${widget.patient.participantID}_${widget.patient.sessionID}_hrv_ecg.csv';
    final File file1 = File(path1);

    List<List<dynamic>> csvData1 = [
      [
        'ParticipantID',
        'SessionID',
        'First Name',
        'Last Name',
        'Age',
        'Sex',
        'Weight',
        'Height',
        'Phase',
        'Timestamp(Local)',
        'Timestamp(Polar)'
      ]
    ];
    for (int i = 0; i < 73; i++) {
      csvData1[0].add("S$i");
    }
    csvData1.addAll(finalecgData);
    String csvString1 = const ListToCsvConverter().convert(csvData1);
    await file1.writeAsString(csvString1);

    // Prepare the second CSV file (HR)
    final String path2 =
        '$dir/${widget.patient.participantID}_${widget.patient.sessionID}_hrv_hr.csv';
    final File file2 = File(path2);

    List<List<dynamic>> csvData2 = [
      [
        'ParticipantID',
        'SessionID',
        'First Name',
        'Last Name',
        'Age',
        'Sex',
        'Weight',
        'Height',
        'Phase',
        'Timestamp',
        'HR',
        'rr1',
        'rr2'
      ]
    ];
    csvData2.addAll(finalhrData);
    String csvString2 = const ListToCsvConverter().convert(csvData2);
    await file2.writeAsString(csvString2);

    // Prepare the third CSV file (ACC)
    final String path3 =
        '$dir/${widget.patient.participantID}_${widget.patient.sessionID}_hrv_acc.csv';
    final File file3 = File(path3);

    List<List<dynamic>> csvData3 = [
      [
        'ParticipantID',
        'SessionID',
        'First Name',
        'Last Name',
        'Age',
        'Sex',
        'Weight',
        'Height',
        'Phase',
        'Timestamp(Local)',
        'Timestamp(Polar)',
        'AccX',
        'AccY',
        'AccZ'
      ]
    ];
    csvData3.addAll(finalaccData);
    String csvString3 = const ListToCsvConverter().convert(csvData3);
    await file3.writeAsString(csvString3);

    // Function to upload a file
    Future<void> uploadFile(String filePath, String fileType) async {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse("https://param.nimhans.ac.in/dashboard/uploadPEBL.php"),
        );

        request.fields['user_name'] = username; // Replace with your username
        request.fields['upload_password'] = password;
        request.fields['taskname'] = 'hrv';
        request.fields['subnum'] = widget.patient.participantID;
        request.files
            .add(await http.MultipartFile.fromPath('fileToUpload', filePath));

        final response = await request.send();

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

    // Upload each file separately
    await uploadFile(path1, 'ECG');
    await uploadFile(path2, 'HR');
    await uploadFile(path3, 'ACC');
  }

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
                'HRV',
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
                  Text("Phase: ${phaselist[phase]}"),
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
                          if (recordingStarted) {
                            setState(() {
                              recordingStarted = false;
                            });
                            stopRecording();
                          } else {
                            setState(() {
                              recordingStarted = true;
                            });
                            startRecording();
                          }
                        },
                        child: Text(recordingStarted ? "Stop" : "Start"),
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
                              if (phase == 3) {
                                _showSnackBar(
                                    "Done with all experiments. Press Submit.");
                              } else {
                                recordingEnded = false;
                                timerDisplay = "5:00";
                                phase++;
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
                saveData();
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
