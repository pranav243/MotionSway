import 'package:flutter/material.dart';
import 'package:testproject/details.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'details.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
        designSize: const Size(360, 800),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'Flutter Demo',
            theme: ThemeData(
              // is not restarted.
              // primarySwatch: Colors.blue,
            ),
            home: const PatientDetails(),
          );
        });
  }
}
