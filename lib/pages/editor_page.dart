// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, unnecessary_this
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:page_transition/page_transition.dart';
import '../models/data_sync.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cron/cron.dart';
import '../models/utils.dart';

class EditorPage extends StatefulWidget {
  EditorPage({
    Key? key,
    required this.noteKey,
    required this.title,
    required this.content,
    required this.index,
    required this.blur,
    required this.password,
    required this.color
  }) : super(key: key);
  String noteKey; //unique string to identify note
  String title; //password does not apply
  String content; //stays encrypted if password used
  int index; //index of note in display_notes or -1 if new note
  bool blur;
  String password; //blank or contains entered password in plain text
  int color;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController(); //password does not apply
  final TextEditingController _contentController = TextEditingController(); //is decrypted if password used
  bool _isOpened = false;
  final cron = Cron();
  bool last_bg_done = true;
  int index_in_notes = -1;

  //void onReportTimings(List<FrameTiming> timings)
  void background()
  {
    //check every 5 minutes if we need to sync
    if (HttpHelper.bg_checks && HttpHelper.current_page == PageType.Note && widget.index != -1 && DateTime.now().millisecondsSinceEpoch ~/ 1000 - HttpHelper.notes_check_times[widget.index] > 300 && last_bg_done)
    {
      //first check for server mismatch
      HttpHelper.mismatchNoteCheck(widget.noteKey, widget.title, widget.content).then((value)
      {
        if (!value)
        {
          //something is different
          last_bg_done = false;

          //check for local mismatch (current text in editor vs text passed as an argument when opening this page)
          bool local_mismatch = false;
          if (widget.title != _titleController.text || HttpHelper.decrypt_content(widget.content, widget.password) != _contentController.text) { local_mismatch = true; }

          //prompt user to apply changes or not
          Alert(
            style: Styles.alert_norm(),
            context: context,
            title: 'Note has changed',
            content: Column(
              children: [
                Text('Since the time you opened this note, it has been modified from other device. These changes are not present here.'),
                if (local_mismatch) Text('You have also made changes to this note. If you reload the note, any unsaved changes made from this device will be lost.', style: TextStyle(color: Colors.red.shade400)),
                Text('Do you want to reload the note from server?'),
              ],
            ),
            buttons: [
              DialogButton(
                onPressed: () {
                  //call HttpHelper.getNote() and wait for it to finish then check the return value and call setState() to rebuild the page
                  HttpHelper.getNote(widget.noteKey, widget.index).then((value) {
                    //if success
                    if (value.first) {
                      //if password is same, update the current note, otherwise go back and alert user he needs to re-enter password
                      String password_new = HttpHelper.notes[index_in_notes]["password"];
                      if (password_new.isEmpty || HttpHelper.verify_hash(widget.password, password_new))
                      {
                        widget.noteKey = HttpHelper.notes[index_in_notes]["key"];
                        widget.content = HttpHelper.notes[index_in_notes]["content"];
                        widget.title = HttpHelper.notes[index_in_notes]["title"];
                        widget.blur = HttpHelper.notes[index_in_notes]["blur"];
                        widget.color = HttpHelper.notes[index_in_notes]["color"] ?? HttpHelper.default_note_color!.value;
                        setState(() {
                          _titleController.text = widget.title;
                          _contentController.text = HttpHelper.decrypt_content(widget.content, widget.password);
                        });
                      }
                      else
                      {
                        String password_temp = '';
                        Alert(
                          style: Styles.alert_norm(),
                          context: context,
                          title: 'Password has changed',
                          content: Column(
                            children: [
                              TextField(
                                obscureText: true,
                                decoration: const InputDecoration(
                                  icon: Icon(Icons.lock),
                                  labelText: 'Password',
                                ),
                                onChanged: (value) {
                                  password_temp = value;
                                },
                              ),
                            ],
                          ),
                          buttons: [
                            DialogButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: Text('Close note', style: Styles.alert_button()),
                            ),
                            DialogButton(
                              onPressed: () {
                                //close this dialog
                                Navigator.pop(context);
                                //check if password is correct
                                if (HttpHelper.verify_hash(password_temp, HttpHelper.notes[index_in_notes]["password"]))
                                {
                                  //if so update
                                  widget.password = password_temp;
                                  widget.noteKey = HttpHelper.notes[index_in_notes]["key"];
                                  widget.content = HttpHelper.notes[index_in_notes]["content"];
                                  widget.title = HttpHelper.notes[index_in_notes]["title"];
                                  widget.blur = HttpHelper.notes[index_in_notes]["blur"];
                                  widget.color = HttpHelper.notes[index_in_notes]["color"] ?? HttpHelper.default_note_color!.value;
                                  setState(() {
                                    _titleController.text = widget.title;
                                    _contentController.text = HttpHelper.decrypt_content(widget.content, widget.password);
                                  });
                                }
                                else
                                {
                                  //if not show error
                                  Alert(
                                    style: Styles.alert_norm(),
                                    context: context,
                                    title: 'Error',
                                    desc: 'Wrong password.',
                                    buttons: [
                                      DialogButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.pop(context);
                                        },
                                        width: 120,
                                        child: Text('OK', style: Styles.alert_button()),
                                      )
                                    ],
                                  ).show();
                                }
                              },
                              child: Text('Check', style: Styles.alert_button()),
                            ),
                          ],
                        ).show();
                      }
                    }
                  });
                  Navigator.pop(context); //pop alert
                  last_bg_done = true; //this bool prevents stacking multiple alerts on top of each other
                },
                child: Text("Yes", style: Styles.alert_button()),
              ),
              DialogButton(
                onPressed: () {
                  last_bg_done = true; //this bool prevents stacking multiple alerts on top of each other
                  Navigator.pop(context); //pop alert
                },
                child: Text("No", style: Styles.alert_button()),
              )
            ],
          ).show();
        }
      });
    }
  }

  @override
  void initState() {
    setState(() {
      _titleController.text = widget.title;
      _contentController.text = HttpHelper.decrypt_content(widget.content, widget.password);
      index_in_notes = widget.index == -1 ? widget.index : HttpHelper.notes.indexWhere((element) => element["key"] == widget.noteKey);
    });

    //all of these are kinda weird working only when mouse is moving over the rendered stuff idk
    //WidgetsBinding.instance.addTimingsCallback(onReportTimings); //this is every 100ms in debug and 1s in release (good)
    //WidgetsBinding.instance.addPersistentFrameCallback((timeStamp) { print("hi"); }); //THIS IS FOR EVERY FRAME (too much)
    //WidgetsBinding.instance.addPostFrameCallback((timeStamp) { print("hi"); }); //THIS IS ONCE ONLY (too low)

    HttpHelper.current_page = PageType.Note;

    //every 5 minutes
    cron.schedule(Schedule.parse('*/5 * * * *'), () async { background(); });

    super.initState;
  }

  Future<bool> deleteNote() async { return widget.index == -1 ? true : await HttpHelper.deleteNote(widget.noteKey); }
  Future<int> writeNote(bool overwrite) async
  {
    String title = _titleController.text.trim();
    String content = HttpHelper.encrypt_content(_contentController.text, widget.password);
    return await HttpHelper.editNote(widget.noteKey, title, content, widget.index, widget.title, widget.content, widget.blur, widget.password.isNotEmpty ? HttpHelper.hash(widget.password) : '', overwrite);
  }

  @override
  void dispose()
  {
    _titleController.dispose();
    _contentController.dispose();
    //WidgetsBinding.instance.removeTimingsCallback(onReportTimings);
    cron.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        /* buttons */
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 0, left: 0, right: 20, bottom: 0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                /** COLOR **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () async {
                    Color new_color = Color(widget.color);
                    await Alert(
                      style: Styles.alert_norm(),
                      context: context,
                      title: 'Select color',
                      content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: Color(widget.color),
                            onColorChanged: (Color color) {
                              new_color = color;
                            },
                          )
                      ),
                      buttons: [
                        DialogButton(
                          onPressed: HttpHelper.copy_note_color == null ? null : () async {
                            if (widget.index != -1 && widget.color != HttpHelper.copy_note_color!.value)
                            {
                              bool res = await HttpHelper.editNoteColor(widget.noteKey, HttpHelper.copy_note_color!.value);
                              if (!res)
                              {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Failed to change the color', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                              else
                              {
                                widget.color = HttpHelper.copy_note_color!.value;
                                HttpHelper.display_notes[widget.index]["color"] = HttpHelper.copy_note_color!.value;
                                HttpHelper.notes[index_in_notes]["color"] = HttpHelper.copy_note_color!.value;
                              }
                            }
                            Navigator.pop(context);
                          },
                          child: Text('Paste', style: Styles.alert_button()),
                        ),
                        DialogButton(
                          onPressed: () async {
                            if (widget.index != -1)
                            {
                              HttpHelper.copy_note_color = Color(widget.color);
                            }
                          },
                          child: Text('Copy', style: Styles.alert_button()),
                        ),
                        DialogButton(
                          onPressed: () async {
                            if (widget.index != -1 && widget.color != new_color.value)
                            {
                              bool res = await HttpHelper.editNoteColor(widget.noteKey, new_color.value);
                              if (!res)
                              {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Failed to change the color', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                              else
                              {
                                widget.color = new_color.value;
                                HttpHelper.display_notes[widget.index]["color"] = new_color.value;
                                HttpHelper.notes[index_in_notes]["color"] = new_color.value;
                              }
                            }
                            Navigator.pop(context);
                          },
                          child: Text('OK', style: Styles.alert_button()),
                        ),
                        DialogButton(
                          onPressed: () async { Navigator.pop(context); },
                          child: Text('Cancel', style: Styles.alert_button()),
                        ),
                        DialogButton(
                          onPressed: () async {
                            if (widget.index != -1 && widget.color != HttpHelper.default_note_color!.value)
                            {
                              bool res = await HttpHelper.editNoteColor(widget.noteKey, HttpHelper.default_note_color!.value);
                              if (!res)
                              {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Failed to reset the color', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                              else
                              {
                                widget.color = HttpHelper.default_note_color!.value;
                                HttpHelper.display_notes[widget.index]["color"] = null;
                                HttpHelper.notes[index_in_notes]["color"] = null;
                              }
                            }
                            Navigator.pop(context);
                          },
                          child: Text('Reset', style: Styles.alert_button()),
                        )
                      ],
                    ).show();
                  },
                  tooltip: 'Save note',
                  child: Icon(Icons.color_lens),
                ),
                /** SAVE **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () async
                  {
                    if (HttpHelper.encrypt_content(_contentController.text, widget.password) == widget.content && _titleController.text == widget.title && widget.index != -1)
                    {
                      //show small orange text on the bottom for 3 seconds to indicate that there were no changes
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('No changes to be saved', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                    else
                    {
                      writeNote(false).then((value) {
                        if (value == -1) {
                          Alert(
                            style: Styles.alert_closable(),
                            context: context,
                            title: "ERROR",
                            desc: "Failed to save data, check internet connection.",
                            buttons: [],
                          ).show();
                        } else if (value == -2) {
                          //mismatch of unedited note with data on server, should we overwrite?
                          Alert(
                            style: Styles.alert_norm(),
                            context: context,
                            title: 'Note has been edited from another device, overwrite?',
                            content: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'This note has been edited from another device and saving these changes will discard the changes made on the other device.\n'
                                        'Do you want to overwrite the changes made on the other device?\n\n'
                                        'Example:\n'
                                        'This note was "123". You opened it on your computer and on your mobile at the same time.\n'
                                        'After some time you changed the note on your computer to "123abc". Some time later you opened the note on the phone without reloading (so note was still saying "123").\n'
                                        'On the phone you edited it to "123xyz" and this alert showed up. If you press ',
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                                  ),
                                  WidgetSpan(
                                    child: Icon(Icons.check, size: 14),
                                  ),
                                  TextSpan(
                                    text: ' "123xyz" will be saved and "123abc" discarded.\n'
                                        'If you press ',
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                                  ),
                                  WidgetSpan(
                                    child: Icon(Icons.cancel_outlined, size: 14),
                                  ),
                                  TextSpan(
                                    text: ' "123xyz" will be discarded and "123abc" will be saved.',
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            buttons: [
                              DialogButton(
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black, offset: Offset(1, 1))
                                  ],
                                ),
                                onPressed: () {
                                  writeNote(true).then((value) {
                                    if (value == -1) {
                                      Alert(
                                        style: Styles.alert_closable(),
                                        context: context,
                                        title: "ERROR",
                                        desc: "Failed to save data, check internet connection.",
                                        buttons: [],
                                      ).show();
                                    } else {
                                      //update our values so we dont get false positive of unsaved changes
                                      widget.title = _titleController.text;
                                      widget.content = HttpHelper.encrypt_content(_contentController.text, widget.password);

                                      //this avoids making local duplicates of a note when making a new one and saving multiple times
                                      widget.index = value;
                                      index_in_notes = HttpHelper.notes.indexWhere((element) => element["key"] == widget.noteKey);

                                      //show small green text on the bottom for 3 seconds to indicate that the note was saved
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(
                                          'Saved',
                                          style: GoogleFonts.poppins(fontSize: 20),
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 3),
                                      ));
                                    }
                                    Navigator.of(context).pop();
                                  });
                                },
                              ),
                              DialogButton(
                                child: Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1))
                                  ],
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ).show();
                        } else {
                          //update our values so we dont get false positive of unsaved changes
                          widget.title = _titleController.text;
                          widget.content = HttpHelper.encrypt_content(_contentController.text, widget.password);

                          //this avoids making local duplicates of a note when making a new one and saving multiple times
                          widget.index = value;
                          index_in_notes = HttpHelper.notes.indexWhere((element) => element["key"] == widget.noteKey);

                          //show small green text on the bottom for 3 seconds to indicate that the note was saved
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Successfully saved', style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      });
                    }
                  },
                  tooltip: 'Save note',
                  child: Icon(Icons.save),
                ),
                /** REFRESH NOTE **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    //call HttpHelper.getNote() and wait for it to finish then check the return value and call setState() to rebuild the page
                    HttpHelper.getNote(widget.noteKey, widget.index, check_if_same: true).then((value) {
                      if (value.first == false) {
                        Alert(
                          style: Styles.alert_closable(),
                          context: context,
                          title: "ERROR",
                          desc: "Failed to get data, check internet connection.",
                          buttons: [],
                        ).show();
                      } else {
                        //prepare text if note same
                        String same = ((value.elementAt(1) == true) ? 'no changes' : 'changes applied');

                        //show small green text on the bottom for 3 seconds to indicate that note was downloaded
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Successfully obtained note from server ($same)", style: TextStyle(color: Colors.white)),
                            backgroundColor: ((value.elementAt(1) == true) ? Colors.lightGreen : Colors.green),
                            duration: const Duration(seconds: 3),
                          ),
                        );

                        //changes found
                        if (value.elementAt(1) == false)
                        {
                          //if password is same, update the current note, otherwise go back and alert user he needs to re-enter password
                          String password_new = HttpHelper.notes[index_in_notes]["password"];
                          if (password_new.isEmpty || HttpHelper.verify_hash(widget.password, password_new))
                          {
                            widget.noteKey = HttpHelper.notes[index_in_notes]["key"];
                            widget.content = HttpHelper.notes[index_in_notes]["content"];
                            widget.title = HttpHelper.notes[index_in_notes]["title"];
                            widget.blur = HttpHelper.notes[index_in_notes]["blur"];
                            widget.color = HttpHelper.notes[index_in_notes]["color"] ?? HttpHelper.default_note_color!.value;
                            setState(() {
                              _titleController.text = widget.title;
                              _contentController.text = HttpHelper.decrypt_content(widget.content, widget.password);
                            });
                          }
                          else
                          {
                            String password_temp = '';
                            Alert(
                              style: Styles.alert_norm(),
                              context: context,
                              title: 'Password has changed',
                              content: Column(
                                children: [
                                  TextField(
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      icon: Icon(Icons.lock),
                                      labelText: 'Password',
                                    ),
                                    onChanged: (value) {
                                      password_temp = value;
                                    },
                                  ),
                                ],
                              ),
                              buttons: [
                                DialogButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: Text('Close note', style: Styles.alert_button()),
                                ),
                                DialogButton(
                                  onPressed: () {
                                    //close this dialog
                                    Navigator.pop(context);
                                    //check if password is correct
                                    if (HttpHelper.verify_hash(password_temp, HttpHelper.notes[index_in_notes]["password"]))
                                    {
                                      //if so update
                                      widget.password = password_temp;
                                      widget.noteKey = HttpHelper.notes[index_in_notes]["key"];
                                      widget.content = HttpHelper.notes[index_in_notes]["content"];
                                      widget.title = HttpHelper.notes[index_in_notes]["title"];
                                      widget.blur = HttpHelper.notes[index_in_notes]["blur"];
                                      widget.color = HttpHelper.notes[index_in_notes]["color"] ?? HttpHelper.default_note_color!.value;
                                      setState(() {
                                        _titleController.text = widget.title;
                                        _contentController.text = HttpHelper.decrypt_content(widget.content, widget.password);
                                      });
                                    }
                                    else
                                    {
                                      //if not show error
                                      Alert(
                                        style: Styles.alert_norm(),
                                        context: context,
                                        title: 'Error',
                                        desc: 'Wrong password.',
                                        buttons: [
                                          DialogButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.pop(context);
                                            },
                                            width: 120,
                                            child: Text('OK', style: Styles.alert_button()),
                                          )
                                        ],
                                      ).show();
                                    }
                                  },
                                  child: Text('Check', style: Styles.alert_button()),
                                ),
                              ],
                            ).show();
                          }
                        }
                      }
                    });
                  },
                  tooltip: 'Refresh note',
                  child: const Icon(Icons.download),
                ),
                /** SET PASSWORD **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    String temp_password = widget.password;
                    Alert(
                      style: Styles.alert_norm(),
                      context: context,
                      title: 'Note password',
                      content: Column(
                        children: [
                          //add multiline text explaining what password does
                          const Text(
                            'This password will be used to encrypt the note. If you forget the password, the note will be lost forever.\n'
                                'If you want to remove the password, leave the field empty and press "Save".',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          TextField(
                            controller: TextEditingController(
                              text: widget.password.isEmpty ? '' : '\x00\x00\x00\x00\x00',
                            ),
                            obscureText: true,
                            decoration: const InputDecoration(
                                icon: Icon(Icons.lock),
                                labelText: 'Password'
                            ),
                            onChanged: (value) {
                              temp_password = value.trim();
                            },
                          ),
                        ],
                      ),
                      buttons: [
                        DialogButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Cancel', style: Styles.alert_button()),
                        ),
                        DialogButton(
                          onPressed: () {
                            //close this dialog
                            Navigator.pop(context);
                            //first verify our content matches the one on server
                            HttpHelper.mismatchNoteCheck(widget.noteKey, widget.title, widget.content).then((result_mismatch) {
                              if (!result_mismatch) {
                                Alert(
                                  style: Styles.alert_closable(),
                                  context: context,
                                  title: 'Error',
                                  desc: 'The note has been modified on another device. Please reload notes and try again.',
                                  buttons: [],
                                ).show();
                              }
                              else
                              {
                                //encrypt content if we have a password and only if its not the placeholder we use
                                if (widget.password != temp_password && temp_password != '\x00\x00\x00\x00\x00')
                                {
                                  String hash_password = temp_password.isEmpty ? '' : HttpHelper.hash(temp_password);
                                  HttpHelper.changeNotePassword(widget.noteKey, widget.index == -1 ? '' : HttpHelper.notes[index_in_notes]["password"], hash_password).then((result) {
                                    if (result) {
                                      //update local values
                                      widget.password = temp_password;
                                      widget.blur = temp_password.isEmpty ? false : true; //same happens on the server

                                      if (widget.index != -1)
                                      {
                                        HttpHelper.notes[index_in_notes]["password"] = hash_password;
                                        HttpHelper.notes[index_in_notes]["blur"] = widget.blur; //same happens on the server
                                      }

                                      if (temp_password.isNotEmpty)
                                      {
                                        widget.content = HttpHelper.encrypt_content(_contentController.text, widget.password);
                                        if (widget.index != -1) { HttpHelper.notes[index_in_notes]["content"] = HttpHelper.encrypt_content(HttpHelper.notes[index_in_notes]["content"], widget.password); }
                                      }
                                      else
                                      {
                                        widget.content = HttpHelper.decrypt_content(_contentController.text, widget.password);
                                        if (widget.index != -1) { HttpHelper.notes[index_in_notes]["content"] = HttpHelper.decrypt_content(HttpHelper.notes[index_in_notes]["content"], widget.password); }
                                      }

                                      //update content on the server (encrypt or decrypt) - overwrite true because we already checked for mismatch
                                      writeNote(true).then((value) {
                                        if (value == -1) {
                                          Alert(
                                            style: Styles.alert_closable(),
                                            context: context,
                                            title: "ERROR",
                                            desc: "Failed to save data, check internet connection.",
                                            buttons: [],
                                          ).show();
                                        } else {
                                          //update our values so we dont get false positive and weird errors (content is already updated)
                                          widget.title = _titleController.text;
                                          widget.index = value;
                                          index_in_notes = HttpHelper.notes.indexWhere((element) => element["key"] == widget.noteKey);
                                          Alert(
                                            style: Styles.alert_closable(),
                                            context: context,
                                            title: 'Success',
                                            desc: 'Password has been changed successfully.',
                                            buttons: [],
                                            closeFunction: () {
                                              //we explicitly define close func as we need to refresh state
                                              Navigator.pop(context);
                                              setState(() {});
                                            },
                                          ).show();
                                        }
                                      });
                                    }
                                    else {
                                      Alert(
                                        style: Styles.alert_closable(),
                                        context: context,
                                        title: 'Error',
                                        desc: 'Failed to change the password.',
                                        buttons: [],
                                      ).show();
                                    }
                                  });
                                }
                                else
                                {
                                  Alert(
                                    style: Styles.alert_closable(),
                                    context: context,
                                    title: 'Error',
                                    desc: 'The password is the same as the old one.',
                                    buttons: [],
                                  ).show();
                                }
                              }
                            });
                          },
                          child: Text('Save', style: Styles.alert_button()),
                        ),
                      ],
                    ).show();
                  },
                  tooltip: 'Set password',
                  child: const Icon(Icons.key),
                ),
                /** BLUR **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () async {
                    if (widget.index != -1) {
                      bool res = await HttpHelper.editNoteBlur(widget.noteKey, !widget.blur);
                      if (!res) {
                        Alert(
                          style: Styles.alert_closable(),
                          context: context,
                          title: 'Error',
                          desc: 'Failed to change the blur state.',
                          buttons: [],
                        ).show();
                      } else {
                        widget.blur = !widget.blur;
                        HttpHelper.display_notes[widget.index]["blur"] = widget.blur;
                        HttpHelper.notes[index_in_notes]["blur"] = widget.blur;
                        setState(() {});
                      }
                    }
                  },
                  tooltip: widget.blur ? 'Disable blur' : 'Enable blur',
                  child: Icon(widget.blur ? Icons.blur_off : Icons.blur_on),
                ),
                /** DELETE **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    /* dont lose content, confirmation */
                    if (widget.index != -1 || _contentController.text.isNotEmpty || _titleController.text.isNotEmpty) {
                      Alert(
                        style: Styles.alert_norm(),
                        context: context,
                        title: 'Are you sure?',
                        buttons: [
                          DialogButton(
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, offset: Offset(1, 1))
                              ],
                            ),
                            onPressed: () {
                              deleteNote().then((value) {
                                if (value == false) {
                                  Alert(
                                    style: Styles.alert_closable(),
                                    context: context,
                                    title: "ERROR",
                                    desc: "Failed to delete data, check internet connection.",
                                    buttons: [],
                                  ).show();
                                } else {
                                  Navigator.push(
                                      context,
                                      /*MaterialPageRoute(
                                              builder: (BuildContext context) => NotesPage()));*/
                                      PageTransition(
                                          alignment: Alignment.bottomCenter,
                                          curve: Curves.easeInOut,
                                          duration:
                                          Duration(milliseconds: 600),
                                          reverseDuration:
                                          Duration(milliseconds: 600),
                                          type: PageTransitionType.size,
                                          child: NotesPage(),
                                          childCurrent: this.widget));
                                }
                              });
                            },
                          ),
                          DialogButton(
                            child: Icon(
                              Icons.cancel_outlined,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, offset: Offset(1, 1))
                              ],
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ).show();
                    }
                    /* no content, no confirmation */
                    else {
                      Navigator.push(
                          context,
                          /*MaterialPageRoute(
                              builder: (BuildContext context) => NotesPage()));*/
                          PageTransition(
                              alignment: Alignment.bottomCenter,
                              curve: Curves.easeInOut,
                              duration: Duration(milliseconds: 600),
                              reverseDuration: Duration(milliseconds: 600),
                              type: PageTransitionType.size,
                              child: NotesPage(),
                              childCurrent: this.widget));
                    }
                  },
                  tooltip: 'Delete note',
                  child: const Icon(Icons.delete),
                ),
                /** GO BACK **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () async {
                    /* content changed, confirmation */
                    if (HttpHelper.encrypt_content(_contentController.text, widget.password) != widget.content || _titleController.text != widget.title) {
                      Alert(
                        style: Styles.alert_norm(),
                        context: context,
                        title: 'Changes detected, discard them?',
                        buttons: [
                          DialogButton(
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, offset: Offset(1, 1))
                              ],
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              Navigator.push(context,
                                  /*MaterialPageRoute(builder: (BuildContext context) => NotesPage()));*/
                                  PageTransition(
                                      alignment: Alignment.bottomCenter,
                                      curve: Curves.easeInOut,
                                      duration: Duration(milliseconds: 600),
                                      reverseDuration: Duration(milliseconds: 600),
                                      type: PageTransitionType.size,
                                      child: NotesPage(),
                                      childCurrent: this.widget));
                            },
                          ),
                          DialogButton(
                            child: Icon(
                              Icons.cancel_outlined,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, offset: Offset(1, 1))
                              ],
                            ),
                            onPressed: () async {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ).show();
                    }
                    /* no changes, no confirmation */
                    else
                    {
                      Navigator.push(context,
                          /*MaterialPageRoute(builder: (BuildContext context) => NotesPage()));*/
                          PageTransition(
                              alignment: Alignment.bottomCenter,
                              curve: Curves.easeInOut,
                              duration: Duration(milliseconds: 600),
                              reverseDuration: Duration(milliseconds: 600),
                              type: PageTransitionType.size,
                              child: NotesPage(),
                              childCurrent: this.widget));
                    }
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
            ),
          ),
        ),
        body: SafeArea(
          minimum: EdgeInsets.only(top: 4, left: 4, right: 4, bottom: 70),
          child: Column(
            children: [
              /* title text field */
              TextField(
                controller: _titleController,
                style: GoogleFonts.poppins(fontSize: 25),
                decoration: InputDecoration(
                  hintStyle: GoogleFonts.poppins(fontSize: 25),
                  counterText: (HttpHelper.show_dates_notes && widget.index != -1 /*when in new note not saved*/
                      && HttpHelper.notes[index_in_notes]['creation_date'] != null /*create new note -> go to main page -> DO NOT download notes and open the new note*/)
                      ? 'Created on ${HttpHelper.notes[index_in_notes]['creation_date']}' : '',
                  hintText: 'Title',
                  fillColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  filled: true,
                ),
                maxLength: 64,
                maxLines: 1,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp('\r'))],
              ),
              /* content text field */
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: GoogleFonts.poppins(fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'Write your note here!',
                    fillColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    filled: true,
                  ),
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp('\r'))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
