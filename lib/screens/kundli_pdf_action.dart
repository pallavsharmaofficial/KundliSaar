import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';

import '../engine/astro/ayanamsa.dart';
import '../engine/jyotish/chart.dart';
import '../kundli_pdf/delivery/deliver.dart';
import '../kundli_pdf/delivery/kundli_pdf_service.dart';
import '../kundli_pdf/kundli_pdf_password.dart';
import '../models/saved_profile.dart';

/// Makes the PDF for a chart; the real one is [makeKundliPdf].
typedef KundliPdfMaker =
    Future<KundliPdfFile> Function({
      required BirthData birth,
      required Ayanamsa ayanamsa,
      required DateTime now,
      void Function(String stage)? onStage,
    });

/// Hands a finished PDF over; the real one is [deliverPdf].
typedef KundliPdfDeliverer =
    Future<void> Function({
      required Uint8List bytes,
      required String fileName,
      String? subject,
      Rect? origin,
    });

/// The "download the full kundli as a PDF" action: ask for the password, make
/// the book on this device with a progress dialog on screen, then hand the file
/// to the platform's share or save sheet (a plain download in the browser).
///
/// The password is asked for here before anything is made, and the file is
/// encrypted with the same one, so it asks again wherever it ends up. Both read
/// [kundliPdfPassword], which is a placeholder gate and not real secrecy.
Future<void> downloadKundliPdf(
  BuildContext context, {
  required SavedProfile profile,
  required Ayanamsa ayanamsa,
  required bool hindi,
  @visibleForTesting KundliPdfMaker maker = makeKundliPdf,
  @visibleForTesting KundliPdfDeliverer deliver = deliverPdf,
}) async {
  String t(String hi, String en) => hindi ? hi : en;

  // Where the share sheet should point on a tablet.
  Rect? origin;
  final RenderObject? box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  }

  final bool allowed = await _askPassword(context, hindi: hindi) ?? false;
  if (!allowed || !context.mounted) return;

  final ValueNotifier<String> stage = ValueNotifier<String>(
    t('शुरू हो रहा है', 'Starting'),
  );
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  // Not awaited: the dialog stays up while the work runs and is closed below.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(t('आपकी जन्म पत्रिका बन रही है', 'Making your janampatri')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 18),
            ValueListenableBuilder<String>(
              valueListenable: stage,
              builder: (BuildContext context, String value, Widget? child) =>
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'कुछ सेकंड लगेंगे। सब कुछ आपके इसी उपकरण पर बन रहा है; कुछ भी कहीं भेजा नहीं जाता।',
                'This takes a few seconds. Everything is made on this device; nothing is sent anywhere.',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  KundliPdfFile? file;
  Object? failure;
  try {
    file = await maker(
      birth: profile.toBirthData(),
      ayanamsa: ayanamsa,
      now: DateTime.now(),
      onStage: (String s) => stage.value = s,
    );
  } catch (e) {
    failure = e;
  }
  navigator.pop();
  stage.dispose();

  if (file == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          t(
            'PDF नहीं बन सकी। फिर कोशिश करें।',
            'Could not make the PDF. Please try again.',
          ),
        ),
      ),
    );
    debugPrint('kundli pdf failed: $failure');
    return;
  }
  try {
    await deliver(
      bytes: file.bytes,
      fileName: file.fileName,
      subject: t('जन्म पत्रिका', 'Janampatri'),
      origin: origin,
    );
    if (kIsWeb) {
      messenger.showSnackBar(
        SnackBar(content: Text(t('PDF डाउनलोड हो गई', 'PDF downloaded'))),
      );
    }
  } catch (e) {
    debugPrint('kundli pdf share failed: $e');
    messenger.showSnackBar(
      SnackBar(
        content: Text(t('PDF सहेजी नहीं जा सकी।', 'Could not save the PDF.')),
      ),
    );
  }
}

Future<bool?> _askPassword(BuildContext context, {required bool hindi}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _PasswordDialog(hindi: hindi),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.hindi});

  final bool hindi;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _wrong = false;
  bool _hidden = true;

  String t(String hi, String en) => widget.hindi ? hi : en;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim() == kundliPdfPassword) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('पासवर्ड डालें', 'Enter the password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            t(
              'पूरी कुंडली की PDF बनाने के लिए पासवर्ड चाहिए। बनने के बाद फ़ाइल भी इसी पासवर्ड से बंद रहेगी।',
              'A password is needed to make the full kundli PDF. The file itself stays locked with the same password.',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _hidden,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_wrong) setState(() => _wrong = false);
            },
            decoration: InputDecoration(
              labelText: t('पासवर्ड', 'Password'),
              errorText: _wrong
                  ? t('पासवर्ड ग़लत है', 'That password is not right')
                  : null,
              suffixIcon: IconButton(
                tooltip: _hidden ? t('दिखाएँ', 'Show') : t('छिपाएँ', 'Hide'),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('रद्द करें', 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(t('आगे बढ़ें', 'Continue')),
        ),
      ],
    );
  }
}
