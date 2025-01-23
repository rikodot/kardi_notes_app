// ignore_for_file: prefer_const_constructors, depend_on_referenced_packages, no_logic_in_create_state, use_key_in_widget_constructors, library_private_types_in_public_api, unused_import, unused_local_variable, prefer_const_literals_to_create_immutables
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:kardi_notes/pages/loading_page.dart';
import 'models/data_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //GoogleFonts.config.allowRuntimeFetching = false;
  //LicenseRegistry.addLicense(() async* { yield LicenseEntryWithLineBreaks(['google_fonts'], await rootBundle.loadString('google_fonts/OFL.txt')); });

  //config preload
  //no need to handle errors, if it does not work, theming does not work, no big deal (kinda)
  try {
    var ensure_value = await HttpHelper.ensure_config();
    if (ensure_value[0] != 0) { throw "ensure_value not zero"; }
    var transfer_value = await HttpHelper.transfer_old_cfg_to_new();
    if (transfer_value != true) { throw "transfer_value not true"; }

    HttpHelper.default_color = Color(await HttpHelper.get_config_value("default_color"));
    HttpHelper.default_brightness = await HttpHelper.get_config_value("default_brightness") ? Brightness.dark : Brightness.light;
  }
  catch (e) { HttpHelper.cfg_preload_err = e.toString(); }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HttpHelper.default_color,
          brightness: HttpHelper.default_brightness,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: LoadingPage(),
    );
  }
}
