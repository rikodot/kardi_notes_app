// ignore_for_file: prefer_const_constructors, unnecessary_this
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:kardi_notes/pages/settings_page.dart';
import 'package:page_transition/page_transition.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/data_sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:thread/thread.dart';
import '../models/utils.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  bool _isOpened = false;
  bool stop_loading_animation = false;
  bool can_continue = false;

  void prepare() async
  {
    await HttpHelper.update_scale();

    //do we have internet connection?
    can_continue = false;
    Connectivity().checkConnectivity().then((value) async
    {
      if (value == ConnectivityResult.none)
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'ERROR',
          desc: 'No internet connection',
          buttons: [
            DialogButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
              },
              child: Text('Retry', style: Styles.alert_button()),
            ),
          ],
        ).show();
        print("connection check dialog closed");
        can_continue = true;
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("connection check done");
    if (stop_loading_animation) { setState(() {}); return; }

    //ensure config
    can_continue = false;
    HttpHelper.ensure_config().then((value) async
    {
      if (value[0] != 0)
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'ERROR',
          desc: 'Error ensuring config (${value[0]}\n${value[1]})',
          buttons: [
            DialogButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
              },
              child: Text('Retry', style: Styles.alert_button()),
            ),
            if (value[2] != "") DialogButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value[2]));
              },
              child: Text('Copy to clipboard', style: Styles.alert_button()),
            ),
          ],
        ).show();
        print("ensuring config dialog closed");
        can_continue = true;
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("ensuring config done");
    if (stop_loading_animation) { setState(() {}); return; }

    //transfer config
    can_continue = false;
    HttpHelper.transfer_old_cfg_to_new().then((value) async
    {
      if (value == false)
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'ERROR',
          desc: 'Error transferring config',
          buttons: [
            DialogButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
              },
              child: Text('Retry', style: Styles.alert_button()),
            ),
          ],
        ).show();
        print("transferring config dialog closed");
        can_continue = true;
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("transferring config done");
    if (stop_loading_animation) { setState(() {}); return; }

    //get custom api cfg
    can_continue = false;
    HttpHelper.get_custom_api_cfg().then((value) async
    {
      if (value == false)
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'ERROR',
          desc: 'Error loading custom api config',
          buttons: [
            DialogButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
              },
              child: Text('Retry', style: Styles.alert_button()),
            ),
            DialogButton(
              onPressed: () {
                stop_loading_animation = false;
                Navigator.of(context).pop();
              },
              child: Text('Continue with default api config', style: Styles.alert_button()),
            ),
          ],
        ).show();
        print("getting custom api cfg dialog closed");
        can_continue = true;
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("getting custom api cfg done");
    if (stop_loading_animation) { setState(() {}); return; }

    //load a few config values we do not really care about
    HttpHelper.show_dates_notes = await HttpHelper.get_config_value("show_dates_notes");
    HttpHelper.show_dates_msgs = await HttpHelper.get_config_value("show_dates_msgs");
    HttpHelper.bg_checks = await HttpHelper.get_config_value("bg_checks");
    HttpHelper.old_ordering = await HttpHelper.get_config_value("old_ordering");
    HttpHelper.scale = await HttpHelper.get_config_value("scale");

    //we have internet, check version
    can_continue = false;
    HttpHelper.versionCheck(HttpHelper.CURRENT_VER, HttpHelper.DEV_MODE, Platform.operatingSystem).then((value) async
    {
      if (value == "unsupported")
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_closable(),
          context: context,
          title: 'ERROR',
          desc: 'This platform is not supported',
          buttons: [],
        ).show();
        print("version check dialog closed");
        can_continue = true;
      }
      else if (value == "notok")
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'ERROR',
          desc: 'Error checking version',
          buttons: [
            DialogButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
              },
              child: Text('Retry', style: Styles.alert_button()),
            ),
          ],
        ).show();
        print("version check dialog closed");
        can_continue = true;
      }
      else if (value != "ok")
      {
        stop_loading_animation = true;
        try
        {
          var json = jsonDecode(value);
          String latest_ver = json["latest_ver"];
          String latest_link = json["latest_link"];
          String instructions = json["instructions"];
          String instructions_link = json["instructions_link"];
          bool can_ignore = json["can_ignore"];

          List<String> currentVer = HttpHelper.CURRENT_VER.split('.');
          List<String> latestVer = latest_ver.split('.');

          bool majorHigher = int.parse(currentVer[0]) >= int.parse(latestVer[0]);
          bool minorHigher = int.parse(currentVer[1]) >= int.parse(latestVer[1]);
          bool buildHigher = int.parse(currentVer[2]) >= int.parse(latestVer[2]);

          await Alert(
            style: Styles.alert_norm(),
            context: context,
            title: 'ERROR',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (majorHigher && minorHigher && buildHigher) ? 'You are using higher version than latest' : 'New version available',
                  style: GoogleFonts.poppins(fontSize: HttpHelper.text_height),
                ),
                if (instructions.isNotEmpty) Text(
                  instructions,
                  style: GoogleFonts.poppins(fontSize: HttpHelper.text_height),
                ),
                if (instructions_link.isNotEmpty) RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Instructions can be found at ',
                        style: GoogleFonts.poppins(fontSize: HttpHelper.text_height),
                      ),
                      TextSpan(
                        text: instructions_link,
                        style: GoogleFonts.poppins(fontSize: HttpHelper.text_height, color: Colors.blue, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () { launchUrlString(instructions_link, mode: LaunchMode.externalApplication); }
                      ),
                    ],
                  ),
                ),
              ],
            ),
            buttons: [
              if (latest_link.isNotEmpty) DialogButton(
                onPressed: () { launchUrlString(latest_link, mode: LaunchMode.externalApplication); },
                child: Text((majorHigher && minorHigher && buildHigher) ? 'Downgrade' : 'Update', style: Styles.alert_button()),
              ),
              if (can_ignore) DialogButton(
                onPressed: () {
                  stop_loading_animation = false;
                  Navigator.of(context).pop();
                },
                child: Text('Ignore', style: Styles.alert_button()),
              ),
            ],
          ).show();
          print("version check dialog closed");
          can_continue = true;
        }
        catch (e)
        {
          await Alert(
            style: Styles.alert_norm(),
            context: context,
            title: 'ERROR',
            desc: 'Version check returned from server seems to be corrupted',
            buttons: [
              DialogButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                },
                child: Text('Retry', style: Styles.alert_button()),
              ),
            ],
          ).show();
          print("version check dialog closed");
          can_continue = true;
        }
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("version check done");
    if (stop_loading_animation) { setState(() {}); return; }

    //version is ok, continue to load notes
    can_continue = false;
    HttpHelper.getNotes().then((value) async {
      if (value.first == false)
      {
        stop_loading_animation = true;
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'ERROR',
          desc: 'Error loading data',
          buttons: [
            DialogButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
              },
              child: Text('Retry', style: Styles.alert_button()),
            ),
          ],
        ).show();
        print("getting notes dialog closed");
        can_continue = true;
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("getting notes done");
    if (stop_loading_animation) { setState(() {}); return; }

    HttpHelper.connected = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => NotesPage()));
  }

  @override
  void initState()
  {
    super.initState();

    //final thread = Thread((events) { prepare(); }); //does not work with async stuff? i guess?
    //Future.delayed(Duration.zero,() { prepare(); });
    prepare(); //should not be a problem?
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        child: Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            /* buttons */
            floatingActionButton: stop_loading_animation ? Padding(
              padding: const EdgeInsets.only(top: 0, left: 0, right: 20, bottom: 0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    /** SETTINGS **/
                    if (_isOpened) FloatingActionButton(
                      heroTag: null,
                      onPressed: () {
                        Navigator.push(
                            context,
                            PageTransition(
                                alignment: Alignment.bottomCenter,
                                curve: Curves.easeInOut,
                                duration: Duration(milliseconds: 600),
                                reverseDuration: Duration(milliseconds: 600),
                                type: PageTransitionType.size,
                                child: SettingsPage(),
                                childCurrent: this.widget));
                      },
                      tooltip: 'Settings',
                      child: const Icon(Icons.settings),
                    ),
                    FloatingActionButton(
                      heroTag: null,
                      backgroundColor: _isOpened ? Colors.redAccent.shade100 : null,
                      onPressed: () { _isOpened = !_isOpened; setState(() {}); },
                      tooltip: _isOpened ? 'Hide options' : 'Show options',
                      child: Icon(_isOpened ? Icons.expand_more : Icons.expand_less),
                    ),
                  ],
                ),
              ),
            ) : null,
            body: SafeArea(
                minimum: EdgeInsets.all(10.0),
                child: stop_loading_animation ? const Center(child: Text('Error')) : const Center(child: CircularProgressIndicator())
            )
        )
    );
  }
}