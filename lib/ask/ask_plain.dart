import 'answer_model.dart';

/// The refusal. Its words are exactly the ones the app has always used: a
/// richer way of answering must never be a way past it, so nothing here
/// explains, softens or offers a "closest" reading.
Answer refusalAnswer(bool hindi) => Answer(
  title: hindi ? 'यह मैं नहीं बता सकता' : 'I will not answer that',
  sections: <AnswerSection>[
    AnswerSection(
      key: SectionKey.plain,
      heading: '',
      paragraphs: <String>[
        hindi
            ? 'यह ऐप मृत्यु, बीमारी, गर्भ, मुकदमे या निवेश के बारे में भविष्यवाणी नहीं करता। ये विषय किसी योग्य व्यक्ति से पूछें। कुंडली के बाक़ी हिस्सों के बारे में बेझिझक पूछिए।'
            : 'This app does not predict death, illness, pregnancy, court cases or investments. Those belong with a qualified professional. Ask me anything else about the chart.',
      ],
    ),
  ],
  basis: const <String>[],
  isRefusal: true,
);

/// For a question the app cannot place. It names no chart factor and carries
/// no closing line, because it explains nothing.
Answer notYetAnswer(bool hindi) => Answer(
  title: hindi ? 'अभी इसका उत्तर नहीं' : 'Not yet',
  sections: <AnswerSection>[
    AnswerSection(
      key: SectionKey.plain,
      heading: '',
      paragraphs: <String>[
        hindi
            ? 'यह सवाल मैं अभी आपकी कुंडली से नहीं पढ़ पाया। नीचे दिए सवालों में से कोई चुनिए, या उसी बात को दूसरे शब्दों में पूछिए। मैं दशा, योग, विवाह, काम, पैसा, पढ़ाई, उपाय और आपका अच्छा समय कब आएगा, इन सब पर बात कर सकता हूँ।'
            : 'I could not read that one from your chart just yet. Pick one of the questions below, or ask the same thing in other words. I can talk about your dasha, yogas, marriage, work, money, study, remedies, and when your better time comes.',
      ],
    ),
  ],
  basis: const <String>[],
  isFallback: true,
);
