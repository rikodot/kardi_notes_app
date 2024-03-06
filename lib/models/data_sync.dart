import 'dart:ui';
import 'package:deepcopy/deepcopy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:http/http.dart' as http;
import 'package:mutex/mutex.dart';
import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
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
  static String CURRENT_VER = "2.0.5";
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
  static bool show_dates_notes = true;
  static bool show_dates_msgs = true;
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
}