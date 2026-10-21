import 'palm_scan.dart' show Say;

/// The words on the camera screen that depend on where it is running. A phone
/// app and a web page make different promises about where the picture lives
/// and ask for the camera in different ways, and the screen must not say
/// "this phone" in a browser or send someone to the phone's settings from a
/// web page. Both languages, here, so a test can hold each to both.
///
/// The phone's words are exactly what the app has always said.
class CaptureCopy {
  const CaptureCopy({required this.web});

  final bool web;

  /// The one line that sits under the camera and on every waiting screen.
  Say get privacyShort => web
      ? const Say(
          'Your photograph stays in this browser, on your own device. Nothing is uploaded.',
          'आपकी तस्वीर इसी ब्राउज़र में, आपके अपने डिवाइस पर रहती है। कुछ अपलोड नहीं होता।',
        )
      : const Say(
          'Your photograph stays on this phone. Nothing is uploaded.',
          'आपकी तस्वीर इसी फ़ोन में रहती है। कुछ अपलोड नहीं होता।',
        );

  /// The fuller promise on the first screen.
  Say get privacyLong => web
      ? const Say(
          'Your photograph is looked at inside this page, on your own device. It is never uploaded, never saved, and gone when you leave this screen. The files that find your hand come from this website itself, not from anyone else.',
          'आपकी तस्वीर इसी पेज के अंदर, आपके अपने डिवाइस पर देखी जाती है। न अपलोड होती है, न सहेजी जाती है, और इस स्क्रीन से निकलते ही मिट जाती है। हाथ पहचानने वाली फ़ाइलें इसी वेबसाइट से आती हैं, किसी और से नहीं।',
        )
      : const Say(
          'Your photograph stays on this phone. It is looked at on the phone itself, never uploaded, never saved, and gone when you leave this screen.',
          'आपकी तस्वीर इसी फ़ोन में रहती है। उसे फ़ोन पर ही देखा जाता है; न अपलोड होती है, न सहेजी जाती है, और इस स्क्रीन से निकलते ही मिट जाती है।',
        );

  /// How to hold the hand, first step.
  Say get holdStep => web
      ? const Say(
          'Open your palm toward the camera, about a foot away, fingers up. A laptop’s webcam works; on a phone the back camera is used if the browser allows it.',
          'अपनी हथेली खोलकर, उँगलियाँ ऊपर करके, कैमरे के सामने लगभग एक फुट दूर रखिए। लैपटॉप का वेबकैम चलता है; फ़ोन पर ब्राउज़र इजाज़त दे तो पीछे का कैमरा इस्तेमाल होता है।',
        )
      : const Say(
          'Hold the phone in one hand. Open your other palm toward the back camera, about a foot away, fingers up.',
          'फ़ोन एक हाथ में पकड़िए। दूसरी हथेली खोलकर, उँगलियाँ ऊपर करके, पीछे के कैमरे के सामने लगभग एक फुट दूर रखिए।',
        );

  /// Why the camera is wanted and who will ask for it.
  Say get cameraAsk => web
      ? const Say(
          'The camera is used only here, only to look at your palm. Your browser will ask your permission when you open it, and you can take it back any time from the camera or lock icon beside the address.',
          'कैमरा सिर्फ़ यहीं, सिर्फ़ आपकी हथेली देखने के लिए इस्तेमाल होता है। इसे चालू करने पर ब्राउज़र आपसे अनुमति पूछेगा, और आप कभी भी पते के पास के कैमरा या ताले वाले निशान से उसे वापस ले सकते हैं।',
        )
      : const Say(
          'The camera is used only here, only to look at your palm. Your phone will ask your permission when you open it.',
          'कैमरा सिर्फ़ यहीं, सिर्फ़ आपकी हथेली देखने के लिए इस्तेमाल होता है। इसे चालू करने पर फ़ोन आपसे अनुमति पूछेगा।',
        );

  /// Said on the first screen of the web build only: the hand detector is a
  /// download, and the person should know before it starts.
  Say? get downloadNote => web
      ? const Say(
          'The first time, your browser fetches the hand-finding files from this site: about 17 MB, once. They run on your device; your hand is never sent to them or from them.',
          'पहली बार ब्राउज़र इसी साइट से हाथ पहचानने वाली फ़ाइलें लाएगा: लगभग 17 एमबी, एक बार। वे आपके डिवाइस पर चलती हैं; आपका हाथ न उन्हें भेजा जाता है, न उनसे कहीं जाता है।',
        )
      : null;

