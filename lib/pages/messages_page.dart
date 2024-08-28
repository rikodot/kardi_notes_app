// ignore_for_file: prefer_const_constructors, unnecessary_this
import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kardi_notes/pages/editor_page.dart';
import 'package:kardi_notes/pages/notes_page.dart';
import 'package:kardi_notes/pages/open_msg_page.dart';
import 'note_mini.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import '../models/data_sync.dart';
import '../models/utils.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _feedbackController = TextEditingController(); //remember to clear when sent
  bool _isOpened = false;
  final cron = Cron();
  bool last_bg_done = true; //idk if necessary here
  double vertical_drag_start = 0;

  void background()
  {
    //check every 5 minutes if we need to sync
    if (HttpHelper.bg_checks && HttpHelper.current_page == PageType.Messages && DateTime.now().millisecondsSinceEpoch ~/ 1000 - HttpHelper.msg_check_time > 300 && last_bg_done)
    {
      //here maybe this could cause to show the snackbar multiple times if the user is in the messages page for a long time
      //but idk, it was happening with alerts in editor page and notes page which i fixed using last_bg_done
      //but idk if it works here, cba to test, it basically depends whether snackbar shows in background

      //first check for server mismatch
      HttpHelper.getMessages().then((value) {
        last_bg_done = false; //idk if necessary here
        if (value == true)
        {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Messages refreshed successfully", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {});
        }
        last_bg_done = true; //idk if necessary here
      });
    }
  }

  @override
  void initState() {
    super.initState;

    HttpHelper.current_page = PageType.Messages;

    //every 5 minutes
    cron.schedule(Schedule.parse('*/5 * * * *'), () async {
      background();
    });
  }

  @override
  void dispose() {
    cron.close();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        /* buttons */
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 0, left: 0, right: 20, bottom: 0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                /** SEND FEEDBACK **/
                if (_isOpened) FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    Alert(
                    style: Styles.alert_norm(),
                    context: context,
                    title: 'Send feedback',
                    content: SizedBox(
                      width: Utils.logical_size(use_media: true, context: context).width * 0.8,
                      height: Utils.logical_size(use_media: true, context: context).height * 0.3,
                      child: TextField(
                        controller: _feedbackController,
                        style: GoogleFonts.poppins(fontSize: 16),
                        decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            counterText: '',
                            hintText: 'Write your feedback here!'
                        ),
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        maxLength: 40000, //db max 65535 encrypted + encoded
                        keyboardType: TextInputType.multiline,
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp('\r'))],
                      ),
                    ),
                    buttons: [
                      DialogButton(
                        child: Text("Cancel", style: Styles.alert_button()),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _feedbackController.clear();
                        },
                      ),
                      DialogButton(
                        child: Text("Send", style: Styles.alert_button()),
                        onPressed: () {
                          if (_feedbackController.text.isEmpty) {
                            Alert(
                              style: Styles.alert_closable(),
                              context: context,
                              title: "ERROR",
                              desc: "Feedback cannot be empty.",
                              buttons: [],
                            ).show();
                          }
                          //call HttpHelper.sendFeedback() and wait for it to finish then check the return value and show an alert
                          HttpHelper.sendFeedback(_feedbackController.text).then((value) {
                            if (value == -1) {
                              Alert(
                                style: Styles.alert_closable(),
                                context: context,
                                title: "ERROR",
                                desc: "Failed to send feedback, check internet connection.",
                                buttons: [],
                              ).show();
                            } else {
                              HttpHelper.msgs.insert(0, {
                                "title": "Your Feedback",
                                "content": _feedbackController.text,
                                "creation_date": DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: false)),
                                "seen": 1,
                                "is_feedback": 1,
                                "seen_by_dev": 0
                              });
                              Alert(
                                style: Styles.alert_closable(),
                                context: context,
                                title: "SUCCESS",
                                desc: "Feedback sent successfully.",
                                buttons: [],
                              ).show().then((val) {
                                Navigator.of(context).pop();
                                _feedbackController.clear();
                                setState(() {});
                              });
                            }
                          });
                        },
                      ),
                    ],
                  ).show();
                  },
                  tooltip: 'Send feedback',
                  child: const Icon(Icons.feedback_outlined),
                ),
                /** REFRESH MESSAGES **/
                if (_isOpened) FloatingActionButton(
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
                        //show small green text on the bottom for 3 seconds to indicate that notes were downloaded
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Successfully obtained messages from server', style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        setState(() {});
                      }
                    });
                  },
                  tooltip: 'Refresh messages',
                  child: const Icon(Icons.download),
                ),
                /** GO BACK **/
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
                            child: NotesPage(),
                            childCurrent: this.widget)
                    );
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
          minimum: EdgeInsets.all(4.0),
          child: Listener(
            onPointerDown: (details) { vertical_drag_start = details.position.dy; },
            onPointerUp: (details)
            {
              double available_height = Utils.logical_size(use_media: true, context: context).height;
              double length = vertical_drag_start - details.position.dy;
              vertical_drag_start = 0;
              if (length < 0 && length < -available_height / 3)
              {
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
                    //show small green text on the bottom for 3 seconds to indicate that notes were downloaded
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Successfully obtained messages from server', style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.green,
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
                        child: NotesPage(),
                        childCurrent: this.widget));
              }
            },
            child: ListView.builder(
              itemCount: HttpHelper.msgs.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                      HttpHelper.msgs[index]["is_feedback"] == 1 ? Icons.call_made : Icons.call_received,
                      color: Colors.blue,
                    ),
                    title: Text(
                        HttpHelper.msgs[index]["title"],
                        style: GoogleFonts.poppins(fontWeight: HttpHelper.msgs[index]["seen"] == 1 ? FontWeight.normal : FontWeight.bold)
                    ),
                    trailing: HttpHelper.msgs[index]["is_feedback"] == 1
                        ? (HttpHelper.msgs[index]["seen_by_dev"] == 1
                        ? Tooltip(message: "Seen by developer", child: Icon(Icons.check, color: Colors.green))
                        : Tooltip(message: "Not seen by developer", child: Icon(Icons.access_time, color: Colors.orange)))
                        : (HttpHelper.msgs[index]["seen"] == 1
                        ? Tooltip(message: "You have seen this message", child: Icon(Icons.check, color: Colors.green))
                        : Tooltip(message: "You have not seen this message", child: Icon(Icons.new_releases, color: Colors.orange))),
                    onTap: () {
                      Navigator.push(
                          context,
                          PageTransition(
                              alignment: Alignment.bottomCenter,
                              curve: Curves.easeInOut,
                              duration: Duration(milliseconds: 600),
                              reverseDuration: Duration(milliseconds: 600),
                              type: PageTransitionType.size,
                              child: OpenMsgPage(index: index),
                              childCurrent: this.widget)
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}