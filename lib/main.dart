// ignore_for_file: prefer_const_constructors, depend_on_referenced_packages, no_logic_in_create_state, use_key_in_widget_constructors, library_private_types_in_public_api, unused_import, unused_local_variable, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:kardi_notes/pages/loading_page.dart';
import 'models/data_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.amber,
      ),
      debugShowCheckedModeBanner: false,
      home: LoadingPage(),
    );
  }
}
