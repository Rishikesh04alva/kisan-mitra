import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/assistant_provider.dart';
import '../widgets/common.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String _tr(String key, [Map<String, String>? params]) =>
      S.of(context).tf(key, params ?? {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AssistantProvider>().ensureGreeting(_tr);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final s = S.of(context);
    final provider = context.read<AssistantProvider>();
    await provider.send(text, s.code, _tr);
    _scrollDown();
  }

  void _openKeySheet() {
    final ctrl = TextEditingController();
    showNeoSheet(context, (sheetCtx) {
      final s2 = S.of(sheetCtx);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s2.t('ai_key_title'),
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: InputDecoration(hintText: s2.t('ai_key_hint')),
              ),
              const SizedBox(height: 12),
              NeoButton(
                label: s2.t('ai_key_save'),
                emoji: '✅',
                color: AppColors.greenLight,
                onTap: () async {
                  await sheetCtx
                      .read<AssistantProvider>()
                      .saveAiKey(ctrl.text);
                  if (Navigator.of(sheetCtx).canPop()) {
                    Navigator.of(sheetCtx).pop();
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(s2.t('ai_key_help'),
                  style: Theme.of(sheetCtx).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final assistant = context.watch<AssistantProvider>();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            const Text('🤖', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Text(
              s.t('assistant_title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            if (assistant.aiReady) ...[
              const SizedBox(width: 10),
              Flexible(
                child: NeoBadge(
                  text: '⚡ ${s.t('ai_online_note')}',
                  color: AppColors.greenLight,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: NeoIconSquare(
              icon: Icons.vpn_key_rounded,
              size: 46,
              color:
                  assistant.aiReady ? AppColors.green : AppColors.yellow,
              onTap: _openKeySheet,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(kBorderWidth),
          child: Divider(height: kBorderWidth, thickness: kBorderWidth, color: AppColors.ink),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: assistant.messages.length,
                itemBuilder: (ctx, i) =>
                    _Bubble(msg: assistant.messages[i]),
              ),
            ),
            if (assistant.listening)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: AppColors.ink, width: kBorderWidth),
                ),
                child: Text(
                  s.t('listening_tap_stop'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _quick('💡', 'quick_water'),
                  _quick('🏛️', 'quick_scheme'),
                  _quick('🌿', 'quick_disease'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  NeoIconSquare(
                    icon: assistant.listening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    size: 56,
                    color:
                        assistant.listening ? AppColors.red : AppColors.yellow,
                    onTap: () {
                      context.read<AssistantProvider>().toggleListening(
                            localeId: kSpeechLocale[s.code] ?? 'en_IN',
                            langCode: s.code,
                            tr: _tr,
                          );
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (t) {
                        _ctrl.clear();
                        _send(t);
                      },
                      decoration:
                          InputDecoration(hintText: s.t('ask_hint')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeoIconSquare(
                    icon: Icons.send_rounded,
                    size: 56,
                    color: AppColors.green,
                    onTap: () {
                      final t = _ctrl.text;
                      _ctrl.clear();
                      _send(t);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quick(String emoji, String key) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: NeoCard(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => _send(_tr(key)),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(_tr(key), style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMsg msg;

  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.yellow : AppColors.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: AppColors.ink, width: kBorderWidth),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Text(
          msg.text,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                fontWeight: isUser ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
