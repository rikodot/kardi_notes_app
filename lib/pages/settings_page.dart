// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, unnecessary_this
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:page_transition/page_transition.dart';
import '../models/data_sync.dart';
import '../models/utils.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'dart:ui';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class SettingsPage extends StatefulWidget {
  SettingsPage({
    Key? key,
  }) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  bool _isOpened = false;

  //custom api currently set and not saved
  bool custom_api = HttpHelper.custom_api_temp;
  String custom_api_url = HttpHelper.custom_api_url_temp;

  final TextEditingController _customApiUrlTempController = TextEditingController(text: HttpHelper.custom_api_url_temp);

  @override
  void dispose() {
    _customApiUrlTempController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
          body: SafeArea(
            minimum: EdgeInsets.all(20.0),
            child: Stack(
              children: [
                ListView(
                  children: <Widget>[
                    if (HttpHelper.connected) ListTile(
                      title: OverflowBar(
                        spacing: 4,
                        children: [
                          Tooltip(
                            message: 'Show creation dates of your notes.',
                            child:
                            Text("Show dates in notes", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          SizedBox(
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: HttpHelper.show_dates_notes,
                                onChanged: (value) {
                                  HttpHelper.show_dates_notes = value;
                                  HttpHelper.update_config_value('show_dates_notes', value);
                                  setState(() {});
                                },
                                activeTrackColor: Colors.lightGreenAccent,
                                activeColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (HttpHelper.connected) ListTile(
                      title: OverflowBar(
                        spacing: 4,
                        children: [
                          Tooltip(
                            message: 'Show creation dates of your feedback and when messages by developer were sent.',
                            child:
                            Text("Show dates in messages", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          SizedBox(
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: HttpHelper.show_dates_msgs,
                                onChanged: (value) {
                                  HttpHelper.show_dates_msgs = value;
                                  HttpHelper.update_config_value('show_dates_msgs', value);
                                  setState(() {});
                                },
                                activeTrackColor: Colors.lightGreenAccent,
                                activeColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (HttpHelper.connected) ListTile(
                      title: OverflowBar(
                        spacing: 4,
                        children: [
                          Tooltip(
                            message: 'Default header color of each note.',
                            child:
                            Text("Default note color", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          IconButton(
                            icon: Icon(Icons.color_lens, color: Colors.black54),
                            iconSize: 24,
                            onPressed: () {
                              Color new_color = HttpHelper.default_note_color!;
                              //show a pop up to select color
                              Alert(
                                style: Styles.alert_norm(),
                                context: context,
                                title: 'Select color',
                                content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: HttpHelper.default_note_color!,
                                      onColorChanged: (Color color) {
                                        new_color = color;
                                      },
                                    )
                                ),
                                buttons: [
                                  DialogButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      HttpHelper.editDefaultNoteColor(new_color.value).then((result) {
                                        if (!result) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Failed to change the color', style: TextStyle(color: Colors.white)),
                                              backgroundColor: Colors.redAccent,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        } else {
                                          HttpHelper.default_note_color = new_color;
                                        }
                                      });
                                    },
                                    child: Text('OK', style: Styles.alert_button()),
                                  ),
                                  DialogButton(
                                    onPressed: () { Navigator.pop(context); },
                                    child: Text('Cancel', style: Styles.alert_button()),
                                  ),
                                  DialogButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (HttpHelper.default_note_color != HttpHelper.server_default_note_color)
                                      {
                                        HttpHelper.editDefaultNoteColor(HttpHelper.server_default_note_color!.value).then((result) {
                                          if (!result) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('Failed to change the color', style: TextStyle(color: Colors.white)),
                                                backgroundColor: Colors.redAccent,
                                                duration: const Duration(seconds: 3),
                                              ),
                                            );
                                          } else {
                                            HttpHelper.default_note_color = HttpHelper.server_default_note_color!;
                                          }
                                        });
                                      }
                                    },
                                    child: Text('Reset', style: Styles.alert_button()),
                                  )
                                ],
                              ).show();
                            },
                          ),
                        ],
                      ),
                    ),
                    if (HttpHelper.connected) ListTile(
                      title: OverflowBar(
                        spacing: 4,
                        children: [
                          Tooltip(
                            message: 'Check for note changes in background.',
                            child:
                            Text("Background checks", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          SizedBox(
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: HttpHelper.bg_checks,
                                onChanged: (value) {
                                  HttpHelper.bg_checks = value;
                                  HttpHelper.update_config_value('bg_checks', value);
                                  setState(() {});
                                },
                                activeTrackColor: Colors.lightGreenAccent,
                                activeColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (HttpHelper.connected) ListTile(
                      title: OverflowBar(
                        spacing: 4,
                        children: [
                          Tooltip(
                            message: 'Use the old interaction system for changing order of notes.',
                            child:
                            Text("Use old note sorting system", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          SizedBox(
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: HttpHelper.old_ordering,
                                onChanged: (value) {
                                  HttpHelper.old_ordering = value;
                                  HttpHelper.update_config_value('old_ordering', value);
                                  setState(() {});
                                },
                                activeTrackColor: Colors.lightGreenAccent,
                                activeColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Row(
                        children: [
                          Tooltip(
                            message: 'Allows use of custom user-specified api servers.',
                            child:
                            Text("Custom API", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          SizedBox(
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: custom_api,
                                onChanged: (value) { setState(() { custom_api = value; }); },
                                activeTrackColor: Colors.lightGreenAccent,
                                activeColor: Colors.green,
                              ),
                            ),
                          ),
                          if (custom_api) Expanded(
                            child: TextField(
                              controller: _customApiUrlTempController,
                              onChanged: (value) { setState(() { custom_api_url = value; }); },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'URL',
                              ),
                            ),
                          ),
                          if (custom_api != HttpHelper.custom_api_temp || (custom_api && custom_api_url.isNotEmpty && custom_api_url != HttpHelper.custom_api_url_temp)) IconButton(
                            icon: Icon(Icons.save, color: Colors.black54),
                            iconSize: 24,
                            onPressed: () {
                              if (custom_api) {
                                HttpHelper.custom_api_temp = true;
                                HttpHelper.custom_api_url_temp = custom_api_url;
                              } else {
                                HttpHelper.custom_api_temp = false;
                                HttpHelper.custom_api_url_temp = '';
                                custom_api_url = '';
                              }
                              HttpHelper.set_custom_api_cfg(HttpHelper.custom_api_temp, HttpHelper.custom_api_url_temp).then((result) {
                                Alert(
                                  style: Styles.alert_closable(),
                                  context: context,
                                  title: 'Custom API',
                                  desc: 'Please restart the app for changes to take effect.',
                                  buttons: [],
                                ).show();
                                setState(() {});
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Row(
                        children: [
                          Tooltip(
                            message: 'Change the scale of things.',
                            child:
                            Text("Scale", style: GoogleFonts.poppins(fontSize: 16)),
                          ),
                          Expanded(
                            child: Slider(
                              value: HttpHelper.scale,
                              min: HttpHelper.scale_min,
                              max: HttpHelper.scale_max,
                              divisions: ((HttpHelper.scale_max - HttpHelper.scale_min) / HttpHelper.scale_step).round(),
                              label: HttpHelper.scale.toStringAsPrecision(2),
                              onChanged: (value) {
                                HttpHelper.scale = value;
                                HttpHelper.update_scale();
                                HttpHelper.update_config_value('scale', value);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  left: 0,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          PackageInfo pi = await PackageInfo.fromPlatform();
                          Size pp = Utils.physical_size(); //physical pixels
                          Size lp = Utils.logical_size(); //logical pixels
                          Size ppm = Utils.physical_size(use_media: true, context: context); //physical pixels media
                          Size lpm = Utils.logical_size(use_media: true, context: context); //logical pixels media
                          Alert(
                            style: Styles.alert_closable(),
                            context: context,
                            title: 'Diagnostic Data',
                            desc: 'api version: ${HttpHelper.CURRENT_VER}\n'
                                  'app version: ${pi.version}+${pi.buildNumber}\n\n'
                                  'pp size: ${pp.width.round()}x${pp.height.round()}\n'
                                  'lp size: ${lp.width.round()}x${lp.height.round()}\n'
                                  'ppm size: ${ppm.width.round()}x${ppm.height.round()}\n'
                                  'lpm size: ${lpm.width.round()}x${lpm.height.round()}\n\n'
                                  'scale: ${HttpHelper.scale.toStringAsPrecision(2)}\n',
                            buttons: [],
                          ).show();
                        },
                        child: Text('info', style: GoogleFonts.poppins(fontSize: 12)),
                      ),
                      SizedBox(width: 10),
                      TextButton(
                        onPressed: () async {
                          Alert(
                            style: Styles.alert_closable(),
                            context: context,
                            title: 'Experiments',
                            desc: 'These experiments might break something.\n'
                                  'Do not use them unless you know what you are doing.',
                            buttons: [],
                            content: Column(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final res = await HttpHelper.ensure_config();
                                    if (res[0] == -3 && res[2] != "")
                                    {
                                      bool success = false;
                                      String encrypted_config = res[2];
                                      for (int i = 0; i < encrypted_config.length; i++)
                                      {
                                        try
                                        {
                                          String decrypted_config = HttpHelper.decrypt(encrypted_config);
                                          if (decrypted_config.isNotEmpty)
                                          {
                                            HttpHelper.overwrite_config(encrypted_config);
                                            success = true;
                                          }
                                          break;
                                        }
                                        catch (e) { encrypted_config = encrypted_config.substring(0, encrypted_config.length - 1); }
                                      }
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success ? 'Config repaired, please restart app to apply.' : 'Failed to repair config.', style: TextStyle(color: Colors.white)),
                                          backgroundColor: success ? Colors.green : Colors.red,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                    else
                                    {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Nothing to repair.', style: TextStyle(color: Colors.white)),
                                          backgroundColor: Colors.orangeAccent,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text('repair config', style: GoogleFonts.poppins(fontSize: 12)),
                                )
                              ],
                            ),
                          ).show();
                        },
                        child: Text('experiments', style: GoogleFonts.poppins(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          /* buttons */
          floatingActionButton:Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              /** GO BACK **/
              if (_isOpened) FloatingActionButton(
                heroTag: null,
                onPressed: () {
                  Navigator.pop(context); //because we can get here from different pages
                  /*Navigator.push(
                      context,
                      PageTransition(
                          alignment: Alignment.bottomCenter,
                          curve: Curves.easeInOut,
                          duration: Duration(milliseconds: 600),
                          reverseDuration: Duration(milliseconds: 600),
                          type: PageTransitionType.size,
                          child: NotesPage(),
                          childCurrent: this.widget));*/
                },
                tooltip: 'Back to notes',
                child: const Icon(Icons.arrow_back),
              ),
              FloatingActionButton(
                heroTag: null,
                backgroundColor: _isOpened ? Colors.redAccent.shade100 : null,
                onPressed: () { _isOpened = !_isOpened; setState(() {}); },
                tooltip: _isOpened ? 'Hide options' : 'Show options',
                child: Icon(_isOpened ? Icons.expand_more : Icons.expand_less),
              ),
            ],
          )
      ),
    );
  }
}
