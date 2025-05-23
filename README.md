# kardi notes | privacy matters
<p>Application for taking notes with capabilities to view all content from any device while keeping all data accessible by you only. The app is designed to run on all modern operating systems including Windows, Linux, Android, MacOS and iOS along with a web version accessible directly from any browser. Download on your phone, save important information, download on your computer, easily pair the applications and enjoy your content from anywhere!

No ads, no telemetry, no logs.

Application is easy to use, mostly self explanatory with hints and example in case you get lost. Please note, if you forget your password or lose your device, all your data is lost and cannot be recovered. App contains multiple safe mechanisms to prevent undesired behaviour such as overwriting notes that have been changed from other device.</p>

More information can be found at https://www.kardi.tech/#notes<br>
Detailed update log can be found at https://www.kardi.tech/notes/<br>
Privacy policy can be found at https://www.kardi.tech/privacy-policy/<br>
Source code for the server logic is in [this repository](https://github.com/rikodot/kardi_notes_api)<br>

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/github.rikodot.kardi_notes/)
[<img src="https://play.google.com/intl/en_us/badges/images/generic/en-play-badge.png"
     alt="Get it on Google Play"
     height="80">](https://play.google.com/store/apps/details?id=github.rikodot.kardi_notes)
     
<em>`* app removed from google play as I refused to publicly share my private information (address, name, etc.)`</em>

## Windows app flagged as malware
This is a false positive, explained in detail in [this issue](https://github.com/rikodot/kardi_notes_app/issues/8). You can contact me directly to get unpacked files for windows, which are not flagged as malware, but this process have some downsides. If you are interested, read the mentioned issue. Thank you for understanding.

## Building
You might need to [setup signing](https://docs.flutter.dev/deployment/android), as `key.properties` and `upload-keystore.jks` files are omitted from the source control.

## Donations
- btc: `bc1qz6uws8vxz7renadfy5lchmtj99tvd3gr8t9856`
- eth: `0x4bfD4f0e445160C5056aDc3a9A994C2e35e1a8c7`
- ltc: `Lds4TLCW6GNcbTw3AwwvCGsrNCZjWX5SpU`
- xmr: `41qXA5Ht5tsM7hoBoXBccYLHBETudvk7sGxsffgzrAptE9QNyHmLm8XDby9cL2umSaRvbmvvH8SxgHyDXEh2x19WHB5HwRE`
<p>All donations are used to cover production and development expenses.</p>


## TODO
- [ ] have to cancel old search to perform a new one
- [ ] missing webview activity and access network state permission??
- [ ] option to export owner key and some debug logs even in the loading screen
- [ ] consider moving config somewhere where android does not delete it when uninstalling the app
- [ ] option for longer notes - separate db table only with longer content and normal table would have nullable long_note_id
- [ ] search on phone does not scroll to result but selects it
- [ ] dev web page to view feedback and send messages
- [ ] note content & feedback content limit 65535 - we limit to plain 40000 and check if encrypted 65535 - stop 40k check and do better > 65535 error so user knows
- [ ] no need to send passwords to the server
- [ ] option to highlight text in notes
- [ ] different update link for fdroid, apk and google play
- [ ] create new note -> spam save button fast -> go back -> multiple same new notes (only locally)
- [ ] add android:allowBackup flag and set to false so people cant copy the data from the phone using adb
- [ ] when setting custom url (in settings or loading screen), verify if it is correct before saving
- [ ] more verbose error messages in versionCheck (not always "notok")
- [ ] better internet connectivity check (maybe also check if can connect to api)
- [ ] optional log file of actions with ability to upload to server
- [ ] (happens only sometimes) new note -> save & go back -> move new note -> refresh notes -> the note that should have been first is moved (maybe to its original position based on creation date - not sure at all)
- [ ] (happens only sometimes) new note with title and no content -> save & go back -> refresh notes -> false positive changes found
- [ ] closable alert cant be closed by clicking horizontally next to it (diagonally or vertically works)
- [ ] site css & js fix - a lot of useless properties, messy code, slideshow can only be once on site, problem if height too low etc etc
- [ ] dragdown to refresh and dragup to navigate -> false positive when moving note with new system
- [ ] dragdown to refresh and dragup to navigate -> probably false positive when scrolling up and down on phone (not tested)
- [ ] dragdown to refresh and dragup to navigate -> if no notes, make sure the text widget takes the whole screen so dragging works
- [ ] unify capital letters, alert buttons, code style, fonts etc
- [ ] change package name when debugging so it does not replace original like add _dev and for google play remove it?
- [ ] bug: on smaller logical ppi settings custom api and scale put on separate lines or smth
- [ ] floating action button - right now i use padding 70px to make sure it is not over some text, find a better way
- [ ] `onPressed: ()` etc can be async e.g. msgs pop ups, might be easier than `.then()` I surely used many times and is not blocking UI
- [ ] reset notes order button: set all last/next keys to null and first element to null, should force order by creation date
- [ ] rename package to tech.kardi.notes
- [ ] smooth edges of content text field in the editor page
- [ ] server insert sql if unique fail (right now just errors out the result)
- [ ] if session not found init new one so possible changed content is not lost and dont have to restart the app
- [ ] post quantum encryption
- [ ] option to participate in beta features
- [ ] study flutter decompilation & obfuscation
- [ ] when green alert is shown, and new one should be shown, dont wait for the old one to finish but stack them vertically on each other
- [ ] scale of notes on main page and scale of text (and images or whatever)
- [ ] green comments
- [ ] script or something to purge sessions and requests from database periodically
- [ ] too many api fails from ip -> timeout AND OTHER API RATE LIMITS
- [ ] initSession() add request_id cuz could spam api? maybe?
- [ ] text not all the way down (buttons are over it - maybe?)
- [ ] blur all option + individual option (when all on -> all individuals on but can turn off individual)
- [ ] offline mode (if changing note offline, save hash of the unedited version (last online version) and when back online check for mismatch (old online version + our offline) but idk when, maybe on startup, maybe when accessing note, maybe when saving the note)
- [ ] blur linking devices owner key with unhide toggle button
- [ ] option to wipe all data from server automatically
- [ ] automatically fetch new notes in the background with option to disable
- [ ] toggle animations option
- [ ] new owner key -> has messages -> opens message -> goes back using android back button, not the icon back button in app -> still shows unread messages on messages page button (does not update ui)
- [ ] last access time, last edit time ??
- [ ] test delete note and then on other device edit the deleted note or smth
- [ ] test open app, delete session and what happens?
- [ ] qr to transfer owner key (buttons: show qr and scan on other device to import there, show qr and scan on other device to import here (for pc), scan qr)
- [ ] mby dont call setState inside of @override initState? e.g. editor_page.dart
- [ ] highlight mismatch alerts with red color
- [ ] color not saved when note not saved yet
- [ ] background checks are a complete mess - false positives, rework completely possibly
- [x] password on startup that is used to encrypt owner key (if somebody stole the phone and knew what he was looking for, this would prevent him from decrypting notes)
- [x] fdroid first startup entering custom url goes out of boundary and bugs out
- [x] Navigator.push() -> Navigator.pushReplacement() ?? will back button on android still work? (right now we end up with multiple instances over each other - not documented probably) (https://docs.flutter.dev/ui/navigation)
- [x] custom button color
- [x] allow back button on phone, definitely pop context before changing to new page cuz memory leak or just too many opened after some time?
- [x] settings page needs white bg on the bottom just like edit page because on phone if setting custom api keyboard moves it up and it overlaps
- [x] send feedback close the prompt
- [x] replies and feedbacks do not sort together
- [x] find text in note
- [x] error checking version sometimes (update 2024: still?? maybe not)
- [x] multiple versions of api so no need for version check
- [x] handle.php some requests do not check if all values are provided (e.g. msg_seen)
- [x] probably should check owner key in all requests, rn if user guesses note key, he can e.g. change blur state of other notes he does not own (actually cant but for double safety)
- [x] when scale changed new reordering notes pretty buggy - after app restart works pretty much ok
- [x] stats (how many notes, total amount of words in all notes)
- [x] on android the first note disappears when floatactionbuttons open????? and also does not flush??????
- [x] scaling does not seem to apply after restarting the app even though it is saved
- [x] when moving note with new system and is holding at top/bottom - scroll up/down automatically - cursor must be moving otherwise it stops
- [x] password on notes (new note set locally only if not created on server yet; dont ask for the password for 5 minutes after closing the note; encrypt content with password)
- [x] make new note, save, go back and download all notes -> shows changes (should not)
- [x] loading_page if `Error loading data` in loadNotes() after Navigator.push(...) near `//well I did it somehow` comment then whole screen is broken, also flashes black screen even if it works good
- [x] show creation date in both msgs and notes
- [x] data_sync json assigning fix lol
- [x] save all settings in cloud
- [x] double delete confirmation
- [x] copy colors of notes
- [x] letter count
- [x] add measures to stop (probably google's) bots from spamming the server
- [x] captcha if config file does not exist (only once, to prevent bots spamming the api)
- [x] make captcha closable so user can change server
- [x] fix errors in loading screen not being closable
- [x] messages tab (so i can send msgs to individuals or all but not as announcements)
- [x] feedback button
- [x] move notes (add index field to db should be enough?)
- [x] disable http errors in php for production
- [x] random Unhandled Exception: 'package:flutter/src/painting/text_painter.dart': Failed assertion: '!_debugNeedsLayout': is not true.
- [x] some alerts account for user clicking "OK" but they also have close `x` button top right account for what happens when they click the close button
- [x] msg white number in red circle in top right corner on msgs button
- [x] `"creation_date": DateTime.now().toString()` instead make sendFeedback return timestamp
- [x] replace \r upon inserting text into textfield not at saving yes (should also fix false positive mismatch - copy text with \r, save, change, save - mismatch)
- [x] msg show pop up all msgs to be shown at once and when hit ok set show pop up to false
- [x] owner key hashing so actually cant be decrypted from server
- [x] different api for dev and prod
- [x] announcements
- [x] save settings to file no encrypt i guess
- [x] php !isset() on fields that can be 0, "0" etc, empty() on those that cant
- [x] `Data can’t be deleted` in google console in app content in data safety
- [x] group buttons
- [x] loading fix two different loading circles to only one
- [x] sort msgs and feedback in reverse order (do client side)
- [x] fix cursor jumping to beginning on some new lines
- [x] auto update
- [x] custom color
- [x] encrypt all data in traffic (key, ownerKey)
- [x] DH key exchange for encryption key on each connect to avoid MITM
- [x] json config file instead of multiple files (if custom api enabled, save it and load it automatically)
- [x] purple-ish default note color
- [x] swipe down = refresh notes, swipe up = messages page
- [x] cant reproduce, maybe fixed: have some notes, create a new one with some content, save, go back, open the note again, edit, try to save - mismatch alert (false positive)
- [x] bug: create a new note, save, edit, save - it will be on the end instead of the beginning (fixed on app restart)
- [x] bug: downloading notes does not seem to work (make changes on other device)
- [x] on save new note dont make duplicates
- [x] on save check if there is mismatch (e.g. edited note on pc, then intending to make edit on phone but note is not updated)
- [x] icon and branding
- [x] add settings to loading page
- [x] php `foreach ($msgs as &$m)` make efficient this is bad (multiple instances)
- [x] fix saving new note
- [x] test on phone (update button no work + cant install??)
- [x] single note download when open button
- [x] downloading notes check if any changes were found in alert
- [x] branding fix a bit
- [x] android selecting text is buggy if cursor not placed
- [x] each note last download time and if >5min, download again in background and if mismatch show alert
- [x] downgrade/upgrade button add blank line below if there is ignore button cuz buttons are weirdly touching
- [x] owner key remove letters such as Il, 0O and other that are difficult to differentiate
- [x] send feedback diff button
- [x] make option toolbar scrollable if screen not high enough
- [x] ```'Failed to change the color.'``` press OK button is exception, maybe same for blur?
- [x] update last check times even if getting the data fails (preparing for offline mode)
- [x] when opening note, does cron from all notes page end?
- [x] in background task check if all the double ```Navigator.pop(context);``` work there when password changes
- [x] test cron on phone, set to every minute, open note, close phone, open phone after 5mins, what happens? also maybe leave note app in background but phone open
