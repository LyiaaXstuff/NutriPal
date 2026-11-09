import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../models/profile_setup_data.dart';
import '../services/ask_nutripal_service.dart';
import '../services/insight_text_service.dart';
import '../widgets/nutripal_ui.dart';

// =======================================================
// 6 · ASK NUTRIPAL (agent chat)
// =======================================================
//
// Follow-up questions about the product on screen. The
// agent knows the label, the user's limits and the
// analysis, and can recalculate other portions. Its steps
// ("Recalculated for 472 ml") are shown above each answer.
// =======================================================

class AskNutriPalScreen extends StatefulWidget {
  final String productName;
  final NutritionLabelData data;
  final NutritionAnalysis analysis;
  final ProfileSetupData profile;
  final String portionText;

  // Asked straight away (from a suggestion chip).
  final String? firstQuestion;

  const AskNutriPalScreen({
    super.key,
    required this.productName,
    required this.data,
    required this.analysis,
    required this.profile,
    required this.portionText,
    this.firstQuestion,
  });

  @override
  State<AskNutriPalScreen> createState() => _AskNutriPalScreenState();
}

class _AskNutriPalScreenState extends State<AskNutriPalScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<ChatTurn> _turns = <ChatTurn>[];

  late final Map<String, dynamic> _context;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _context = AskNutriPalService.buildContext(
      productName: widget.productName,
      data: widget.data,
      analysis: widget.analysis,
      profile: widget.profile,
    );

    final String? first = widget.firstQuestion;

    if (first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(first));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final String text = (preset ?? _input.text).trim();

    if (text.isEmpty || _busy) return;

    setState(() {
      _turns.add(ChatTurn(role: 'user', text: text));
      _busy = true;
      _error = null;
      _input.clear();
    });

    _scrollToEnd();

    try {
      final ChatTurn reply = await AskNutriPalService.ask(
        context: _context,
        history: _turns,
      );

      if (!mounted) return;

      setState(() => _turns.add(reply));
    } on AskNutriPalException catch (e) {
      if (!mounted) return;

      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;

      setState(() => _error = 'NutriPal could not answer. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> suggestions = InsightTextService.suggestedQuestions(widget.analysis);

    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  // Same thin "<" back arrow as the other screens.
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF38138C),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset('assets/images/NutriPal Mascot7.png', width: 40, height: 40),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask NutriPal',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: NpColors.ink),
                        ),
                        Text(
                          'Knows your profile and this label',
                          style: TextStyle(fontSize: 12.5, color: NpColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NpColors.lilac,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: NpColors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'About: ${widget.productName} · ${widget.portionText.toLowerCase()}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: NpColors.purple),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                children: [
                  if (_turns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Ask about portions, swaps or why a level is what it is. '
                        'NutriPal uses the numbers from your label and your limits.',
                        style: TextStyle(fontSize: 14, height: 1.5, color: NpColors.bodyInk),
                      ),
                    ),
                  for (final ChatTurn t in _turns)
                    t.role == 'user' ? _UserBubble(text: t.text) : _AnswerCard(turn: t),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: NpColors.purple),
                          ),
                          SizedBox(width: 10),
                          Text('NutriPal is checking…', style: TextStyle(color: NpColors.muted)),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NpColors.errorBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_error!, style: const TextStyle(color: NpColors.errorInk)),
                    ),
                ],
              ),
            ),
            if (!_busy)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    for (final String q in suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(q),
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: NpColors.purple,
                          ),
                          backgroundColor: NpColors.lilac,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onPressed: () => _send(q),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask a question',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: NpColors.softBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: NpColors.softBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: NpColors.teal, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    style: IconButton.styleFrom(backgroundColor: NpColors.purple),
                    onPressed: _busy ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(
                'General guidance, not medical advice.',
                style: TextStyle(fontSize: 11.5, color: NpColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: NpColors.purple,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14.5, color: Colors.white, height: 1.4)),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final ChatTurn turn;

  const _AnswerCard({required this.turn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: NpCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (turn.steps.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final String step in turn.steps)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: NpColors.okBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 13, color: NpColors.okInk),
                          const SizedBox(width: 4),
                          Text(
                            step,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: NpColors.okInk),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Text(turn.text, style: const TextStyle(fontSize: 14.5, height: 1.5, color: NpColors.bodyInk)),
          ],
        ),
      ),
    );
  }
}