  /// Shown while the camera is being started.
  Say get startingCamera => const Say(
    'Starting the camera…',
    'कैमरा शुरू हो रहा है…',
  );

  /// Shown, on the web, while the hand-finding files come down.
  Say get loadingDetector => const Say(
    'Loading the hand detector… about 17 MB, first time only',
    'हाथ पहचानने वाला हिस्सा आ रहा है… लगभग 17 एमबी, सिर्फ़ पहली बार',
  );

  Say get deniedTitle => web
      ? const Say(
          'The camera is blocked for this page',
          'इस पेज के लिए कैमरा बंद है',
        )
      : const Say(
          'The camera is off for this app',
          'इस ऐप के लिए कैमरा बंद है',
        );

  Say get deniedBody => web
      ? const Say(
          'The palm cannot be read automatically without it. Click the camera or lock icon beside the address, choose Allow for the camera, and try again, or trace your palm by hand. Nothing is lost either way.',
          'इसके बिना हथेली अपने-आप नहीं पढ़ी जा सकती। पते के पास के कैमरा या ताले वाले निशान पर क्लिक करके कैमरे को ‘अनुमति दें’ चुनिए और फिर कोशिश कीजिए, या हथेली हाथ से अंकित कीजिए। दोनों तरह कुछ नहीं बिगड़ता।',
        )
      : const Say(
          'The palm cannot be read automatically without it. You can switch the camera on in your phone’s settings, or trace your palm by hand. Nothing is lost either way.',
          'इसके बिना हथेली अपने-आप नहीं पढ़ी जा सकती। आप फ़ोन की सेटिंग में कैमरा चालू कर सकते हैं, या हथेली हाथ से अंकित कर सकते हैं। दोनों तरह कुछ नहीं बिगड़ता।',
        );

  /// A web page has no settings screen to send the person to.
  bool get offersSettings => !web;

  Say get unavailableBody => web
      ? const Say(
          'No camera could be started. Another app or browser tab may be using it, or this device may have none. Close whatever else is using the camera and try again, or trace your palm by hand.',
          'कोई कैमरा शुरू नहीं हो सका। शायद कोई दूसरा ऐप या ब्राउज़र टैब इसे इस्तेमाल कर रहा है, या इस डिवाइस में कैमरा नहीं है। जो भी कैमरा इस्तेमाल कर रहा हो उसे बंद करके फिर कोशिश कीजिए, या हथेली हाथ से अंकित कीजिए।',
        )
      : const Say(
          'Another app may be using it. Close other camera apps and try again, or trace your palm by hand.',
          'शायद कोई दूसरा ऐप इसे इस्तेमाल कर रहा है। दूसरे कैमरा ऐप बंद करके फिर कोशिश कीजिए, या हथेली हाथ से अंकित कीजिए।',
        );

  Say get modelsTitle => web
      ? const Say(
          'Hand detection could not start in this browser',
          'इस ब्राउज़र में हाथ पहचानना शुरू नहीं हो सका',
        )
      : const Say(
          'Hand detection could not start on this phone',
          'इस फ़ोन पर हाथ पहचानना शुरू नहीं हो सका',
        );

  Say get modelsBody => web
      ? const Say(
          'This browser may be too old, or the hand-finding files did not finish coming down. You can try again, or trace your palm by hand, and it will be read the same way.',
          'हो सकता है यह ब्राउज़र बहुत पुराना हो, या हाथ पहचानने वाली फ़ाइलें पूरी न आ पाई हों। आप फिर कोशिश कर सकते हैं, या हथेली हाथ से अंकित कर सकते हैं, और पढ़ाई उसी तरह होगी।',
        )
      : const Say(
          'You can still trace your palm by hand, and it will be read the same way.',
          'आप फिर भी हथेली हाथ से अंकित कर सकते हैं, और पढ़ाई उसी तरह होगी।',
        );

  /// A failed download can be tried again; a phone that cannot run the models
  /// cannot.
  bool get modelsCanRetry => web;
}
