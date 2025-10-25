import 'package:flutter/material.dart';
import 'package:promptu/ui/screens/home.dart';
import 'package:promptu/utils/theme.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Promptu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: HomePage.routeName,
      routes: {
        HomePage.routeName: (context) => HomePage(),
      },
    );
  }
}
