/// The password the kundli PDF asks for, and the one it is encrypted with.
///
/// THIS IS A PLACEHOLDER GATE, NOT REAL SECRECY. It is a compile-time constant,
/// so it ships inside the app bundle: anyone with the APK, the IPA or the
/// browser build can read it. It is also only eight digits, so the encrypted
/// file itself falls to a short brute-force run. What it does is make the app
/// ask before it makes the file, and make the file ask again wherever it ends
/// up; it does not keep a determined person out. Change it here and nowhere
/// else: the in-app prompt and the PDF encryption both read this one name.
const String kundliPdfPassword = '13061996';
