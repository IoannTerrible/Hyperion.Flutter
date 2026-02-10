import 'package:flutter/material.dart';

void main(){
  runApp(FlutterDemo());
}

class FlutterDemo extends StatelessWidget{
  const FlutterDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
  
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text("HelloWorld")),
      ),
      body: Center(child: Text("HelloAgain")),
    );
  }
}
