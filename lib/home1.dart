import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'details.dart';
import 'bodysway.dart';
import 'hrv.dart';

class Home1 extends StatefulWidget {
  const Home1({super.key, required this.patient});
  final Patient patient;

  @override
  State<Home1> createState() => _Home1State();
}

class _Home1State extends State<Home1> {
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
                'Choose Experiment',
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.all(ScreenUtil().setHeight(20)),
                  fixedSize: Size(
                      ScreenUtil().setWidth(300), ScreenUtil().setHeight(100))),
              child: Text(
                "BodySway",
                style: TextStyle(fontSize: 25),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BodySway(patient: widget.patient)),
                );
              },
            ),
            SizedBox(
              height: ScreenUtil().setHeight(50),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.all(ScreenUtil().setHeight(20)),
                  fixedSize: Size(
                      ScreenUtil().setWidth(300), ScreenUtil().setHeight(100))),
              child: Text(
                "HRV",
                style: TextStyle(fontSize: 25),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HRV(patient: widget.patient)),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
