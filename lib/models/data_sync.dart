import 'dart:ui';
import 'package:deepcopy/deepcopy.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mutex/mutex.dart';
import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../pages/editor_page.dart';
import '../pages/note_mini.dart';
import 'utils.dart';
import 'dh_key_exchange.dart';
import 'package:crypt/crypt.dart';

enum PageType { Notes, Messages, Note }

class HttpHelper
{
  //api settings
  static const String url = "https://www.kardi.tech/notes/handle.php";
  static String CURRENT_VER = "2.0.8";
  static bool DEV_MODE = false;

  //owner key
  static String owner_key_hash = "";

  //custom api currently set and saved
  static bool custom_api_temp = false;
  static String custom_api_url_temp = "";

  //session related variables
  static String session = "";
  static String enc_key = "";
  static String enc_iv = "";
  static bool connected = false;

  //notes & msgs
  static List<dynamic> notes = [];
  static List<dynamic> display_notes = [];
  static List<dynamic> msgs = [];
  static int msgs_unread = 0;

  //check times
  static List<int> notes_check_times = []; //index is equivalent to index in display_notes
  static int global_check_time = 0;
  static int msg_check_time = 0;

  //note color
  static Color? server_default_note_color = null;
  static Color? copy_note_color = null;

  //scale
  static const double scale_min = 0.2;
  static const double scale_max = 5.0;
  static const double scale_step = 0.1;
  static double note_mini_width = 0;
  static double note_mini_height = 0;
  static double text_height = 0;
  static double title_height = 0;

  //current page
  static PageType current_page = PageType.Notes;

  //mutexes
  static final config_mutex = Mutex();

  //synced settings
  static String? first_note_key = null;
  static Color? default_note_color = null;

  //local settings (important, we check return values)
  static String owner_key = "";
  static bool custom_api = false;
  static String custom_api_url = "";

  //local settings (less important, we do not check return values)
  //make sure to load their value on startup in loading_page.dart and save their value below in ensure_config()
  static bool show_dates_notes = true;
  static bool show_dates_msgs = true;
  static bool double_delete_confirm = false;
  static bool captcha_done = false;
  static bool bg_checks = false;
  static bool old_ordering = false;
  static double scale = 1.0;

  //scale updating
  static update_scale()
  {
    note_mini_width = 180 * scale;
    note_mini_height = 180 * scale;
    text_height = 12 * scale;
    title_height = 18 * scale;
  }

