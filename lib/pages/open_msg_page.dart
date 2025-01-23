// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, unnecessary_this
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/pages/messages_page.dart';
import 'package:page_transition/page_transition.dart';
import '../models/data_sync.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import '../models/utils.dart';

class OpenMsgPage extends StatefulWidget {
  OpenMsgPage({
    Key? key,
    required this.index,
  }) : super(key: key);
  int index; //index of msg in our msgs List
  @override
  State<OpenMsgPage> createState() => _OpenMsgPageState();
}

class _OpenMsgPageState extends State<OpenMsgPage> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isOpened = false;

  @override
  void initState() {
    setState(() {
      _titleController.text = HttpHelper.msgs[widget.index]['title'];
      _contentController.text = HttpHelper.msgs[widget.index]['content'];
    });
    super.initState;

    //register callback to mark msg as seen
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      //mark as seen on server
      if (HttpHelper.msgs[widget.index]['seen'] == 0)
      {
        HttpHelper.msgSeen(HttpHelper.msgs[widget.index]['id']).then((value) {
          if (value == true) {
            HttpHelper.msgs[widget.index]['seen'] = 1;
          }
          else {
            Alert(
              style: Styles.alert_closable(),
              context: context,
              title: "Error",
              desc: "There has been an error, this massage may not be marked as seen.",
              buttons: [],
            ).show();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        /* buttons */
        floatingActionButton:Padding(
          padding: const EdgeInsets.only(top: 0, left: 0, right: 20, bottom: 0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                            child: MessagesPage(),
                            childCurrent: this.widget));
                  },
                  tooltip: 'Back to notes',
                  child: const Icon(Icons.arrow_back),
                ),
                FloatingActionButton(
                  heroTag: null,
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
                  counterText: HttpHelper.show_dates_msgs ? 'Created on ${HttpHelper.msgs[widget.index]['creation_date']}' : '',
                  hintText: '',
                  fillColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  filled: true,
                ),
                maxLength: 64,
                maxLines: 1,
                readOnly: true,
              ),
              /* content text field */
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: GoogleFonts.poppins(fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: '',
                    fillColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    filled: true,
                  ),
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  readOnly: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
