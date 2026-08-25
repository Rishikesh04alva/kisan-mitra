class CropOption {
  final String prefix;
  final String emoji;
  final Map<String, String> names;
  final List<String> aliases;

  const CropOption(this.prefix, this.emoji, this.names, this.aliases);
}

const List<CropOption> kCropCatalog = [
  CropOption('Tomato', '🍅', {
    'en': 'Tomato', 'hi': 'टमाटर', 'mr': 'टोमॅटो', 'kn': 'ಟೊಮ್ಯಾಟೊ',
    'ta': 'தக்காளி', 'te': 'టమాటా', 'ml': 'തക്കാളി',
  }, ['tomato', 'tamatar']),
  CropOption('Potato', '🥔', {
    'en': 'Potato', 'hi': 'आलू', 'mr': 'बटाटा', 'kn': 'ಆಲೂಗಡ್ಡೆ',
    'ta': 'உருளைக்கிழங்கு', 'te': 'ఆలుగడ్డ', 'ml': 'ഉരുളക്കിഴങ്ങ്',
  }, ['potato', 'aloo', 'batata', 'urulaikizhangu', 'alugadda']),
  CropOption('Pepper,_bell', '🫑', {
    'en': 'Chilli / Capsicum', 'hi': 'मिर्च / शिमला मिर्च', 'mr': 'मिरची / ढोबळी मिरची',
    'kn': 'ಮೆಣಸಿನಕಾಯಿ', 'ta': 'மிளகாய் / குடை மிளகாய்', 'te': 'మిర్చి / బెల్ పెప్పర్',
    'ml': 'മുളക് / കാപ്സിക്കം',
  }, ['chilli', 'chili', 'mirchi', 'mirch', 'capsicum', 'bell pepper', 'pepper', 'menasinaikayi', 'mulaku']),
  CropOption('Corn_(maize)', '🌽', {
    'en': 'Maize / Corn', 'hi': 'मक्का', 'mr': 'मका', 'kn': 'ಜೋಳ',
    'ta': 'மக்காச்சோளம்', 'te': 'మొక్కజొన్న', 'ml': 'ചോളം',
  }, ['maize', 'corn', 'makka', 'maka', 'jola', 'mokkajonna', 'cholam']),
  CropOption('Grape', '🍇', {
    'en': 'Grape', 'hi': 'अंगूर', 'mr': 'द्राक्षं', 'kn': 'ದ್ರಾಕ್ಷಿ',
    'ta': 'திராட்சை', 'te': 'ద్రాక్ష', 'ml': 'മുന്തിരി',
  }, ['grape', 'angoor', 'draksha', 'munthiri', 'thiratchai']),
  CropOption('Orange', '🍊', {
    'en': 'Orange / Citrus', 'hi': 'संतरा', 'mr': 'संत्री', 'kn': 'ಕಿತ್ತಳೆ',
    'ta': 'ஆரஞ்சு', 'te': 'సన్త్రా / బత్తాయి', 'ml': 'ഓറഞ്ച്',
  }, ['orange', 'citrus', 'santra', 'santre', 'kittale', 'aranju', 'bathayi']),
  CropOption('Apple', '🍎', {
    'en': 'Apple', 'hi': 'सेब', 'mr': 'सफरचंद', 'kn': 'ಸೇಬು',
    'ta': 'ஆப்பிள்', 'te': 'సీమ రేగు / ఆపిల్', 'ml': 'ആപ്പിൾ',
  }, ['apple', 'seb', 'sebu', 'safarchand', 'aapil']),
  CropOption('Strawberry', '🍓', {
    'en': 'Strawberry', 'hi': 'स्ट्रॉबेरी', 'mr': 'स्ट्रॉबेरी', 'kn': 'ಸ್ಟ್ರಾಬೆರಿ',
    'ta': 'ஸ்ட்ராபெர்ரி', 'te': 'స్ట్రాబెర్రీ', 'ml': 'സ്ട്രാബെറി',
  }, ['strawberry']),
  CropOption('Peach', '🍑', {
    'en': 'Peach', 'hi': 'आड़ू', 'mr': 'पीच', 'kn': 'ಪೀಚು',
    'ta': 'பீச்சு', 'te': 'పీచ్', 'ml': 'പീച്ച്',
  }, ['peach', 'adoo', 'aadu']),
  CropOption('Cherry_(including_sour)', '🍒', {
    'en': 'Cherry', 'hi': 'चेरी', 'mr': 'चेरी', 'kn': 'ಚೆರ್ರಿ',
    'ta': 'செர்ரி', 'te': 'చెర్రీ', 'ml': 'ചെറി',
  }, ['cherry']),
  CropOption('Soybean', '🫘', {
    'en': 'Soybean', 'hi': 'सोयाबीन', 'mr': 'सोयाबीन', 'kn': 'ಸೋಯಾಬೀನ್',
    'ta': 'சோயாபீன்', 'te': 'సోయాబీన్', 'ml': 'സോയാബീൻ',
  }, ['soybean', 'soya']),
  CropOption('Squash', '🎃', {
    'en': 'Pumpkin / Squash', 'hi': 'कद्दू', 'mr': 'भोपळा', 'kn': 'ಕುಂಬಳಕಾಯಿ',
    'ta': 'பூசணி', 'te': 'గుమ్మడి', 'ml': 'മത്തങ്ങ',
  }, ['squash', 'pumpkin', 'kaddu', 'bhopla', 'kumbalakayi', 'poosani', 'gummadi', 'mathanga']),
  CropOption('Blueberry', '🫐', {
    'en': 'Blueberry', 'hi': 'ब्लूबेरी', 'mr': 'ब्लूबेरी', 'kn': 'ಬ್ಲೂಬೆರಿ',
    'ta': 'ப்ளூபெர்ரி', 'te': 'బ్లూబెర్రీ', 'ml': 'ബ്ലൂബെറി',
  }, ['blueberry']),
  CropOption('Raspberry', '🍇', {
    'en': 'Raspberry', 'hi': 'रास्पबेरी', 'mr': 'रास्पबेरी', 'kn': 'ರಾಸ್ಪ್‌ಬೆರಿ',
    'ta': 'ராஸ்பெர்ரி', 'te': 'రాస్ప్‌బెర్రీ', 'ml': 'റാസ്പ്ബെറി',
  }, ['raspberry']),
];

CropOption? matchCrop(String query) {
  final q = query.trim().toLowerCase();
  if (q.length < 3) return null;
  for (final c in kCropCatalog) {
    for (final name in [c.names['en']!, ...c.names.values, ...c.aliases, c.prefix.toLowerCase()]) {
      final n = name.toLowerCase();
      if (n.contains(q) || q.contains(n)) return c;
    }
  }
  return null;
}