  static List<DraggableGridItem> get_new_ordering_notes(BuildContext context, Widget childCurrent)
  {
    List<DraggableGridItem> list = [];
    for (var i = 0; i < HttpHelper.display_notes.length; i++)
    {
      list.add(DraggableGridItem(
        isDraggable: true,
        child: GestureDetector(
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
                                childCurrent: childCurrent));
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
                          color: HttpHelper.display_notes[i]["color"] ??
                              HttpHelper.default_note_color!.value),
                      childCurrent: childCurrent));
            }
          },
          //onLongPress: () {} //cant use long press, because it is used for dragging
          child: Material(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            elevation: 2,
            child: NoteMini(
                title: HttpHelper.display_notes[i]["title"],
                content: HttpHelper.display_notes[i]["content"],
                blur: HttpHelper.display_notes[i]["blur"],
                password: HttpHelper.display_notes[i]["password"] != '',
                color: HttpHelper.display_notes[i]["color"] ?? HttpHelper.default_note_color!.value,
                selected: false),
          ),
        ),
      ));
    }
    return list;
  }

  //url selection
  static String get_url() { return custom_api ? custom_api_url : url; }

  //encryption
  static String encrypt(String text, {String key = 'wkhiDGkLnp2aAcGxV9qzFHkiRKBtj9Zx', String iv = 'CFuoA0nQJRap1sfX'})
  {
    final encrypter = enc.Encrypter(enc.AES(enc.Key.fromUtf8(key)));
    final encrypted = encrypter.encrypt(text, iv: enc.IV.fromUtf8(iv));
    return encrypted.base64;
  }
  static String decrypt(String text, {String key = 'wkhiDGkLnp2aAcGxV9qzFHkiRKBtj9Zx', String iv = 'CFuoA0nQJRap1sfX'})
  {
    final encrypter = enc.Encrypter(enc.AES(enc.Key.fromUtf8(key)));
    final decrypted = encrypter.decrypt64(text, iv: enc.IV.fromUtf8(iv));
    return decrypted;
  }
  static String encrypt_content(String text, String key)
  {
    //if key is empty, return plain text
    //ensure key is at least 16 bytes (128 bits) long
    //encrypt and also account if text is empty
    if (key.isEmpty) { return text; }
    String key_rev = key.split('').reversed.join();

    //key is key and iv is reversed key
    String enc_key = key;
    String enc_iv = key_rev;

    //ensure key and iv are at least 16 bytes (128 bits) long
    //e.g. key = "123" -> key = "123123pad123pad123pad"; key_rev = "321" -> key_rev = "321321pad321pad321pad"
    while (enc_key.length < 16) { enc_key += "${key}pad"; }
    while (enc_iv.length < 16) { enc_iv += "${key_rev}pad"; }

    //account for empty text
    if (text.isEmpty) { text = "\x00"; }

    final encrypter = enc.Encrypter(enc.AES(enc.Key.fromUtf8(enc_key.substring(0, 16))));
    final encrypted = encrypter.encrypt(text, iv: enc.IV.fromUtf8(enc_iv.substring(0, 16)));
    return encrypted.base64;
  }
  static String decrypt_content(String text, String key)
  {
    //if key is empty, return plain text
    //ensure key is at least 16 bytes (128 bits) long
    //decrypt and also account if text is empty
    if (key.isEmpty) { return text; }
    String key_rev = key.split('').reversed.join();

    //key is key and iv is reversed key
    String enc_key = key;
    String enc_iv = key_rev;

    //ensure key and iv are at least 16 bytes (128 bits) long
    //e.g. key = "123" -> key = "123123pad123pad123pad"; key_rev = "321" -> key_rev = "321321pad321pad321pad"
    while (enc_key.length < 16) { enc_key += "${key}pad"; }
    while (enc_iv.length < 16) { enc_iv += "${key_rev}pad"; }

    final encrypter = enc.Encrypter(enc.AES(enc.Key.fromUtf8(enc_key.substring(0, 16))));
    final decrypted = encrypter.decrypt64(text, iv: enc.IV.fromUtf8(enc_iv.substring(0, 16)));
    return decrypted.replaceAll('\x00', '');
  }

  //hash
  static String hash(String text, {int rounds = 0, String salt = ""})
  {
    //return sha256 with salt and rounds
    if (rounds != 0 && salt.isNotEmpty) { return Crypt.sha256(text, salt: salt, rounds: rounds).toString(); }
    //return sha256 with salt
    else if (rounds == 0 && salt.isNotEmpty) { return Crypt.sha256(text, salt: salt).toString(); }
    //return sha256 with rounds
    else if (rounds != 0 && salt.isEmpty) { return Crypt.sha256(text, rounds: rounds).toString(); }
    //return sha256
    else { return Crypt.sha256(text).toString(); }
  }
  static bool verify_hash(String text, String hash)
  {
    //return if hash matches
    final h = Crypt(hash);
    return h.match(text);
  }

  //get one note from server and update in memory; return: (bool, bool) -> (success, same)
  static Future<List<bool>> getNote(String key, int index, {bool check_if_same = false}) async
  {
    try {
      //update check time
      notes_check_times[index] = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?get_one'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "ownerKey": owner_key_hash,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);

        //convert response body to json
        var json = jsonDecode(body);

        int index_in_notes = notes.indexWhere((element) => element['key'] == key);

        //decrypt all values in json
        json['title'] = decrypt(json['title'], key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)).replaceAll('\x00', '');
        json['content'] = decrypt(json['content'], key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)).replaceAll('\x00', '');
        json['blur'] = json['blur'] != 0;
        json['creation_date'] = DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(json['creation_date'] * 1000, isUtc: false));

        //check if notes is different to json
        if (check_if_same) { check_if_same = (notes[index_in_notes].toString() == json.toString()); }

        //set notes to json (cannot be in else statement)
        if (!check_if_same)
        {
          notes[index_in_notes] = json;
          display_notes[index] = jsonDecode(jsonEncode(notes[index_in_notes])); //.deepcopy() does not work
        }

        return [true, check_if_same];
      }
    } catch (e) {
      return [false, false];
    }
    return [false, false];
  }

  //get all notes from server directly to global notes variable; return: (bool, bool) -> (success, same)
  static Future<List<bool>> getNotes({bool dont_apply_changes = false}) async
  {
    try {
      //update check time
      global_check_time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?get_all'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);

        //convert response body to json
        var json = jsonDecode(body);

        //decrypt all values in json
        for (int i = 0; i < json.length; i++) {
          json[i]['title'] = decrypt(json[i]['title'], key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)).replaceAll('\x00', '');
          json[i]['content'] = decrypt(json[i]['content'], key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)).replaceAll('\x00', '');
          json[i]['blur'] = json[i]['blur'] != 0;
          json[i]['creation_date'] = DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(json[i]['creation_date'] * 1000, isUtc: false));
        }

        //also get msgs and vars and return that result (must do before we move notes to display_notes - due to first_note_key being received in getVariables())
        bool msgs = await getMessages();
        bool vars = await getVariables();

        bool is_same = (notes.toString() == json.toString());

        //set notes to json (cannot be in else statement)
        if (!is_same && !dont_apply_changes && json.length > 0)
        {
          notes = json;

          //heh kinda hard to avoid shallow copy
          List<dynamic> notes_temp = notes.deepcopy();
          display_notes = [];

          if (first_note_key != null)
          {
            //in case some note has wrong next_note_key - it and all notes after it will be added to the end of the list in order in which they were created
            //in case some note has wrong last_note_key - it will be repaired

            //start with first note and go by next_note_key until it is null (each time remove the note from notes_temp and add it to display_notes)
            //then iterate over notes_temp and add the rest of the notes to display_notes in order (and also set their next_note_key and last_note_key)
            String? next_note_key = first_note_key;
            while (next_note_key != null)
            {
              int index = notes_temp.indexWhere((element) => element['key'] == next_note_key);
              if (index != -1)
              {
                //fix corrupted last_note_key
                if (display_notes.isNotEmpty && notes_temp[index]['last_note_key'] != display_notes.last['key'])
                {
                  notes_temp[index]['last_note_key'] = display_notes.last['key'];
                  await updateLastNoteKey(notes_temp[index]['key'], notes_temp[index]['last_note_key']);
                }

                display_notes.add(notes_temp[index]);
                next_note_key = notes_temp[index]['next_note_key'];
                notes_temp.removeAt(index);
              }
              else
              {
                next_note_key = null;
              }
            }

            if (display_notes.isNotEmpty && notes_temp.isNotEmpty)
            {
                display_notes.last['next_note_key'] = notes_temp.first['key'];
                await updateNextNoteKey(display_notes.last['key'], display_notes.last['next_note_key']);
            }

            for (int i = 0; i < notes_temp.length; i++)
            {
              notes_temp[i]['next_note_key'] = i < notes_temp.length - 1 ? notes_temp[i + 1]['key'] : null;
              await updateNextNoteKey(notes_temp[i]['key'], notes_temp[i]['next_note_key']);
              notes_temp[i]['last_note_key'] = i > 0 ? notes_temp[i - 1]['key'] : (display_notes.isNotEmpty ? display_notes.last['key'] : null);
              await updateLastNoteKey(notes_temp[i]['key'], notes_temp[i]['last_note_key']);
            }
            display_notes += notes_temp;
          }
          else
          {
            //probably transferring from old version that did not use sorting, setup first_note_key and next_note_key & last_note_key for all notes
            first_note_key = notes_temp.first['key'];
            await updateFirstNoteKey(first_note_key);
            for (int i = 0; i < notes_temp.length; i++)
            {
              notes_temp[i]['next_note_key'] = i < notes_temp.length - 1 ? notes_temp[i + 1]['key'] : null;
              await updateNextNoteKey(notes_temp[i]['key'], notes_temp[i]['next_note_key']);
              notes_temp[i]['last_note_key'] = i > 0 ? notes_temp[i - 1]['key'] : null;
              await updateLastNoteKey(notes_temp[i]['key'], notes_temp[i]['last_note_key']);
            }
            display_notes = notes_temp;
          }

          display_notes = display_notes.reversed.toList();
        }

        //update individual check times as well
        notes_check_times = List.filled(display_notes.length, DateTime.now().millisecondsSinceEpoch ~/ 1000).toList();

        //print the links of the notes (titles)
        //notes displayed as follows: 5 4 3 2 1
        //output:
        //null <- 5 -> 4
        //   5 <- 4 -> 3
        //   4 <- 3 -> 2
        //   3 <- 2 -> 1
        //   2 <- 1 -> null
        /*print("getNotes() order:");
        for (int i = 0; i < HttpHelper.display_notes.length; i++)
        {
          print("${HttpHelper.display_notes[i]['next_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['next_note_key'])]['title']) : null}"
              " <- ${HttpHelper.display_notes[i]['title']} -> "
              "${HttpHelper.display_notes[i]['last_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['last_note_key'])]['title']) : null}");
        }
        if (HttpHelper.first_note_key != null) { print("first_note: ${HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.first_note_key)]['title']}"); }
        else { print("first_note: null"); }*/

        return [msgs && vars, is_same];
      }
    } catch (e) {
      return [false, false];
    }
    return [false, false];
  }

  //get all msgs from server directly to global msgs variable
  static Future<bool> getMessages() async
  {
    try {
      //update check time
      msg_check_time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?get_msgs'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);

        //convert response body to json
        var json = jsonDecode(body);

        msgs_unread = 0;

        //decrypt all values in json
        for (int i = 0; i < json.length; i++) {
          json[i]['title'] = json[i]['title'];
          json[i]['content'] = json[i]['content'];
          json[i]['creation_date'] = DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(json[i]['creation_date'] * 1000, isUtc: false));
          json[i]['seen'] = json[i]['seen'];
          msgs_unread += json[i]['seen'] == 0 ? 1 : 0;

          //check if this row is a message or feedback
          var row = json[i];
          if (row.containsKey('pop_up_on_start') && !row.containsKey('seen_by_dev'))
          {
            //for messages only
            json[i]['is_feedback'] = 0;
            json[i]['pop_up_on_start'] = json[i]['pop_up_on_start'];
            json[i]['id'] = json[i]['id'];
          }
          else
          {
            //for feedback only
            json[i]['is_feedback'] = 1;
            json[i]['seen_by_dev'] = json[i]['seen_by_dev'];
            json[i]['id'] = -1;
          }
        }

        //set notes to json
        msgs = json;
        msgs = msgs.reversed.toList();

        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  //edit a note on server (returns index of note in display_notes, -1 on failure and -2 if unedited note title or content doesnt match the version on server)
  static Future<int> editNote(String key, String title, String content, int index, String old_title, String old_content, bool blur, String password, bool overwrite) async
  {
    try {
      //fix cursor jumping to the very beginning on new line (now fixing within onChanged callback directly in content and title textfields)
      //title = title.replaceAll('\r', '');
      //content = content.replaceAll('\r', '');

      String last_note_key = display_notes.isNotEmpty ? display_notes.first['key'] : "null";

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?edit'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "key": key,
          "title": title.isEmpty ? encrypt("\x00", key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)) : encrypt(title, key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)),
          "content": content.isEmpty ? encrypt("\x00", key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)) : encrypt(content, key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)),
          "old_title": old_title.isEmpty ? encrypt("\x00", key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)) : encrypt(old_title, key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)),
          "old_content": old_content.isEmpty ? encrypt("\x00", key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)) : encrypt(old_content, key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)),
          "blur": blur,
          "password": password,
          "overwrite": (old_title.isEmpty && old_content.isEmpty) ? true : overwrite,
          "last_note_key": last_note_key,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200)
      {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok")
        {
          if (index != -1)
          {
            //edit note in display_notes
            display_notes[index]["title"] = title;
            display_notes[index]["content"] = content;
            display_notes[index]["blur"] = blur;
            display_notes[index]["password"] = password;

            //edit note in notes
            int index_in_notes = notes.indexWhere((element) => element['key'] == key);
            notes[index_in_notes]["title"] = title;
            notes[index_in_notes]["content"] = content;
            notes[index_in_notes]["blur"] = blur;
            notes[index_in_notes]["password"] = password;

            //update check time
            notes_check_times[index] = DateTime.now().millisecondsSinceEpoch ~/ 1000;

            return index; //success
          }
          else
          {
            //update links
            if (last_note_key == "null")
            {
              first_note_key = key;
              await updateFirstNoteKey(first_note_key);
            }
            else
            {
              display_notes.first['next_note_key'] = key;
              await updateNextNoteKey(display_notes.first['key'], display_notes.first['next_note_key']);
            }

            //add note to display_notes
            display_notes.insert(0, {
              "key": key,
              "title": title,
              "content": content,
              "blur": blur,
              "password": password,
              "next_note_key": null,
              "last_note_key": last_note_key == "null" ? null : last_note_key
            });

            //add note to notes
            notes.add({
              "key": key,
              "title": title,
              "content": content,
              "blur": blur,
              "password": password,
              "next_note_key": null,
              "last_note_key": last_note_key == "null" ? null : last_note_key
            });

            //update check time
            notes_check_times.insert(0, DateTime.now().millisecondsSinceEpoch ~/ 1000);

            //since server produces some values when note is created (like creation_date), we will get the note again to update it in memory
            //because currently in memory it misses all changes made by the server -> causes mismatch
            //right now we ignore the result as at this point it is saved both on server and in memory, just has differences - not critical
            await getNote(key, 0);

            //test linking
            /*print("editNote() order:");
            for (int i = 0; i < HttpHelper.display_notes.length; i++)
            {
              print("${HttpHelper.display_notes[i]['next_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['next_note_key'])]['title']) : null}"
                  " <- ${HttpHelper.display_notes[i]['title']} -> "
                  "${HttpHelper.display_notes[i]['last_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['last_note_key'])]['title']) : null}");
            }
            if (HttpHelper.first_note_key != null) { print("first_note: ${HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.first_note_key)]['title']}"); }
            else { print("first_note: null"); }*/

            return 0; //success
          }
        }
        else if (body == "mismatch") {
          return -2; //mismatch of unedited note with the version on the server
        }
      }
    } catch (e) {
      return -1;
    }
    return -1;
  }

  static Future<int> sendFeedback(String content) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?send_feedback'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "content": content,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);

        //convert response body to json
        var json = jsonDecode(body);

        //if response body is ok and contains two elements and verify json[1] is a number
        if (json[0] == "ok" && json.length == 2 && json[1] is int) {
          return json[1];
        }
      }
    } catch (e) {
      return -1;
    }
    return -1;
  }

  static Future<bool> msgSeen(int message_id) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?msg_seen'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "message_id": message_id,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          --msgs_unread;
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> popUpSeen(int message_id) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?popup_seen'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "message_id": message_id,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> editNoteBlur(String key, bool blur) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?edit_blur'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "blur": blur,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> editNoteColor(String key, int color) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?edit_color'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "color": color == default_note_color!.value ? "null" : color,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> updateLastNoteKey(String key, String? last_key) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?update_last_note_key'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "last_key": last_key ?? "null",
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          notes[notes.indexWhere((element) => element['key'] == key)]['last_note_key'] = last_key;
          //print("SETTING REMOTE: ${notes[notes.indexWhere((element) => element['key'] == key)]['title']} -> ${last_key == null ? 'null' : notes[notes.indexWhere((element) => element['key'] == last_key)]['title']}");
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> updateNextNoteKey(String key, String? next_key) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?update_next_note_key'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "next_key": next_key ?? "null",
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          notes[notes.indexWhere((element) => element['key'] == key)]['next_note_key'] = next_key;
          //print("SETTING REMOTE: ${next_key == null ? 'null' : notes[notes.indexWhere((element) => element['key'] == next_key)]['title']} <- ${notes[notes.indexWhere((element) => element['key'] == key)]['title']}");
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> editDefaultNoteColor(int color) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?edit_default_note_color'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "color": color == server_default_note_color!.value ? "null" : color,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> updateFirstNoteKey(String? new_key) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?update_first_note_key'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "new_key": new_key ?? "null",
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          //print("SETTING REMOTE FIRST: ${new_key == null ? 'null' : notes[notes.indexWhere((element) => element['key'] == new_key)]['title']}");
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  //delete a note from server (should be called only when note exists both on server and in memory)
  static Future<bool> deleteNote(String key) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?delete'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          //fix links of notes
          int index = display_notes.indexWhere((element) => element['key'] == key);
          if (index > 0) //not first
          {
            if (index < display_notes.length - 1) //not last one either
            {
              display_notes[display_notes.indexWhere((element) => element['key'] == display_notes[index]['last_note_key'])]['next_note_key'] = display_notes[index]['next_note_key'];
              await updateNextNoteKey(display_notes[index]['last_note_key'], display_notes[index]['next_note_key']); //uhh kinda hope this is correct
              display_notes[display_notes.indexWhere((element) => element['key'] == display_notes[index]['next_note_key'])]['last_note_key'] = display_notes[index]['last_note_key'];
              await updateLastNoteKey(display_notes[index]['next_note_key'], display_notes[index]['last_note_key']); //uhh kinda hope this is correct
            }
            else //last one
            {
              display_notes[display_notes.indexWhere((element) => element['key'] == display_notes[index]['next_note_key'])]['last_note_key'] = null;
              await updateLastNoteKey(display_notes[index]['next_note_key'], null); //uhh kinda hope this is correct
              first_note_key = display_notes[index]['next_note_key'];
              await updateFirstNoteKey(first_note_key);
            }
          }
          else //first one
          {
            if (index < display_notes.length - 1) //not last
            {
              display_notes[display_notes.indexWhere((element) => element['key'] == display_notes[index]['last_note_key'])]['next_note_key'] = null;
              await updateNextNoteKey(display_notes[index]['last_note_key'], null); //uhh kinda hope this is correct
            }
            else //also last
            {
              first_note_key = null;
              await updateFirstNoteKey(first_note_key);
            }
          }

          //delete note from global variables
          display_notes.removeAt(index);
          notes.removeAt(notes.indexWhere((element) => element['key'] == key));

          //test linking
          /*print("deleteNote() order:");
          for (int i = 0; i < HttpHelper.display_notes.length; i++)
          {
            print("${HttpHelper.display_notes[i]['next_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['next_note_key'])]['title']) : null}"
                " <- ${HttpHelper.display_notes[i]['title']} -> "
                "${HttpHelper.display_notes[i]['last_note_key'] != null ? (HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.display_notes[i]['last_note_key'])]['title']) : null}");
          }
          if (HttpHelper.first_note_key != null) { print("first_note: ${HttpHelper.display_notes[HttpHelper.display_notes.indexWhere((el) => el['key'] == HttpHelper.first_note_key)]['title']}"); }
          else { print("first_note: null"); }*/

          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  //check if note content and title matches the one saved on server (true if they match or note is not saved on the server, false if they dont)
  static Future<bool> mismatchNoteCheck(String key, String title, String content) async
  {
    try {
      //update check time
      int index = display_notes.indexWhere((element) => element['key'] == key);
      notes_check_times[index] = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?mismatch_check'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "title": title.isEmpty ? encrypt("\x00", key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)) : encrypt(title, key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)),
          "content": content.isEmpty ? encrypt("\x00", key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)) : encrypt(content, key: owner_key.substring(0, 32), iv: owner_key.split('').reversed.join().substring(0, 16)),
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  //edit note password on server (if note does not exist on server, nothing happens on server and true is returned)
  static Future<bool> changeNotePassword(String key, String old_password, String password) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?password_change'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "key": key,
          "old_password": old_password,
          "password": password,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  //get all variables
  static Future<bool> getVariables() async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?get_variables'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": owner_key_hash,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);

        //convert response body to json
        var json = jsonDecode(body);

        //set variables
        server_default_note_color = Color(int.parse(json["server_default_note_color"]));
        default_note_color = Color(json["default_note_color"] ?? int.parse(json["server_default_note_color"]));
        first_note_key = json["first_note_key"];

        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> createOwnerKeyOnServer(String key) async
  {
    try {
      var request = http.Request('POST', Uri.parse('${get_url()}?init_owner_key'));
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": hash(key, rounds: 5000, salt: key
              .split('')
              .reversed
              .join()
              .substring(0, 16)),
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        if (body != "ok") {
          return false;
        }
      }
    } catch (e) {
      return false;
    }
    return true;
  }

  static Future<bool> initOwnerKey() async
  {
    try {
      owner_key = await get_config_value("owner_key");
      if (owner_key.isNotEmpty)
      {
        owner_key_hash = hash(owner_key, rounds: 5000, salt: owner_key.split('').reversed.join().substring(0, 16));

        //example scenario:
        //user is using production api for some time, decides to switch to custom api
        //when he starts app the next time, owner key is loaded from file locally but is not created on the server (that happens only when the key does not exist locally)
        //so we check if we need to create it on the server
        if (!await checkOwnerKey(owner_key)) { if (!await createOwnerKeyOnServer(owner_key)) { return false; } }

        return true;
      }
      else {
        final decrypted = Utils.randomString(32, true);

        //save on server
        if (!await createOwnerKeyOnServer(decrypted)) { return false; }

        //save locally
        owner_key = decrypted;
        owner_key_hash = hash(owner_key, rounds: 5000, salt: owner_key.split('').reversed.join().substring(0, 16));

        return await update_config_value("owner_key", owner_key);
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> checkOwnerKey(String key) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?check_owner_key'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "ownerKey": hash(key, rounds: 5000, salt: key.split('').reversed.join().substring(0, 16)),
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> changeOwnerKey(String key) async
  {
    try {
      if (await update_config_value("owner_key", key)) {
        owner_key = key;
        owner_key_hash = hash(owner_key, rounds: 5000, salt: owner_key.split('').reversed.join().substring(0, 16));
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> initSession() async
  {
    try {
      int client_priv = Utils.randomInt();
      int client_pub = DH.pow_mod_p(DH.g, client_priv);

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?init_session'));
      //set request body
      request.body = jsonEncode({
        "client_pub": client_pub
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        //convert response body to json
        var json = jsonDecode(body);
        //get variables from json
        int server_pub = json['server_pub'];
        session = json['session'];
        //calculate final_key and gen enc_key
        int final_key = DH.pow_mod_p(server_pub, client_priv);
        enc_key = DH.gen_random(final_key);
        enc_iv = DH.gen_random(final_key, length: 16, shift: 133);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  //must be called as first api call as it inits owner key and session
  static Future<String> versionCheck(String current_ver, bool is_dev, String platform) async
  {
    try {
      //init session and see if it succeeded
      if (session.isEmpty) { if (!await initSession()) { return "notok"; } }
      //init owner key first and see if it succeeded
      if (owner_key.isEmpty) { if (!await initOwnerKey()) { return "notok"; } }

      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?version_check'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "current_ver": current_ver,
          "is_dev": is_dev,
          "platform": platform,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        return body;
      }
    } catch (e) {
      return "notok";
    }
    return "notok";
  }

  static Future<int> captchaCheck(bool success) async
  {
    try {
      //create http request
      var request = http.Request('POST', Uri.parse('${get_url()}?captcha'));
      //set request body
      request.body = jsonEncode({
        "body": DH.enc(jsonEncode({
          "success": success,
          "ownerKey": owner_key_hash,
          "request_id": Utils.randomInt()
        }), enc_key, enc_iv),
        "session": session
      });
      //send request
      http.StreamedResponse response = await request.send();
      //if response is ok
      if (response.statusCode == 200) {
        //get response body
        var body = await response.stream.bytesToString();
        body = DH.dec(body, enc_key, enc_iv);
        //if response body is ok
        if (body == "ok") { return 0; }
        else { return int.parse(body); }
      }
    } catch (e) {
      return -1;
    }
    return -1;
  }

  static Future<bool> set_custom_api_cfg(bool _custom_api, String _custom_api_url) async
  {
    try {
      if (!await update_config_value("custom_api", _custom_api)) { return false; }
      if (!await update_config_value("custom_api_url", _custom_api_url)) { return false; }
      return true;
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<bool> get_custom_api_cfg() async
  {
    try {
      custom_api = await get_config_value("custom_api");
      custom_api_url = await get_config_value("custom_api_url");
      custom_api_temp = custom_api;
      custom_api_url_temp = custom_api_url;
      return true;
    } catch (e) {
      return false;
    }
    return false;
  }

  //must be called before any api calls
  static Future<List<dynamic>> ensure_config({bool force_creation = false}) async
  {
    //ret[0]:
    //0 -> success
    //-1 -> cant get handle to the file
    //-2 -> probably file.exists() failed (not sure if possible)
    //-3 -> cant read the file / json is corrupted
    //-4 -> cant update the file
    //-5 -> cant create the file
    //if return -3:
    //likely corrupted config, alert user to back it up (possible owner key recovery)
    //and offer an option to reset the config (will lose old owner key)

    //ret[1] is error from catch block

    //ret[2] is the file read from disk

    File file;
    int ret = -1;
    String file_read = "";
    Map<String, dynamic> options = {
      'owner_key': owner_key,
      'custom_api': custom_api,
      'custom_api_url': custom_api_url,
      'show_dates_notes': show_dates_notes,
      'show_dates_msgs': show_dates_msgs,
      'double_delete_confirm': double_delete_confirm,
      'captcha_done': captcha_done,
      'bg_checks': bg_checks,
      'old_ordering': old_ordering,
      'scale': scale,
    };

    try
    {
      await config_mutex.acquire();
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      file = File('$path/kardi.config.json');
    }
    catch (e) { config_mutex.release(); return [ret, e.toString(), ""]; }

    try
    {
      ret = -2;
      if (!force_creation && await file.exists())
      {
        ret = -3;
        file_read = await file.readAsString();
        String decrypted = decrypt(file_read);
        var json = jsonDecode(jsonDecode(decrypted)['notes']);

        ret = -4;
        for (var key in options.keys) { if (!json.containsKey(key)) { json[key] = options[key]; } }
        String encrypted = encrypt(jsonEncode({'notes': jsonEncode(json)}));
        await file.writeAsString(encrypted);
      }
      else
      {
        ret = -5;
        String encrypted = encrypt(jsonEncode({'notes': jsonEncode(options)}));
        await file.writeAsString(encrypted);
      }
      config_mutex.release();
      return [0, "", ""];
    } catch (e) { config_mutex.release(); return [ret, e.toString(), file_read]; }
  }

  static Future<bool> overwrite_config(String encrypted_config) async
  {
    try
    {
      await config_mutex.acquire();
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      File file = File('$path/kardi.config.json');
      await file.writeAsString(encrypted_config);
      config_mutex.release();
      return true;
    }
    catch (e) { config_mutex.release(); return false; }
  }

  static Future<bool> update_config_value(String key, dynamic value) async
  {
    try
    {
      await config_mutex.acquire();
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      File file = File('$path/kardi.config.json');
      String encrypted = await file.readAsString();
      String decrypted = decrypt(encrypted);
      var json = jsonDecode(jsonDecode(decrypted)['notes']);
      json[key] = value;
      encrypted = encrypt(jsonEncode({'notes': jsonEncode(json)}));
      await file.writeAsString(encrypted);
      config_mutex.release();
      return true;
    }
    catch (e) { config_mutex.release(); return false; }
  }

  static Future<dynamic> get_config_value(String key) async
  {
    //no need to check if key exists, we ensure it does on start
    try
    {
      await config_mutex.acquire();
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      File file = File('$path/kardi.config.json');
      String encrypted = await file.readAsString();
      String decrypted = decrypt(encrypted);
      var json = jsonDecode(jsonDecode(decrypted)['notes']);
      config_mutex.release();
      return json[key];
    }
    catch (e) { config_mutex.release(); return null; }
  }

  //delete later
  static Future<bool> transfer_old_cfg_to_new() async
  {
    try
    {
      //read owner_key.txt and custom_api.txt
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;

      //get old owner key
      File file = File('$path/owner_key.txt');
      if (await file.exists())
      {
        owner_key = decrypt(await file.readAsString());
        if (!await update_config_value('owner_key', owner_key)) { return false; }
        owner_key_hash = hash(owner_key, rounds: 5000, salt: owner_key.split('').reversed.join().substring(0, 16));
        await file.delete();
      }

      //get old custom api
      file = File('$path/custom_api.txt');
      if (await file.exists())
      {
        String encrypted = await file.readAsString();
        String decrypted = decrypt(encrypted);
        var json = jsonDecode(decrypted);
        custom_api = json['custom_api'];
        custom_api_url = json['custom_api_url'];
        if (!await update_config_value('custom_api', custom_api)) { return false; }
        if (!await update_config_value('custom_api_url', custom_api_url)) { return false; }
        await file.delete();
      }

      return true;
    }
    catch (e) { return false; }
    return false;
  }

  //must be called before any interactions with config (fdroid compliance)
  static Future<void> default_server_option_first_launch(BuildContext context) async
  {
    try
    {
      //is this first launch (does config exist)
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      File file = File('$path/kardi.config.json');
      if (!await file.exists())
      {
        //prompt user to select server (default or custom url)
        final api_instructions = 'https://github.com/rikodot/kardi_notes_api';
        String custom_api_url = '';
        await Alert(
          style: Styles.alert_norm(),
          context: context,
          title: 'Select server',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Instructions to setup custom server can be found at ',
                      style: GoogleFonts.poppins(fontSize: HttpHelper.text_height, color: Colors.black45),
                    ),
                    TextSpan(
                        text: api_instructions,
                        style: GoogleFonts.poppins(fontSize: HttpHelper.text_height, color: Colors.blue, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () { launchUrlString(api_instructions, mode: LaunchMode.externalApplication); }
                    ),
                    TextSpan(
                      text: '.',
                      style: GoogleFonts.poppins(fontSize: HttpHelper.text_height, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              DialogButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Use default server', style: Styles.alert_button()),
              ),
              Text('or', style: GoogleFonts.poppins(fontSize: HttpHelper.text_height, color: Colors.black45)),
              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 40),
                      child: TextField(
                        controller: TextEditingController(),
                        onChanged: (value) { custom_api_url = value; },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Custom server URL',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.save, color: Colors.black54),
                      iconSize: 24,
                      onPressed: () async {
                        if (custom_api_url.isNotEmpty)
                        {
                          var ret = await HttpHelper.ensure_config();
                          if (ret[0] == 0) { await HttpHelper.set_custom_api_cfg(true, custom_api_url); }
                          Navigator.of(context).pop();
                        }
                      }
                  ),
                ],
              ),
            ],
          ),
          buttons: [],
        ).show();
      }

      return;
    }
    catch (e) { return; }
  }

  static Future<int> count_letters() async
  {
    int count = 0;
    for (var note in notes)
    {
      if (note['password'].toString().isEmpty) { count += note['content'].toString().length; }
      else
      {
        //base64 is used
        //output_size = 4*ceil(input_size/3)
        //we do only approximation so we can omit the padding and ceil
        //input_size = 3*(output_size/4)
        int enc_len = 3 * (note['content'].toString().length / 4).round();

        //PKCS7 is used by default
        //output_size = input_size + (block_size - (input_size % block_size))
        //block_size is 16 bytes for AES
        //we do only approximation so we can omit (input_size % block_size)
        //input_size = output_size - block_size
        count += enc_len - 16;
      }
    }
    return count;
  }

  static String captcha_img = "/9j/4AAQSkZJRgABAQEAXwBfAAD/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8LCwkMEQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/2wBDAQUFBQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh7/wAARCAHgAeADARIAAhEBAxEB/8QAHAAAAwEBAQEBAQAAAAAAAAAABAUGAwIHAQAI/8QATBAAAgEDAwIDBQUECAUCBQIHAQIDAAQRBRIhMUETIlEGMmFxgRRCkaHBByNSsRVicoKSotHwM7LC4fEk0ggWQ2PiU3ODJTQ1k/Kj/8QAGgEAAwEBAQEAAAAAAAAAAAAAAAIDAQQFBv/EACgRAAMAAgIDAQADAAIDAQEAAAABAgMREiEEEzFBFCJRBTIjQmEVM//aAAwDAQACEQMRAD8A8Q1AkXzMpwqyOM/3q+X4Zbu4I6iQkfz/AFrlnuTpfTDgVuknIC5dNxHrkYzQeiu0074RfBxgvu5x/wCazjo1dnoEmqLH+ymzimG3xIysKn3mYllJ+Qwan1t7/WJNK0C0kMsTTsluCcYLsM1Kr0h5jT2ey/8Aw8+ySW3sz/8AME8ZNzdkrAD0SMccfVa9W9ntNg0/SrTTIFPh2kCxpg54UYP51zb5hksx+xIImZX2/wAQAzuPpRv7tpWWCRWcdQG5rHpE1bFEcV75hGohUny7htzXd7qMkNwBdIqEHxFJGTXK8uOa7Gaph1r7PNLbrPcQJ4oBywPUV91DULq4t43tLuERPjeV649KbJ5mFIn62wa+uNKR0tpFZJSCokceUGpPUL03F3Im6N3VcElucZryM3kq6HUaPvtbbX0d2j3G1rJ0Dw7ei5Uj86XXGr3NxGsEhVoUyoXGea8/MlT2h9ii/wApBhlR9vuhj0Fd3gVrUSBSpYkbmHHypFL32Tok9VmZWd8xMCQAfSv12Y4pZAw3kZx5csPl8K9fxlLRzMRvNJcnw3Xw15JULw2ef0oi706ZFjuJ43S1lVzG67ecHG0/Abs/LFejOJ6FUiT7JtmZpBu58rLxj4Vf6HaWM7xGCFTKwCEKxBOeOdtSyW56Kceiej0R76ISRhXw/EmOT/4r0tI4LFGEkFxGz8kIq99wzuK57dDXG+/guiStkX7BNYXcCM0mAX2gkHseePxqmltrJFblWWcjbknjPJ+nr2p8cWmZx6Bbn2R0uO1E1pDNdb4mkJY7tigldgHTjr5vpRf9KahHa7Mo25AoAVcAHkV1quzEeb6tbbCVKiIglzgbBzwOBxmjfaG2nndzEjbi2SrKM5/iHz6V2Yq2URJXNwTgEbSMgc9T60LcwyQz+HMrBgSCCvTNdPEAmB3YE7CVyMkdzR/sRCdQuxaqqyTHHhMeo46UcTD7GLuwto5JYAYnXykkA9ex7U6n0SeC3ja509UhZyNxkY4K8ZweB9KUJ+k/qLm40O5upiDtWOGFctkZcnOe/u5+tZa7Iqt/Rsa+UzFgBzwiqoOfmxoZeTHQrdZy4SRvMwWX+yvIql9n7OG2s2kkRld8nG3PG481N5NC2tm/sxoCvdRrdRGFWJ2ZPv1ceyt3BqFuti+Yiyk7wvYUv8jRk49k1rUd1pl8bdFRFI8vl616G+jy7l3QJNFH/wAOV41Jx3q0eVIt4aJP2X0x9Qic3TuxLAxhuAcd/pXolnbXNxEsJiVI053gYrX5SYs4WIrDSBDcpMqsWPGdvGKr4LNIl2sVbbQs4/qAfCYoF+FNdgLAqvbFPOfQenYkMBBNOmgWQHaORXVj8mWc94KQlS3yfdpl4BU4x8M1V5Z0JGNpmMEOVxt6UZHDhSc9K5MlzX06Jlr4YSryCV46UQV8uKl6sVfS6q0hfKI2QjG3Bo3w17rXNfi4/wAKRlpA8MK4DGNSMcGtyAMhTt9KtimYWha3QDdW5kjlAHbg/Gt5IyV8zd/SrxSIuTzzWAhupI5rdjkHcxPGe/54q01DRYb9f3wcqOy8Zrpmlojx7IiKKzjt7i3vCUgnABAGceh/5ar49Cs7TaEDh9x84ZvOMdDQ6X6OpoQWGlDQtPF/Ehukwu4IuWEWeDjvROqXy6XPsgElzNneltEwLAHjJHRB9cn0qdVDRSZZL/tMh0270QNDqljb3W0SRK8q+fHPOWzn49qmNU0Jtf8AaCW10/S4L7U5TunESBbe3H/3JBzn1GF+tc00pKuTD9kvtlI076PqcxZH3PC7HlWHLDPcEDikvtPompaJO1hqKLG9s2QYIfDMbEKd2RywIOCT3xVllWheG2e52U7xlQSv/E5H9U9/wxUn7Je0mnax7EpcXl1DY31jKkLJ7i87trA9yduT/apd8xKjR6vapFHbliq5bHmpZbrImjW1xNNEv7rks+d+PKCPwrGlKGg2vJxtIUEc9R3qbvvaXTraRk3+NIBygH515mbyVNdDcRX7dR3F3bpHErFGYbwRmPPb60gi1u4OrfartoTCScxBhkCvP8jNVBx0UPs1Z20yR2k8BhyT5d3DDHHHzrHTtYsm1L7QpiRwRhi3AFeh4HkKeibdBXt57DW+oaZcTRBVmijJRl4OQDgGq2PUI7/TJJ4JVmVRgvGQQK9ipWSdiqmqP5BmgeGd45lwykqw+vWq/wDajpC6V7RSorblZcqT14PIrj46Z6MPmgDQ5zL7BarbEMXtpUnRMfd8uf8AqoL2ZuJLWS/UDJe2cKG6EjnmrxXRzZZ0xlqGpfZtOkIy6MGhJJxkc7T9CKn9XuTc6aiDapD5IHUH/SrT8Jl//wDDppQv9c1i6kG5oYUTj0c//hVD/wDCTND9q9orWQZmligdR8FZ9x/FlrKE0ekR6T4G7CALnoapNUjLqyowJyMEDJ+WKX4NxP59/aDLpth7Zadqt477oC8UcQi3NISp2/UFgD/WYfw1N/tU1Y+1HtWNK0RRLbJKFjYDPiyHKhh6JjIB9GJ+9Q8qX0FJLaLNcah7VSXgXe8kjSuAwIYk5wD3O4Hzfe+le3WP7K7bTfYQmKNZNSaETPIG5JPYfGuTLmivhPJyPOdTdHP/AKPxcggl5HL7ieQAO3Gaba5oljpqq9+0kMgUEQhSCzKTgnrt9715rmfa2c/YkhMioocbiXLAHhSSMdPWv18u1MQnAUgDafXsf5f3akv7AGaffXELblWBYxnlSQQvb86mZXlikO/dnPan9Gw7LaO7MgcSEllOcn0+FS9peSlmfLBHGD8akvG76M732WdkWvLsQ79qgeZgcEr3GBx+NB+yd4Vu8iSUZG0BVz+Pwrk8znK0dOPX6U6WTW1uZfDYSrwTuzlRx169+nSub83U0A3yjxCCiglVyDxXlxVv6VfD8B7u9kL4k2xycgMR2zSWd3W6eOTYdoxwQMH5969DFG0c7DJdVkW4VbiNXdlJSUN68H8qmCZ4kMgMjNk4J6fIVacAoi1NQ0knOCqogPrtUD9K6v8AaYpZFCnLBVGMYxya+kT4nc1sDsVbYIl4XJOfU19t3wDjaD3FPC29jLo9Y/8Ah8s0uPbb7bKu+Kwgdw3pI21QPwdv8NNf2DeHp3svd6iyFZrufDOF9+NeF/BmevA/5TzXiekOr/D16/1JUZ2SRuAcKGxz8qjNR1KSSdlXcixjqR1zXz9+flf6H9SiGpXAGEwoBz5TjJ+NTaTTlSoLebHO7pUv5OVr6H9RzeTT3G6aeQKSwwznj5UvOqQ2MYGwlfvMDnmlWTJX0NjjTbpEUeLKfMfLkbht7fnU++opPL4q3B8/UqMKg9fnVJyUmGznXGkWZpYIWXeTkk4I/wCxrjUplmVZYHmOzbuMoAJGOo+FNt0+yV0cafZTXZbdN4KovbbyaBn1WXT7gQeIU3sSzRjGOOSfTnHzrox4UyXLRhrk3gqIsu7IAMFuOuM/lS7U7pyZBdMu1lOGCjJA5yavPjpsR3sX3UMrM7sdqgg9cCjrCf7RgWsUc6xcsznAUZY5H4124vETRNrYmNrerp7JCrzxx4YR5bAION2O/wA6q7G+0+e0nWdEmZztBj3ELEeisMcklen9WumP/F9CdJkZ7He0tpompql1aiWOUKI28fw22noR8gxrfUNM0nUdQe3t0ePJy0TQt5H7lD278Ul1jtdnTGSS81fV5p4BfQFXtABMVVdm0ep+Px715tZaZ7UaKJk02W3u4I3ERt5GDuT2wvXPHbmudeOq/wD5hXB/Co1vVCt6winjaMnBMbc87mwc8fhUPb6rNNf3EF/Y3FndxFfFSVSGTjuD0HWnWK5XZFx/h6nYzfbtEVoYwpzkoXx5R1NKdEu1+yp4kilSuJDnqPSl3Rilfo5tbO6nuxdPeLPOR50G0bVHTzFc9NvSl2nX8ct3nxGZScDCcAegH6001SY6mCL9tbP7PqV3gJmKVieD7mfXv7wph7eCddSuJWVVWVRu52kkcH8m/wCWvWw23PY3RPexWoHTfa60m3bIpGKMw6AHgmkCzBLmIswZYm6E54qkpNMFrZ/U1vJbX9rcWsrI8sLFdhxgFl4f6Lk143eftA1lNFl0x2s45o3P2iW2blgOAFZWw2Tg7h2BBrlnC1W2OJNUEV77f3lpaIghtna2QEcEKzbv8xp7+wT2audbvLu/8NmWCMPIynGWOccnk/Glz5VC0gLG70rTL+NLi2LDwlCFETAA3HaPqM1c2/scdLhWeSWFdwR2MgY8twB/v+tXErpmKSV0mzvL/WIYVuGaNFDRKFAxnjGcc16Zp6W+nxSKWhXBJDA48oGBn69Kb87HU6P1jp8tvapFI/mQcse3wrCD2gsJ3IJCqyb1w3XPJP5Vktfg+wzwlXqdxrUBHiEkR3KRmqLkGwZgtdMN/HpVIAzCKvGetaiJSvypnsD9H5Rjy8+tZuUXjzVszQM+yYbzeXjisi4PTpVpVE38PjNnjb0ruPw9x3Nt4pzEY5PatRGBkdVPINA/4YgMxrbZ/D+dBhlsxyc/QVsuBw3f0FY/gE7c6wYdUl077LcySqRgxwtswfV+n0PFPJ9PiaK7IeUm5O5juzg7VAwB06Uq3/o39f8AAWJdbdXMdrYxRlDsaWcg7scZCqaCg9l4lt2jm1bVLnOcePOCBn4dBjt3p1v/AEOv8P2qvFpml3V3q+pJI8EZcw2iYJwM4BJyTx8PmK5svZHR7a9F9JE13NH/AMF7gKfBPqvHWjkBO6X7JS69M97e/aNN0yVvEjso2KTTJjgysCTg+gq/UndxtwBgVnIAbTLCw0u1FpY2sNrAnuoke0D14X1755NaXGc+TG74it2Ak9sfZjTvaS08O53w3KjyTpjcPQY90j4HmmUs0yum7wQrg+YnGD61nID+b/b39mvtPolw13ZQreWhdsPbkA9O69c/Liv6YksLO40/wLyNZwOck/yPb51s5Jldi7P5d0b259trjQo/ZeG0lutjHwEZCDGF4KZJACDqMkc16x7S6VaQakLnTTGgiO0RiPJZeh8x55AB49KlXk4t6Yb/AMPM7P2M/aDcuLhprGwwofYxZ2Xn06HPpuq/lvr+W3WIRmNSw8ob3Pw5/Gs/keNPwT+55xrfsbr94zLb6xa+IiklGXIJXg4O0Y/P51V39z4F6QwLSuNx3HseKhXlY2/hh5h9r1fRLhbPXkHhsw23CM2KudcEeopLHIg8Mp+BxSvNjb6Wg5aHv7M/aPRLLT7i2n1MW8UhDtK544ryG79ntVtIZGtpXeMDcYlHXniu3DnSWuQceXZdftl1LRdU+xX2nX0Nw5Z1mWLqvu4P515yV1WG3MF7ZyWiP5l+0QFC23jyevzq6fMrFcQ3RNu926ggoxLeqHFb6VGkNsC6MGkc7Tt77D/7qdTo1vkJ59mwA+UEHHxwa+agCfK/ALsBz8KovhGj07/4cdSOk6nqd1IImtzBGkgc4zlqkvYSYwxzEzyRq5y5UZBxz07detQttFI1o9p/bZ7Vx6VoF3bWM6z3F6mxCj52KwII/P8AzV4Hq2of0hcLbRMzRxsxZv67cD881mnK5sHxPRf/AIdvZWbUr+X2mvEB8J2S28Qt55O7j5dP739WvQtF9pdB9lfZbTdHjUsbSBMuoyPE7gfDcTmvMzeYrejZcl9cwStZSRxMokdcA4yFOOteZr+0FxdSxLerNNK5fw2gKZPfae4x1rnryEvgOp0Tntfo91Z6g73EqsjOXXYduwEsB5P7OOfzPSl+ra5p15qMiSTfv2bJQNkfj+lc1ZLo5La2Jr1F2yIeCVMjE/Hgn8cVtfTySAqoRgB2bGB/smqYuX6ITc0JnnMQVpAxGMDmnuhafcS3wmQBmRg3IyMA1avKWNGpbMU0C6s7uNbgw4kAP9gd8/EHAr0OwT7TCEntgrEHAOfLnnj51x1/yVFfVoQ6Lpc0CvLDGsjMoG5ehGadTwRRAlTsCnofWuavIeT6CWhZqLEwlGhjaTeRvY4C8dj/AL9e9Y3CeGCNm7GTVceNP4JTb+mMWkwtG1wT40kgxsVPzz3ru3u0DOZiu4P7ue1V3UfBpmWKf6LjMUkl0yosbYEYfn557fKm81zBtkXI8NugA6Giclv8BqTzLV7iNIktArDIGSOgJOa51yPN7dgqCVkC5HpuGK+qTdJM6daYMAABkkDHUd61s42kuURRu5HWqP4bB7v+yIpL7EWlu23ymTGf/wBw1x+zq5S09k7eMpAiCV9mGwxOfT+9Xxv/ADC3kMpjn2jilEzpGcMAPLt6it7mSK7VZIXJDHzZbH0rzViJqhFp2oaks3hOPKp8/l7VpPqkeleJN5VlB2DC7evxqk4uxuXQvfU47e9nVVafceRnGDSdpRIzOAzyMNxOc8Zq6xCOhlHfXtxhSzEMSQP4RSKXWFs7WYA5AUDGBwT8qpPjNsTkyk+128cDxm62SA5zjPPpUn7LSa3JJ9uhtjIxkO2coHRT/U3dTjv36U9eLM9thuh0122u6jFY2O4XLBcRwqAXIPGB/F6URHol19pF0b64WPcHaNWK7j3z5cfQU0ZsWPrZnFgsPi2+pLa3QKmMlXE4wwP+/wDmorWH+23MchSSCEDCFTkqevP4VZeRD+GKRza6VE8bSz7xLkBiHxtY9j8uVHyoT7dJ4SQwwHMhAOTjPxqVeVc/B1I1s9EsYkaKFEYk7mOdxNB6ZeXOXNyFU/dO7rU/5NM3jIt9oNGiiuvtdmTAw9DjJ+nFb6hqLPIH8SRs58o6Ue2mZxRn7MxNbXEX224aNUlV1cJtwc9c0r1HUIFgENx4ZwA4A6jnvV8Wal8MRt7YwWl37e31pFGqx3dtLGSgwEZf3q5O7k4bd9aUavqunXHtPbXdrN4W2LYS7dCVVOn3eq/Pmu6XVLY6+BNpZxRQwrNOwk4V2K+TG4/nWhKGESGTaoAKkHIXnn8f0rneQlRU+yVpaRXtv4szpNyVlbDRsNp4U5HPoMipiOK5hUMrvnaCzIdoxmmjJoafhS+3+ixCxivlnZUcybYmVd6cJleCRjnPrU5qt9dNaeHeSMyZAKkYPwOe9UnLVGOyHnsT47qFDLnO7HIplPBIrPIq5JK7ievTj9a7YzNToTmJBZiaGOFPEJOF29CeemKbWQaHV4lVQCGDqS3XmmvPxgpjo/o//wCHPQobP2NCkqpuZXdmIwQM4x+VReia5cQQrHbSeGoAkYgYQE8de5rx3l5UUdHqvt57RDSrze6q3m2wjqAAOpX19DXnGr63JrkoeZ4y0QChi3JqeTPpdMJoK1LXbvVb9Fk3TxBiS0bYTH8JA5Y/E9KmWuWWMxQzBFQnOeM/XvXBd3T+llXRW2CrZ2KmCUByx3tznn/Spqxv5JJxbCUJC7ZId2259apiql8F/qegwavJZRRt4iz5x4iRvnHzHY/+2peIsrSAT71UYdlk4+VdH8nJJm0X9vqNtdKDHIA+MsvcUk9mpEJcGVgccHPQ/Lv867/E8jl9DkP5JQoyrD60G89vtYS3as3YbeprtrPhnthvZ2XZ3z8aXW2sQJckT27FCcDB2r86i/PxfjG4jaDKnp1NM7WKG5hWa3KspHZ84+FUjPFraYcQMbVyT1PpTNbaCIGSRlVfi3elfk8RlANb28shBK7Fx1PWmccTNCTCVZiPLtakebfwooFN7GsPdmzRS2Ezs3iIwbPJrFmo3ihXG5U5KcdqcvYqiEDk45BpllYcUKmmXHl+ta3FssfIG0nrimWQPWYmTisXjZDk9D0p1YOOjQspU89qHLbT0ptk+JruJGFrmPluuM+laqDifHRtrsXxgHmgfaCWWDT/ABEHmz37ioZs1QuhWKL/AFIPI6Ha0SsBk9jUzqsjxjxPcbdtx8ua8vJ5OXYjKSXWGmRojJ4a44Vm83Hf5VIRXRfLAKwHu4z9ak8+R/QD9TiDSCVDvUnpu6H1rOObw7cvhlz6io86b7AXy+FFaTuApCsxIxnPFCy29xM00SyqqlsYB/4kZ4/SqL72Y2Ss2oxS3UmydWYngHsR2rn2q0YWcm6xmVWkOGRhjnaa68ShrQnI1tmkkjZhHiVucnocUv8AZ/WjAY7XUbYRzhPCZt/AIU/zApqw0gZS6I+zcLuW3EYYMCOrH4/KlKzRoTuJOQcAehrZ5Logxj7eWttqmguzFTNbJvgc9VA52/I0uubsPC6qCoYcg02K7m+xovTIotJNZh2KKAgVcfnR93bgQMMAhSSAPX735V9Bje0jol7ROXwUoJBgksckfKtpEHg8DJyePQVRgwOyjmwFMkiwPycLTGyYJEkRdVbOF+ZqD6EM7KJ7e/g+zw70B8TG3qR5cmmMSQnVBErmJIYfBBDdz1Nc/kVuBXRWWmnpfKX1OWRETl0jc7pRnpkdB8K0jTZKFUIwRQMuNx+deIo22LyCbi00DZFDFp6xjHmZnLyqPTcemfStlspphGMgq/YLipOKX6YxLdaJax75Y7VbdyC0UpXIbHQfOnF1bS+AbTftDHJOz8qpG1+i/SJu1uoJ/wDjxsrcYA70z1LTiA6RywyQhAWGBnNduJzolx7HXsLLGiThzF4gY7nDdsUo0rTpBM80TCGFjtO5vMRjt/exXH5OGb7LxWkWkkm3MzxqyA8K7eY/9qTC2uIUJMksrFduduePTO6uKfGkd5BnJdDwkkZULE4Ug9McfrU9NJdNKBvbqMDd6VafGQnMJv8AUC5eGJFMp4UncSD2pZdvKJykrMH3E/TFXx4tCujJHfwy7M3U/l1pfdyKshLS8muyJ6E5BrXKorKxzkcDdSYzI0u7k8YyOtN6wAdSTbcXYLbgH4O3rz+lfLsq0siA4ATGPjgGvWhbk9Gj7YKqyxtkrkjkdq0swN4VcFg2eflTVWpA9P8AZh0tNJA8ch85IJ4Q9V/It+VB2sSKhMJ2sI0UhRnkLmvk/PjlZz2+x6NZmMQtVwrHPnXnIrHSLa1lgu1nhDSYxA/ic89RioRi/qbEckT3tVNfRaXNdW8IkjUqodm6FjwfwVqaftUltoNK0qxtCv8A6iVCxHVhkL+RNdfj4+K2Y509Aem+zutXdrFNaLDFbxuW+03UhkEnmIwF5yME8YFWzX0EWmwpbwBIkQLGWLHIxwf51LJ5L5dG8NEhp3szO2oi/wBU1Wa4ZWbw7dmZomIHBOcg47AAYpslwrp9oUmbLYVScAY4OKL8nI1oPh8kufscItm8NY1yQEXof7P60n1SeSSRgHbI6Z7fCk48zHQ5tLxmuIijsFJ8xdccfCp+zvDbyiQMuz7vHfvSvD0KqLVreKVQsxwrMcBep46mkkGozSWR3zBSh4wuTUfVWxnUnWpSwBnRGYKgKg0k1C8mnVgECkHhQeR8/nXRGJ67F5IYWl8kZcy7XwxCMTznHSlEBljtABDHuQ5zjOKKwr8DkH6hOryFzHuVCCF2dD/v/lrCJpZYucEPHkOzY47AfWtjEzOWxbcw3F5N+6Rt8hwFFHW7NAyPLIzojcKFzzVlThdGJAWkeyaxXEl3dSr4jcIoPAHf64xT+K6WWN2VGVOysjDK9vzqV+Rmfwokv0Gm0iGFcROykjqRj86/TX8SSRRrIGZjjzye78/0qfPJ+hqPw6dP/RrCCoLce9jb9e+aLfEgIixMrMpZs7h8qFkpMziItYlkWN5lkZ5CQQBxt7Yx8fWv2qQBd7QXAaPPAZsu3rgDjiu3Fe32QoWXl6FZtv7xc+d1OVU46fOlupW4SXa0ciSkZYIcZ9M16eNxrZkhdqUlZJH2mMnkkZ4r5awCHYGYDI3YHU/Oo5rTXRney10+FrlWEN1uBJxzjeCc1lo+oNGoe3iDNwpA6mvJycm+isPSHU+mtbwjeFJDHjPwr4daW4nBmgLYXBYLyp+NJwb+m+wwcSwjYw3Y94joK3vblHteNuT/AFe1HpTD2AFrcNHdZDHbkZ2+lBvIN+0KOTjjrQpcDJlOl/M0pVZGZDgYK9KUaVeC0uFkYCSYEbUK+XHqanfJlFWz0XRdXitIxiLxnK7TlelIrjU9ybFWFSEU47Zz2pFktDoe37XLuZCyrDjIHpSyHWHFjdxtHbyuuE3qrErjcezYo/7dsc28YRkGRf3efPtGeexpPLqMxjyjecj3/hWLS+GplrYalemVEsrlWhZskhxnp0x2qKstgzKzFivI2r3p1kr8HTK+71q6t7kwThpn3fujvJxmkGn3sU9/GNRMoRiA0oJYjnpis3bG5bPQ/Zj2gZZhFdSLIXfaMLyuf7x/kKBt/sej3Ky2Be9jKYG2PJQnu3oPjXXiy3IJHobEFSR0IyKTabqRuoJFL7lXGSOxrqWXYwbK2ePSsHlUgjd0p1WwOZYhJncOtcNOqoc7ulMg5A7wJkqDWc0wByvf0qiDkBzCIbl3kNnoO9ZuVYsQm055B/nT8hHRm06xRF8Hj+KgdemFvYyzMu1mIVRjPPrRy0I60ZX+o2mxorsqEYHYQeh7VHajJcSvlGZTjqKheWqJe3Ysv0l3SI0yqwHvE9s8UdqEiQbxMhDls4bv71cVS2ZyBtMijWVRKVdUHU9zQj3WwmTeAo4wozipeszka30rIX2DCI4Khm4BpFczl5JiXIV+SSc5+najgHIOk1G93fu9m3vg7ef1ocWMhtw+9mAY9OgGKNTsR0KNcuhcRskh24OTk96z1mGNIznc+P4v0rpxShHRLat4aXRkXAIiDID95l8wFcaxGDGHiAbwjuCjrjvmvVxLaHitoP8AtYeNZjgeKofA7KeB+lLdKVRa7ANzKAQv8SE8fgf+WoZse/hzZZ7Gbz5hdI28x649K/WMP2l8SDy525HX5UmLFphjM7kFbR8nIA6nrWmqKIlcglsHbkdCMt+Yr2cC1J2T8JvxEciNmG4EkZ9K4MbfapIi+AASvzq6FZm7mEuGLNIQCu3+PFFaPa7dTAkAfwlLkE9a5sj0Tb0MNC08ku8yHBHXdyCaZSyrHLGJ12lSSQOmMcVw5Hy6JO9jOG6XIZGVpGJYZHPTFTx1RcjHxAxUfTtCFlZXLOyAPJEU905xSCC88QI+MYHWpvEOilnuRM2wNKzZOQW68daVR3EagsDk4/hpOOjfw+F0S53GPzYINCCYb3ErZB6Adq38BDRY/FUFFVdxycVxal4Y8kgkjIU/zqFrY6DDttlYlwfgxoKd28PEhVMnhdvWiMRhylwJJhGAgJzg7aWtId/lVVcA4JrpWHoRm12gO8M7P8A2B+FLr24kRgSyk45A6GmnE0DYBfSMsuxU2jPJ29a2NsJ0WbLSE5DoTsGe3PerSmvomxfA4XO1BIxB4ZaIksJIpgrRsgPulTneadaa6MFl0cMCHY+bZj4AE0Ne7pJJo4mVdgG7d3yp6f4q9GVxk9JyaQ3QELujbTgrj6ClcqLbuhK7lyNxzmtptx0Yq0e5apKsNiGG2LCpl1Xvt715/rfts90pS1KxIXyS7ZbgkdOwr5/J4t3eydTy7Luw1BpSJBIvI6gdPj+f+WvO01rWb+IW+lxSQwHyyXEi8E9G+mRS/wAPX1mJaRQ/tF1azu/aCDG1YLcxsyFsHhwT+NKtL0JYFW9vhLcTseGkOQfkOwp59ULWyV1pjl/aG4nmb7DBdrCSQHkYHv2+FaENCC8scQiwApxn6VBqH8QnsoLsbnMW1WkZQxz5ejYoGGVvMw/dkngqNtJ69/hqtjOUS5wpaRcYDN2JoMTSKu5pF3HgnOSBWrGa8h9kQzMIzCSwYcg0XbRWxKsYzKR5gSvlJ+NOsZPmfVidcxSgiXJIB9MVrqF5G5eQ+GQ7ZIK9OMYFK8S/A5Cy+VsNja3GMDpQd5cQb3V22EkBjjp6VWMTQcj4ly0KmPeoyMEL2pRLdGNnK5kx7pHrVHhT+m/2HK6o65SMMyAeXy/jSywhedMMyQknJdlbPyrPXEh/YNfV97qpOZARgbeRSzU7G7S+la1hZkz5iRwOO3zpljikbyocf0/cwxo1uRMduGLtjAz0x9759qX2MVxBEzXoXDkHaEycfGp1MSw5Uzj7ZKl0BMyJECEY5U7eCc57/PtWWpRo0wYOuWVdq5z39O1UhzSJPkiksdQik2q53W5xhSwUKfXH60BpP2dCilGkk8nGMDpXNlxTvZWLb6ZQ2Ue/N2X3FlAVRwMZ7D9azhdsM6lYAo5jD8Y+vP8A/rXHSb+Mtxk5vdMt5mwyxq4+/wBG/HvX2ad9rkNDHHjzP4eMD1x+tNHsXSZmpR0NMtlRUcrnH3OSaFtryNrh40lzMmMkr5T6GrqM36ZykMjje2tHSExxoxycrliPnXH2zMZ3MqqQPMv8O04/OouKT7MdLRglxckNAniKF6KG60K/hyW8/hSPE45Lv0YfCrytkwhrp42cSlpFH9bofSku4ozbZMuRwfWrLHtGooIFZ5BMFXBHAVuRQWm3iBoyI2LgeYjpUMkufiKKpHdpK6N4eF8Qnh+9Dy6tZCPKud2MHC9DXOsV1+FFUoPluZEIDtk560mN5JfbvA3eGpGWX3q1eM/0R5l+Dq11KdXIjOUbykK386ly88cxZgI1zj3uT8af+MtGzmZUfbn5VWZfKMgHIPNT/wBpzIwJ5wPrU3g0UVlPFc7jtHlGQQM45qfjmwWfCt0G2keMfn0WC6i0o/eK2McFe1Ta3vnVt2UAxs3dKzhSBUWulX22UYLgZ6g80v8AZrV7W3IuC8QcHBgYHkeuV6ULkmUVbPTNE1u5SONBEZIvjSXQ/aC21GUJbxweKQdqbsZPYAnkmuiKf6bsure5W5HixqyjuPjSqLUQt0fHgVNq78o2chugX6rzXVFI1ZBwzdc9a5tWS5hSSMjnt3qqZvIxdG95a1YGNWOVGOST0FPyDYH4cjNiv0mp2MavuvI2ZQSQpBpXklCg95pMt3C0TbSp6H41la+0to91tRDlvvdEP/ekedfA1smNc04adMYhGQVQEljnxOeo+P65qsupLTUYxPLHua3AY7TvAGdv979Kk6EcSjyzWL50eJpo2DgYQkYwKF9obqS81e5kclkViFJOAAPSo7IvQsupXmcs7KAei561nOdkYUnIJ6Chdig5Uo7q23aCPzoeWUKGG4MPRqosexBlBcRHT0aU7uTtGeeP4qR/ao1QsikNnGCeDR/H5M10a6vIrKfDKqCKXySCSbMiufQAZxXRjw8RHQJHHlm8QDaBtJPfNfpBKsuxiRk+XNdmMxCuK0mNyZIR54iSpPQj0raaCVp9y+KQDuYr0wKpS6Gfw2jmuJLYyiLwpIm5D9PmMcUH9oXadqhecEjr9aSJ7Iz9GurXMawXCYVmOzH160ovrtJXuZEb32iVfoOa9PDPR24/hheDZtcjcT77Y6V9uvMFwMtjpmq/hhlYTLHe+KehGODgVivnkC7MsD09K5Mvwk/gzvZS4eRlVVPAX1rRrBfBClmZiuSo6AVydIkL7dGWbxEAC45o+1sffdw4YMdyt0IxxR7JA+xy7IlOCvXkUV4Y8PClFwPeZvyFLuWB8hvGJx5jx1oCS1nLb/EVVBxj9aGpAYfalCMZPO46fCsdPiETfvdxYg4YDoPWp8ZYv9g+11AJH4rSNv7Aill0pcjD7CM4BOCRR6ZYdjO81ISqzSu24dMdMUka5aNNjICMck96acGgCJLsywnCsoB4Ipd4+9sE4UdqssegGaPHKqIDJIzDnjpQdpNEuDH1HWscgUVo4S0RJYyXzyFYe78aXxXsVyhdVKlSAVPf41FywGUv2bDHIEbKVCg55rkuksLFomVVIJKjtQpYEeYC5Q3CNG5Byo649a6WQJl5nwmcHLe8P+1eu40d/IX3SxlnBLFQcYIGaN0qFbvXMzx5QvuK+gHb61DLfrXRN0O/Zr2RSeNbu+XbGwykWcZHqaqG1GKCEokuWJwSR1OOfwFeFmz5arSEdBD2FnHC5gfG1CoDFcrz/KltjfJc3SwwFm3nIwcH47q5L9iM+j3TZo7q3aCPwg8RHnbnPyNLL66WymdFdmLrtdlPV+x+i5pZw3XYcEMDbbLURTAooJOAMuT/AKUvW/MuBNIxXbgbuadYrQv9TlkCQkryrNyCOa5N4s5IKkqO5bjj0qiVmPWgF18MtIQynPQntQ+oT5JRyCM8fKrwtkguDVGSFYPEKRqTglcgGkV1vSNm25OPLin9fYn6ETTXMYLGWBk4IKOMn3T07daQxMzylmXcwPI3VdRocfovj4K9Sa+QK6QDfkYGWYdu4/nUqejGfUd7aXaFWRM8qazkR3uDIMkYAClutCezJbX0c2kIltYgU8PfnASk32x2kCSzbAhGCD0+FSrC2Xm0PdUuBaKi4cIQ2ST8am7rUGnIgBdgMjduxTxgpi3Y+srm3ZlEUZwQdpdePjU2L9nf7OM7EH8XOa1+LX0VXsbaisPitKoLO4wGPQGgZrgyshBGASduMkkDpT48D/QC47uMTs0JKzKcEq2M8UvdJIQ4UKrEjzBORmqPx5YDKLU7iO6WR1L5BLBjjJHTnvSWa4kHmkkZ3Xse1H8OReTHlxrck87FhuLE7wO/H6Ugkd2LF/KCM8d61eLKew5UNIb9jdSk8ADgGlcSSyN4cYyxHT4Vb1y0aUyXaSHG8qpxnAzzSazgukJZ0KxjggtXJkwTsPg+WGSVmhEqxxOpOSOa7094THt2b1xyAeM1y0nHwrFSwWK1vTIfBhyvug7OtM3ubiBSY5ByRhQ/QVs1bQzlMTXUBDBPsyrhRjPU8805vTHdwqzsyFOAfX1/lQsnEzgKkLPH4bbSy9CRkii7siBmdWjfZjkdMeg/WqS3RNxoDS8eEsVw2Op92gb2aSUMFRI1PJUdTVZxv9FN31FJ2AR3WQH1yM0qichjsIBHOW7VZY1oB2lz7m8qQR1Ld6FsIpbhgIizsGOSV45Hao1CX0pNUOLMiQFQeQN3Fd6dZS20hkLMQRgg9q5KcIqqejdFxHvLRpsPug8mimjmlDMgUdBtJ61P6BmskYA3dzj3aYWOls8BkMqhjwwAyBWes0Y+zjTz3YtklBBGWQAHd8Dnimfs2ttZahskt5GSSRN8p8pIyMj5Ujns2Uyx0HT40j/dCRQQu4soCoc9QAvbr9ardHisYrNZLIiSQqZo8MrZHb73ZcVSEtFpk32xW1oz3J8IYJIznAA647VMe2WoT28awq25roHyEckdxTvKoXQ/w11r2jy8traSlfNww2tkY/Ko64nLq9xnDMzPkt0yf+1cmTyqbN5hEl3cPEWIXeSXkLDnnikN5f3AjAEgVsHCnpWTdUI8h1c3cIibdIA2/lCcfWp3ULm5kZjvXaSAQtVWOvojyF9ouv8Ah2txbRyD96m1ieinHBFQunXM1tIGLEq/VVXykenzpa5GzexpqrxNcbVO4nO/Pf40su5fNIPGZs7v7oJrZ3oWgSedFLwlkYjnczdBS65glcMVOW7H1q+NIiwK6umJZCVKk8FTQdxhSR98HnFd0ShGdSXLFvDjLIMcn1FAxSjeWbjBxzVlIo3EoAXncccUsa6VMkjAHf1p+PQDeLz7sKucjNLlvwilhu2nGflWJUYzW9aONVkjG3B5waBnnhniOW3MTxx0pu0hGC3UsLTzBY8yNjzZxvri5hV7d5IdviA7yR2HSqYlyGxyCeIzhyy+YsCfgBz+tFWSAxBmLNuB/Gu+Olo7Ynoz3FoQT5WByPjW0yK0WN7cHr+lP1roHJlYwiV953ZBya/aVOY59jjcpOK48jpdog5GtqHt0D7dzEnBP8q5WfazSeYEDy/CuB1dEzUzkqRIcknIG3pS26mO3eCxJPJ9aaMewDRIeQ/Q9KWJe/IkdAar6gGqRRzPK/jxx+GvRznPwFAJcM2GGM9wO9HpAOeSV40VSoKnJPAz6UEsjyMWxtzz7tE4Gvop1dEiPwkKgsoLH45oe7Vmiz5R8fWrzCQA8zqWEQxwOWHrWCoVGSeCeafiYdO/h7yh8vQ/GsXG8Zi3E5xkUaA0aVkIYnaCOKFdGztDHd8axyA4s5h9k3qrGHcMnPU0ttd6Mqsdq4J+ZpHGwKeC9nS3CRlVjkB3K3JHoc0qtLmAy7ELBscnHSptOTOxfflkj2RkgvGQxHVgexri4BMuSh6529zj9K9B9naF6YGWGNxKqjG/HpniutGgaSB1J77cN0wOf1rz/I2/pOw2a7nMAdzuVjgHdivkcSNKTuMm0Y3dlrlWOdbJI7tdR+xHMCfvyMht+MfSh4ku0lnhQ7Le5ILqPvKvA7etCxTQJmrXs1zc+LK+Cvf1P3vzrqa0cRAINoFPwlIlVMKGoALtLcY5pLcxzIrS7vIAc84rYwyxVyHsGqB+A20DgfGpe0uC+QW2jPJxjP170z8ZfR1sqLUyXN2Io8bnyRn1oTTMmFPDV1fPDHv8q56niapDLwXFlOLVBHcCTyA7c7SOn5ZpvpKtHC6qCfEGWZ+o+NctZ+I8xsSz6HezXEU0CxN5iSA/Ofl2qtku4rUK0bpsUYYoRkmovyslf9UXWLRM5urdmiuSrSR4ztxgN3Hz60fqlzHcxh7dmZA3Az09f9/+2q46p/8AZEbnQknmneQIieUsMNu7+layFXjfBV2APDV1RxJIUThwzeIPMjYJzmtJrWcsWcZUjkjp8hXRPHQ/4BLLIfKFwCCAP1olIu7hsjpTJr8FAntFilWbeGz91lzzRjwhv3jtyP5U+2wDYW2ruyqNxuCPx8NoPIoRbkIUZFGFI8pX86ziYE3iyy7iTxxwoyaFnuGIKZG4g78DGM1qkmCi4eMsEL4K8j15rnwmLSAHG0dfWqM1G2yQyIoYNlSdp7V3BFKFDkhWB4yvUVNjoLs48ruJAYdCG71wLjafPHhh1VTgEVNmjHxHx4bHCqM4Hr60tuJmMO8KEHZB/Ol9YDaK6ET7R5lxk0tgmi+zFmm2vvOU29sdax4tmIe/aImXduzntt6Uke5yQqHITocYpPQOU0FwPD8JuCRwan0uwIyHbDY4NSrx2zOXEaTW81xKbaAHf12juKCs5N7vJGXbGNxDYwPlTTLkzezOWHZGSSd+SAG/Ot78rlvOV2j7w5NVRotEeZNhznr5a6i3tKAFBBPINP8AEGtjrQzsY7QGUDOCvU0PbytKCjLtYDII6YFc1xVgnxKu1j3Q+Kdqc5K+vwpJZ6ldbkDSKqghWfbnPwrirx2uyk3tjiQsZhtYn0XGK+LJbOCDtcEZJ3YyaT4hmVOgv4sJjlBWPbg5GRSvTWZGUqzcPwo9K58lv8Kz8KuJYLTDTqs7A4hDNgAH4UujuRdRLA8aqSf+IT+VR5X+sdBsmrXsLQulzMphOI0jbAB74HyoMaWp3S3FwJVyMKFwQPn3o5P/AEoM77VW1QKkzrDcAdSvu/P40DH9ksxh2Tcv3SOc98/SjnQna+ms6sFfeytkchR1pRrupSRIRCY3LMdqh+enr2+VNOKqewdzoV6lciLcqFve6elIrq5llVnyPewFBzj1zXXGFr6c7o0urqAXJllO5eMgnkUkuvGE+Sy47YrqmEkT5FjYXUcduG8UuhOQpHQUksJXjgUOd4bnArnyx2Uihze3lu0gCDanXjpmlU04LFmWNQRjmtx4mwdBF0sq2jbCqh5DgjqOKB+0v4ZUMCnYiumMDRjoBuIj96TLZ6jqaHnmyoON3J5rpiGJyAJw6bh5iueSaxuJT4j4bAJGQWrqxwMfpQ7p4qFSF7UIZSoKmEtGT2qrjQBFhOu90kXdxwPjQU8qgkqmHGMMeoppWw0F28OJJ43dWCnguyhh2/DmhJLl59pdWZW4SRW6fOlrHsxyMpnaLUBwW8I54PbHw4oCymmtbplmUSOcbcntT4o0ExobWmEuJrXGRkPGD2B/2Kz1BxvgnkfYAmYiOoOW4PwrofwvL0dXQGwY27jmgZr4hCjxEqed5bAPyoXwZs6sNq3Cs+cAEnFc6ZMEuAGY7gDgnp8qjl+MnT6DZTJKCyo688H4V8lbcXYAMc84NcKnRAGmikaPbH3OD86+sSPJnax6U6rQAEyMmN6spzjH61teXAYRrKSwVyTiuiGUmT4snhkFg0Tdh6j1oO5kzcSSIzFC2APTimc9i1Iyjut2Qx34HBFY2CAsN3Q0CcTcM5jJPuk9+ta3EL+ccOg6Ar0rV9DiAzyrvZY923I3UQLaLH71gGXoq9/hWUHEFuMqNyZxkcA9a5fm4WNkKKeY1JxtHf8AGiXpBxOHCkAqCrHruolocLlUUYHXOazezAcvuYGQ72XoB2rGVGAJ+P8AFQp2ARbklmRpNsZPT1NBwli+PNye4zW8QCgzSElU2Mp4PrRbwLFtQLg4YkfXrXQjsY19j7B7s3I3gNEAcn5f/jRHsV9nW3mZ0leR24jU8Hyn/WvH82mq6I2Mv6IhlgDpdFZFPKKqkGiIzcLJKLYw28ZGCpGWH+auB5bFkVXCRpOEdQsivwFXp8/nRurWcpt5WCo7bDlsZPSrYsrGcn2yhiugCi4RiRwvfFYaZrlvptkty00UrzKAse7BBU+nfnPFd8SqW2Lx7E2t2zWl0YJ1YAnLICAPgaZNBda/d/arw+FC/JZYyF+GP1payxBjjZIiFYbwx7kbHIB8ox869Pt/ZmxtLR/tKtE0pysgb3RjrXNXnyukbOLonPZq3H2dmQIxRj7r5A4WmsdjdxXMrndMJOA2ew6VxZM/sGUaNJDklUxjIzj1oW9EkPv7R8KSI2xt6R+lmkQGOJEcueXbtScXcjTAuVyM4QN2q6wNGqkEXHi+GMqh5PIasZJd8a7Sw4OR6VWYaJXSBjKIZSQqbiO1fUj/AHpbPbpiug52G25ZrYIzKMsSSeM8dKykljDFA2TgZHpWytseb60Y3ZER8MBSD1AORSy7uSp2g5HOBXQsYGkoDMQpB+APSl0VwwuCRuIx09DTqACGIDZOWXoQO9ByOUlLMznPOPSm4mcQ3EYYyjIGMZb+VZQSL4X2lQQgOCT3rHPRnENjJMYIAUDowrOO8RSUG7AGeen0qTmmYg2zw673O7B4JoVLoScxllPQ0vqY6+G9xJHEWL7S2eKwGHKBhjJ5Y004wAru4kyI/eUnOPSu/CbxHOcKpy5HerLGBmlxJApVj5m6A9hWLwe9Ju8p9TTesAiOR9u4twTz5qHCqvm3H38c0esz4NY4Syh3UFccEmg7SVhwpzz0B4qTxi72NI1eQ+UrlR29K4t7pC/gBWikI6rzUXAKQ2aZpk8MlQcjkj0oKWSRCVLkk/1ualx7HOrqVk8yojkucnNCTylSMcnPJroiejA6G6ZgArhVHvADNcWaZiAZSMAkAL+dJcr8FQ0svtUo8WPdJCvXavT50TpRuUjLw4wxHkB5/DvXFSoogm1uXSUFWKOD5cDoaGnDCYtIGCj3BnPPy7VJpsZdD/Trg7wblRgeh5J9TS+OZYn4yxABIFReF10Osmij+3qZj7oYYC80lWTxJA6F/LwT+lTrx1AyyFbp86yJmVn94YwMikME4iiwCwkY+uP99Kj6UyiyB2uz+ZQq7opMgqy/mKU6lMxO8jxHLEHnOBiqY8ZrvYFqF/IF3JIVJOQM5x26546dKT3jNIA0CZbdkqO+O1duPGv052cT6i6KuXGIlzgnqQcZpRqEc0cyLLMTjyDHfviu2MM0uiY7tpmmkV8gZOchaDsHEaoPEwrjKgNg/Go5MWn0ahvHP++KnynHfqv/AJoHdkctw4J560ix/wCjbO7m7kdgjoykZxx1HrSy5UxsSxyT0y1dePHGg2MDOrwlQ2AO3xpKs5TO9sjPTd0q6xmBss4zj7g60vE4ZWJ6dqdYwNkinmcyY3LnjPXFfort4VwGyeufh6U6nSAKtIkEZLguScYJ5Wu7V42nlTGMxB1J/Op1XYAWpwEMuERlzyAMkj41tPKGkV8lcjHHel5UawVbPIQ7AqsMZA/KiVuZZIOGZQQAB9a1VQjA57VwY3XG5T+VFuyGEozFGIwSe9Umh4fEXNBMbsRXLNiPgbjxgc03vE3W5kcLukVGz81GfzUVZUdUrYrltw6He3APGPSimkZ/3fhqF25B9cUGsDtUCvndlhwD8KzjxHcgBsqQcj41j7RKvgwV4yhAdSM/nQzKoUt8Kg8Zz8TV84PyrNjhchmwRS8NBxBboKG6+Yiv18V8MFNoA53H19KvBWD8kCrHkc7epre2VpIg6qWVxyR61j+mP6dWjEnYi7sjAzX51dQWKsAOpIoQuhjBfwW1zJFJIsanIZnXjp0qfvFBmLv7q4Hlbk/KmQaGU15aTStcST4XPmOeuPSli2c8s6CSDbnBXcMqg+NbxDWg+4vRPMs0haTbGFQFz5BWRtooUMjNHdsTyRJy3wx2FHEORpJNN4W1BsUjkFufnWXhk7mVNq8dG6fCs4mGbxqUzuZmJ61+aLy/WtUgC5ZQVj3c9a0ZMNWijOYAOCq9F5rDxsw7ww3dDg9qsdhQeylzIkV1DG2JEIYALngcfyxU3pt7PY3QmtyXccEn09K83ycPJiviVxzGr3V3J4EMRy8kpABHccc1NXceoazerNfhorcMPL6DPQfOuePHSXYm5Q4vbu79oY/C0+d7TTQMNKT+8f4KOij8zRtpFbRRrCke1QvCg8H/AL0aUfBHlX4aaTZW1nEIouGx5n6ux9TW8GEkG0BSPT0pOVMX20x3osEe8FV2uSMZbkn1oSC5DzoocDDHJI6VxZXVHRFSNdTmjMvhOXZVHc55pZeTAEGBldgdufnXLOFt9m1SRjdXkkUZi2gqV8uFpBrF7PHOVhTYAeCG4PrXZGCWQd7NNQMrjBfzHnBHOKFNxcSxeMXILEZIrqiFAjAhgPv2sSDya41KbwgzA8Fj5s98VdLYoQ16xbIDgAY2+tJDfys/v+UD+GnWPYDeWeRRsAdd3PFLfFmPnByCOBTzEoOJ1c3DlSGZuD360PJuK+K/K56Z71aeKN4g1xO0gGSzAZHJrpELSFY0Xmt5SB0qCQkRlmbA524x9P1rqKIowYNkdCK3kjUDxrM9+EILSN0xTC08H+mLVy2Mnzj4g8Vmx+OzCGAR3YS6ZhErDcp60z1G1RtPnmMrbwFMcu7kPg5DfnRsPULxaLNdDEywh1Y75G6Y6VyrxjRLi4SRVVGXAK55YYIz8aBOB8tXURnDKTuILZ4PxFbaDYeLpXjCRVZeSMdRg9+1AcTWK4iTh03L+vrXDkQxlMHaDklTnArVPIzidiaKZEt3Dly2WYdv98190iES2eF3u7xK7IvxAYZ/GnS0HE78W5aJRJCDhPIB1wO5riRplkEY/dFTwDWBxAbiQv5ShBzyBTSxs2uZg0cglzlFdEMnI5wwHIPpj+KgOImjMinktjsx7U6u9LjiZ7VVIbYCHCNlT5cD0GBwxPOTWOTOIrS4VAEQMCDyfWtPszQ7WeMK5bPJzkZY5/OpuQ4m6AN5EJyR756VnEkpLYAVSOSO4qXHQBMdmWGPEDeuW4+lbwp90NgcZNHLRj7OLDalyowH29hW7pcAFUGVIxnb1rGuRinQ2WYELtZV5GQOv1pHHOY4kR1bIb39tRfjtjKtFA67o1m8TDYK5HpQKziS3VQu0ghQ3rmovA0+w5H65lyxPu4I+vxrBkkMuPug/nVYhJByHekzvNMoVSG4XJ6MKE02OUMHVcJnBOcZ+vakvFLGmtlXawfa5HMI8JXJAJ93kZNVHs1ptrd6a0dtEDdvgzFQcAfd3Huc5xXFUKS0zsSyaVLJbnZCJVGBuT+Ht+dWkFq2nRmEsu4jnIWpFHJ57Po9xaCR5rcRQlDgIQZEcjpuPAADZxVlrSpJYNE+7hOSFHHy+NasjRNz0eJa7bK186BC4TPAcYGDt78ZOO1XVzocPjLJbK0WGHisRw3/AHrtnyeMklJ5/NDPCEjePaxGcK3I9M1U+0dgseoSywxtIeg/Dn/qox+RyHU9CW2SRgCQxIY5TPw60VJE0dqGi/dbj5h/55rHe2KK7xzkrhevvDqK/TxGMEOdxB9K7cHwBRMW8205+FEuiknH15xXTNGCuPKht/IP5UYbSRk8XZ5SCRxnOKfl0akGww2xtVhRFaeYgxSl8BMfdYep7ULELu1UuYUMUhKgSHIcg5yB2xSDaCLOTAWIuI3QMpIGeD/+WKGupoZ5oXjWUuD53ZuWHcD4UBxC7ECWHc7qqoh6jGT60BGgiERZ3ZdhwiLknNa5MGPiJkeEVZXPB+HelaSyRN4RUBTkgn3vlScQ1sbzPGq5bacUpRyY3VywBBwabQrnTKqUxy6NagqcqWR8fPI/nS3TrjMDwMcxgRkfPzVqR2YX0cXEYBKqQQeAA3I+daTyEBi/JLlgfRgOR+H/AC0w1AFsrG8dtqkmV8UXYoPEG7vu/M0EWZzkxpgjaQeaY3FmzHyhXUkA/Cl4ktCZpGIAG3Bo82XIAU4Oc461qnsHIj1GQpbkcDewOBWusBWvoLfAVVOSAeP/ADTjYxlpmmyLYISzISpOQ3GKo9ZbR7Cwy18rybR+7RtxBI/Kk/TWILm5ZLcxFlMaAknPWkaLqOs6gLewtWIzu3LjOB863v8ARTfTZbZrh7u9Vmwf3cK9/Q0zj9mJbJA940d1J/VkGCfiF64rehDiHUlvrweDbKrFArRucr14PzppZabbxSfupFkmIyUMYy4/h97GPnzWGGkWkX89uklqmGkbfMyRgKiKuSRj0HWn/s7pt/eXCx2DyLMrAbpHO4ZPUBTxigCY1eBbNn2SLcAAZdTx8hnn51U+0ns5cW8LzGdHjVM7o0JbC8cnp6fGgUg32lQ+NpPXHSj5oVgXc8yyo/KEdG/7igBTJD4j/usE56LRsMJVlKFVBOcUuwE+xhG0aybVPUD+dFCIjKlQAeoP86vy2dsnWkz/AGeRsRq8gIwxXJHxr9o0ayXzLIp4HGPSoZJJZZGLmR3MzBioGFVunPUmtQqJcbS7eH3HqKkpOfR3bz8gogC4wT2r94ayMDsXAB3Y6/DNK8aBSaQ3rLIFY5YA4B9Kx+z71DqvqBhaR40OpGSX0ZXY52n4HilkkLMwUeYjv+lL6YYDlrpjbB4yEicEF1GaW28kkAMZ3FD0Hoa58nj67BAmpeBC4ZWeQZ949ia01CN28jHEOOAepJrMUmtIAju5D5fHwuem2sI7VhPygAzwSa6VPYjSPjDcNkjSF3ztLHj6UQ9sqxlQAxzk461XiKLUs3jnHiSKwB2+UZIzW8No7sESUAIc5ZeflQ1pAgowrFbDekuSo3EHA68UeZHFs4ysjKMAN0JpZrZQn2RljLxrIQrYIBzxRlrBdIrKVjVQS2372f8ASrTKDWwO3iedcxyqr7sMzHp6V8tzJFdyGOFip98BuKWtfhvrC5LXbbRKVAbnJxkGuDfC4td8C7lQhSYkZD064749aJ3oOGgS6j8J1kT3skflR9xLHtKEHcoL5ZeTyKdMpjADcyXMH2eQFtx7iutI2SatjzBTuJHxxTb6HZpcwT2VnJat4ZWQRzMOnRiP+qifaGKX7LHcFsthlIPbccisl7DiNPZCJZIpC+0h1OAGxiluiTSWsEMySEJsC5LdyaHJjkyvoS9/NZW8pCOGCtnACH1oG+nkNvd3bkb522qQfu96eBNFlo0EUNqr27Qshh8pyoBHT68ilFtqTabZqnirHvUEKV5+fPND+hxC9StZP6cFuiM0sh8yKON3f8qUaabye8a/1J5WjjAJYj3hnoB3+VMKeuaP/Q1tj7PaX128MRigmtVVnkbaN8jxszBcMNmVY5xzikF7rVzqIi02ERWsjq28IgXCf1QvOSP9/wAMwOSttdHUpIlZLOFz4jpGBubPopwceXI/DjNGNfjTtBj0u3uQI3ZUlt1tlSRsjcdzMc8dT8cUCsidQEcl1MlnvghAyFK4478/EY4qr1O1s4g8SMY9kQZ1LMxjOWyTnnqB8PielAn6QSLOrsZJG2jp8qaX+A2xpFVD04Vd1IAHG5LqUO70OK5ETpLtkITI8zE9qAGJuI1iCtvcH3gOPyoTTEY3AjkCuoYEkSbM88c9qRrRgWbWa5Sa4SJRHHjzKcgN1JIzxwc/WrP2W0s35CXkjtATlUiZufKfezwSOgI9aVUBEwxzozeIPMCFGDwc9xVxrns5dr4/2Ml7UtvXe/IJYDFOBN6VC21SI1lZmZcFOenp+tO9I0udoyJLKeG0dX8WZNvQHgnnp0P1oAzsYnF1JPFbFY9i74lKhAQfMT17fGmENjJp+oy2kYxGjhdrS8Ow65O34nio3ISWfsRcNBdTM7ySxyxkA79ij3eCvr1wvbrWFjALeCG6a38IhAAFAAPP5frXFcF5bQ1vnMpIDc898YFJNQ1CV1KY2qxzhF5qKjQ1Xs+XV9OJSluTIqsAcjAH+tCeHKIQfHaJSc7VHLfA1OtJmz8MLnUbiSbY8ab2P3Tjiuobf7QSRJgKehXJzU6qTBZqVsjSCYjLtyBtIx9e9E6naSl/DSNdmMkgc00UgJrUreZsSTSr0OAMcCir2NXIij8zKeW/Sqz0SqRVa2wlLF2bcGIVdvXim2n24SFvEKrg8CuicrRsz0Ts2myidgqM3f5VS/aERgiLGxLAFiufpXTGemaTsmlrDaR3CKzM652ge4c1TXUirF4Uj+UjIAXvTO6Al7mAC28Z7Zp0QkYJ6HNM76BJrdJAyw4PvE4zTK6YrJ3U7aPEd4IfDwyqVK+prTWXIijUD3HAC56c/rVFspHwChjL2sY2A7d27K9PSn2nW8UWmRSOVBK+YfAmtdgxLa2CI0hkQ7R69D8qeyW0ItjI1uzfwljx9KTn2YTEsBhEiupUsDtyvandzplxNiYHMe4jOM44qqoAPQ4BulDKpyochuxBOCKZaRaL9ueKZlUGIHOcZxTqui8fBYpU+LuXEkgJA+XevmoSql06oMEZAPqK1DOT9Zl/EGG5KnFcxsyQRuMN5m8xHTinRNyWGl2bSwo4RTE46nrjt+dZ6P7VabD7Kx210sy3UbnbsjDBvhu7UCrGG3MFlp0QllMZZFJUfH41IX+sNcrK8nh4DgpHEuAPiT3NIOoF14rT6tJfMRDBIcxBhlyo/wB8UDdXc19OIUj3SueNoz+Na6FfEPtNOudX1G3061QtNcOFGDk4JxkjtXo/7I9Pt9Bna/uSGvJUwjMudg74+NTdCPRS6Z7F2Hs3ouX8BiY8SIU3SOxH8XYfCrzStPs9Usnga5Z4p/ez1yfj2+VCFPHNb0iNE3QmZklbxACvIJ4x8q9N9q7P2V0ld1tq9ostuN/2Wa53Fscnn3vp0pt6QHko07ZGsiNjeccryDXqWl+ztrfQDVJZPGSXbNFEq+bBHOD9aT2BxFn7PdPli1BTFEUSBTs3HPmI97HarOT2ctljEcN3LbxztmRpSu8J2Ao9gOejyL251F79DHPPOxid5EdxgDPPAHB69ac+2fswgupE0qCaRYwMvNJksc9QBwBTc9k+J5n4HjK6IxJizkuvJyabR6dcSTNK21GjyxOe/TFH0OIpsLWUbZHRHKnoTtGKafZS0uHJ8Q9FGfL/AOaUOJNOiMFDkguMcHFZPI5tQ6OcbveA6GulncjTQlWPVJmZCwCruz0HPB/5aK9ibf7ZrLRFXXKDfiPJIBwTWPsjkkeXE9pHNaPPGrqr4lZCGAHqccgfLmub6BVmntZ8AA7FnU7Q4PY/Gk4EVIJdfZbfUZPszbrcXGyMqwxs5Kgd+mOtYS6PNDp80zyyTQuAIXBxhtpwM9+a3iapGEkfhxvPbSL4KoXdR14GaAtoxDpMiyzHxpWRZCBkoNx/n1/u1nEfj0d2pUEvM6xJ1yV3UTqlo1lDAxtfHadmVRKu0EAg/r/lpeJNmULiSRy+GRmOMNnjHXHagUneNN0yNtyQGjGQnwqfDa0J2EXky+D4KsNoOfNSmS5HiswRs+h9PWlXj6M7C18HYxmCcA7cUH4gdi0u5Q44O3pTrEHZqzq842RsuB1HQ1mbaWaCJkglcyZxt44HvH8aZYtApO44czb4ztXPNdW8jRjwLldsg6ZXjH+tSuRlISLY8M4UAngBvzrqNHA3sVZf7PapKTVJxPDCkRyVyfU0RDAJ5QxVVhPXK9adSx1IuNsQcQuEyOoXrTcpCC/itGUBAAIwaZSBP/0IkkMjk5CZJJQZNM7t3yViCxR94s549Pp1p0gELWkNtcIUUMXJ8PO7yHHT60ZqMW11EXuxDef4uOfwpkMhPCxstWHl6AlWH5iu79XNxFcY8qjzf2e35034UkY65Ko06JG24MhP9wcUFDGbkRW0jMylwm70Gc0qHM470nT3tsFmLEr8Bn/vWBhUOzhseGxAPrToQOlheSCDTiqeK7Biw6gep/zVv7LWs097LIvmGOaDCj0/TdIhgiE1rEx2EGWXD8/EHp8KOsILhkLi1jMKHBMnf5eX+rQIwGTRbjUNWtbOw8FDI5d3GAFI7gc98dhTr2S0/wAXVZZnkaHafBRduRu7/kKwUstN0Wx0C1doYRLcgNvkfPPrlhyPhiuQusSKdNaZWkISPxQvIB5AGOM+WlAlbjxYtQGoMPCkYZ3hFYLkEABW4OfjzTi5s7PVPaOPQtPR7r7GVmu5A/DOT5Y89iBzj6fdrdhqie1C2Nzch7SaSG2cjbBLkEbfMDhfK5O45Yd8D+GvSdQ0BtJ0eZ7f7Pa3ISRJPs8Y8RQS3OTlt3pzjNHIOLPM9PhsVuUW7hZ448hY5V2ZB6liCD0YdSKcRWVu7zxSHwyjDwyzK/i7iylmG5cYx8fdpWHET31tbyBwbFgGAKbWZ1Bz5j1OecVQ2mmqI4YrdZFvWkO1C4CtwvIxg9c9zSMOJM2mmyteTpPCqSx//TKnBYDGVPfj8KuZtFdwQY1aQsDMzsTtIX1Nc9bFcnP7P57KCQQx2bPK7kJIwydvofL69Keew9umnXEK+EynAABOCQVGcD9aaCkT0U2r6aHs5LiaylVlmVoQyeXPqSvQfOm1m083hGOcyDcRPC0eCB283b5d/QdaqO8ZE6nDC0iwXkqQxxNhlEfhyONwUL2ySRgnjjHA61Z6rpNtPseaJpmADxmf7pB4z+lAjjR5/ptjazXTT7FdzLuCYypHQE5wMjy9CapE0CWC9FyqzPMJC7hPdjxSOQSP13FE9qsc6lGRCCpXhSRzj5ittSSOO3MsSkzCPLKZMfWpUtIproiNWtRZMSiLkncMtnP07Vz7SziSHYsjL/EAOn171xt7Ec6AftgkdAyhvVQc4pLFOsKq+9nYLyD1IzUajYnLTKoXUCRfu0YHHmOykP22SSF0QlIseUFu3eovAWihhc3iAYVWHfOOtT817+7BLKwAIHNUjA/wWqC50iOZE95zk560nGpyKjJvwvXOPyq04L32T9h1qF4nlDyMVGRjaODSC6kkmmYKOp94tXbjwLXYewZSagjRBoSysDwwoCBVWN4nTc5B2/OqrFKM5bCUupDbq8jSMQMAluTzQpVI1CsWZuu4Dg/+KfijOOwie6naJBscKM8tQrS7xtLDA6YrVGjEtC/VDuAXduZDuxt6V+uEEjyEBidpAPpVE9D7GtjeLNZCOZ2XYGAx86TQhsNIo83AI9fjQ1LFKa1KSweDIzqoOVKjP1NIrWeRY2Xfy3AWk9aYFQYlNuwiZmwpJAHWl2mXsqqsQXjBHLY5reGjF9NJLeEXsLsG8EsUf4A9PzrWV3R2dwUPPA+fWsfSOzEKPaWGbckjIyqMgr6n/wAbf8NOPapC1ish2htjhAevLDB/DdTYizkk3kAtVKklkc9e3Fc3cBtZPDRtzBQrD0711EXINaeUSs7MIjzsbpn1rPcXjPGUB5HrQBjdXUaQlUwSTkYrXSbJ7y8OIWaFDkqFyKV9Im3oP9l7VoM3UiMJZOh9BTaKDwUCS4Mnceo/7VBvZF3scWdxNmNI2YqvcjvS2z1DZNjftUnHHSkciHp2i/0neWwt11QWyblwoOcnPSprSbovKlwHDCPDDA9PnzU3yHR6bpHslo1pMl1eKuoXR8xeYbgx+Xwr9ousR6jGF8IeRvePrikbodFZZzWaQopjVbfsWC8Y9B2FSl7LmbZ5mwc4ZeBS8g5FF7QXlvcQSWyu24jl9vT0xUy83kyTtTo24fyo5ByPt1/6aJjuAAGSO5pLqN47pJzuVjgNu7elMqFJ7XESRpXjhXaWUkJ1Jz1Na3Fs3gvLIrMiMMjd0FUVG6M7GNGI/wDTKFmYIWl4A7ZxRum21wrA58OBunxFPyN4niFgFkwsskjIcg4WjNKiKWuSgI3HcSPwFdVHQux9+ziGOX2wsbWRgplZo0bPAkC8EjuN2OKX+y1y1hrFnfRnzwTq4AO0HDA0roxye4ahoTX1i91NAba6i3brcgNInOAwHTGQRu75yOAa9D0lI7nxcHbMBuilVeXiYDC/EZAGPRRSOhOJ47FpsEV9p2gTOx07ULuBAYmyDD4gyCD0PmHX6VSe3Nh/QepafqE/EFrcGeJV4RpM7+3KHcBwQwPlyRWphxPK/bnTDpftB/Qas0qnUhHGpOSyhgBn8aY/tukOo+1FheW5aNr0JLEC4BHiHA+uV5+Kin5GOej57Y6bp51dLe2j8SOBlhlijIkJlZiSNy8H3enUVTn2cTTPZm3e0lkkQozTCVF3mVTk4zyv5Z+NYSI+R7gW97YjTzsupVIWU52lepz/AGscUc1nbQx2xWGZZIolYAPhGJ7/ADH/AE1qDRGTWdzEwmaKTaXYP+7OwHdx5u/yr0uHRIL8IVnJaNC7IY1Ep46Ahsn603Qujzu1WO3Bnnj3SqR4QIBViGAYY7cVfnQGXXbdIZoczB5HeSPfuUqMjvjryc/xcnpR0GiXjk8KOaJW8Jw5wFPmO09cc5I7dfpXp6+zOl3KPcwWhYh3LxQyglWHlYbTuGMc8496l5DcTyOaykvZ4JBbGJZSFDKNilvL5gccGrvXtHex0Jo0jjjidhJCwyPMFBYFtxUH3uw96sbWgUnn95hXWPftRXMbSKcgnCjbjuRyc06sEgl08agRGCsu+SLAwTlsFT3+NIuI2jO40z7AUkVi0M1sJQpT3AJHUp+WaY3F+1xFEs6gNaq8ZK/1zu/6T/iputBoA1BtNlkElsJg5HmHYHcaom9nkT2Vtri2hikklt4pCxXzplVby8Hpgjp3pF2BFXVnJ9mLQQvtQqM7e5Px5q40uKGa1VZoIoorpVfxQodEQ7T7uPu78kZHu9KosYHn9pZNcTBp0ZnBCxMevyar3T/Z3xPaGG1try3gJKzAupaMbWJfJ7gbVP8AW/Jd4gjzf2k05LS8NsR4cMsG5Sw4AwOn1/5apv2vaTJp2spK7uWlWRxG5wY2KBmQH08jgD40cSiIaEGO2NzhfECcebuSwLfhQrTh7QxR8MW4J/h7D8aUYxcAhYwvfJz3NfYQTKMkZBwSTjFC0gPXf2aaRYNpy242+M4UEllBLE4AUnqeOBXpvsF7IQaRBaTzSSLK6FXdXZUJDblDY4J90D+zS00/hhFe1Fsmg6bND+5VmkYEqqE8nofjS79q1wLnW00iILB4kw8UHjwUzwc981sSybKL9nGn+HpMV1dxokU5MrSP0I9Kx9nL/VfaeCeH2Lu7G1sLY+C17dQGSYvkEbEJwnBHLDPoB1pWYY+3Wu3UGsnRvZ+JjqV8kaxyEDKnBBIA5A68mrf2A9hbLRbmS/vJf6T1WU5ku5OrfLPAA9BTT8Ay9kfZ2bQNJ+wGEyxSRB9qF13u3vO7biXz04AAq8u1jaB43jVx2ArDSPl05rWESWcAGG8yIz7B8wzc/OmUfj6dctNCWZIjl1QeVvn8aQESF7CYrlpY7dY52UxxBmyob73GeM/9VMtUmhF+6KFkhlSOdEZ8YXLZ/wAtMPxB9Ni//mMccbujKcl4m4T1H1phJatFrzwKsio0odW2cMjEMOvK4z9axhxPz6cnjMJAyrs4J6hieT+HP96qGGxEg3Kdynn6iphxJ2PTGM7vxsGMELz9apRZtISiuVUenrQHE60WNo0Cseg836UVa25gOGLNxSjILwrjDAD0xX5SW8obaKBvwCubaLwgI5GiYZYtnFK/be8nt9O2Qxr+94Ln7v8A5rmzZVHwVkR7T6s0V1OsBjkOcbwuDn/p/WkOtqEjldDtkcZY7q4XmqhBHqt0GtzK0nXO750DehnLI6ZHBIPX502Lf6ToWWskkt26u++PGcegomG0MIYqpwTnlqv/AFZFmc1xNHcBE8iY4X1oO+Jjl3XADZPDE9BVJg3lR3PcNKMHduGdzevwoN5EI8hAHcirTjDkz65wpI8wI6VjcS7OSWxjg+tUUmnSw4fxevGcHtQpuwGAYYXHNOpAJW42uY/Kue5HIoZf3kmxGwSODu7UKTT9E253USqwRuc0LLvSTxAeQcFfWqKTUGTzARII1YlzyQvFZuEFk5RR4hUFWH5ijiaZlkw2W7eXH51+uUSERIfMSMknrn0o4gcysA25eOgA/Wv1pHK6ubh4wcHaB0A/1oA1t7eVvCJRl3AjdTDSlR7mOCWQqnigI3YA9TQA0tbQx27rsLyOBghc1U+ydpbzaqbe5kLQbcq0b7tx/Ss2Yp7J1rC4kuEgcSFpW2FSvIONwNUftA6xe0l1NEjPHCh8MFudxGBmpt7R2Ylomva91S8EagCFMkkdwCMY+vWkHtFfSeIyIWZudxYYI+Ge/wAfjiqYpK1Ql1CTdI4DZJ6H9KEYsWLeXdXRxOdvs2mUi3WBG5HP1rSHa0wH3TjdWM1fCk0Owhi07Hixx4HmLdTRENg8rO5jdshtqgcfOos56MrqBQoEcvjN6fCmFlZwtv8AHDBdpAwcc0GcSckR1kK7Cme4qubSVuLRpIQrRhjjJ5AA5oDj0I9EkkjKxIzOT1Xu3wotbULMYoiobcACnvVOjEeo+y1gz2lsQYowcS7C25s/P9KC9mZ2t7NxcFt/JCv3wRUaGHWoIbFmNxISpOcj+VLrnUJLnJeIKAfMHbj4GpqX+mGM+oRyjZLMI1Jw249fSk9zbSPO5V41UA78nIyemKfijUPY3tkkMeV2EDKsMg/KllszQIq5LYHZaQ1B8vhpiMRryeMdMUqmuJWLhd2w9cUv6UQYJsoYiVIAOCq/lSdHaM71zkHJ3GqI08riZl3r4e5gdiH5c0NLckXB8P3mGDXpsc6iuZILsOSdqsN4HUDvWMqNHNEVAbPOD3NJQH9iaBcLb6JpZ3Ee6hPcrg/6Us9nWnl01T40PgwRBU5zkhM/lXK3oNbHXtxHa6h7P3drcqsgkQgE9VYg4NRlpql9rNw3iyrHZ+JiNI+Qyg9SfT4VqszfE8RMwk1axuZ53lW1dAAeQAJM5H4kn+038VVH7UdA/oq7v0jUJEw3w7RjGXTP406sx9o9Z1LT21GwiMEUTTLCZi54JYeXOPgAv+Gnn7NXkutBtb+6BYXEAJQ/c8uB+Oad1okyR9lvZJPaD7U1zN5Yl8FkJxlx5z/mAr0HQ449K9nzMGUeM/lA6hFAUfyFTeUXRL+yECey+tRR6ufFspso0p4yegDfKnmp6tpuoMYb218SNGOCDkk4oWSTdEZ7TQfYvb6xt1CLC7SsmG3BVZB0xzz8f4qE9r4bi01jTdSM017BaOAJAcHbnC7vrx9Fp1cgpPQbKODT7dvDjBUlYmRTgkBAA3+EBPpSr+kFu4kkR1ZI3EbgdSuzJz8hisdIcC1m1JaZLje2k3EjJcKoBCsTgMPl3/s1Trb2sumXFnMEEUyYYnpkjikdoD+cNa0s+zntA9pDPIbN2YAj+DGU/L/lp9+1PTBaTCMu0rK5LybtxYEYHPcABfl5qpD5G8SJ0uKe+uFsYdzPcOMgdT5uCadfsweJfakvcJudbWQx/wBrBUf5WrbrSCZ7PUobJxFAtsSPCiCMg6sccH6DNZ2V1cSXLraBSzE5J+9x+lc81RRyFezdhZT6rNDcoQLaNRKoHJD7iM/XNG+x0olXWTMPAu/tKeIy98IP+9XmmQcoRe2GmT6F7aWeohNtkHRJBliY5CN6sGHADMQD/wDlVL7eiS70wpEIZC08J8Jh5WxIOvxrao2Ujyz9s4e4v1eXbuSdlDYz0ReK1/bxKIZLqSFEBi1IqYw3I3KCPpjNbFdFVKPEY4wI4yzZwo4HbrRrpBPE0kYZUADe932nNMaD2FuZ7qWFP/0yeevSvtmTBfHcWUcA/EGh/A1s/t72Xli1L2USXI2XEazIT2UgH+deSeyf7TrGw/Zi9pI7JqdvCI7ZWXiQH3W3f1R2/q1FdGcCE1sD2o/aVctLLtsZLsRZB/8AplxEn5AU6/Y37Nt7Ra59ok3CytAJpsr75z5I/kev92meTrRjjSPX9JsNO0WyTTdGsIbOFEGRGqjce5J7k1QmxhgTyqiKDxg4wAKi6JCpZltRuG4Y95fX4191C9gl2oJDlOuen0qbzaQHzUdSleD9yjK204IXvSu4vVVwYz37N1qf8imAsvL+8YyB5CwHugDn45oW7YSO+WC5OfM1HspmoXxTCXWLctgJtKqScA56D8WpRqzsjuchNrAgq351aKooeiyR21z7ZWux2BDtIQTwCqKtSeh61I+ri4kiBZIfDck5y24DP4LWtsD1mGWOSZ0jKsQQKmdOkdrdpDhU3eMqA7dpHH50utG8itWMBizD3aGstThmjU4zLkLIpdVI+PxoVAqN2Vi+d3UcURHNHJtZGViM+63IrXQxlgMQpBJxyBWWozYspgnkbZw2Oam70YxH7Z3iroF8kSx3HhH96Afd4/nUnr7mCyn8OSSbOQ7Fsl857dq5MuTkI6Im6u7aQOVjdfKcsX77ulIk3Ssd+9ZAeAW6DBqCnYmzp5YklaUtgHgEtyfhS278SPeXZWPx64qkTsQ3N6lwmRuzzn5VMCaRJWdU3Kcg5bkV1Th2Ib61Jm6Cbjtx96hLieV25IZB2POKtMaF4g8kohzt25I5rh4jKcqMfGrL4HE4aUsCD0xnitorZ8FivkjHvfGnRqkxh8zYZX5Pf0oqS3eMRSxRnbIeSelMh1J8tkZZ/CkO1x5k+VfbhQI2RjuMYLBl6CgZSa6jbR28gKuz+KoLDPfJoa4nL2sPdwzbiPXHFA/ENu1WDSop/EZWA5Hwy1ZXB8S0TA3RrDhseu6gziH+zml/0jMbm+bhlz+HStfZg28k6xX006KqkRhOQCemR6UBxPujaLc3N3fQQDKRXHhtuHxJ4qj0fSvF02+kWZhi68R/JjIw1BggbTZreVhMoDI2GBP4VSjStSurm4eKFRG5Iff3B5yPjWP4L9DPZeOztZ0vJInjZgfClyqjOOw7/Os44ozbrEh8SRlAGU2ncDyMZ9O9SdcSsY+wfWWcC/1ER7Q7iJMnylh1b51+9rphbxRWrOpER8gxwMjp8+lKnyZ0zGkQWuDM75Ibc/Oa71JkkuHkBULjlf1rrxisTeEY5F2qvNdSY8ckNwowKdkWH6dDGbSaVlU+cBAKYxW3h+z8bPuHir4ucZz2X8qRmnpXsXottqKtBcz+DGkflcr5c56fPilXsH7V2WnxP9vBPiJujwm4rLjBHwyKi/pjP2o2Yj1g2sK+MYZyML1PI/7069hkfU9ei1bUIWS1Zy6tjCuVORn4isdClTHbNM/9HX1tDaW0m08IOeOp+NPr/XrEWrYiWZww3Nt9eQPyqLoCSj9moJdYligt1ZseWRgcAetVttriGMNGsUcePM7IP3Y7D8aXmZxJbX9OtLPbCqvDMF8xkK71+f6VQa/Yw6xA96rqkrj94pGDke79DRyMc9Hm9/uWQRKFXPQsMbqeR6NcahdxWcxVIRncyjdgnkGmVToVAeni3ubQxSbUkI4Yrg475Pf4UffKtpG4dI8KCzmI5B7ZJ9fhU6pDIWTho48W8m4KeS3Q/Kgp9QZyyQNlWGCMUrYBYmMXmZV3Ec5oNJZNqNJHnAwDik5dga3E6SEDYmT6LQN04OGjbDDORnFUQx4vAQt3HvLe8AfiMV3IBvbHUbT+VeryHYUzg3EIJwA4wPhmsFmClGZc4IOK19oVUeu+xWv3Fx7JzaWZGeaV/BU+kY6/lUn+y+6nluLyMFQFG4D03cVyZMY/Lo9W0m5WFI/3mFhwCAO9AWEvjTLASVQPgketRVcRdcj7+2G9W90+2KsrMI2jDBORjaeaS+3oQRxQh2blhn606rYb4npP7PtStz+zuzsWOyVohsbdjbz0+tQ3sbfTLoloisqqikc9+WrHyYnI9C1a8nZhDu/cooEabvdQcf6VJNqDDJZimDyR3pHjbDY6+0YYMTjB/i6VMSai7Ftm7GevrWcDBxf6mwtpw4zu8oGe3rSa4fxLQyt5WccH1rZjQBHs7rMtgsqzRF1cggD0xSRBLJGGK7VYkZxVX2ZyPQ4deN0QuGiYsQUK/Dg1F2zyvJuZm4wNxbPA7Y7VCo62Cex17c28V1o3iEszwAr7vYDI/LdWF8ZItGvIiqhfAJxu+HWjFReEeY+yrbPaSNUfkBgG9Mqa++zfh/8AzRBlcgycj6Vaq6Na0eq2UCxabEHjkEzneCF93FOLcRLpUbHcxzhNw4A7ioTklGN7BPZ37QvtDqsSgJay+HKoPc7AK5aS3+0vOigEoBvHzq050ibnYy1q4aNcyKrwptdeM4YHPSgr+V5LJo0HvDp+tJWbbKRGjz79vMq3epysh2LK0ZY597CYzjtjdU57cXrahdq7biADk+hwB/rXTiraNfRJWisY3ijTGAfKe3/mvsQKXE0e7BK+UjuaoAw9l9OOte0S2aRbllABAALAd8Z4z86K/Z1LPa65Dc2pKSoxIwM7gF5BrH8AL9qrOGz1ifTrWOSNISF2NnI4XIPbn4UaDJrXtozXSAST3ZVyqY53DP5VN10DPaP2WmTQPZW2hSJBLKPGnI++x/7UPbM7MsSbiB5VPyFcV099CMsdQ1T7VCB4fhlhkkVOTTAQuJJACBgkHBrOTf0lxBtYm25RJthJ6Hr86VyzbZiizBgOm45NZpApNZJ3VlxOrrjnPWl93MFZirMFIyfLnpTzA5pPcpHl2Xdz1zQ8aNMu7O5TTcQFmusjt4kM25SRny9PhWvtGsKlfDG3OMn1NUidGoN9i/BuNTlt5WbZgZAXr8Ky9jLpLe/8VkVt/FJddDr4egXX2a3RYgGVzgMD+VK9T1ETymTndgYUfCudOhTia5dZQVcqucDDUoupij+UHAOdx7H0p1tiFh7NamsbulwzEOODuqf0ffJC8jLjAznd1rG9Gj7WdRllfOcIEAUnvzSmZz46wtt24zwaRp0BlqEomhcAEHuSMA/KgtYLLI8JlYJIMhgPyqXrYE/rdiRZkwonLZBxkg1jcXphc8vNzxnoMULGzCYvg8D7JYldieCOtNIp3Nxlo9wGSFC10TGhSWaCRi4ZQjPnAK54qrumjlkbEBjOOSO9WT0BGSWLRHnPTv0+lPp4UlcABclh/s0yDiTwtWRd4weepp/9ieRVljTesh2+VuMinXwxz0A2UKxhxL5sxhghXj6/CmFrCD48d1uwFUsU6lScE/SqwKgG9jWdXn+zLErZeFAvKbjkDr0wSv0ra+Rkt7aIKzKiDljkkZ44pmOhXNaS2kgeNWLYwysMBx0/SndjatIioVwBwOM4z8O1YMiSmVfsoI3mIIWiY9VPcfLt/dpl7QRfZtUext1VlkcyBf4SSAfxO2gdAywt/wDL+CuGdlIJPXhqJvhi2t4N2wn3T/FjgfiWJ+lY60HEL0eK4gWFTGCwG2PxF7Dk4r0G00RJNOT3hLEpBHywc0nt/A4i72em2RXu47NxjUhBznYa/WxNhLqCCXa6kYPoaZVpB6ypguFjnMngRhWIBARdp47frQ1vYlbRJYpdqGIrIr/AdRUKzdhw0LYIVuvakW8jLC6lm2KPJ8DxxmlkN+66nc2yspDINrf4c/lipt7OrET/ALZytHqlzMx6HYny7mkfthcPc3Uy7sDcQW+tduGOgsTm4UMQpy3Iz86HtolfzYY87VB9O5q/HRBm2n20l7eRRIuTM4XP1xTz9n8STe01ojbFUsUORwQQwparSE/Ss9qbaKPTIIIwsaRIzIv8SgKo/LNNfb2FhpsUo2+DkouDg5wPyqM0aSnsNY217rEdte7WRQXVW6H4GsvZeVotWhlUM204IU9aW30Y/h6vcIkVwbeCULGECKg91cc0DBepLax8GOTP3gTxXK6E4jSXyRjcMvuPI78UBIW8IFbhHXPA+NJyDia4+zssitsXPKp7pP8ArS+7aV2wrMy45J6Z9KDEUthrhht/DVdqI3KIOWqRSfYu4nBB55oHXw9Dh1GCO2c2rKiOxEgZclcipLSrttk0TOzqRkp6N3P4UKpMMNQtYZLpihYl2OWCnFGvk7thJU4yA3Q0cpATSaa6KSHXcORmurgtFOUbBz0x1+tUXaMQt8QiRoFUlR0Jbn4/SubgHxtxOUkB5+PpU3j7HQDO2G8PeynBJzXMUYNwEd0KMcAn75q0ToOJ5XOu2R129SDx/Zoq/wDLdS8dT+ld8V0NU9gLJvTaUwnqeuaKhj/er8SDVEYpKr9l8J/pySCPcVmTap/zH+VDew+of0f7aWZDMAHUKA3GSRn/AC5rkztqWxuJ7HHYPbWpdoysadWPevt/rMlxanyng+XB71438mm+ykSSXtY7O4Vmym44Hp5hQepx3d4hZF4A6H1zXRjzL9EqRx7K3McGlBZXUFLhsAj+IZ/1pLplvqEMynYGTIyp3VV5J/3YijZTXF5FIGKKrfEnFa2T2s+yH7JtlOASV4qL82Y/B/TtC4SmWT96xKgde3ypxLa2akq0gUnqB3pP/wBGBfRQimOLYAyAnb5QO3NUNtZ2U6IAw2jjzetC/wCShAvHpk0GQLGrS5VeuWxzVRcaPbwOhMSPEAfJGN/4im//AEYr4hv47X0T2sUWAHKE5yArSZIpzDe6HA6fuoDLkcuGTBrH5O10gWOUK9cu2g0O4yozKvhAAnIYAZzn4Uu9rryG6doLPw4VEhLJvyF+NPhycjX/AEIyG8+xaxDeFS2JOQO4rZtNSY7ZXXduyGAzXU31oR1s9S066nuLNXWRER1BCnr9agIrm7SBbZL1gqdEBI2VzPF/jF5HoccMphyLpTknIA6VBwarqcS7Vunbcc1N4r/GHI9ChhvMbJZVES+6cZzUVba9qIyr3DPjoKn6sifY8Xskvbj9xfXR+6s0gDYxzuFZe1zG41GTe2fEJkI/iLnr9K9PAmkM+ydjYOy3CjDYIzjrWqIQjJ/CpxXZPwkx17AN4WpO7eVRllKnp6k1n7OyiDWBgYJYMCfQ8GpUUn4PPZslPbS2Z/NuuWz9ScGh4o5NL9obZEyzxSjZt9CNw/JjU74uQ+nrD6gkKFON2eKBtNSTKRo6NIDsAc5J4yfwrgWVS2Z69oKkvhJECCqHPJHSv1pcpMdkOzchKsjJ6c8UvuQvqZm1yrB1CAK452jrWgihlRXMcO3GGRV5Xn9az3yb6mBzmP7PjxBtHB3H17VveLHDbnIiZCnlK9R8KrHkyw9TR8spI/sZAKgE8EClb3DpGEAZCTwc9RWvNJvFoG9onRogML5GVM/IE0NdQ3XiyeKfEQDIb9KpGaWZxNfZqT/1fhs3fjNBW0cm5TGh3A9hzS1UsOBdXQaPbJKEVnHBHelmm2OoXMSs8riLoQ0pTH0qLyQg9dBUiwSsFmKAYzhTgmtx7Psf+ENwA5PiqcGkfkQg9dG0WIspGiJuAIVzkkV+/oNkADXaquOp7Gj+RH+h62czTs20m5CkA8r2r9DobyKwF6m4HgDuPWs/kQl9Dg0ZXRWeAia53AEbmXqD2owaCqncZiwYcnFJ/MgOGyU1DSZPBa4V0OTwd3LCq6PQrUcPM7jOcbqP5kI31EPp2nSm8GYYz6DdVpNY6daupEMjNg4IGeaxebD+G+slb2zliYs1uI88dcg/Km0+GufDnkkjiJ4wlUnyEzPWTC2oWRJQCOfMB1xTm6toopJmUuI5FGxj3bPP5V0TnX4CxC25tp0sVZCyiVdw2+gPb9aoYZlfSLCFowEMMoGT7pzj9KHmpsb1aQj1bRRbWtrdCUL9plVQu3k+7midUvhdTabaOuI7Zw2fXyin9jJ8ULvbm0t4pH2HHlLhfXdyaD9rrr7ZeA4VsLhcnpWrIzOKGIsoo4rI20zM1yh8UhsbePSqrRLCBrS1lwvuqCq+u3rSVn0UWLZ5h7VxG01a1d2VpZoDGWIwQTwT+FGftSSwg1y3GTuQHGPd29s/HNdOKuSJ1/VieGNbv2gsoijADD7Sc4wT/OvvsnITqL3QXKopC7+hNFjS9nruinHEyhomDDI9PSl2laxa22mQtOg8uchV71zP6VU9E1rSp/8AMGoWkMYXdPEo3D0VjQ97qSye0pnj2IkzkkscYK8CqrfDomz0W5TZCYCsQZIWV1I4VAMnjvlqm/afVHhgnjhb97dbY41JyXDDk/Ieb/DXHHN0VhbIe+uWVpJo0EbuzTHyYBB4H5Zr5rjJI03jJuWMBAQ3B9RXdjkso0iYmZrm4cHbkpn3aBF4YpTjJI3bQD73/iu6JIU+zpWCRyeqHaMfGgWkkMb75WyGz/a/8VnHVEmei/sbtopvaF5wodYocru9W4H5UX+wmOQ6xeyRlVVYlyp6k1DyK0jYKL9qlyv7qxhc7Yg0j5PAJOAB9A1JP2mSKutSRwPv3tuds+8cbAPwFQx0bYp9l/8A+5qfB37hnb6117FzLFrtu5OQVJx6EU2StSwhbZ6V7P6dPBDPHdRhWyCinzJg/HsfhRMd7a3CBTcqwA/i6GvIyZaLqJCjYwuwYpCpHWhvGtkk80/GOOah7qDhJ+u9L0+WaNpZgpxjCtgV0s1oVJe7XAPFHvoOEnxdN0pW3M+AwwDjOaJtzZTjCXSZ+AzQ89BwkxSGwh88UUzkdCwwKNWGIdJdwqfuoPUJ7x5pHxGm1e4p3siAA3fhR76QepEdc6dNK6qiMAT1b1+FWRWJl27h/epl5loX0I89u9PvURl8NmUAZIb41emOMHBEZHrTr/kLN9CPPINOusjb5DKo5Enm35r0RUhDbyiFh0OOlD/5Chlh0fzRqyJ9vl/hLMD88191lXj1S5iY5YSlWP8AeJx9K+lxPolc9mMIHijb2FfoiGlCEEs3IGKuTZ9hdoNUiuIzhvFRlPxBFZz8XiBSy5YHJ7EdqnlTcNIXej+h9O0ma80mDeqldihR+ZNJNI9rjbWMUAlYqkahRjvXx+fxs/Lo6Yyz+lTaez9vFlH8MA9j60ni9r1bcjbVJHBPepvxvJ0M8uMohp1lBCwVY1Xv8TUpce0iklRJuPUgdqpHhZ3+ivLCKVrCwIZikeQQRmoK61+8eUgTZQdAO1dE/wDH5mvor8mEXL21mhL7I2wOir0rz6TU7iUc3D47gnrTz/x2T9EflL8Kq/1u0ix9niSYpkFSOAajzcCQ4xvXv86sv+Pme2I/Jp/Bjf65fS5MT+AvdYzgYoaO0ikQPI7KO2P5U84ca+Im6t/WAyxTXkxPJJGcnvTO0SMMxXdEwHBH86spaXSF4/8A0V/YpgwQHHr8qfwSvHJ4sZDNj3h1PzpXzXxDKEIRp06HKosg7gdqpxq5V5PFG0Fdqkd/Wkfu/wAHUJE+dLmXJW2O7Ixn402utZO5gq5Y4Gd+OKVzmDjAJDos0luSAd3cAU+sdYt4lESSQtIuCzhwR8vnScc+wUwJh7NzmLLlVB6560fqOvW8du6sqIoXbgtwSOeKaYz0+x0oXw809qgkevyqvuxZ83xApfq98txrM8pRSruePUYr1MEuZ7MddAUVwPEVhuPiOwzj4VgjYiRwCy7jjA6VcRDFHxJbTofOMAfPFcWgaa3GAwIPesrpFE9Fzollc6haeO8HiNHIviefH7sHA5o/2V1BLaKJWZkLTKhK98EmvH8m6/C+NTZUWWgQKTBchN8i4jz1DnjGTyelaWWoQNJFFOGMjBpVJ7ivO9mQq4lHUPs+iO/hgSBR5gaYw6ipSSNvFZm6FT970/CkebIZ64MIdDiTzCNyw99V6fCmMl0jbUtldm24cAc/WpvNkYeqUAtYxRhkW2Rlxlgzc1lPDfySKVfCoep/lQrf6w4n6bTpbnY0drbNxkKr84Fflhv45IzFPlkOCPTNPzWvocTi40S9K7I7RASOTvP4U3tP6UyDJOcBBjBpfZS/RfWITpep2IKW9shzglgmcH51UTw310SUnABJyo6EgfzrV5DT+g8ZFFdVaTY5myMlc9AO9U95FfwvmKFXbbgnbTe/YnFiKG81ZLUxxzycH3gPyo8zajA+xLBnXO4ER/jRzM4i8x61eQKSzjYerHFGXXtHFCuyS2dGHUYxzWrJX+DcEKV0/WoWMqSnaDk4bmmSe1GnCUxyEwMMZJ5FOrp/hihGSXWrRIqPFK5J6ndRtpqlleY8G7QkHqGpW3+ofiLbzUr+JsSxPE2MhCrc05e4t42WRmDcEblatly18DiLLfXQEHimRW7jYa4uPaO0gYpGm9ueT0oUz/gh3P7QwqvkUsfilKX16/u2CwrGrjPCr1FOscv8FPms6y95AqTR7FQ+Uisnt9Q1EbppvEdUGADjHwq8VGMlfL8BzqtxHZR2UQDRltxzu7802tNBYAS3kbiHbgktxWvy4Fn2E28lzIjR7d2D0C9Kspb3SrOHZEFZkXqyYAHrnvWrym/iH9b/AFkG1tM84Vo8buc1S3+rRTMFRUyBlTswM06zW/wPWv8AQLT9Wv7eGGzlkVbdCQHxjFB3GqTTsAsMaKMqSx4z6it26fYyVSia9uLqS91R5WO6JSFHOcn1r9rVtcyTB4wkik5IC8AiuzFUronU0+xx7Hi22fvPCLmYBgxzg7eKUaZYXC3bxu6253Z8wyDWZdP4zJ5F01tB400L7WOQmEGAB1qdtjd2odxI8o6sMZBA+HauThX3ZRcjnVvAW6UqgKo4CHHxr5qo8VjIoVVOHVS2OnWuqP8AqapP17NBHfi+kSTwbYByQvQkN/v/AP2oTVbqP+i5xJHGWZNo+BwOfxyfrVMKKKRdrUqLprFHZpCN8vmzsOeRjtnaaXalkW7lwSXBY7uuSxAz+n9muqY0axLGgMxJ6A5GK0JWP9394EZqy6RB/TGNF86SjKk8g9a0Mf74YZsE5rfiA9P/AGJCO2tNQuZQ25mEYPy5A/OsNDzp2jRwofClxvkb1FebmvdaDegb2wmE16ku/fIz8H+Lj9KV63h0JRt3A83qc1TGuIvPZp7Mkf01aRk7S7Op+tKrSS4S7jMU2x1GVI7HtT3DqWb/APT1iOyAACEE+oqa0n2luYo0jkj8ZgOXPrXnvxrN9iKJtLeVvMZmx6HihLP2qx//AFMeZcrjY3bHeo/xrBZEwiTRpBHnLKuehrQ+10fI8BgAORuHP+WhYrX4a2gEQ31mCY2bbnjBre69poLiJlaDZyMNmnma/UI2kfE16eHCvkNjqe9IL66DnDLkseD8KssMv6K81FAvtP5CC3I61Ib8ZCjv19KdeLiYnuotIfaiIck4+NRqO4IxHk9jQ/DxDe+y3HtQkgAA4B61FCV1G3Z5Scmp/wALECz2Xn/zJbqAWXdk9d1QrzyAAqjYHXFK/BxG++yFvSfHfeChLcgndjP+tH6vFBNvZPEjaH92qvjcAo5x8DXqxXRekKpiYyHU5CE7j/VyM1zPuSCIp5iwCgA8nmqomzq5kJmQ9GHnB9Wy36ULGwkMcARg4ycY6U/WhNbLvSLoyWquvQYz86D0lHSysJVErZi2yYGejMMZ/AfSue5liXA5ExLZxn4etc3ItooTLJLJGSXRUEanzDkZJYEfgalLldGKNI0F4wlBjj244I20sjugG8m3cTgHd0qqiRBvK6FxuTzHml8gWG7mtoJvGVGID7Nm4Zzu29tx798UcZDQeGVTu2tQyO558RTxjHpWaMDl2ryp29yKCyxZgWXBxmt0YHO5Rd3iMGPSl08jscg7iRj6VnBGjCKY4GW55passpXc3utxRpIENPtz4fylXxgkevalc3iI/mGGOCDWcpNDmvXUt7xxjaSenrSt5Dnb1J5Jo5SAza4kGG6fD9aWkzMQw4DKcH1pOSG+hn2tkkYI2wMN5PqTxS6LcUdn6jrQmg9Z+1WWe5wrTNJGTkD4isZMqd6rjDgZxn7tNyMSaE9/F9lYYdWZj5crkAdxn/FRklmzFihLxtu3oww456itVD76FMKmJWDRsWKeVgeAT344pobSXY5bKom1FV9u45G7J/X4sK10YDRGVEVSTnOdxHFGmCQ2wmZMkDJAK9AFpG/w0Jsb/wAKRQHL4JDIegBHUVg9oyMjqVaMttUfxdz+FSrCn9NVUinOusSTuJfadwPbjip1bWbjAUEg8fCovxoY/upFXZe0UnimSSTCoASMZ57/AJ4qVeF45G2sFXHIPc1KvEh/AWe/09P0bXx4zAu8YLKikHjy/H9KgLS4urcIEc7SCRk8A/CuWvBb+FJz/wCns1trLq/gZURgMSduc89a8tj1i7hLKzM2QDt6/WuS/ApF/wCRJ6curqZ35wxQljhRnA4rzv8ApfJL+6JAARnp8aVeG9B/IR6Jb+0YjQd9rAZzmvPrW8uZgQpYNgbk/hGKT+HoX+S/xHp1v7TwA4DBlJwoC9TXnsbaod42MrIQQ23tSfx9B77/AMLub2oG0qJNy4GQfvDP6V57cJqazuiqzYGVIXqO9H8cPdf6j0G110iLbI+1hnaPhXnSald2koW4jZWPHnHGKPQ0Czb/AA9AvprG8WRJI02kcYHbuaj01ZQ3EiKQOR2OaThaH5p/TTVdERxxmWPBIKeU49PjQsOtzx3KvI+5U90r0+VdEVaNlQzjTvZmZ5OXkhcncmHUHB46VTPDBqkKXYLxOy7zIrYfnj8Kp7mX9SFknslqxtd8d/tYHu24kfH0qi0eVLG1kAkmkZuhm8y5o9zD1IjrT2fvXuGW5dUdJMhCud3xqovL+8RTI1wpRfKxCbRxyAKOdMk8SBLaCK0dDbRxucAygnDBgOPpSm6vFkWVBOC5YMyn7gpliqmUjFKRVy6ybaOSN1USIBuZTkDPSvPbzUZXvIozIB5DkK2EPp9avPhL9BzBbDWbWeN4nnbwSxVyy+/kd/0rzgXe1Q3hyLApA4XOwMMn8sVefCxrsTjDKPWZo7ifyuVV2cKx6YHpU4b+R7bxnclnYmMd2YnGMVRYNG+iPwMkijhZw4YA99vX40Bd30e4biJAEGQDkNzzz6j0qijRjw9dBskSxB4sg71yCwoCS5eZEePc/iKPDA6kBefwreJHg0FRTjbmVWwefKcA54oG4uf3bh4uEIBY9M+nzo4h2g9JHyDGcOEABzllbPXp0pa9yhtYwMs2OMfeGWx+W6t4yGxmt073S5HnyT16gDk0tEsbIzSMzOFDq2cDkkM2Picf4qOKDkb3lxGSREo5bjHr/vbX3TYFnuGluEYxjGCidaB4jmK7xZJTFakMPMWJHyrTV7yF7mQW4JyxUBu3FdGMZ4+Ig1e5R5ZJYCW2PtIYdFA4P40DqTK9x4cZGWPAHf1roRy5GcxSh1Z5VVm7GucKs5IfKgDccdKdElR3G4N1HvJXzDp6ZrOF0lm3naqsCAc4ofaA9BN74kAgDsckYJ9MVO2l41raxyllYny4xuyK4smPbD6M9Tljx4WxenJIrBri3aO3CFXeUgStg+QFj8a2YaKREmUUEi4yqqFOW56+lZrNKbZ5DIiiMoGUtywq22kLUIOR5Mnwgenmx6URaxTrDHOoiVZFJj2nzbP/ADUtiODKPxN4J3ZHSjLd2iYOHVXwctt5pHQhkgdiSGbI60XDKDI7+KhYkZZqR5NDcTAQz4O1vdpuWzcNhkbGI8qeDjmovMHHYtjhlctIpZmGPpT5ljCF9qhY5PMBU/fo1YhKImZmLHcwIq/isbeeV3EYP7oEKPl1qb8vQyxEQLSaTd5W5xiry302NJGREyoY7geo4qT87/RvUec+E29lzjBwQfWr6XRYWciKLAJyc+tUnzo0HqIT7JNuBHQCvQ7TRYDJ50JJ6gVC/wDkF+AsOzw2+eF4pGiZ8DynPrimOuXFvqCuEeZ/sphhG91I2uNxHw8znAx0zzXvY7RVfCeso0huLO6kLh4pA5G5hgg5B8vP4c+lG6vbx28xRyQd5DBT0yTiquhDLXLS3tNelEUwneVfGMiOxALHDDzLuzuU1+1G2d7dbtZGZhKEXd2UeYf5QanVdGr6U1ncqbG1tfszSLE7gAIxIAKsTkc96+afcW1roGpPaT+I010YYpFGdoZMOP8ANUfdx+hWNV8D7HU7L+j50CBhIShWVc4PTj/eaITRray0NbyOTH7tzhhv8V43Tz47c5H92oPJN0asbSE+miK31Bbjda3dtDIQysMqw6Ywec4IplYzWYhuMjdJPE7ynGDkeIV/vEHJ+CiuhZ6X9SfrRhbx2l5ezPZx+GhySjPkt8vQfCv2iRH7BvYbFIVQF64LdaheSo6/0zg9Bd1acjwx4cb43KG6H1r9v33RV1YbnOxy3UDdmpq7QnHZzLbhZJF8XcQE6tz0rBARNld2ZTt69QvLfnTe60g9Ic1nHFdRRyBmjCHIB+n61xG6iJZERiASvAyWPoPjU35N6MWM+QWiSSSFVJgjyefh2piHKhLOPazY3SkL5QPQfH1qX8i/0dYxatsZnkZQWjAxx2+FO7UQ2ahsFWIOcUj8pz8D1k9d6eyTqqoVVRkg04vb6KdCRAykHh6pPkXSD1ipoFAdFG5cZX4etb3HibUIXYGYg/Hih5Kp9hriKhCRcSx+Zdw4IoxYSVEgztQ4GTx8PyzVceVSDnYqijcopCgKFCnHXp1NO7OzzcF5GAUsXCHpyMZFFeToxSACzJtkLsMpHjjuP9rVXZWCS26RNjCkKuRxwc1zvzdMbh0TUFpEl5HvX3GwUPXI5FUUenRJevE8jbigkUfeJO0cfCtfngsZOxWckcTruPiHcVUjjdvOPz/LFOteso7Np4sZw7JkdQcpzVcfk8huGkT5gQWAxtZmdsBW+7j/AFoe9MyvgFsAcHb681fn/wDSbqUFwiNNgbaVcjg9QaWymZYwXG4NxyOaORJ5EGsltvGV8ueFz39aDiSVJ/Dbjy7iCOSe/wCVG6BWhlDAp3TSlsEbwMdQeKBkm3HZH7oHOeCB/wCMVu6H5oZWyQhlkYsclQTj3hj9KXGSUMiRuW3kdaVoFUoaJHE0fjks3mLhc44HloI3EiwqsZKsQCoB64NI5HWaUUWnTLaBUaYmRlKc9+4P16VPi9dlBjkYKUCsfhnp+NRc7HXkpfEegPqSpbtNI5DLGAY2XzEf6VDJcmVfCGSQOCG6VF4u9jrzH/hWyarCYwhJMisVOPlkCpKe0upUa4UjeeAoHJ+dHCWH8pv6Usl3bXuGwvhfeVvUVIrcyWd0BdllTHug4wfWh4VraCcsth2qt9gBkhBaIZwe4P8ApXVrqVjcgiUpjG11cdaIxv8AUNUp/AHTNQZZhJKrkAjyqv5040aP2dtZPEnmZgTnaAWA+XpTPGv8GjE/o70qe4uLf/06OQOxGMUdZ+12kWcXh2Fq0KD3WK8t6mpfx7fxHT0vrGFlpF7NbJ9qLKu5iE3fDrSm/wDbhZfLFC3wLHFZ/Ey/4Z7IS+jS601LcP8AbLrcu44iRl6Y71Daprl9qKFGY7SchRVo8K39J1lT+BXtNqFtbCRIB4bOhTanBwR3Pep+/iiuVDL+6ZR5lLcsa6seDh9IOqYDLfyO0e5xLIilQWGMD0z3oOS1dJSsZbnmuj+pP+wQlyS7AS7iRjDNgP8A74rEQlV83LdzRuUC5B8EoeN0Q7VUbdhbhAQucfOv0VspIuXTAZcMfU9qR2OstSfLaNmuB7zhNxXAy5OOmfSmWkwxPNCSBgFkAPfA/wDxpHkH9jaBocNA6mVdwXjaFO2T4Y+XOPrTDT7OJ0eONdsvis2T0PwpOYLIKNkkjRS3M5EYTggLtUk4yfjW+oGW1t4wsSuGj2zKB8fXtR7B+fQNPYy2kBjLKbiKVknjDLhADhefvZww+GKYLBHcW08QSSFABGN5ySnYH48Lj45rfaJ/UXzvbMIxBGXbacKPXv8Azoq1sZXjBykJVJN57rg+79Dg1qyh0frK5S008CJWcTxHLM/ur6fj+tb6faNFpzxyyhGW5DRlTgBu6n4Hp9K15SkdCS+LJdtLP7pXj5Uz1YC916Rg0rNkvv3ZbbkAEH4Gq48xlZDzq5mJ1FZiMFicH4Uxl08/awrlpgcB1Q4DE9MHjJ+ldXtRy3Wzm+TfAZEYqTkggfDP60wbT31KxIs2XagHikt1JOMj59DR7UYp6AZ7KW0SyBeNmnXO3PKCm0en3rWNlIDEwVpoxuf+Arx/nrHmM4gyW7xLFeSqrQmTee+zHOPrmmkNvdtpDosat4jxRCMdMsj9P8NTeYOJhDHdSXMtxOQ7sCxZGxuAPAOOMU3s7AhSzK8wWNYgxHvAOCAP8tcuTyJX6bxozuLO0ilOPCCZOCF3EHOP1pm2kSNazzQwuCpLhW64LEGprzJX6CmhFqMskcSWA8IpCWIKxlct5h25zgj8Kpr7RzLCdSVWeOQnxYR14Xv/AHsf5qdebGhnNE/YmR/ERnCMibF3AgqQMgcc8/GnllpAuYIZizsvjR5yuSQVzhvlUq8yNicWJZPHV5FeTylxnByKe6fp4W4dTHGQULkHr5+lY/KgOIAMDVN1vM7KCJCxOCDj+VOLXSbiJjD+6YFvMvcKFyfyqf8AKhhxAbO5d5WIfC5UMD169aYafp8x8WFYEMecuSuaz2wzUNNG1F0cpMzKREcH+rlqEt7K5jk8CXbvEXL+g3LXNkcP4Oiltbze7oCMsrSAnPc4rHT4Solkyp2IBn18v/41yMfYZHdslq7upIHUivkBSNI4cBhI6BgehAGaRLs1V/pno2r2Woo89jcxSxglCPQ980No62UCSPbW0MRdRvaNFQsFyBz3wuB9a25n8N5T+HjexIoL+CVNzXSW7+U4AI3Z/JRWhurZtLjsmDM0BkMRPdQECn6YY/Wvp4rsgC6zGBaLIhYyMCS2c4IOR/OiL5VaMIFyCjkk+mFP6inWT+wbX4C+I6W0kfhgoWSXa3bsB9QxrWTMjBR1dbZ3z/axSZ766DlQ6smt4bu3tY3Jtubjnau9yNgBPbkcUktZXj1KASHfmN8keon5H4VztVUDzR6FqSRPoVuIGaEz23hxbYhjJZWkk29hvONvpihU1CI3VlbuuI4Yt0g//hmT/orjl1OyypDi40lWudQmfw44I7JXiB3ZVvOBub73C4+uPiwh1H7bp7w/8ObUbpEeMH38bS3+VaR5csjrgbHSWfT40tw7SIyByq8cDJx9ad3V6llEljbsrTPxI3oMdKl7sjextQ0TlppDRee5kbAjLrEeqA8An6ZppcyC4WQocRMIo1HqCWH866P5F19JPGkSn2a6a8aFUClEBYgfeYEt+eKb3cjNDGnl33j5+QP/AGxR7ddCcUYeGkaJs80cJCR8+8wXJP0XNE3CKXEAUMqxl2C/e3N0qVVRnECsUQk3d2zNGq+IFXrK7HauP7qj/FWl3uVngEpAjIa4kH3pDwF/L/lppbYcTSOYm3iim2z3YX3E6E5+98hQ6WpkhePcUBGbmQen/wCmP5mm4mHbPNKALWOFgoO5w3lJHGB+tdGWKNf3RAVABEp7mtUsw0eBioVpA6svIPUH0+VBpePGxbyszHkbqbiwdSF/ZFMwiHXdk/hQ6agJGdwdpUcfPr+tK5ehHU9jEnwTNhJHIAIIAIHfP50BJqJltnDSQrI425ZN2RhR/wBNZMb+jYqn9G0F8As8MswExwYlI2j50ktGY2sqSSJkMCzng53DHPpnPFLWCGXp49dFPNdNLAZI2PiNJxnkkDOfpS2CZfsrIApIIQshwfX9al6EvhBN/oRfoL2zYhF8QqARjGP9/wDTWbXySmcW2x8rsyRyWHOMd+vWtUUikuX0Lb+1ghneOZi3ih3G0cRjJYZ+OAcf2q2vI5JUjZZofFeOMFiuPJtOTn4jiurHtfTYjAq/sC2Zs7y2aCAStCHYvJ4fKoUJwPmQx/u0SEtLbThLFIqzbPBaMDG4euP1qlUkh8yxa/oIri0lMAmIdXYgASDBJIz/ACNUn2ZVmaNyjKPKM9+NufpmoLynJyPGS2nWTS3CxTklj5iRxwO1XCWajU4ZyIySWDhT8Rg1r8ynIvr7Ey6BIk7BIwvI2gjGCODz3yKsDcBrxInZSVXkHscLn8q435lj+uWRsns/LHLvWNmiB27B6L0P416FI8TtPnw8IBik/mWw9CPOJND8FGcry4HA6hs8/lVHqt7GZ8DG8SEcelUjybB4pRMW9tFASWiyw6k9q21C9iikLsfeOB866p52iepQbbYjVHXzAg48vSkp1Q+EIwrApnHm60jwXTG5yH6tBHdxGRlbcvovFIRrBeJotw2gA8+uelWx4rkFUn2aFkeN0VmVuAB2NHaTdRSYSZY2hzyCuTXUra+nViSfwEt5HllaNIzuA53VfWfs5oBXfLMqBgDn0z2p/fKOj1UyGktpY/30ihom4wG5q5utA0czqw1XCKPLG7cVqzoX0Mhd427QML2AfJFP7vTLCG5P2e6FwS3uqucU3tWgXjv9F1ppF/doz2lpK0YwS5FWWkmwSErc37W7nClY/MSPT4VGs9Fp8aCQu9Da2hD3EwDEcqjDNV97pmntBLObpm2oNqk5JpVmrQt+PCR52ICCVydueM0y1NjAHBOQTwemB8qznTOOo0LBAgPiL7woOa4SOYiQMqkZxnG6tSpkW9BqztayLKRmMnEiDpn1pE0sjF5WZtnIYFvwpuIioo4rlYbpot6+d1dT8c9KX2BFyImBZ5Bxj49qnS0h5rYcZp/tojjl2qREQSM8bRmnGn6fC7CR2jKAcKeqr6fTp9ag7H0fJ7SWF4i7+JESzoAchk3IcY7dap40SOS0GxW2owXzdPdqLyG8Rf8A0aYZBMFXDs6Mv8KswBP6/Wj9WufPtUhc4Vcdx3rHko0W39i1u012jeG0ofPGcufLn8qIvJRMkce4kAEgfEbqX20mAouLNPsiBBuBIWVgMecuM/lTSRU+zPGGAXwiQxOcNniseWmYS19YySKt3G6rMdrNgc4O48+b4U9aKSC6SXw1lRTsYdPIRjOPpVYzVJjIeLTXlvQWIATLLKqL5hliGPwJOKsjpfg3kTKWwsroPNgFCNwH0OR9a6P5T/ROJFx2ZivkltbVQZmZWRWz4fGGGO2CM1Yvo8a3D36qokMwcAH7vQ0fykHEnbewkk0u3Cq+5HkLebHldDn8lFUxght4Y4RJ1n5ULjnYB179TSPyXroFILp+mEztAkbKonDbPNyVTFUGktbrNKw/4qhPvf1RXJl8mykyFW+lK9pFtCr51JyvvEjOfpjP1prpcsafZmLHa0oHDd8VxvLbK8TKLSo2AYtkBQNuCATmtxIEimYEbsHODzj41Fu2GtH59MhtvFAZXVwXVW6DB5ri7uRIsUYdCyhuD0xsNPj5CujS2sYILmMxIoR3JYL/AGaAi1FI4oXBOYpS+7uylTj6An/mrXyJugmWwghuXZQqsGSM564zmuZbkfbYZFKss6owwe4rVyYbO79YlnuGdY/cClivbCj9KAu7hV9oI1lJMTx/vIzJjKgsD+Abf9KpMU2Gw+OBEt7kjaXwSCF7YpdouoA3VxZyk7t7RqWbk8d/ptx/arLi9mcj7qM4g+0yttwsfP8AiP8A7aB9o2K292m3/wCk6D/AT+tVxx0GwsX6Q2k7s3l+zxkfhSvXNkWkYJVg0bgMT0CDj86b1cg2ObRixjzu4TcfogAoS1uzHpd1e4XdFDvHGc4Qn9aVY9PRnIF02RhZhvN+9lnH+Eqv6Up0m6kX2e0Ryu4l5hIPxNdDwaF5HnEMfhpGxfc0sUpIB3ehH8621eezn1JFswm0W0kjbf4mVCR+Oa9pr9BrRoxWQRRg4IgYkj+yKxknEYiY+XFox/8A+bn/AKaBORnZSkXyJncD9nU5/wAX6Vzp7FLt5lRWEID49RGgJP8AzVlLaBUajdLdWag4aQMAf/4hr7CrW120rDB0/To2UejlcD8yanMDch1a3Qn1ZjjdGLooBj3kjRkx+VLNAlWwt3vpdzQWUWSB1LMD/v8AvUtY9hzH2kXLLrBZ9zLpsRzg4zMfe/A5pClxLaWVlboB4t2Q8zsvJkfn8hSeh/pqyFQ+pH+kYROWXZId7fLnFTa3o94I0hkRSSxwAcAUPAtDzkKpdVeOF8n92ZPKfXzn/SpiS6uHt0DrwTvAHTJ4/nmknxjXdFRBfoNZid87YrYAYPcn/tU3HPIb2QPuPgwjkfHtTPxdoT2NFXLqMENvPdRr+6DnIYZ3thdqfQf8tSqXLTRxWjOzcuXP3QufN9c0i8XgN7h9YXReLfJu3yt4gA6KzdCP7K8UlS6MYDAsFOXUnuOi/wCXFOsGw92h1cahGWjt4sKpO0KO57k1OvciFxJ5d2D1qmPxkibz7KAzg4BKkbuQPhSWO53QiMuviscnB6CmeJITm2MIJGnlduAoBIAPXFLjeeKv2PMZgYqSAuDnHXPesWPZv9P/AGDdQmntp4yFUW5GN4GTk0HqCMLVlfzbYxjz+4y8EfXBp1g2I9f+owS5R7crjBccD9aTRSsLkBfR80l4A5Dv7WI7KVlY7nTHHxLGkgkZ3dDt2MOPnWTgBV2Pbe8KCKAszF1dNx+BJxSoSq2xwvIyxx8TiteFGvIOtOvGtryVw5aNB4ig/Gldk37oGVlcNKQSwzgYWpvCtDRWxpqmpw21u7neokABKdAWUmkmqROf3z5OTw2MBvT8KWcKXwq5HN7eKCUlVgCDjK+4Dj/f0pExc2xj39CCWZuD8BSvG30K5ZYQXryRgnawUcE9hlT+tTthNN9kUOzRqhABHIzuP/TmoZPH0PHwr5NRGEkBw6ISA3Q/KkLSM0A3Fhzwwbg1NYkjaGc+rkXxd33bm2g+h6fpSO8iud0i7Akq5KktncM9jW+qSZSprc80Tp42FyPdXt8fypDpcjgSvNwCuY0A5yeMn16UemQGt05luWO7OxmOfrQt+8en2sREqtKQWkUjBFYsX+AzG7iTaSw3NnJ+VDfb1kDt5vKPuj+dOlaEBbxJCd6IwbGAPhXd3dBo1dSW7Yz1q0VX6HEmbq5kimYFcHPIo7UbITszLxKxPA7cV6GJy0HE60rUJIyrhtu0g4oWyspM43eXofnTPHI2Pkiys9Sa6ZWjkBY+UgtjFJLW3+zjI5Pc0jxo6pyVopoJ5VcqIyeeVXoaSxvJHICGKuPTuKPW2UWTRWw6l9lckWEbKceRySM1PWN3NABPCwZkPO4cij0MdZy8sdYkNvl7R0B6COPgfKo5/anVVGx5oQexKdKX0V/hRZ5/WUesyySaY/7u4XJPMgUgfTtUzc+0uoyjwxMcliCxTjpR6L/wf3Y2vpPapO6O6sd3p5aMvR9qOZohI/op61qxNfTjy41XwnDOdxAdmPcZps+hTOgKpPHgE4xninSlHO8NJCe0M4uAT5lPbGUHzo+CzKOeJGwcEdzSZKSXQil/pQaTawyTE7GUPsbCrxkjGRX1JDAsY4XpgZ6fL9a8+3VDqUObi28KDxbeUouOVbquP9aHSYBuJ1eOVeQeoNR4UxtaH01yxjeQNuEaqy/Xg1OxakqZjlOAFCY+AOc0LC2Zy0EX+oE3Ltuw6MMj4UhvJ2S4diNxLAH6rxTeoOQ7vb7wQGY8o3b0IpPcTR3NmzMFaZeNh9PWhYdhyHtnehjFFLjBCq2fnkUngcRvI7hvNCNqjrmh4NBsp/JcL4Up2hZtrkHoDQZkUSr5j+9QeUjjOw/nUXGg5DePw2uWj3+WAxbSfm1JI7qP7VHHtx4kUeD/AFh1/KsUbBsa38628txauUCyAvGd3XJyPzqb1O8a52THKyQPsYH0z1p1hEdDTU5EE6O23cLlSef6tI7i5WQG4J3b5VZiOmMYpvWZyHUd2ILyba2MlEA//hg0pvJFEl1kKwOwq/p5BR6tmqintb/wBHj/AIaM7/4Tgflmp62vDITG75DIwA+ZzUrxcR/YVcV0nhSMDtZ3L4HQjFTTXzGeMrtAyQR8xmlnDvsPYPLa7LKk7AhSwTA+VJ7S7JjntlXzofET5HzD8xT+km2PyVmtZE8RhImdrHtSu1vY8Sz7sRBEAHwx/rU6wibDNKumn0iNkGJraQZVuwU44+dILm+bT9bmHSG42ybcenet9P8AUORR65KsF3aSqfK7+GWPYMuB+dJfae8FzpgEZAKMpUj1psGEOR3qV01nrZePzB5YncDtlWAP/LSy+vUvY1ugOZ7WNtx/jRsn8jXX6Q5D32lufFjhYe7M0xb6E/8AtpDfXqPodk7ybjm6UMf6wU4/OhYQ5BN1ffaPZWy2M3iIkofzfeIB/lSMXCjx7HriVjkdP+Gf9KvHj7ROqHy6gsXsNOBJ+8ZBFH8mAH8s1JLcmeCK2ZlESu0hJ+WKH4unsaKKae5Fl7OWsQTO3coHwZRk0l128IjW3RgyxRk4X+7Wzh3Rl0SqBormLe+QQQB8CrD9KEMzN9kBOSVK/k1ei5F5dDGOUybm/gtHA+keP+qgZDtt5HRmBYlMfMf+KTXEXYTb3Qt7W5fYqhxLCh+BUL/ImstQIWwt4Q3BZs/jQ52gVDC/nMv9JsykNLawAgeu4kH8qHfcsd3Id2TboPplh+lKpG2a3y49m7W3U7mvZ8j+uq8D82/Kvl0x8WxydxilVQPiVVv0puPQKhvqAgk1K38V2ZIC/HooVcN+Pl+tJJrmV1kKjLTkRgei7QxpONGVRtbYi0+FnYkSIwQfxEnyn6V3FHHJcWcB9xBvb5Dp+dDljRWmM7oBJY1I2GOJUI+PXNARyyXN5I8Ssc8Z+ArYjRd5dn62k2Tag6kvGSIUcevpQxVUUWsfSLLzN8uMUzIOg2aYI9rbQuQrcMobylRzg/GlTGWe7eTzMUBA+AUbf0o4mbGLXBZy7A7iC5B6egxQMkrIwUDK4yAe5oUhyNXlGQFZm4JA9DQVwhJykpmDjcjj19PpVZ+AHwybiCrbYypRh8RzQVvI00YRgyu52kfHsanSAYQy7rhEWQ4DBRj4ml1lu+1rGx83iDJ9eaFIo4F8DZ3IfhzGjZPcYApLduxQH+KEfkD/AO2nUgOLaTfK2TgFeDS+3naIFFOdvJA+VJYoxQspYhmJ3jafjmh2mPgO4OCxJAPXg0qA2MuJ2jCKyuNwz+dDPIEuFZCwAfnH8Pmx+davgrY0sZ3MS7Dl3YrkYwBlaDtg32QYPBlJUAc57GuevpbHWuxvaXOIX8aOSUuTsY9AB1xXzT4hcpKSQgUAoS3bcF/manT19OlZmzmIq7T+QFQGIDdiRmqUaOschlR9xlgIKAYyzAhue/3q535EJlFbFGmbZbNilthmTehk3bJCPLn8qotG0i7jkkYKygrtjCBve75+lRy+VD+Ar2GW+nxrCzgsWWIuyqehPm4zzjinljAEs9O8VWZ1ibLHgn6fHr9K828730OR+o6Jc3EEZjnVj4gjZjwTzxk9sVXXRIR5BDiQBtiqmAef50+PyaEJJbWS1Roso7IQBIy58mT0Pf3v81OrzGDFt2h2Xynn51V+QxWS2r6fc/bfsiYCIpdVHOFBwBn48cVXmzgeaO6ePexZtgA6LnI/MVTH5cwZ6+R509nNbx3CbMIrGPB9cZq6u9KjMreIMqS24kcsSOPwqv8AOlsThro8zVrg7UeRVQcByOc9MfiDVJ7T6ZHD+8wG3kBtzdPSuzFnjJ8FccWB6a8fgKLlPEVgcHd0pekr27xxLEFB6gfxdz+FX1r4UjJpdjqSOGGAuyrz7tfIVM9szlmUeGQQfn/v/DUqtp9lpuPwGvHRIQzcE9BW66VLfBpEBkiXA3dvkaac0r6LViRr1422JuAPamVzpaxjBB3N0PYH0qk55fwmqOLa9Zoo2VsNnBG3rQkduY2WRizKc4HoavF7HT2NoiZn2tskXOclehr5a+JGomhw/PIbtVuRqkJlSGEglU6d+lcym6lVvMquhGAB1rHXRSY7Co5rdnV4p44gBy0Y5z8SeRQkdvNI4V7hYVfqShDZ/wBK56Z0xIa+n/aogGvbh0OcEuSM/ChxawxnxJL+FkHBEbcn4VJ0M5F/9Hi1nZDPtUFSG7k470yiso7r7QtqryKR7pRlwfXNJ3+k6xt/Bd9vUMVD+IU6+Umu5dLlt4y0jdcjYi4I+JPej+pzPx7+g8tw6lLlEkVR5WLdCDS+82wxtxK2fuO3H0oUyI50bi9VxMM+Ybjj0GaXWpxOzgLzgbT1puK0I2MJZy9qVJ8zqMNt6DPWv1rasfESdNoYEgfxj1+lRZgZZ20RM+ZyXVRKQO4PaibVRBJCGO9SphY+nvYpQPlpJsggZydigoCfgAcVnBcBrWeFwf3QyuD8a36YGT3cclu1yZAGhkXcg/gzwaQwzsjGWYGNd22UMmdhPQ4/Gt9exGxvPc4iaUybGYq4z3YH/SskVpITZXiArIMwzA5Unt8j8Km8aTDlR81NzFd7iB4YcCUHueua0unWazW5I3N4YSVT/EOp/CqTpIzkzGEl0+zNgKSJFA78VxCc2AkWQO1sSVJ+8vcUJbM5HUx8SOMOuGliTj+sEGfyoG/vAoi5K7drAH0xziqLHsOQZpcjm6WGQBWyxGfgKxtJSlxbyFg2ZFYsG5AY4waneMZUM3lYopXsyyH8DQUjhCnhnzB26emBSrH0Py6GomCX9synarQ4bFLBcsWtiACwQjB+bU0Ydicgt7gojsWXaYwBt69aT2lyZLdlbDNtDAj4HpW143QchrrspmuBISwAQAnPzpZc3BdS0chVwg2Z+/60+LFojQal2JrAx53bPePx7Uotp8XjITtjlwFA9a1+Nutmz8NY74R2ojd2CrJyB0xmgmP7p1BBkDHaDV+IoR4rtYvD4mVU8D0O5QfyNYXHESuoCq6+IAP7WDRxAItCfta724ky4/DFDu+JbcelUiTD9FL4bDd7oUn/ACmsEb966+mR+NY57DZpPdFvEKDA8J+aGjCrDOTuysRFGl+A6E7EFrUhsk7sD0rIFUaIDouTXQp6F5BkbSNcOFfBUZAz0J5Y/gKGhlLNKij3/L09aXQcgm4fdPbKAwCJz8TnrXCytJfb/QBaOIKhkGWQXEW7hYgG+Slv/dS55CrOQ3/EYg/jS8RthtzJ5UcsFYygg+hPB/LH+Gg5ZC81vGW4QFh/hNHENjEJ4l6iLzHBGBkd8nk1hb3CrYSySnOXJUfeyB/KkAJileSWZ1b3uPoKGtn/AHIWU7VLBT/aHJ/KgB1aoItPKxKu6Q4Y55A7D6n/AJqClm3qIQdocbh8jxmkNP2ES18NDuj3bmkxzKR2H9UdvjXLyK0u91JVMKEHr/3oX0wFuGKwiJNo8TLMP6vbPwz+WK+OrBzJJkSscqD2Y84/AU4HVt4Qy87FWA8i55J7fSsVkCLvdtzjJzjP0zRrYBgMdwzRy7Ypmx4bhcIT2H9U/wA6Wia3bMXhSeEx8yqCxB9a3Wh0dyI6yyJJw7A4OeprtGWVPCkkaVh/w2YYJ+fyo2Oja6fNzBdkZ8Qq7D+sOG/Os1kja2DblxHMrgDuCMGhGHV0wCKuchVdgfnuOKxkyZUjbcCqEH8GA/5qf8EZsu0MzZwuFUfMha+21uxKOzMSELkBfUKBSNyjDMElME7QM5H60X9maJWkmDMpiZWXHcnikWSQBZJT9okWM5XdwfjivsluyAs48zYGP5UzqWKErcB48HuPL+tDRKQ6A8kdvSlcyBQaRdx28Qld8YHB/vCku4rHFtbDZPFRrFNDS9HpGk6tFcOCXZAhDIP4f/NSFhefZ50fd5AARn865MnhJro6Jy6PYtOmSIxqQRFIxbA7nFQ2m66ZLPwZ1AIKrn1IOT+VeTl8C0VnNLPS1WOV7SNmYZzz3I9KnbbWFjS2Odphc4x/erk/j2iytND69jhfdtx5uG9cjpSu5v1MyqW8xUg/2hyfyoU0TZ8miUzYLc7i/wCPFAteq1xJLMuFAwD60/F6FHySQoUhXaVx5j3pHG0sgM0R2lwwUfWl0NseX01u0KoArcHrSC5eeGNlA2gbceXqM80KTU9nOrWQu3CjBA6KKOtXWBgxfDHJAx04qs3UfDeCJ0+zkcUy7lDSEHAb7tOrmRBhtnAwBk+7g5P41efKyhwWiY+zCPKptwj7ePU1QyWOJ22lQshLAheQcU8+S6+icRdA7Q2kMJZVLjJPq25s/lSzXohBBGxdgsa7SCB1J610S0w4m17ZRTROxY7ieo7UqGsRRytbuWMb5O4euOlUmdDKBfeJNDcMHLGMjp8PWmIil1UJDh8OfIWXpXdipJdlZxNvoGtrslFRNzYPHwo+f2Tv7NU2DfvI5rojJH4WWC19C7YIT51ZWOOh4NCxafqsTpGsR3HgYpayFJjX0qtPS0Eb/a7YSJjy4n2nP4Uqg032hA/dSMpx7hK1Cq3+llM/4UkVt7PRQ7nsArMfvvg/j3pGNO9oSPPMqHuDUuPf0eZX+FT/AEhpcELeBaAY6LHH1+Z71MXFpeoT4902eOFjzmt1sbehnqupxzRTRLbwJkjgqM/WpO9hu413jFuMDErtg9evLZrVi2TrKKtYt5RO7uIkRTw56fTis7pY5w32y7ZnThcEvk9uO1dERxOLKuRha2yTXT4JVQO4yCfUV+RlSMSboy4O0ELzW0tohw0MJ5IxCGQsJU5xuwMDvQF1L4ahZA3TyEdSD1qPrEcmt3dCKPxOVUkEqehPwpHLfRsw3R+KGyAMcD/vRwJuQtr1orjxlfKt1J+9/wCKFs4mlmELrtRmJFNqUSCmZ03MrbUUeG4HR16g/Q1+URpIY5m2gqNq4zuOelCa+CBmkXm+2e2d1VQdwHp8aTzSNFdeMjFY+hA7VrxgUFpdDw5gRkpLhx60jN2wfxUHDxgu3xVwB/zUnADWaeSyvJYWZTEXKlfhjNL9XuDPLuj7gfjTKQCmbduUnOD5T/dPFDQyiRVWTlWHJp+IDS0ZpLQJ98KdvzrKwk3Md+4KvvGlYbGcuHkjmVWLsck/FhWLuHgdQdoAJX4ml0Do7DgjyDkIki/i2aWST4uFZmwqdQOlVUk9hcKrHwg4cKVB7mg7iX96I0KqByo+Hb8s03HoOR3ezHZvA3MjZIHYf+MViZhPI20hEKAMT3rELs0k8txG+VbzZ+VYrl4nt1XlAdpFURuzTUAVlJXy5kyDQs8pktwCOFO0/Ot4gHOR/R4A5CF0z8PKR+ZoaGTdZSjfyVWQD1Oefyo4gayMolRt2drKP8tAu+AzAsDvXj600yBtDxdyLt6Of5V+hcm9mY9dooc7YGaBnnkUffOz8S1ZmXZdu6jIA3qPkwzWqNCidmBlUk8BeaygJaM7jzxn5VTQG0PKlm7HLN/IUPPIXcRpxEO/qaNAGR5RWdfePT5VkXEj+GOwGflRoDSRsEBehHl/WshIniZUdqNAbiQ75n7pGAPxahlcbeeQW3H6UOQC5XBWKAdQMmsEzJlt2Xb3j/IUnEAsSZkUk7go4B71g0kUaAAZA6isc9AMIJCd8znJcgZHYVlbSAoCS7E9IlGOKTiCClZtpVGO8nitAZIlHu26kZ4GWo4lEfDabVDXksUZ6guTnH9gc/Wsv/T8kSBmJ5LBq001E2lRll23Fw4BKkbFXP15/GhiJpZfBhxux944yPhQBwt6zMwa2jaMnAC8P+I4Jr4zzQDYY1Vge8amg1Gsgj2iRJMgcoCMFfr3rK0VriUAo28sAMDAJrG0lsdGkKZ8QxxtvUZfn7vY/jRN9ZzWV28E0bRNgNwcgik5J/A4mYs2klt5CuUwY2P51va7nhZFKhTwD8ax5GkHEY6e7RYfaiudznPU8YFBCbwpODuZwq/lUmuZgzi2TxMqbh+4AUO3G7hv5g0NauVfYqEqoyzD+VQcNfADP6Pa+u4/EOWCqGCt0OOK5jv0H75hN1wHjfCrj9aeYtfTf6iw2xiumj8vkY++c/lRJc3ZZg7STc72JyQPjVvwEpPl7p6RC3Mc0Tl0ByJFbHPw5Hbii4LiPR9djdJbS5EBG0TxeJFk/eIAIOPQgj4Gpq+JWYWuj5ey2RijhsrdSGiUTTDdw+45+8e2O/0oPWJmjWOKJIlkuQZZzDMHSUk7hwANnOcLge9j7tOnvsle0EQzbHG7cyjof9/OsNMmtSWNzJtQEeXH3f8AzS09olH0pmvFDRNH5mYNwe3u0q0+Zri8cBvICAvyrkuEy6fRTpflcuy+Z4gfx4rIIstmZpGwyqMHd6GuPJEL4MqG8IbYhUZUrgjHQlhWmnHEsUbM23BZh6nHBrjf0dMZsi2lkil+hJ97pzWOqOZnkCdFjU8/j+tLUjGclw0siFiu0sN3xJ5FY36eCGt1ZdnbHUEkY/LNNE7A6knyWkPAzwPlSxmcXCxOqMcgbyOCPT51ZYjdhH2rdIhyCueQR0oFEVZFVzgFmzg453cU/q6DkNReMsZfOWT3QxwKX3Czxb3Rd4AyAe9J6lvodHzVrdLqB1eUIx7L8aV6ldTmfGHRYgGYkcD4CrxjaWyiQn1CL7MySSxJIiKVCuuc9e9XGg6fcapYbnSI590yp1+VXjI5+nViw8hBoMreDEyxucjjY3A+FV9lotzFdnwoojABhiBnYa2rTOqcXFjrQbFrqyYXImWRByjdPhjmjLSyvtweTwdpBAymOM/BsVHnR0ak/HS7ATqQGJHBEo3gfTtRd3PcW2SkCyAAe4VFaqpmak+WdnFHKcNFkHjamBQ7+0N14W42Ltg7cMwp9WZ/UooNIiuItzqjAjnC1L3PtLqsagR2RCkYwDyKzVh/UZ637OwSR5TCYPVTipW99otbZvD+xeY93bGBTzzQj1oXaz7O6fBM01zct3+/SvWb3WbgkPAWGeWU8D4VeLvZFpCXVbfTlMjDxGUAndvz0oWPQNQvrpQUkPiAkBV6VdWl9ZGp38QrmaORTFaocIcly+MUc3stqSzsNviAchfugj1+NOssL9IPDb/BLcxNNEI/E8dgCUJfOB3FUMWjLFA8CgxlCCM+9n/Sp1mkR4iSiRYYwig78kkj+VVn9A7bZJmuWK45GenPyoWWdCenYgidWaNQio6DklutGahCfCVnnKgEAKB1GKJqWTrBoWtMMn7SwY8gAdhWfgo7SzGNRjgBjyavMrRy1OjEvJKCAylgcBW6kelcxZWUhC2TxtVsN9PjW9CHYKPbfuyqqp4Xdj513ibf50IbHCk5yPj8azoF9Bip++OH5FF+EreUphh2zis5DuTONP8A0kbFl8Ns+6ec/Gvssarb7ztLodpX4UbE4hEZ3N1G3JH5V+AQhj0GDIFHzrDDaWQhQp5ZBgAN2rPftI54I5FAgOzeIx3H96On9cV9YK2TlQQfL86dGHLsHTw920//AEj6H0r4WEkZiZMyA5J/jHr9KpIGiNuxIy7WHlPHX41lbzJuaGVmww4b0oqQPt25inSYHKnr8q+XSkRkMMgjk/yrZnoD67KryAghXGeKwkH/AKaNjgEfyptAa2MgSTaTnaeAfSgppdsytu8wDFsfPijQBYP7iRQcgebP16V0rZld8ZYAZHwoFNrcL9oEnVXiGPnXEJPgrz0zhaAAVypzjhHKj5HrX52zFK2cMGxTAIo2B3ICC4GcH0rJiu9CO3B+tVHN2kWMjkKw7ChbpzJcMB1Ax9KOIvELSTahYtyelYwlGdt7bUTH1NHEOJvGWlf5VyZCx2RnYD3pQ4mjM20D+HI/GsZXdJSjgAJjAYZzQug4hMMhAwDgjoaymZrcGOWKSKVRna4KsAemfgfLita5G8aOi5acLuZlTqNtFWdgr6JdaiPGO1/II49w4AHJ3DA8w7Uvx6DjR8jnYvuiXaAOc1xpiPdypEMp4rBVJ6A54oc6MntjSzum3PH9lSd9wAGQSuOMYPDZzjPbFFRxxxWQvbYvA7vyobfvQ9UI28dMio1W+juxQvrGHtLpMlvcXFuumXlvPao8rySRjw5Ytxw6keUZGcAcYUgcrW2se0E177NaVoEUskkFvndMyjfjcwCr/ChUoSO7AUktyuxsiT+E3azBl86bgPQ07ttAt4dEk1F1ulIcqiOMZAOCW/SsfkJHP66J4rcvA5BjCFvKJH6VTnTYU02K6lMEfiSZjgC+ZowG5/y0POqBRQPPfLBapp+kW3mZAJpWOXlJ7D+rRGjWtzEUv9OtZdkUgfx2U4cg5x2/mahXF/PpWJbfYDLZ3djMI9VjuAwiDBXbJ2Hpg+me1N9fudX1e8V7qFYUVfDiQAeUjmkjJr/uUqF+HXss2jwaokutwTXVjG7GRIZSjNw2BkcgbsZNBXmm3On3QSa2kjjkQGN24DH5UNKu18FXJA8tvJqGsyjS9PlTxndorWIEmNCM7RnLHb0JJzxzxT/2V1G40GY6laPauZDtKMElJT0cHlfpQ6c/9SkzFL+wqj2RMyqgVgpDITjB75+NHgx3txNM6xB5HLEbMYJ7D4UnLb3RK5S/6imWJ7sOq4Ve+BVDp9mI0HhQeCWyXw2Nx7U68mSPH/6TdhcXdotwqTKpuFKujJ1B5pteTRQRTRSRuWIGHU479KpLmnsxz19NfZ7ToZbF5JLO3EfutNJNzkgbRj0xx9K1sb3UodJaGDc1iXJQbMpnHc9658s1y/qzoxZEoPt9Z6Vppjn0u7W+unilSSJlyIwVPIxz+NZaFC1xHPdHMZBIXjBX1HyNSvJw/wC7IulTEc0LSGCJEXcTgn4ntVO9olrCkjbNzOCsQHUZ5NZPmL/1JcNC6yU2d+kTupjDeGSPXriibiB5bu4eNcZaN8bumRj9Krzm1/b6anoaIwPBVSS4wSM0PDI7KqnqsuDXHePZXkPZ7hV1ArGEUJGAxUYzSSO7+0XZIbJc7Sf7vSp/x9hyKqKdXdju4MK5/GkWmXwSGUE8btv5tUngGVSUlw6TSeNywVtoI69KWaddJJiM8lcyA/E8UvDTHVIMjsxsBwoIZSSW5zjjNYC/Ms2OETaAQPn1oUs1sXT7PG2rIGjjQ5bsG+FD3boqyyOGIKK2P4iTgCuuJbQvLQZ9qP7ncfdJjYfIZJ/HFJ9Tuglyqj3DySeo4qk4djTle+xvJqP2e4XeqyKUGNvUc96nftsbNAGC7d371g3KCrLx3o78OWWeg6bqc5ZJLSWMgjBUr0qV04xq+baVAScxSEHj6jkUjw0d00esaT9rkgSZmRW6nC9ahbDWNcsk8SNzOQfMgJHy56H+dQeKiyrZ6PJscFdy78ZPGKi19oL+5ASa0ePJ4O9ufWlUNGja60+aSb/iN58kYbAriG4lkyXhkxgYwGanTaN0cQaS6S58FJWz6E/9VNbOdYBgqV3eoxWu6DidRaXKIwXaC3Q9VXrimMU0e0TvJw3wpHdBxFzaGrbyh3AqeRRk3tFp1sxQSMxHvMO1Zug4iO60+K2TYIg4HJy2M04OsLdEO2n+MgPDbhyKOVGOeiXlZ0iKKnlJ/wCEp2AfHPenV2LObc8VrNFN/AH4oVUzFJK3UQ+zKzkKmeFhJBz8+9ftWl+yuQBtcgkZUE08xTJUtAl5HE7JsCxOBgsF6g+vxpDq+oSGHxImZSTkuepI7VZYLOXJUjC5l8MNDsWVgM5K9qQS6tKMtANhdvOrnpx+tUnBZOak51BosO6eDvHG1hvf6DtQV7eGQmSUKgA2kgZ61eMPEalLXQlvtviSO7lpAcghMYoprKGRg5Z/DJydq9RXSnpHBlxC2K3MrEhmL4zhDg4+NETSOtxIbdCuGKgt1IxSNnJwC0hTzfavGlIxg784FZ2Nz4czPNmVWxlSvAqbYcTKcIZCFztHuse1aahC5RpLdAiNysZ94+uPhWodHEsSyxmaQcKuGPqe1cwuYiEkDeHKMFfjToSvpqJk+xOm1VEjDB9M8/pQgYblO1jtxgg84x0rRDa5lhijMeGaTYCBuGF/80vm8WTxHV1RiRgEYGP9a3QgQXHh72Tb/ZOaWbdsZUmIAnJKPyTTKTAoS5AKOQQdyMOvyNBBpPDIwCoPG79PjVFIBTyiZGkUbJh/xU9fjQvibcTBiF6EsM4PpT6NDIp/tNu0Te+BxigvENtcLOCNuQGI7g0cQCxcBrEr1ZG6Gh/CK3TxBsiUb1HoaDD9OGkIMfJPvH9K+LhZEP8AGnPzBoA2MzJsZTnJCEelYztiPPxoAZWcqq6tu8r/AM6HQ8Rt6vQB8vPJJLjoSDXN4MhvjgflWikqGIfaOjHiu5dpMex2DpwRt71fWx9dnJLGViG54AorS7Ge/vDaWsYkmcZVGO3NZviViHSME90q7d81xDGwVnlYsSN2Qc54OfwxR9FqWgpUZICTyD7p3UTpcj3OmyxSSKqxoEj3NjkyjP54rTNAsZH2geKpYhsjJrmcH7QpyW+6c9PpWNdGpNdocXtzca3LFK8UKSOViQqMZ+f+KmPsBrOn6K73l9p1vqOyLAhniEiA7l6buh256c0rXFHThlZL/wDINPsmiW/szdWg+0T3yQNOJIjLguTtPlXyLjHU9c5+9hdEFzeaY82kxwGCzid5Y5nUFnIdN2Ty3BwAePN5ea5nW6PUy+iMbUkey+BMLfc5liyrADkYY4/6a1s7dpPtN0Qv7s73YdFJ7V1PuTxP6jbU4vB08SxlfBNslzKuceZxkEfiuaEurmWLS7eCZv3AjTf/AF/IvP0xXNOPs3r8D4yLSa2K9IGDNj0C4/Shp1MpmiBIVogqEdcgqT+VZU7+jz/8KGHW7l7K3B8KS1BZFjIyJBlic/DDCsn+z6fJY2RUKqwBmyuc7uck+mMVy3hlotLpdsqry0Osaho9mUjDCASylF2hUJxgfSksHtHJaS3NzBHFJDNL4ZctyEBCr9MZrkrx8kT/AFFrNLKL2wuraDTYrXTY2jWCbanCncdpx+RNTd3qH9JNBawgLDHL4jByxO/Crkf3SaTBitPdGK50PZrZ9P8AZrRo0umtp7lxI7gKGwQGK7sHAXrnBx171zqfg3+ktBcMFjVzEkncgHgfjTNcr7OjE9roSa7dpcRKI7++vbpJCrJIFK49Rydvut6Z9PLSWytYrOUNDLukYkef08tdLmJRtRY9uItOa8kWygmkhwCxA5GR/q1O/Yr2aurojUTqkVpDtM5mdz5MAHO1fdznb8cmoVev0rHjtrbQgaMRbyQ4CkAAnDAVjdK8t/cyXcvj5kK7kbG70PPNap5LezlzXOPrQzj3pbJ4jHkg8dc9s1lDaXt7DHAWkQYJkycnA68fPFQePZPGqv5J1fR209rskUqfKSwHPWmt17NBdLm8WYLMEzCVZSiNjkMo55+NVxvh9HvxMutpA1hqNmmmPbNHGYvC2yBzsB/sj73xHetodO/pG3lt4phJLAS0SsMIUHYfWpZckuugw0oX90ZWEFrDKlxZp4lrIOVDYAX4DtzQlhMlnK8cpBAfAQevfFTyLaIZUqrcoZXQVkkiJLPuymBkhQwAB+maxsNSji1FbpYomhSQKUbqFYZzUOLS6Hxpfo7ttI8S5jcKqifDAnuoXj861a6nWRHkMYYW5DRr9wsBj881zVWXkVcwKbuxSJILny48Xe3yzR0y4sUJbIziNf4ifvfTr9a6cdX+ka4fhKXJlt5dzQ8785HTI4P5VrfKPtBicNIQ2UC9/wDea7Irrs5n9M7W8U3CqMASoTgeoalc0UysFMDI0Tcgrzk9KopljIbWesCKdcpwUI5+dIITmRxIjA54J603ploZFRBqSRGSWQt1cKfiWFS01yRGEXcV3kgnrkjP6Uq8fZvIoBdC8WQvJtxLtIB7Bgc0p0+4jtZPElY/X5tTqOIKtjCdo5HkEiyMrjzeXr6UDc3DTSYUZ3HgD0qsSUUmLzA3BMUbIT5QD6VpJZSiIBAspJzlWXK11TJSU12OtLMqOPAVmLEBcdvWki3MkThH25/iHXjtRWLa6OvFn/09C0+eaK22yxM0gbIw+D+FTel6tIcoPs8OGPmcZzxXLXjWehGeNHqGgarZSx+GUPjH7rbetQia7E8hia1slYY86+XH/moV4lMrOeUenXGoTxRnZ4JIHBzkgV5fc6pLOmxLkEA8FXzj65rI8Gtj/wApaKS81J7ufmTzAkYAxipEbmlDfbYfj58nNVXiifyf/hY211/9Nr+QMeBz0NSKOC7BZzIR/DR/ED+Sv8HWqQuqvJJfzM2fdG08euaSSvPMvhlnCjsafH4zX0R59/EEJrc1m5jgvrkRgZxtU8/hQJs7cxkiRZXz0zj6Vb14l9Iu8rfSNn9qdTJJFzMOehCn610mnxTRCJbWNWP3zMTil/8ACvw1+1gM+r3NwyG4uDJj1AOPp2pjqGhTp5WAOAAFUr0PeqTeHXwR48micu7gCZSJ/Mc78dKMb2eaZgrQsAM4/eVRXCOWsdsAkWURpIWUp6k9Kok9mpUgA8MeFjox3UlZoQ0+PbIt7hkdm3K6g5woyDVxH7KSSRbYoVQ5yCARSvNI/osjFvLm5dvDQqwAIRU4T/zT/UPZz7I6homADAqwbjNJ7ZMeCxRbICTLes78Y2hV4oizgR32ytHlc9+1JWQlWFgOpRQSx+EigtjiOL3sfGmUMdt9qf8A9PMFyA5i7/GtnJ0czwti6DTr6eIPJIISgwhfqR6UxvryK1fw4rq6iQj70YPP1bd+HFZzpiuOAnvQ6oI5mOSd+49OeKw1C7llcJcTPMUYH3MZ9KvCeibW0BtceHKqOdxzx8qHkZnl4Riuzg/pTolxZ+maSSMGV0Rc+UN6ULPulyxA/v8AQYqmw4mhaONHEkigEjBZRivllF40TbtrDoN3Sj2B6weOXDFFWXfnIeNMij0tS25luVK5CgHoxoV7Dho6tx4sDSMm5X4YAjcfpQ7lcvGkZJQHJK8E/CnFNvszojowQqQdpzgMP9RWaDDFUfw84J470Afg2ViPl3RHHvdq6RXSQLIq8g4b1oFM9y5jJ6nNZBf3hBOSrnj0oA08QNa+GF5ySK5t9piYuyrHuwSO1Bhuk4+ypGTtJYE/SsW2hYcFghJ59fjQAXe4ZSUXLYXnHXiuvtBijfDMoUgg+tagJaKCWJ38VWjZXKlGUj41be2ntTq3tBoFlb3uiWVja2sheN7YHliFGCM9cd6r2dXrnRNaDcC19oLSVsbfF2nK54NAzEgAqvU+tYzJfEHIaNyjOytyDnp3Ip5rrKdRj1KJRKl6hnYkZAk43fmTTSLS2L9MUtGIkV5Myq7Kq9getH6TKYLwvDGJPFG7w1OAD1z+dJdGxIJdgi8QLkZkfjuOaYzWVy2olJVDlZCjKG6PnzfmD/ipVWkY57Pwglhs0V4mJnXeFx1BLD9KYanqd9EskU9x5jFGyFHKiEbQPDxu6dwOxya1ZE10UmnP0/QabdS2EiJI6xThWkk7Ic5z9cYo1r+X/wCX4IbdLdluglvLGRnChAwPzO2uVuuaLOpqRXZSboX2sCksZThupHH/AE1xZiPwYreMKCwP456V172cVfTjVpC+kWCsMbI9hPptPl/JjXVwsl60NlFgOWOSTkDIBoa0tsfHLt8UbWttc31tbNaeE8jDbIrtyuPN+eDRiKNEv7WWNSWWUNljnd944HYcVN8bno6pwPBX/kNdQtL2e5adtoWWNF8QtwGO1cflXet6rFBaGFlbDyeJgdiCR+lc0TaZmfLNLUgV5cK0OoJGrLGiouT0+JH5UBIy75IIyz+LgyH4en4YrWjiHmm3cggElwyK06b1PoFQqpP1zQt3N4M/hABWS3Mfl/i2HOfpU+IDbT9Tez8G0kiiZEkWdZH5JJ2/lQVrcI93Yu5EbBdjYGTlEGDU7g6cPkOPwe6tYxWulxXN0iNdXMxAiR1LwgcncufeJx9KAceNYC5WdSwl8OPec5ycdO1Io2dy81tfBr7Xe0MNxJZWVqk1msUCIke9iVjKDBbPA3HzYHr9WktYu3uryWfcSxO0HttA4H41eMMr6cuby6fQTcXMxtsow2yON0oOTwveh7MoNPV92G8UZH9XH+tFTKOLVU9lRpGsXT2byTRMscaBVYBhnHGaXM1oNQtUubiZbUws0whbknzY/wA2Km9P4deHyqxlJDrYudQjE4OIS77GPvNhlP5VOz3xk1CCABfBtkG1QMZYjue5xU3jbQ2Xz7paKKw1kTIzRwfZXt1DnMmQ5IIAx2pA1zDarFNGQyyTGZgwB28tt68e6RXO8C/DhWRsd6RYwXcrXOpylI2b93EPfk+PyrBL2SfWYZppQS8J4AAxxx0pHhZRWO5tWspJrZraxhS2DMiSFMsSoxjNJpig0IZcbkd3GfXxAf1pHhX4DooNmIXmc7ZMJGUH8QGM/nQj3LPewiQ7FdkbAPp3qLxUJyCdRk8KVACSIohGgHXPWv0c0U+thpFVoYEJ2jvSUqQwMbB9OSW+nVDOq+UZ4TPuj5kf781a6zLJf38dir7miwzlujStyR/KmmqQExq7zNPGiROZGx7ozyR8eaobpV8V2hlMcMSbpJT7208YWrzlAlpLT7OoV/3lxkq5PSJQMkfOmmrWDiJI4kMTTBYwmP8AhDPQfzNXjKBMtGBGWIRgxLKP4dvH51RRaSkayuf3SpFuOeu4qQq/Qc1b2yjUtiIxJI/hyuqLDECT8fT+dUK6HJNd3GAFMkikgdQOfKfl1o/kyvo6xiaza4lKxlW8QA5ZPX7355qw0zQonikmlaRcqSM9D5scUPy8a+HRix02IYrQGFIvBVpVPJXpj4/GrrTPZma5u3gWJgoyXY/Kpvz0jvjx20QEtk5LCQrtA3AhemO1XuraJHBeJp9un2q7ccoB5QPVvhVsfnplP4hCCxkZgpRlJHA9asF0Se1lDFPEdQVb+tnsPhVf5i/AXikm1jcqmBnge8V4FVcqTW6YNmVjU85pl5jf0d+Ml8JW18OInxQGb4tkfQdqd3Fk97L+6gSFcckdc068iX9JvFS+Cia8d/IqKqjocda6k0i5E7KS4A6HHWqxkxv4Sqci+n6Oa4LAL4fA71kLWSIEEsShwQKZ8WbNNfQ+1tppnw7q2T7uaGXULhVHlR1PADjmpuW10Um1vsttJ0P7Rbqsr5jfjbjOKXaLq9pGUN280RA5EcrEfh2rhy4rO/FeNotNP9l4YI96CJh08yqcV3o2q6RNt8O5k2n+Ju9cGSciKpyEJ7PGeMoqJx/CmBTW21japECq65xkv1qSq0PqWJ5dEs7GUNKRuAzhe9EXZmCu4Z2kznGeF+VMqpmeuUaWqWEke2zjHl6IRjmg5bqSCESMZF299vU0+qYf1QPrWo/0bAsklrcSM5wUgiV8D1NL7r2v8EMrrM+OCM4zVccV/gruf9Et9rsd9IYDp17GD0LQ4/kcUbH7ZWcqsp3KR1BVjiquK/wR1L+sl7vTnSUP9lkZSCR5aeS+08DB0hwo9SO9NKv9Qjx46+EtMWtoh4cKxsygEN8631SZZ5C0kbNnnI6Cryv/AIQqJSJy5s7i6jPjFiqk7WB3gfIdqaSxwghAkbEjj/eaop0c9YZZMTaY5KvFE4ABBBOATVDcWsapkWaAnqcMaon+EX40/SYeBopNkFuxZB5icYBpncM2AkasMA5DHBH/AGplBN4ZFE0F47Eui7VYjn4ijXlIXedvH9anUCPFKFd1bgyL4xyqjJVeM/DPaur2/gZWVlRl7jHINHrIZFH4Y+WWZEjjCJuPKNgHjoW9a/BgsaeI89tDECUVTtdj/pRw0S49G4aKFpFENq8xH/DkdjkfPvWVtK5BQIbeJjyxj8z/ADPemEM5JJhF4r6Taqgb/wCk5XP+atGtrRORcBgT0K9DQB0ohYA2+5cjJhlHf+qe5rJ49yAbwSpyGH8qUHJhIYvtKtgjeCpI9fQ1pMVbjbtZh120COTKAK0EgJ2srZZB0PpXWRFCeN0p6VqDicWTbH3zAspBAB6L8RXEfiFWDqAp55HemQcTqRg9tcMeSFBBr5CkgZ43VfMpzj8qA0OtHvE0CY2N8tlqGm6ioWaQBsxjODtPY4HGaA1O8ttZ13woY8wquHx0IHm/Suqmket5Hqx6UMD1ZtNu5J00azaGJrrbEhOX2YXbn4ls45+lcT2qSSXLxMISkImTb93Bbj6+Wo89nBluWzO1IfRxE648CbGT1XcMNn67azsZPFv335K3CefnBOec/wC/4qPnYY5VdBOnOkOotCERw6EksfN9PhXMPnTx0wzlHZjjad2Ome/BoeqJ06m+CCLi7+2eLa3QaQqX8FlXBc/cDnvxinP9AwW+gpqF7KyPtViqkZK55xnjNI6S6O/+FczyYou0kNgDKoVwqqSD1AOF/Af8tc3qIsQWB3aAljGz4y6Z8vT4Y/GkbPMyUuXQR4vhjTF8LO1W43f1BzW0yKstkD2Rv+UUmwq60L0bY1uwGcSFScZ6KTijLadYXuNjomDgFl7F0zVlmmTJpv6dNpGp2+lQ6/Gp8Pcc7eiheN5+Bxit7y5lkufsk00wtyYyYRJ5SMcqB8OtP7JtHdiUJbT0xTqN1c30jTQxMoiiLsp7YGefn2p97PGCTQtUSYIlukLkeXk7gQg/HbSq1K6Om8dZ59mS96FOo7rqWOTPLxmUY6Akk/rROTb6LI2FaWKFEYjsSzfpXPeVt9HmKk90jLT4syQ4Ufu2V2I++SN2PooI+tEPO0P2bwEVg3hIM+u3J/nU9ii8ySPeytu5Z5PoPDPFHz2kcMMkqAjKMFx6tG5/6RRsF9MZFEa23J5Qsf8A/Gh/WiNUbdehFTGdwT5bY+fwzWAzrT5EdbdG91ZfEby9sK36NWM0iWthGYgpkmywUjG3HlH4jNaumVxs70rTb3UbgW9vAZJAgZ2PRRxk/jim+jatPp0bKuI5FjUhiMgpvGAfqKXJeR/9Tu8fBgdc8j2MdR9mNPj9nDeQXRiliAhaCQcs/fFLLzW77WojdTlIokabbChxhggOfqStTlU/+xXysnjUtQgbQNHutVuXiiLFlUkkHJJHQV17O67qGhRXDWhRpJcHzoD3PFOefHr1/YEMc1tJMLlZImAVcOMdutE3l3q2s363F7IHg3upACgggZw2OfxoObLx3/Ux/eSrBbjAMjnr6dM/lX1j4MM0+MkkQRH4+Xd+X86P6smqCk1QG4iEYKqrBFJ6g5/kc0jG9GgPUg5J/wANb60x1Q/e8Jg2luRu3/PecUs3bYSB1Hh5qbxgVMd6I7iGQnIHU/SkEVyBIik8FTkelTeNaAqLe+w8kwOd8hRR/VHJpLA7LDDncN6NtPqu7moepDD/AEq9VmM7nLu+6Q/xFi38hSe7M0CeCy7ZWUyEfF/dT6Lg0PDIDwym+8C3U4jZhK/xBOR/lzS1LkQs6BsZlEZb0CqoNT9K/DUU/jK17NO8e/wiPDH9Yjj8yaQJfvHH4EZUks8sjHrkHaKR4qGQ1VTcXEFqfMofxZGHQkHJP1IxSWLVWt5HlV22qURR6kDJNOsLZnLTKrSj9tnmjtlVXYEEj7pPJP4YqatNZmsbd3hfZLISwP8AB8PrxUr8Zs6MeX8PQUullvUs4UjEaBo4gq5JxyxzUxb6qsE4jyviRW6rvPXk5NE+KdM5lDPS4b2Kz028vDcEqJSpIK+6pKgfiK8907XZLuG3glbdFGfHk+Iz5fzrH4rTPQw+Qn9PQtB04RWDz3fF1cgPKSPdXPlX6danJPakXfhRjcpUecjooHemeGzrnJBcx2MDMC/miYdPWpbTPamGaBpJpVVnO2OLd0Hc/WovFZebgobvS7aY7Qikjofh6UhufaqNR4bMu0dOaaceVjNwG3Oj220KikNnkr2qbn9q5C5Ecm1R0BFWnx8rEdQMtUtbGzt94Q7uhJqN1TVpbgsxckk9A1dGLx7X0leSPw/aneWoLYhwfXHWkc7vM/m3cV6EY9I4qyJnVzIFIZGUhuCuK/JIIseJl1z7+elU40S5ScwRtIMhGYZ94HpWzSE+eOfDN0FapoOUn63S+t2EiFlHJb9KHllvmO3ezN+lY8e/piya+Dux1q5iCxvIw78NxU473EZ8jMw7ilfjSyi8mkX9r7VNHGELbj/bqGSadCCX6f1ulTfgyOvMo9Gj9o5pSMR8Y/jFeeC8uWJBuNoHQbqT+FI68xlteXk925jYQg9gfSoyO+kQjDKCD7wGadeKl8MflSxxfRIJd0kkaMD5sdc9qR3F3I0e+Mqr7ucpyfjTrDQvvkbQQxoxaQBnPKsw6fGkbXtyxbxHSQZHvdRR6KD+Qh9NeTJIE3oV9dtTr6gzArxwPutQsDM/kIN1JrV5WZtyPxkDv8aW/aFcebd9Wqiw6JvLs0vL0rAwYs2OF6ViGiY9VX+9TqdCOti+VjICeVyOw60xkSBl8nGOp+NMiTJ6W3jkBJaTg5x60zu7ZJU8hZTn3hT/AIT+ilIzCS0e2Jj3XrijraSK2YlOXHUnvU/7C8IAbqF2RiYydvZu9Mrq5nuMPHtBxggLR2HCNCyGB1QS7VbB97b7tMORapH+8YZywU7RWaJvGDSXPiJsWUbl9FNa3e1V3yw7VIwrbwaOIjgTXbmJN4ODu5O3rXy8TxXHhLtQHr8aUlxZ9XdIxZY1GMEj9azeN3AdJF2/eoBSa7Y3VQWUMcgqf51yd+0BSGY9MHvWobiZPlQdnug/nXSlpmJaJ1PY/GmRjk6FwWRpG8uBj51i28xhBG2WAJG349aBOJ+tba802/Zb22mhyGWMuuCeOoPcd/71FanfNdxQxzStM0Sg7j18yKcf81Uqtorm4x1Jhd21wbtFVmZZ4g7j1J4H8q1jaRbyO4eZfLsUKDzhTnmlmmp6OCsmhrf21pa6XaOyLG8seQwXJL7Scn5EKP71J4JJLi7ht3l2rEm1SOgG7JNRmbfZ14X/AOw+9j9EsL2Sa51S4VLNcnwy20HCgEn4ealdlObaW1xP5wjJMArL4bEnK/HnBpkn/p2xkwf977HntvYaJbzWyWy+NvDRhmldjwOAPN0pHZZDtqNwjGGzkbyjp4jcKv0G40zT12wy+bjyS1EmOo4X7MvRQgAHpzWE7loYt33MAfAcnFSr/qeUF384WW1zuY+CAPniuNdWRI7WRh5TDxU8S3sGYTgxXeUGFdW5+GOaMni8REZDllQMjevwpla/6sVXxN791/pqHys0cgKgjoDkj9KaaPpcd9oFvMT+8jyqt6EFSPyqF5owlFW+xVdWrxNqADMixyQ+UDg7iDVFqViZYroogLEQO2PQSMufwxUp8nf0fm/gouYVkkngVtrSTwx7Q39duacWNuq6uqNblsXUU3I9Vb/21rzLQbE2pWx3xMhwDJJIo/gCoAPzanMFit3qBtWyqPIAT2A3Yb/KBSz5GkY2JWt5jC6yMRwoKjtvG1V+gGarLexGp60lugUxs8lzJj7qhAkf4/8AVS5PMUS6F3sSW2nmW7n1OV2hjhjUsD1IwozVP+1V0s4rPSLRUCCFTKUXmQ/7FRwZq8juR96PONSHjXDOw94ByG7AnCr9BzVf7FWWmR30ut6q0M1tpwLvYs2w3L5wsIbG3jysR12Ka7lknGtV9An3uYWtECxkeImJSTyWUAfhhq2sLL7bqiJsSLx3Mj7BtEa85GPu4G7y/Wl5ByObmEQadaRYMckkZfafRnLn+Uf+Gi5EOpXbyopCsVgjUfdXGD+WB9aHfXYOuhbeoYTEY1cXLYkYHtnhFHyHP1qx0PRTevNI37uIP+8uAmSTjG1PjXNfmRHwI+EtoVrLFZ3dyQ+xAIyzffbNW15bwf0hb2VtGI7SyUlUBz5vVvXP5VP+Tz7Fomr7SxLe22nKMx2ygSf1pDy34HH+GqzS9MMkct7IwRQC5ZvU8DFJ/L4smecNbM7RjaPM0zct26Vc3mjwzcRxMFgQRoQvVTgtXRHl8kBDXIALlAuDsHvdyM07vNI2G2DB45J5DM+RjZEoUD/mqqyrWzUL9BsmvtRMTkxxqTJNIOqIBlj9Bk1TvYSWns5LLGghn1F/AUDqkCqWcn+6o/w1N5JfQ66Ed7fNf36/ZYBEkrJbW6dkQDgfPLZo6308wpDIkSrJbxNIX+JHA+i5P1o5wvg2zPWZIrjVb65ib9yZm8H/APbzgfpQZJWJ1xliMgfXrWp8mHIylnYFoydwGCK+Q2t1MfCjjzJL5c/Ac025kU1MriKSXzDrgfWh7rfH4isceE21R8citWmacySDwwF5wCT86zkB2xqvvAbn+fanMNxKd8oOR4agYHw4/WhHYtI4PUjmgBl9sJyysTujAwe1LTJ5/kxH5Vmh02vhRWt4beZQnlG3Zn1Ucj86TT3OZA/qT/KhStjrLaHUerOsriNiu1O3c0mhkVYhuOGLZB+FPxR1YfIpFBFqBLCaNSjIgjYDvzmg7FoyPOoWJOWz3+NHGTsWSq7HCX0u3e+FB6Fu9CCNblXIZkCINh3dflTzjRryWavqIV0Jkh2H1XvQs9os9yIbQqsYAJZ/XvVlE6EeSzaS/iEhKPGykchl4FA6nZmKUW0aDdCgVnXpuzk/lWpT+Bzt/Q2O4M5yqlVzgHtQtpM6SBbgFVxgANjNNrSBf/QmRXTcxYdP4uK+xyceIgZgDxntWLIv01z/AIZCeGJcqrH1IPGfhX19Pdmaa4UKvZVI5+dUVwJxs3tLtJMmPC4/4hbnNforFVwVYbWHAWt5R+Bxv9NHAmQ7WRAT19a/RSJErjxAGHAQhevrRsOPRlLZxEgtuOByRX77adh8RdnOAB3+NAh+h8LHPug4rh54ifKuDjr60AEFYgCfKy46elDRvty3mbPYLQ+h12fHVGcRonnJ9O1awk3TFIzt3dc1N5NIrOLZgyQbTvO5hxjdn8u1MZdNWFQdviMRSLKir8dia4VG9yJsAUd9mYOIwjbyemMcUyyoR4WLAk0q7EiYgd8VS2tnhSJmWEY90jP1o9w0+OSYtZt5yh49apNQSGKE+E0bn1zitWXZlYNdiKKAKrMWXGOnqa1nfCbivOeMdKbZByZbWPBLqvotcIZGJaNSF9F9a1MTgfPskAVvIdx54zk/OumlmztMT9O603IPWZxnwEOImAB5FcTSM3LAL2OFrOQcD89z4j4ii5x6UKY7onMEEnPRqDHB9uIhys8q89FHFCqojmJkjPi980COTXzRI6xQJj+JmrQySSHyqFwKA0BvaPhy+Rk5wOn0ogsiW7eMS5J4A9aA0A/Yi3QhT2yaMUwsBtO1iOhpQcgJtpI5A5LYHvk9B8qZyRlkaFwCH5A70E3Iu2hlA8RmCAkvtr4LaOJ23y5APCv2pWS4i1F2u5G3KkDitC227kZlXaXB/CqOThl7+mc4cQwHze7+tarcE31ojHKSrlx6YFJ/YesKf6dQBotSiJGFydw9Ad2TRDXxlfwyojA2xsU6smdx/KjsaEp62BzKysAUyRI0ZHz8wNFXt7bSNJHGjFt5cOf7KjH+WnhitbB5Vd1RDJhGnZiAM8+Vf1NaOVSNfe3I7fma2mn0NEtdj7Vn0K8iSO2lRLp8ICi4XOO4pFpfHtBa46rMhP8AiFReJL4a8rf0a2Nrbarpf2cXCx3sA8KISjaLnB7H7rj07ilN8WC8EqBeZGfXMlJp9iNoPhY20saTxustq4SeIjlRnA49CCOa4a5kvY0muj++jUxmQdQD069R8D7vUVjkTjsf+yLpEZ7FnHg3PniyvTg8Ukt5n24UgSxuChXuR3rjzYXaBVx6LO5uFh2M4bMgQMQOudy/zC0ovb0ahZx+DwHDxqD15DPn8RXNHj0jeQ3SRB7ReLKQoAifn0Kt/rSBtYILzKGPi2UQB9CpWteBtaDkUvs9cRS3M42ruiuiC231DYpFp18bKz1S435KO7KPUhiKW8Dqphfgci2/Z+Ema+1FwFWebajH+AGlOlXy6b7D2wL7DKgwPnljXF5OK8uf1/gcj9rQj1v2pleYO1uigsqdTzhV+ZK4+eaH/Z45m1aead/JC8bSN6eGGJP44rtmKwTwgpDNvaW0eG5t9Ahl8QQBzO4HLOfM7fTkD4Ka60iQ6trN/eyjHilVx6eI2SfoOPrWTkeNN0M3tgv2M2mh6jqhh8Myt4FupOCoJwT/AL/hNUvtVIk2o21gHHhRsQdq8jjzfgOP7xrJy1S5jJ6E3s5ooLQQz4CqrBs9jnL/AIeUfWqgWk1laLIU8K8uBvCKeIE8wUfPPNc2Tyay9INbObsKxGn2EbEwLjI4G8+8Se20cUut4ptQsH07TpPB00ee7vWPlcZ5wf4R2H3jzUPVWxGYaXatql++m2EuIRmS9vTyiIOyn+Z+90HGa61GUz2SaNoUbW2miRRPOw5uJM8GQ9vgvbrV5TSFGd1IDEotQF06E7V2nJlYd2P6Vgzw20AsLdEBLcKW6D72PnUGl+CP6dXi79LbAZw0pbI6EE4z9Kz0smXTfBEjKyyEhvSlSrZsg9zZtqOvwwFTGtwzyMG94KCQgHwA5/vURot2n9J3dxFtXA8MMW5VF5rq/txGNNfSKbVjasj/AGawgWFB/GzckfjtH0oS2vo4/G1ORN5Qt4MZ7u3A/wAJ5qMOuw0c+0ccVpGLGNgGMXiTHHJZx3+QrfS4rOztn1TWFE8sjbkiI6/H6U81Qyl/ol0f2fuL6NrkwmOFPfcnb9B86bz6jfa48hISC1i8sMQOEU9h8zVVWTQ6SAJYVjIitCqyKCHmAwkY/hA9R1zRGuiMQ/Z45lS1tsRk/wD6jdTRFbMZJX8X2q6DQBUt4j723JZvXHeqECGxtEv54TlARZ27jOT/ABNXTObS0KyZ1PT302eOJyRmIMAR1z8O1GTWF7PKL67LK12zYkY5Occ4HYAU85H+mE/Kg8bYfeNGz2u3UREpyqPgH+IDgfnVlknQAIQsSANxPSmdhp+5YnJbLuE47ZGKz2SMLXRzI6kbdi9KbWlkXjmnwxIDMpPcdB+db7JBACLIVfHRGz+VFfZGkmihBZUbaWx8q15JRWej9bv+6ESLgMDk+po9LTnHmVUPWk96Racmgy1haOCSRwoIAwV9fjRdtbbreKPcxLuST8KT+UVnIF2FsII93hIy5LRgKCTz5T+NMEjaZkiXcVEgIPy5/WkfmaLzkX6J5dNd7sop3bj5nPU5/wBKstOggErNKxIUeZR1I9Kz/wDQX4dEOKI6b2caUkKGchyC3pkV6GLcmNAiBSQMDueeKF/yFHTOCKR5fbaTNFdhEmDMeqn0r0qHSVMryiBevGOue+PjWvztjz4qRL6fpTyRBmCSNnAkBzn/AMVeW9n9lfb4aqJcFtq9vj8aT+VsssEo891TSZoYmeBQAOWKnbmrDV/ZlQJJrW4YBgWA9PWqR5K32xXgWukeV6iqeIzMzBgOmc8081vQZoCWDtuB4UdzXpYfIhr6cOXBX+E9bxu43MBlvX0olYlRiTFKyr1d24Bro9knN6mfJbX92Cpyx98LmvsrGWRVto9wIwcNxmj2SCwtmfhxyAbDtx1ZuufSmel6RdSTZAXJ646CoXmlHTj8ZmGn6TJLs2ll5zgr1q00/R7w7UJikx6Z4riryZR2z43ROrYbDIHvl3HpjqD6GvRtM9nFU+JM+4kdNufzqD8xbLR455Y0F3vxGdw5y4HFep6n7MwyQnk+GeSAeuKrHmSJXjs8gmKLu3IC44JDdaqtd9l3gDPFDKhPug/zrpjyIr4c1YqRHlgRhI/DJ7Zz9a0u7eaymIk6geldMtUjnapAUqyg535x2znNbw3UBYmWLPwRuvzoYugjTNZ1CxgNtbTCOEnJBjUjNcfaLIAslqzH/wC5ICBSfocTi/vri6Vmk8FWPVo4wpP4VjOzuhaK3YKDyYxxToAbRRDHqMcl45KDJYbc89q6iSQlkaPykc460z+CpNDuSfQZVY4j+OE5+tTkscSgYhZd4PO080qx7GeTX4aX0FmC5hkQd1wtY26xhiGQcfxU6/qQf9jELM+BErN60TII3GC4VfRTW7M4AksJRFYFg2DkUUFtwQsca8nBZhmjkCgVH96SVVgw42+tUUenvMm4RqAg4K96zka4JwGTO0yNgf8ADK9V+dMr2zeHJVPLnndRyJuOgE28rL4xkGR3NZSnYP3ICknzqfT1FKScikNtTeegALfKsJgTZrGh5dNo+pWun8PLUn2BidQsie8SkfLaa7VDHqEC/wACMD88VJjM+h1+1Ptb5n+8KGjUC/Jba4KNtBPvHHX6U8/BQmDTr54mu0srh4SSA/hkgn4VdaD7V22nezkMc0DKyYjVN3mIAySPh3/vVL2Nfh6mHxsFxur0RI81uN6lXErZGMEc/wDejNd1NtYu5dRdBECVVFB5PHeqQnS3o4rmcb1FbMdFJX2mt2ZvKrA/lQ+myMuqGU5zkrwfhWPsid3jmWCSMR8tM0jeX14BrOxuvGRRlvEXnnnA5pOANbCNPkMULjGSVIA/s8/7/s1wOXMCvsb3ip+9WOSetBNg3h3CoTkIwIP8SHr+DUPOxjlhlHAzhh8Km52jVQwsLxY50hY+5Px8ij0mmHgaijndscjFLOLSGY748C3zt3CU27fIqGoeUnzl+paJx/aIYfyFDSQn6fYZ82d3IX3CVGcA/E/9qCtyTp8wPQoM/wD+Q1rUjj2+vN1hbQK7eFbwhjluM+lJrpgNOKFvPIQopFilvYFXp94dP9nXCnM12gyfizMSPwNTt/dMbXMbf8ONUT50tYk6M7K72b1YWFoHjwzl/GLDqNq4X880k0UpZWLTzguAQqof/qHrWZcUL6HZb+xksMWqTaxrBMlrZ8IiL/xZm+4v/N9Kjn1SeRo7UnLsxlcD7pbn+VceTxqyfP8AqNz4Hokt1c+0WpfZTOqRufGvbhD5SO5B/h7KPTFT2maklppMkYPnnPnb+Jew/H/mrn/iJdYw9uyi1OddYlOjafi10m2AMsx8oVR95h2Pp61MLqUuoxGxtSIbOM+LM5PEjHjezdz2App8bgL7BxO2l6flNJJeONTmQuf3snctSqe7tLaEbctHH/w1K8yt6/KsePbDnsYWF1dNcNNMqKQuFwOuaWWWpzzpPLIqpHEMhaV4f/ggxe7eDT5tkirK7HB/hXuaVLOJrOGMAys7DeB2XPP5Unr096NQ4in+yaDODtSWZlyP/uEcD6daSaxcTLgJbtNsBZf6zE4/KnmOY/ILlu4QttbY8iumF9QBn+dJoZLlruaR4GEyqMJ6VVYtIOQ31e/lv5kt8Et0IHYUhs2mjuDIC7ZJ3lR7lPGI1UVEl99ktFtbZ8bX3PtPLPjg/Q0ljjlmkjESbgT53fhSewH61lYtD8uh/ZzQwWkcl6RulkMgiVcsxPHWk2pR3lu8VxcllZ1Phq68hB0I+Gax4dmKh3M8t9doJ0VUjUyCINxk9M/GlMc4toE8R2aaUFnPwqbxaHVDi9PialHaxyKYYISWIb3twzj+VT7X7T6nOwO1W8oX14rYikAdDbGO6ExCuxVyB8QeKztLxN9tub7hgf554rHtMwI0YKY/BkCb0eNcD4c0NaFzPNjoHO7PXouKxghhGNmnxI3mDzYJ/wDtruOK+rKrvEp8yp4kuD3J/wDNRbY6NrezSGykuMRtJMcKT2Y8/wAq7v8AKqtu7YMMOXPox/7UiqhkAXCOschz5k9K3u+Z7iAltxIOB6Y606pjr4MIwVmiQryIufwrmKYG9VuOIUx68ClfZqoY2k6QB5tqlsu48vp5aXzXHhrHCdzNu25Hp1/6qRwOqGlreObhIy/vwkE/LnH86QSXi28EJkbDPHtAHxBpeI3saL6yula2d2lUMSHDHsOlSNhqvjWfhBhvzJjP9s0cdHTi89x0eg6XOs7xRxFdiAeI5XgnPFTlpqH2fSokUKFK4xjOWJpuK/D0cXlc2WFtunuHcELGjYIXvSzTrr/08SKu1wM7sY+lHBnoQtrZQm2i5woLkZII7UqttUYvLHtyEOCTSqdD6FeuWU1xL4dsiySMeWzjaKdpJGINgZXLHJBqk3oOJ5lrFi8U7K6/vD1wQ1XN3oNvLvLL4e/ncOldePytCPx+R51awCCXMnm74xiqDXrGC3xDbjzDk7hkH4iq+/mI8HE+WGorbsVSzUkYxt6fP50Ja9VGxGZSDyrD8qVtGzLK3RtWMtx+/i2MSFUetLYklkmS4W1QOo4UnIPyHaoPRZTWi9tp3dlCwdfSpS11pYI1L2sjFjguWwGNR4hqi4W5toU33axJg8Dqfw71IXGrePAjy2/h8AKof49a1Sg40z77Ue0lnI8ot4jsXgsRx9B2qW1q2+1z7oVDZPIRm3CujFEJmNXKEGt3CXsrERsQO5WstT0meJSzIw39BnJr0cVQjgyxdMQXUKtKNwAYHghRnFFiwUSgSqWz2L4rpeSUc/ppi2azi8TET7geoC8g1RWVvEikrCQrHBYHP0pHnlAvGpsT6ZDHFMFKljkdTiqs2AaMeVQpHClM5qVZ+RePG4jHQbLS7uPKFFmUc4oC1064jlDWzMhb1PH0Pb5VzU2zoiUhrqvsrAkLyPPHgcjIoJdP1K4k/eRyNzjqx+tTV1P/ALDvHNf+oh/oI/aD4W2VueAO1VVjaS27mOSaG255Ak5Pxp15VL9Efiy/wm/6EAXEiRvKBwqnBHzq6ujp1tY4aPc55LA7s/Gj+TTYLxZR5hd2a2kiv9nVWQ/xU+19rLYxiHJ55OK6MWSqOfJhSJkalJC5CxKuf61A3Uo3ttGeeldak4zq6vJJ8hjtXPPm7UDJceowRVFJN/DF4UZvcJJzgjuK6LsTjawzzn1rSbP/2Q==";
}