// ignore_for_file: prefer_const_constructors, unnecessary_this
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:kardi_notes/pages/settings_page.dart';
import 'package:page_transition/page_transition.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/data_sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:thread/thread.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  bool _isOpened = false;
  bool stop_loading_animation = false;
  bool can_continue = false;

  void background() async
  {
    //do we have internet connection?
    can_continue = false;
    Connectivity().checkConnectivity().then((value)
    {
      if (value == ConnectivityResult.none)
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No internet connection',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                          },
                          child: Text('Retry'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("connection check dialog closed");
          can_continue = true;
        });
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("connection check done");
    if (stop_loading_animation) { setState(() {}); return; }

    //ensure config
    can_continue = false;
    HttpHelper.ensure_config().then((value)
    {
      if (value[0] != 0)
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error ensuring config (${value[0]}\n${value[1]})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                          },
                          child: Text('Retry'),
                        ),
                        if (value[2] != "") ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: value[2]));
                          },
                          child: Text('Copy to clipboard'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("ensuring config dialog closed");
          can_continue = true;
        });
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("ensuring config done");
    if (stop_loading_animation) { setState(() {}); return; }

    //transfer config
    can_continue = false;
    HttpHelper.transfer_old_cfg_to_new().then((value)
    {
      if (value == false)
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error transferring config',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                          },
                          child: Text('Retry'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("transferring config dialog closed");
          can_continue = true;
        });
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("transferring config done");
    if (stop_loading_animation) { setState(() {}); return; }

    //get custom api cfg
    can_continue = false;
    HttpHelper.get_custom_api_cfg().then((value)
    {
      if (value == false)
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error loading custom api config.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                          },
                          child: Text('Retry'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            stop_loading_animation = false;
                            Navigator.of(context).pop();
                          },
                          child: Text('Ignore and continue'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("getting custom api cfg dialog closed");
          can_continue = true;
        });
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
    HttpHelper.versionCheck(HttpHelper.CURRENT_VER, HttpHelper.DEV_MODE, Platform.operatingSystem).then((value)
    {
      if (value == "unsupported")
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('This platform is not supported',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          //close the pop up and leave user on this page
                          onPressed: () { Navigator.of(context).pop(); },
                          child: Text('Close'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("version check dialog closed");
          can_continue = true;
        });
      }
      else if (value == "notok")
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error checking version',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                          },
                          child: Text('Retry'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("version check dialog closed");
          can_continue = true;
        });
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

          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text((majorHigher && minorHigher && buildHigher) ? 'You are using higher version than latest' : 'New version available',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          instructions.isNotEmpty ? Text(
                            instructions,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ) : SizedBox.shrink(),
                          instructions_link.isNotEmpty ? RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Instructions can be found at ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                                TextSpan(
                                    text: instructions_link,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()..onTap = () { launchUrlString(instructions_link, mode: LaunchMode.externalApplication); }
                                ),
                              ],
                            ),
                          ) : SizedBox.shrink(),
                          latest_link.isNotEmpty ? ElevatedButton(
                            onPressed: () { launchUrlString(latest_link, mode: LaunchMode.externalApplication); },
                            child: Text((majorHigher && minorHigher && buildHigher) ? 'Downgrade' : 'Update'),
                          ) : SizedBox.shrink(),
                          can_ignore ? Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: ElevatedButton(
                                onPressed: () {
                                  stop_loading_animation = false;
                                  Navigator.of(context).pop();
                                },
                                child: Text('Ignore and continue'),
                              )) : SizedBox.shrink()
                        ]
                    )
                );
              }
          ).then((value) {
            print("version check dialog closed");
            can_continue = true;
          });
        }
        catch (e)
        {
          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Version check returned from server seems to be corrupted',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                            },
                            child: Text('Retry'),
                          ),
                        ]
                    )
                );
              }
          ).then((value) {
            print("version check dialog closed");
            can_continue = true;
          });
        }
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("version check done");
    if (stop_loading_animation) { setState(() {}); return; }

    //version is ok, continue to load notes
    can_continue = false;
    HttpHelper.getNotes().then((value) {
      if (value.first == false)
      {
        stop_loading_animation = true;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error loading data',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoadingPage()));
                          },
                          child: Text('Retry'),
                        ),
                      ]
                  )
              );
            }
        ).then((value) {
          print("getting notes dialog closed");
          can_continue = true;
        });
      }
      else { can_continue = true; }
    });
    while (!can_continue) { await Future.delayed(const Duration(milliseconds: 100)); }
    print("getting notes done");
    if (stop_loading_animation) { setState(() {}); return; }

    await HttpHelper.update_scale();
    HttpHelper.connected = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => NotesPage()));
  }

  @override
  void initState()
  {
    super.initState();

    //final thread = Thread((events) { background(); }); //does not work with async stuff? i guess?
    background(); //should not be a problem?
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