import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/scheme_provider.dart';
import '../widgets/common.dart';

String _translateCategory(String cat, String lang) {
  final map = {
    'ALL': {'en': 'ALL', 'hi': 'सभी', 'mr': 'सर्व', 'kn': 'ಎಲ್ಲಾ', 'ta': 'அனைத்து', 'te': 'అన్ని', 'ml': 'എല്ലാം'},
    'INCOME': {'en': 'INCOME', 'hi': 'आय', 'mr': 'उत्पन्न', 'kn': 'ಆದಾಯ', 'ta': 'வருமானம்', 'te': 'ఆదాయం', 'ml': 'വരുമാനം'},
    'INSURANCE': {'en': 'INSURANCE', 'hi': 'बीमा', 'mr': 'विमा', 'kn': 'ವಿಮೆ', 'ta': 'காப்பீடு', 'te': 'బీమా', 'ml': 'ഇൻഷുറൻസ്'},
    'CREDIT': {'en': 'CREDIT', 'hi': 'ऋण', 'mr': 'कर्ज', 'kn': 'ಸಾಲ', 'ta': 'கடன்', 'te': 'రుణం', 'ml': 'വായ്പ'},
    'SOIL': {'en': 'SOIL', 'hi': 'मिट्टी', 'mr': 'माती', 'kn': 'ಮಣ್ಣು', 'ta': 'மண்', 'te': 'మట్టి', 'ml': 'മണ്ണ്'},
    'ENERGY': {'en': 'ENERGY', 'hi': 'ऊर्जा', 'mr': 'ऊर्जा', 'kn': 'ಶಕ್ತಿ', 'ta': 'ஆற்றல்', 'te': 'శక్తి', 'ml': 'എനർജി'},
    'MARKET': {'en': 'MARKET', 'hi': 'बाज़ार', 'mr': 'बाजार', 'kn': 'ಮಾರುಕಟ್ಟೆ', 'ta': 'சந்தை', 'te': 'మార్కెట్', 'ml': 'മാർക്കറ്റ്'},
    'ORGANIC': {'en': 'ORGANIC', 'hi': 'जैविक', 'mr': 'सेंद्रिय', 'kn': 'ಸಾವಯವ', 'ta': 'இயற்கை', 'te': 'సేంద్రియ', 'ml': 'ജൈവിക'},
    'INFRA': {'en': 'INFRA', 'hi': 'अवसंरचना', 'mr': 'पायाभूत', 'kn': 'ಮೂಲಸೌಕರ್ಯ', 'ta': 'உள்கட்டமைப்பு', 'te': 'మౌలిక', 'ml': 'അടിസ്ഥാനം'},
    'WATER': {'en': 'WATER', 'hi': 'पानी', 'mr': 'पाणी', 'kn': 'ನೀರು', 'ta': 'நீர்', 'te': 'నీరు', 'ml': 'ജലം'},
    'WELFARE': {'en': 'WELFARE', 'hi': 'कल्याण', 'mr': 'कल्याण', 'kn': 'ಕಲ್ಯಾಣ', 'ta': 'நலவாழ்வு', 'te': 'సంక్షేమం', 'ml': 'ക്ഷേമം'},
    'GROUP': {'en': 'GROUP', 'hi': 'समूह', 'mr': 'गट', 'kn': 'ಗುಂಪು', 'ta': 'குழு', 'te': 'సమూహం', 'ml': 'ഗ്രൂപ്പ്'},
    'MACHINERY': {'en': 'MACHINERY', 'hi': 'यंत्र', 'mr': 'यंत्र', 'kn': 'ಯಂತ್ರ', 'ta': 'இயந்திரம்', 'te': 'యంత్రం', 'ml': 'യന്ത്രം'},
    'CROP_CARE': {'en': 'CROP CARE', 'hi': 'फसल देखभाल', 'mr': 'पीक देखभाल', 'kn': 'ಬೆಳೆ ಆರೈಕೆ', 'ta': 'பயிர் பராமரிப்பு', 'te': 'పంట సంరక్షణ', 'ml': 'വിള പരിപാലനം'},
    'INNOVATION': {'en': 'INNOVATION', 'hi': 'नवाचार', 'mr': 'नवनिर्मिती', 'kn': 'ನಾವೀಣ್ಯ', 'ta': 'புதுமை', 'te': 'నవ్యత', 'ml': 'നവീകരണം'},
  };
  return map[cat]?[lang] ?? cat;
}

