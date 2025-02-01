// ignore_for_file: avoid_unnecessary_containers, prefer_const_constructors
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kardi_notes/models/data_sync.dart';

class NoteMini extends StatefulWidget {
  const NoteMini({Key? key, required this.title, required this.content, required this.blur, required this.password, required this.color, required this.selected})
      : super(key: key);
  final String title;
  final String content;
  final bool blur;
  final bool password;
  final int color;
  final bool selected;
  @override
  State<NoteMini> createState() => _NoteMiniState();
}

class _NoteMiniState extends State<NoteMini> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Container(
        width: HttpHelper.note_mini_width,
        height: HttpHelper.note_mini_height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HttpHelper.default_brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
          //new ordering system inserts shadow on its own, in old we put it here
          boxShadow: [
            if (widget.selected && HttpHelper.old_ordering) BoxShadow(
              color: Colors.black.withOpacity(0.4),
              spreadRadius: 4,
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(children: [
          /*title*/
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              color: widget.color != HttpHelper.default_note_color!.value ? Color(widget.color) : HttpHelper.default_note_color,
              padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0),
              child: Text(widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 16))
            ),
          ),
          /*content*/
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.topLeft,
              height: double.infinity,
              constraints: BoxConstraints.expand(),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  enabled: widget.blur,
                  child: Text(widget.content,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 5,
                      style: GoogleFonts.poppins(fontSize: 16))
              ),
            ),
          )
        ]),
      ),
    );
  }
}