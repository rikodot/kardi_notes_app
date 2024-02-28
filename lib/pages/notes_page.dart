// ignore_for_file: prefer_const_constructors, unnecessary_this
import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/pages/editor_page.dart';
import 'package:kardi_notes/pages/messages_page.dart';
import 'package:kardi_notes/pages/settings_page.dart';
import 'note_mini.dart';
import 'package:page_transition/page_transition.dart';
import '../models/data_sync.dart';
import '../models/utils.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({Key? key}) : super(key: key);

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  bool _isOpened = false;
  final cron = Cron();
  bool last_bg_done = true;
  bool moving_note_old = false;
  int move_note_index = -1;
  int move_note_index_new = -1;
  double vertical_drag_start = 0;
  /*Size last_size = Utils.logical_size();
  int last_size_change = Utils.now();*/

  Future<bool> move_note(int old_index, int new_index) async
  {
    //discard preview changes
    if (moving_note_old) { HttpHelper.display_notes.insert(old_index, HttpHelper.display_notes.removeAt(new_index)); }

    //prepare to alert user if something does not go well
    bool failed = false;

    //thanks to this check we save performance obviously
    //but also we can be sure if note we are moving was the first note, we will have a replacement for it at all times
    if (new_index != old_index)
    {
      //for illustration check data_sync.dart getNotes() function
      //we need to handle 4 neighboring notes, the note we move and also global first_note_key

      //not 100% sure if these are correct:
      //old position last note -> HttpHelper.display_notes[old_index]
      //old position next note -> HttpHelper.display_notes[old_index - 1]
      //new position last note -> HttpHelper.display_notes[new_index]
      //new position next note -> HttpHelper.display_notes[new_index - 1]

      //make link between old position last note and old position next note (take out the note we are moving from the old position)
      if (old_index + 1 < HttpHelper.display_notes.length)
      {
        HttpHelper.display_notes[old_index + 1]['next_note_key'] = HttpHelper.display_notes[old_index]['next_note_key'];
        if(!await HttpHelper.updateNextNoteKey(HttpHelper.display_notes[old_index + 1]['key'], HttpHelper.display_notes[old_index + 1]['next_note_key'])) { failed = true; }
      }
      else
      {
        HttpHelper.first_note_key = HttpHelper.display_notes[old_index]['next_note_key'];
        if (!await HttpHelper.updateFirstNoteKey(HttpHelper.first_note_key)) { failed = true; }
      }
      if (old_index - 1 >= 0)
      {
        HttpHelper.display_notes[old_index - 1]['last_note_key'] = HttpHelper.display_notes[old_index]['last_note_key'];
        if (!await HttpHelper.updateLastNoteKey(HttpHelper.display_notes[old_index - 1]['key'], HttpHelper.display_notes[old_index - 1]['last_note_key'])) { failed = true; }
      }
      else
      {
        //HttpHelper.last_note_key = HttpHelper.display_notes[old_index]['last_note_key'];
      }

      //if moving note to the right
      if (new_index > old_index)
      {
        //connect new position last note with the note we are moving
        if (new_index < HttpHelper.display_notes.length - 1)
        {
          HttpHelper.display_notes[old_index]['last_note_key'] = HttpHelper.display_notes[new_index + 1]['key'];
          if (!await HttpHelper.updateLastNoteKey(HttpHelper.display_notes[old_index]['key'], HttpHelper.display_notes[old_index]['last_note_key'])) { failed = true; }
          HttpHelper.display_notes[new_index + 1]['next_note_key'] = HttpHelper.display_notes[old_index]['key'];
          if (!await HttpHelper.updateNextNoteKey(HttpHelper.display_notes[new_index + 1]['key'], HttpHelper.display_notes[new_index + 1]['next_note_key'])) { failed = true; }
        }
        else
        {
          HttpHelper.display_notes[old_index]['last_note_key'] = null;
          if (!await HttpHelper.updateLastNoteKey(HttpHelper.display_notes[old_index]['key'], HttpHelper.display_notes[old_index]['last_note_key'])) { failed = true; }
          HttpHelper.first_note_key = HttpHelper.display_notes[old_index]['key'];
          if (!await HttpHelper.updateFirstNoteKey(HttpHelper.first_note_key)) { failed = true; }
        }
        //connect new position next note with the note we are moving
        if (new_index > 0)
        {
          HttpHelper.display_notes[old_index]['next_note_key'] = HttpHelper.display_notes[new_index]['key'];
          if (!await HttpHelper.updateNextNoteKey(HttpHelper.display_notes[old_index]['key'], HttpHelper.display_notes[old_index]['next_note_key'])) { failed = true; }
          HttpHelper.display_notes[new_index]['last_note_key'] = HttpHelper.display_notes[old_index]['key'];
          if (!await HttpHelper.updateLastNoteKey(HttpHelper.display_notes[new_index]['key'], HttpHelper.display_notes[new_index]['last_note_key'])) { failed = true; }
        }
      }
      //if moving note to the left
      else
      {
        //connect new position last note with the note we are moving
        if (new_index < HttpHelper.display_notes.length - 1)
        {
          HttpHelper.display_notes[old_index]['last_note_key'] = HttpHelper.display_notes[new_index]['key'];
          if (!await HttpHelper.updateLastNoteKey(HttpHelper.display_notes[old_index]['key'], HttpHelper.display_notes[old_index]['last_note_key'])) { failed = true; }
          HttpHelper.display_notes[new_index]['next_note_key'] = HttpHelper.display_notes[old_index]['key'];
          if (!await HttpHelper.updateNextNoteKey(HttpHelper.display_notes[new_index]['key'], HttpHelper.display_notes[new_index]['next_note_key'])) { failed = true; }
        }
        //connect new position next note with the note we are moving
        if (new_index > 0)
        {
          HttpHelper.display_notes[old_index]['next_note_key'] = HttpHelper.display_notes[new_index - 1]['key'];
          if (!await HttpHelper.updateNextNoteKey(HttpHelper.display_notes[old_index]['key'], HttpHelper.display_notes[old_index]['next_note_key'])) { failed = true; }
          HttpHelper.display_notes[new_index - 1]['last_note_key'] = HttpHelper.display_notes[old_index]['key'];
          if (!await HttpHelper.updateLastNoteKey(HttpHelper.display_notes[new_index - 1]['key'], HttpHelper.display_notes[new_index - 1]['last_note_key'])) { failed = true; }
        }
        else
        {
          HttpHelper.display_notes[old_index]['next_note_key'] = null;
          if (!await HttpHelper.updateNextNoteKey(HttpHelper.display_notes[old_index]['key'], HttpHelper.display_notes[old_index]['next_note_key'])) { failed = true; }
          //HttpHelper.last_note_key = HttpHelper.display_notes[old_index]['key'];
        }
      }

      //put preview changes back into effect
      if (moving_note_old) { HttpHelper.display_notes.insert(new_index, HttpHelper.display_notes.removeAt(old_index)); }

      //if we are using new ordering this is where we make the changes locally
      if (!moving_note_old)
      {
        HttpHelper.display_notes.insert(new_index, HttpHelper.display_notes.removeAt(old_index)); //update in display_notes
      }

      //test linking
      /*print("moving note order:");
      for (int i = 0; i < HttpHelper.display_notes.length; i++)
      {
        print("${HttpHelper.display_notes[i]['next_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['next_note_key'])]['title']) : null}"
            " <- ${HttpHelper.display_notes[i]['title']} -> "
            "${HttpHelper.display_notes[i]['last_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['last_note_key'])]['title']) : null}");
      }
      if (HttpHelper.first_note_key != null) { print("first_note: ${HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.first_note_key)]['title']}"); }
      else { print("first_note: null"); }*/
    }

    if (failed)
    {
      Alert(
        style: Styles.alert_norm(),
        context: context,
        title: 'Error',
        desc: 'Saving the new order failed. Do not worry, your notes are not lost. The app will try to repair any issues on its own. If you notice any irregularities, please contact the developer via feedback.',
        buttons: [
          DialogButton(
            onPressed: () { Navigator.pop(context); },
            child: Text('OK', style: Styles.alert_button()),
          )
        ],
      ).show();
    }
    setState(() {});
    return failed;
  }

  void background()
  {
    //check every 5 minutes if we need to sync
    if (HttpHelper.bg_checks && HttpHelper.current_page == PageType.Notes && DateTime.now().millisecondsSinceEpoch ~/ 1000 - HttpHelper.global_check_time > 300 && last_bg_done)
    {
      //first check for server mismatch
      HttpHelper.getNotes(dont_apply_changes: true).then((value) {
        if (value.first == true) {
          //prepare text if notes same
          bool same = (value.elementAt(1) == true);
          if (!same)
          {
            //something is different
            last_bg_done = false;

            //show alert
            Alert(
              style: Styles.alert_norm(),
              context: context,
              title: "Server Mismatch",
              desc: "Your notes are different from the server. Do you want to sync?",
              buttons: [
                DialogButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await HttpHelper.getNotes();
                    last_bg_done = true; //this bool prevents stacking multiple alerts on top of each other
                    setState(() {});
                  },
                  child: Text("Sync", style: Styles.alert_button()),
                ),
                DialogButton(
                  onPressed: () async {
                    last_bg_done = true; //this bool prevents stacking multiple alerts on top of each other
                    Navigator.pop(context);
                  },
                  child: Text("Cancel", style: Styles.alert_button()),
                )
              ],
            ).show();
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState;

    HttpHelper.current_page = PageType.Notes;

    //every 5 minutes
    cron.schedule(Schedule.parse('*/5 * * * *'), () async {
      background();
    });

    //register callback to show pop up msgs and mark flip their pop up boolean
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      //get all pop up msgs
      List<dynamic> popups = HttpHelper.msgs.where((element) => element['pop_up_on_start'] == 1).toList();

      //show pop up msgs in a singular alert
      if (popups.isNotEmpty) {
        String title = "New Important Messages";
        String desc = "";
        for (var i = 0; i < popups.length; ++i) { desc += popups[i]['title'] + "\n\n"; }

        Alert(
          style: Styles.alert_norm(),
          context: context,
          title: title,
          desc: desc,
          buttons: [
            DialogButton(
              onPressed: () async {
                Navigator.pop(context);

                //mark as pop up as seen first locally (if user click note and instantly back, http req might not be finished yet causing to show again)
                for (var i = 0; i < popups.length; ++i) { HttpHelper.msgs[HttpHelper.msgs.indexWhere((element) => element['id'] == popups[i]['id'])]['pop_up_on_start'] = 0; }

                //mark as pop up as seen on server
                bool any_fail = false;
                for (var i = 0; i < popups.length; ++i) {
                  var value = await HttpHelper.popUpSeen(popups[i]['id']);
                  if (value == false) { any_fail = true; }
                }

                //show error if any fail
                if (any_fail) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text(
                          'Failed to save some data, pop up might appear again in the future.',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3)));
                }
              },
              child: Text("OK", style: Styles.alert_button()),
            )
          ],
        ).show();
      }
    });
  }

  @override
  void dispose() {
    cron.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: /*LayoutBuilder(
          builder: (context, constraints) {
            //is not called every frame, is called when window size changes, sometimes in some other scenarios too
            /*if ((DateTime.now().millisecondsSinceEpoch ~/ 1000) - last_size_change > 1 && last_size != Utils.logical_size()) {
              last_size = Utils.logical_size();
              last_size_change = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              Future.delayed(Duration.zero, () async { setState(() {}); });
            }*/
            //print("hi");
            return*/ Scaffold(
              extendBody: true,
              extendBodyBehindAppBar: true,
              /* buttons */
              floatingActionButton: !moving_note_old ? Padding(
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
                      /** MESSAGES **/
                      if (_isOpened) badges.Badge(
                        badgeContent: Container(
                          padding: EdgeInsets.fromLTRB(2.5, 2, 2, 3.5),
                          child: Text(
                            HttpHelper.msgs_unread.toString(),
                            style: GoogleFonts.lato(fontSize: 14, color: Colors.white),
                          ),
                        ),
                        //badgeAnimation: badges.BadgeAnimation.fade(toAnimate: false),
                        position: badges.BadgePosition.topEnd(top: -5, end: -5),
                        showBadge: HttpHelper.msgs_unread > 0,
                        ignorePointer: true,
                        child: FloatingActionButton(
                          heroTag: null,
                          onPressed: () {
                            HttpHelper.getMessages().then((value) {
                              if (value == false) {
                                Alert(
                                  style: Styles.alert_closable(),
                                  context: context,
                                  title: "ERROR",
                                  desc: "Failed to get messages, check internet connection.",
                                  buttons: [],
                                ).show();
                              } else {
                                Navigator.push(
                                    context,
                                    PageTransition(
                                        alignment: Alignment.bottomCenter,
                                        curve: Curves.easeInOut,
                                        duration: Duration(milliseconds: 600),
                                        reverseDuration: Duration(milliseconds: 600),
                                        type: PageTransitionType.size,
                                        child: MessagesPage(),
                                        childCurrent: this.widget)
                                );
                              }
                            });
                          },
                          tooltip: 'Messages',
                          child: const Icon(Icons.message),
                        ),
                      ),
                      /** NEW NOTE **/
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
                                  child: EditorPage(
                                      noteKey: Utils.randomString(),
                                      content: '',
                                      title: '',
                                      index: -1,
                                      blur: false,
                                      password: '',
                                      color: HttpHelper.default_note_color!.value),
                                  childCurrent: this.widget));
                        },
                        tooltip: 'New note',
                        child: const Icon(Icons.add),
                      ),
                      /** REFRESH NOTES **/
                      if (_isOpened) FloatingActionButton(
                        heroTag: null,
                        onPressed: () {
                          HttpHelper.getNotes().then((value) {
                            if (value.first == false) {
                              Alert(
                                style: Styles.alert_closable(),
                                context: context,
                                title: "ERROR",
                                desc: "Failed to get data, check internet connection.",
                                buttons: [],
                              ).show();
                            } else {
                              //prepare text if notes same
                              String same = ((value.elementAt(1) == true) ? 'no changes' : 'changes applied');

                              //show small green text on the bottom for 3 seconds to indicate that notes were downloaded
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Successfully obtained notes from server ($same)", style: TextStyle(color: Colors.white)),
                                  backgroundColor: ((value.elementAt(1) == true) ? Colors.lightGreen : Colors.green),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              setState(() {});
                            }
                          });
                        },
                        tooltip: 'Refresh notes',
                        child: const Icon(Icons.download),
                      ),
                      /** LINK DEVICE **/
                      if (_isOpened) FloatingActionButton(
                        heroTag: null,
                        onPressed: () {
                          String owner_key_temp = '';
                          Alert(
                            style: Styles.alert_norm(),
                            context: context,
                            title: 'Your Owner Key',
                            content: Column(
                              children: [
                                //add multiline text explaining what owner key is
                                const Text(
                                  'This \'owner key\' is a unique for everybody and is used to identify your notes. '
                                      'You can use it to import your notes on another device.\n'
                                      'Simply copy it and paste it in the import field on the other device. '
                                      'Once you do so, all previous notes on the other device will be lost.\n'
                                      'If you wish to keep them, write down the old owner key so you can use it later.\n'
                                      'Also keep in mind uninstalling the app might result in deleting the owner key from this device. '
                                      'If you do not back it up, your notes are unrecoverable.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                TextField(
                                  controller: TextEditingController(
                                      text: HttpHelper.owner_key),
                                  decoration: const InputDecoration(
                                    icon: Icon(Icons.lock),
                                    labelText: 'Key',
                                  ),
                                  onChanged: (value) {
                                    owner_key_temp = value;
                                  },
                                ),
                              ],
                            ),
                            buttons: [
                              DialogButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text('Close', style: Styles.alert_button()),
                              ),
                              DialogButton(
                                onPressed: () {
                                  //close this dialog
                                  Navigator.pop(context);
                                  //check if key exists using checkOwnerKey() and if so change it
                                  HttpHelper.checkOwnerKey(owner_key_temp).then((result) {
                                    if (result) {
                                      HttpHelper.changeOwnerKey(owner_key_temp).then((value) {
                                        if (value) {
                                          HttpHelper.getNotes().then((value) {
                                            Alert(
                                              style: Styles.alert_closable(),
                                              context: context,
                                              title: 'Success',
                                              desc: 'Your notes have been imported, please reload the page.',
                                              buttons: [],
                                            ).show();
                                          });
                                        }
                                        else {
                                          Alert(
                                            style: Styles.alert_closable(),
                                            context: context,
                                            title: 'Error',
                                            desc: 'Failed saving the new key.',
                                            buttons: [],
                                          ).show();
                                        }
                                      });
                                    }
                                    else {
                                      Alert(
                                        style: Styles.alert_closable(),
                                        context: context,
                                        title: 'Error',
                                        desc: 'This owner key does not exist',
                                        buttons: [],
                                      ).show();
                                    }
                                  });
                                },
                                child: Text('Change', style: Styles.alert_button()),
                              ),
                            ],
                          ).show();
                        },
                        tooltip: 'Link device',
                        child: const Icon(Icons.phonelink),
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
              ) : Padding(
                padding: const EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: null,
                      onPressed: () {
                        //move note one position forward
                        if (move_note_index_new > 0)
                        {
                          move_note_index_new -= 1;
                          HttpHelper.display_notes.insert(move_note_index_new, HttpHelper.display_notes.removeAt(move_note_index_new + 1));
                        }

                        setState(() {});
                      },
                      tooltip: 'Move note one position forward',
                      child: const Icon(Icons.keyboard_arrow_left),
                    ),
                    FloatingActionButton(
                      heroTag: null,
                      onPressed: () async {
                        await move_note(move_note_index, move_note_index_new);

                        //reset values for moving
                        moving_note_old = false;
                        move_note_index = -1;
                        move_note_index_new = -1;
                      },
                      tooltip: 'Save changes',
                      child: const Icon(Icons.save),
                    ),
                    FloatingActionButton(
                      heroTag: null,
                      onPressed: () {
                        //discard preview changes
                        HttpHelper.display_notes.insert(move_note_index, HttpHelper.display_notes.removeAt(move_note_index_new));

                        //reset values for moving
                        moving_note_old = false;
                        move_note_index = -1;
                        move_note_index_new = -1;
                        setState(() {});
                      },
                      tooltip: 'Cancel moving note',
                      child: const Icon(Icons.cancel),
                    ),
                    FloatingActionButton(
                      heroTag: null,
                      onPressed: () {
                        //move note one position backward
                        if (move_note_index_new < HttpHelper.display_notes.length - 1)
                        {
                          move_note_index_new += 1;
                          HttpHelper.display_notes.insert(move_note_index_new, HttpHelper.display_notes.removeAt(move_note_index_new - 1));
                        }

                        setState(() {});
                      },
                      tooltip: 'Move note one position backward',
                      child: const Icon(Icons.keyboard_arrow_right),
                    ),
                  ],
                ),
              ),
              body: SafeArea(
                minimum: EdgeInsets.all(4.0),
                child: Listener(
                  /*onPointerDown: (details) { if (!moving_note_old) { vertical_drag_start = details.position.dy; } },
                  onPointerUp: (details)
                  {
                    double available_height = Utils.logical_size(use_media: true, context: context).height;
                    double length = vertical_drag_start - details.position.dy;
                    vertical_drag_start = 0;
                    if (moving_note_old) {}
                    else if (length < 0 && length < -available_height / 3)
                    {
                      HttpHelper.getNotes().then((value) {
                        if (value.first == false) {
                          Alert(
                            style: Styles.alert_closable(),
                            context: context,
                            title: "ERROR",
                            desc: "Failed to get data, check internet connection."
                            buttons: [],
                          ).show();
                        } else {
                          //prepare text if notes same
                          String same = ((value.elementAt(1) == true) ? 'no changes' : 'changes applied');

                          //show small green text on the bottom for 3 seconds to indicate that notes were downloaded
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Successfully obtained notes from server ($same)", style: TextStyle(color: Colors.white)),
                              backgroundColor: ((value.elementAt(1) == true) ? Colors.lightGreen : Colors.green),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          setState(() {});
                        }
                      });
                    }
                    else if (length > 0 && length > available_height / 3)
                    {
                      Navigator.push(
                          context,
                          PageTransition(
                              alignment: Alignment.bottomCenter,
                              curve: Curves.easeInOut,
                              duration: Duration(milliseconds: 600),
                              reverseDuration: Duration(milliseconds: 600),
                              type: PageTransitionType.size,
                              child: MessagesPage(),
                              childCurrent: this.widget));
                    }
                  },*/
                  child: HttpHelper.notes.isEmpty ? const Center(child: Text('You have no notes.', style: TextStyle(fontSize: 16, color: Colors.black87))) :
                  (HttpHelper.old_ordering ? GridView.count(
                    padding: EdgeInsets.all(10),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    //crossAxisCount: Scaling.notes_page_cross_axis_count(), //needs LayoutBuilder to scale on window resize
                    crossAxisCount: Scaling.notes_page_cross_axis_count(use_media: true, context: context), //scales without LayoutBuilder
                    children: [
                      for (var i = 0; i < HttpHelper.display_notes.length; i++)
                        GestureDetector(
                          onTap: () {
                            /** existing note **/
                            if (HttpHelper.display_notes[i]["password"] != '')
                            {
                              String password_temp = '';
                              //prompt user to enter the password
                              Alert(
                                style: Styles.alert_norm(),
                                context: context,
                                title: 'Enter password',
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
                                    },
                                    child: Text('Close', style: Styles.alert_button()),
                                  ),
                                  DialogButton(
                                    onPressed: () {
                                      //close this dialog
                                      Navigator.pop(context);
                                      //check if password is correct
                                      if (HttpHelper.verify_hash(password_temp, HttpHelper.display_notes[i]["password"]))
                                      {
                                        //if so open the note
                                        Navigator.push(
                                            context,
                                            PageTransition(
                                                alignment: Alignment.bottomCenter,
                                                curve: Curves.easeInOut,
                                                duration: Duration(milliseconds: 600),
                                                reverseDuration: Duration(milliseconds: 600),
                                                type: PageTransitionType.size,
                                                child: EditorPage(
                                                    noteKey: HttpHelper.display_notes[i]["key"],
                                                    content: HttpHelper.display_notes[i]["content"],
                                                    title: HttpHelper.display_notes[i]["title"],
                                                    index: i,
                                                    blur: HttpHelper.display_notes[i]["blur"],
                                                    password: password_temp,
                                                    color: HttpHelper.display_notes[i]["color"] ?? HttpHelper.default_note_color!.value),
                                                childCurrent: this.widget));
                                      }
                                      else
                                      {
                                        //if not show error
                                        Alert(
                                          style: Styles.alert_closable(),
                                          context: context,
                                          title: 'Error',
                                          desc: 'Wrong password.',
                                          buttons: [],
                                        ).show();
                                      }
                                    },
                                    child: Text('Check', style: Styles.alert_button()),
                                  ),
                                ],
                              ).show();
                            }
                            else
                            {
                              Navigator.push(
                                  context,
                                  PageTransition(
                                      alignment: Alignment.bottomCenter,
                                      curve: Curves.easeInOut,
                                      duration: Duration(milliseconds: 600),
                                      reverseDuration: Duration(milliseconds: 600),
                                      type: PageTransitionType.size,
                                      child: EditorPage(
                                          noteKey: HttpHelper.display_notes[i]["key"],
                                          content: HttpHelper.display_notes[i]["content"],
                                          title: HttpHelper.display_notes[i]["title"],
                                          index: i,
                                          blur: HttpHelper.display_notes[i]["blur"],
                                          password: '',
                                          color: HttpHelper.display_notes[i]["color"] ?? HttpHelper.default_note_color!.value),
                                      childCurrent: this.widget));
                            }
                          },
                          onLongPress: () {
                            if (HttpHelper.old_ordering)
                            {
                              moving_note_old = true;
                              move_note_index = i;
                              move_note_index_new = i;
                              setState(() {});
                            }
                          },
                          child: Material(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            elevation: 2,
                            child: NoteMini(
                                title: HttpHelper.display_notes[i]["title"],
                                content: HttpHelper.display_notes[i]["content"],
                                blur: HttpHelper.display_notes[i]["blur"],
                                password: HttpHelper.display_notes[i]["password"] != '',
                                color: HttpHelper.display_notes[i]["color"] ?? HttpHelper.default_note_color!.value,
                                selected: move_note_index_new == i),
                          ),
                        ),
                    ],
                  ) : DraggableGridViewBuilder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      crossAxisCount: Scaling.notes_page_cross_axis_count(use_media: true, context: context),
                    ),
                    children: HttpHelper.get_new_ordering_notes(context, this.widget),
                    isOnlyLongPress: true, //this means cursor must stay in the same place
                    //dragCompletion does not work in version 0.0.9 so we stay at 0.0.8 until it is fixed
                    dragCompletion: (List<DraggableGridItem> list, int beforeIndex, int afterIndex) async {
                      await move_note(beforeIndex, afterIndex);
                    },
                    dragFeedback: (List<DraggableGridItem> list, int index) {
                      return Material(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        elevation: 2,
                        child: NoteMini(
                            title: HttpHelper.display_notes[index]["title"],
                            content: HttpHelper.display_notes[index]["content"],
                            blur: HttpHelper.display_notes[index]["blur"],
                            password: HttpHelper.display_notes[index]["password"] != '',
                            color: HttpHelper.display_notes[index]["color"] ??
                                HttpHelper.default_note_color!.value,
                            selected: false),
                      );
                    },
                    dragPlaceHolder: (List<DraggableGridItem> list, int index) {
                      return PlaceHolderWidget(
                        child: Container(
                          width: HttpHelper.note_mini_width,
                          height: HttpHelper.note_mini_height,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      );
                    },
                  ))
                ),
              ),
            )/*;
          }
      ),*/
    );
  }
}