String _translateState(String state, String lang) {
  final map = {
    'ALL': {'en': 'ALL', 'hi': 'सभी', 'mr': 'सर्व', 'kn': 'ಎಲ್ಲಾ', 'ta': 'அனைத்து', 'te': 'అన్ని', 'ml': 'എല്ലാം'},
    'TELANGANA': {'en': 'Telangana', 'hi': 'तेलंगाना', 'mr': 'तेलंगणा', 'kn': 'ತೆಲಂಗಾಣ', 'ta': 'தெலங்கானா', 'te': 'తెలంగాణ', 'ml': 'തെലങ്കാന'},
    'MAHARASHTRA': {'en': 'Maharashtra', 'hi': 'महाराष्ट्र', 'mr': 'महाराष्ट्र', 'kn': 'ಮಹಾರಾಷ್ಟ್ರ', 'ta': 'மகாராஷ்டிரா', 'te': 'మహారాష్ట్ర', 'ml': 'മഹാരാഷ്ട്ര'},
    'UTTAR_PRADESH': {'en': 'Uttar Pradesh', 'hi': 'उत्तर प्रदेश', 'mr': 'उत्तर प्रदेश', 'kn': 'ಉತ್ತರ ಪ್ರದೇಶ', 'ta': 'உத்தரப் பிரதேசம்', 'te': 'ఉత్తర్ ప్రదేశ్', 'ml': 'ഉത്തർപ്രദേശ്'},
    'MADHYA_PRADESH': {'en': 'Madhya Pradesh', 'hi': 'मध्य प्रदेश', 'mr': 'मध्य प्रदेश', 'kn': 'ಮಧ್ಯ ಪ್ರದೇಶ', 'ta': 'மத்திய பிரதேசம்', 'te': 'మధ్యప్రదేశ్', 'ml': 'മധ്യപ്രദേശ്'},
    'RAJASTHAN': {'en': 'Rajasthan', 'hi': 'राजस्थान', 'mr': 'राजस्थान', 'kn': 'ರಾಜಸ್ಥಾನ', 'ta': 'ராஜஸ்தான்', 'te': 'రాజస్థాన్', 'ml': 'രാജസ്ഥാൻ'},
    'KARNATAKA': {'en': 'Karnataka', 'hi': 'कर्नाटक', 'mr': 'कर्नाटक', 'kn': 'ಕರ್ನಾಟಕ', 'ta': 'கர்நாடகா', 'te': 'కర్ణాటక', 'ml': 'കർണാടക'},
    'TAMIL_NADU': {'en': 'Tamil Nadu', 'hi': 'तमिलनाडु', 'mr': 'तमिळनाडू', 'kn': 'ತಮಿಳುನಾಡು', 'ta': 'தமிழ்நாடு', 'te': 'తమిళనాడు', 'ml': 'തമിഴ്‌നാട്'},
    'GUJARAT': {'en': 'Gujarat', 'hi': 'गुजरात', 'mr': 'गुजरात', 'kn': 'ಗುಜರಾತ್', 'ta': 'குஜராத்', 'te': 'గుజరాత్', 'ml': 'ഗുജറാത്ത്'},
    'BIHAR': {'en': 'Bihar', 'hi': 'बिहार', 'mr': 'बिहार', 'kn': 'ಬಿಹಾರ್', 'ta': 'பிஹார்', 'te': 'బిహార్', 'ml': 'ബിഹാർ'},
    'ODISHA': {'en': 'Odisha', 'hi': 'ओडिशा', 'mr': 'ओडिशा', 'kn': 'ಒಡಿಶಾ', 'ta': 'ஒடிசா', 'te': 'ఒడిశా', 'ml': 'ഒഡിഷ'},
    'MEGHALAYA': {'en': 'Meghalaya', 'hi': 'मेघालय', 'mr': 'मेघालय', 'kn': 'ಮೆಘಾಲಯ', 'ta': 'மேகலயா', 'te': 'మేఘాలయ', 'ml': 'മേഘാലയ'},
    'JHARKHAND': {'en': 'Jharkhand', 'hi': 'झारखंड', 'mr': 'झारखंड', 'kn': 'ಝಾರ್ಖಂಡ್', 'ta': 'ஜார்கண்ட்', 'te': 'జార్ఖండ్', 'ml': 'ഝാർഖണ്ഡ്'},
    'PUNJAB': {'en': 'Punjab', 'hi': 'पंजाब', 'mr': 'पंजाब', 'kn': 'ಪಂಜಾಬ್', 'ta': 'பஞ்சாப்', 'te': 'పంజాబ్', 'ml': 'പഞ്ചാബ്'},
    'HARYANA': {'en': 'Haryana', 'hi': 'हरियाणा', 'mr': 'हरियाणा', 'kn': 'ಹರಿಯಾಣ', 'ta': 'ஹரியானா', 'te': 'హరియాణా', 'ml': 'ഹരിയാണ'},
    'WEST_BENGAL': {'en': 'West Bengal', 'hi': 'पश्चिम बंगाल', 'mr': 'पश्चिम बंगाल', 'kn': 'ಪಶ್ಚಿಮ ಬಂಗಾಳ', 'ta': 'மேற்கு வங்காளம்', 'te': 'పశ్చిమ బెంగాల్', 'ml': 'പശ്ചിം ബംഗാൾ'},
    'CHHATTISGARH': {'en': 'Chhattisgarh', 'hi': 'छत्तीसगढ़', 'mr': 'छत्तीसगढ', 'kn': 'ಛತ್ತೀಸ್‌ಗಢ್', 'ta': 'சத்தீஸ்கர்', 'te': 'ఛత్తీస్‌గఢ్', 'ml': 'ഛത്തീസ്ഗഢ്'},
    'KERALA': {'en': 'Kerala', 'hi': 'केरल', 'mr': 'केरळ', 'kn': 'ಕೇರಳ', 'ta': 'கேரளா', 'te': 'కేరళ', 'ml': 'കേരള'},
    'TRIPURA': {'en': 'Tripura', 'hi': 'त्रिपुरा', 'mr': 'त्रिपुरा', 'kn': 'ತ್ರಿಪುರಾ', 'ta': 'திரிபுரா', 'te': 'త్రిపుర', 'ml': 'ത്രിപുര'},
    'ASSAM': {'en': 'Assam', 'hi': 'असम', 'mr': 'असम', 'kn': 'ಅಸ್ಸಾಂ', 'ta': 'அசாம்', 'te': 'అస్సాం', 'ml': 'അസം'},
    'NAGALAND': {'en': 'Nagaland', 'hi': 'नागालैंड', 'mr': 'नागालँड', 'kn': 'ನಾಗಾಲ್ಯಾಂಡ್', 'ta': 'நாகலாந்து', 'te': 'నాగాలాండ్', 'ml': 'നാഗാലാൻഡ്'},
  };
  return map[state]?[lang] ?? state;
}

class SchemeExplorerScreen extends StatefulWidget {
  const SchemeExplorerScreen({super.key});

  @override
  State<SchemeExplorerScreen> createState() => _SchemeExplorerScreenState();
}

class _SchemeExplorerScreenState extends State<SchemeExplorerScreen> {
  bool _bootstrapped = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      context.read<SchemeProvider>().init();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sp = context.watch<SchemeProvider>();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => context.read<SchemeProvider>().setQuery(q),
              decoration: InputDecoration(
                hintText: s.t('search_hint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 28),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<SchemeProvider>().setQuery('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: sp.categories
                  .map((c) => _chip(c, c == sp.category, isState: false))
                  .toList(),
            ),
          ),
          if (sp.states.length > 2)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: sp.states
                    .map((st) => _chip(st, st == sp.state, isState: true))
                    .toList(),
              ),
            ),
          Expanded(
            child: !sp.loaded
                ? const Center(child: CircularProgressIndicator())
                : sp.items.isEmpty
                    ? EmptyState(emoji: '📭', text: s.t('no_results'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: sp.items.length,
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SchemeCard(scheme: sp.items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, {required bool isState}) {
    final s = S.of(context);
    final lang = s.code;
    final text = isState ? _translateState(label, lang) : _translateCategory(label, lang);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: NeoCard(
        onTap: selected
            ? null
            : () => isState
                ? context.read<SchemeProvider>().setStateFilter(label)
                : context.read<SchemeProvider>().setCategory(label),
        color: selected ? AppColors.ink : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.yellow : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final Scheme scheme;

  const _SchemeCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.code;
    return NeoCard(
      onTap: () => showNeoSheet(context, (_) => _DetailSheet(scheme: scheme)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheme.name(lang),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  scheme.benefit(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeoBadge(text: scheme.category, color: AppColors.blue),
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Scheme scheme;

  const _DetailSheet({required this.scheme});

  Future<void> _openUrl(BuildContext context) async {
    if (scheme.url.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse(scheme.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _call(BuildContext context) async {
    if (scheme.phone.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: scheme.phone));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.code;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scheme.name(lang), style: Theme.of(ctx).textTheme.displaySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                NeoBadge(text: _translateCategory(scheme.category, lang), color: AppColors.blue),
                if (scheme.state != 'ALL')
                  NeoBadge(text: _translateState(scheme.state, lang), color: AppColors.yellow),
              ],
            ),
            SectionHeader(text: s.t('benefits'), emoji: '🎁'),
            NeoCard(
              color: AppColors.green,
              child: Text(
                scheme.benefit(lang),
                style: Theme.of(ctx)
                    .textTheme
                    .bodyLarge!
                    .copyWith(color: Colors.white),
              ),
            ),
            SectionHeader(text: s.t('elig'), emoji: '✅'),
            ...scheme.eligibility.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: NeoCard(
                  color: Colors.white,
                  shadowColor: Colors.black26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Expanded(child: Text(e, style: Theme.of(ctx).textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            NeoButton(
              label: s.t('apply'),
              emoji: '🌐',
              color: AppColors.yellow,
              onTap: () => _openUrl(ctx),
            ),
            const SizedBox(height: 12),
            NeoButton(
              label: s.t('call_helpline'),
              emoji: '📞',
              color: Colors.white,
              onTap: () => _call(ctx),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
