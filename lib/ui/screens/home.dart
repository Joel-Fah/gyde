// lib/ui/screens/home.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Paint, PaintingStyle, StrokeJoin;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/ai_service.dart';
import '../../models/chat_message.dart';
import 'package:soft_edge_blur/soft_edge_blur.dart';

import '../widgets/home_page_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const String routeName = '/';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final List<ChatMessage> _messages = [];

  bool _isInputBarExpanded = true;
  File? _pickedMediaFile;
  bool _isProgrammaticScroll = false; // guard to prevent shrink during auto scroll
  double _topTitleOpacity = 0.0; // Opacity for big top title

  // Model generation shimmer flag
  bool _isGenerating = false;

  // Demo seed control
  static const bool _enableDemoSeed = false;

  // Quick-start suggestions shown when no user messages yet
  static const List<String> _suggestions = [
    'What is GDG and how does GDG Yaoundé fit in?',
    'How can I join GDG Yaoundé and stay updated?',
    'When is the next GDG Yaoundé meetup or DevFest in Cameroon?',
    'Who are the organizers of GDG Yaoundé and how do I reach them?',
    'How do I become a speaker at a GDG Yaoundé event?',
    'Share the GDG Code of Conduct and community guidelines.',
    'List active GDG chapters in Cameroon with their links.',
    'Give me a recap of the last GDG Yaoundé event.',
    'Where can I find GDG Yaoundé on social media?',
    'How can I volunteer or help organize GDG Yaoundé events?',
    'What programs does GDG run (Study Jams, I/O Extended, DevFest)?',
    'Tips for first-time attendees at a GDG Yaoundé meetup.',
  ];

  bool get _hasUserMessages => _messages.any((m) => m.sender == MessageSender.user);

  late final AIService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = AIService();
    // Removed initial model message to keep empty state truly empty
    if (_enableDemoSeed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _seedSampleMessages());
    }
  }

  void _seedSampleMessages() {
    final baseTexts = [
      'Hey there! 👋',
      'How are you doing today?',
      'Let’s try a longer message to test how wrapping behaves in the chat bubble. It should gracefully wrap to multiple lines and still look nice.',
      'Short one.',
      'Here’s a list: 1) Alpha 2) Beta 3) Gamma 4) Delta 5) Epsilon.',
      'What’s the weather like over there? Do you prefer sunny days or rainy ones?',
      'OK',
      'This is a pretty long paragraph intended to stress-test scrolling performance and bubble constraints. The max width should be respected and content should be readable with proper padding.',
      'Neat!',
      'Let’s add another message to make sure we have plenty of items in the list.',
      '# Heading 1\nSome paragraph text with a [link](https://example.com).',
      '## Heading 2\n- Bullet item A\n- Bullet item B\n- Bullet item C',
      '### Heading 3\n1. Ordered one\n2. Ordered two\n3. Ordered three',
      '> Blockquote\n> Another line in the quote.',
      'Inline code like `final x = 42;` and a code block:\n\n```dart\nvoid main() {\n  print(\'Hello Markdown!\');\n}\n```',
      '| Col A | Col B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |',
      'Image: ![Alt text](https://picsum.photos/400/200)',
    ];

    setState(() {
      for (int i = 0; i < 24; i++) {
        final isUser = i % 2 == 0;
        final text = baseTexts[i % baseTexts.length];
        _messages.add(
          ChatMessage(
            text: text,
            sender: isUser ? MessageSender.user : MessageSender.model,
          ),
        );
      }
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _pickedMediaFile == null) return;

    debugPrint('[HomePage] _sendMessage textLen=${text.length} hasMedia=${_pickedMediaFile != null}');

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final newMessage = ChatMessage(
      text: text.isEmpty ? null : text,
      mediaFile: _pickedMediaFile,
      sender: MessageSender.user,
    );

    setState(() {
      _messages.add(newMessage);
      _textController.clear();
      _pickedMediaFile = null;
      _isGenerating = true; // show shimmer while model responds
    });

    _scrollToBottom();

    // Kick off model generation
    final prompt = newMessage.text ?? 'Please help based on the attached media.';
    debugPrint('[HomePage] Starting AI generation');
    _generateModelResponse(prompt);
  }

  Future<void> _generateModelResponse(String prompt) async {
    try {
      final md = await _aiService.generate(prompt);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: md.isEmpty ? '*(No content returned)*' : md,
            sender: MessageSender.model,
          ),
        );
        _isGenerating = false;
      });
      debugPrint('[HomePage] AI generation success, mdLen=${md.length}');
      _scrollToBottom();
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('[HomePage] AI generation error: $e\n$st');
      setState(() {
        _messages.add(
          ChatMessage(
            text: _friendlyErrorMessage(e),
            sender: MessageSender.model,
            isError: true,
          ),
        );
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  String _friendlyErrorMessage(Object error) {
    // Map common exceptions to user-friendly messages
    if (error is SocketException) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (error is TimeoutException) {
      return 'The AI service took too long to respond. Please try again in a moment.';
    }
    if (error is PlatformException) {
      final code = error.code.isNotEmpty ? ' (code: ${error.code})' : '';
      return 'A platform error occurred$code. Please try again.';
    }
    final type = error.runtimeType.toString();
    if (type.contains('FirebaseException')) {
      return 'A Firebase error occurred. Please verify your configuration and try again.';
    }
    if (type.contains('ServerException')) {
      return 'The AI service is temporarily unavailable. Please try again shortly.';
    }
    return 'Sorry, I couldn\'t generate a response. Please try again.';
  }

  void _pickMedia() async {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedImage01),
                  title: const Text('Pick Image'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setState(() {
                        _pickedMediaFile = File(image.path);
                        _expandInputBar();
                      });
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedVideo01),
                  title: const Text('Pick Video'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? video = await _picker.pickVideo(
                      source: ImageSource.gallery,
                    );
                    if (video != null) {
                      setState(() {
                        _pickedMediaFile = File(video.path);
                        _expandInputBar();
                      });
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scrollToBottom({ Duration duration = const Duration(milliseconds: 300), }) async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_scrollController.hasClients) {
        try {
          _isProgrammaticScroll = true;
          await _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: duration,
            curve: Curves.easeOut,
          );
        } finally {
          _isProgrammaticScroll = false;
        }
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _expandInputBar() async {
    if (!_isInputBarExpanded) {
      setState(() => _isInputBarExpanded = true);
      HapticFeedback.lightImpact();
    }
    await _scrollToBottom(duration: const Duration(milliseconds: 250));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocusNode.requestFocus();
    });
  }

  void _scheduleExpand(bool expand) {
    if (expand == _isInputBarExpanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isInputBarExpanded = expand);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final hasUser = _hasUserMessages;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: SoftEdgeBlur(
                edges: [
                  EdgeBlur(
                    type: EdgeType.topEdge,
                    size: 150,
                    sigma: 50,
                    controlPoints: [
                      ControlPoint(position: 0.5, type: ControlPointType.visible),
                      ControlPoint(position: 1, type: ControlPointType.transparent),
                    ],
                  ),
                ],
                child: _buildChatList(viewInsets.bottom),
              ),
            ),
            if (!hasUser) _buildEmptyStateOverlay(context),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: OrientationBuilder(
                  builder: (context, orientation) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: orientation == Orientation.portrait ? double.infinity : 900,
                      ),
                      child: ChatInputArea(
                        isExpanded: _isInputBarExpanded,
                        onExpand: () { _expandInputBar(); },
                        textController: _textController,
                        onSendMessage: _sendMessage,
                        onAttachMedia: _pickMedia,
                        pickedMediaFile: _pickedMediaFile,
                        onRemoveMedia: () => setState(() => _pickedMediaFile = null),
                        focusNode: _textFocusNode,
                      ),
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(double keyboardInset) {
    const double kBottomThreshold = 56.0;
    const double kDecelThreshold = 120.0;
    const double kTitleFadeRange = 220.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        final double extentAfter = metrics.extentAfter;

        final double pixels = metrics.pixels;
        double newOpacity = 1.0 - (pixels / kTitleFadeRange);
        newOpacity = newOpacity.clamp(0.0, 1.0);
        if ((newOpacity - _topTitleOpacity).abs() > 0.02) {
          // Defer setState to avoid scheduling build during current frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if ((newOpacity - _topTitleOpacity).abs() > 0.01) {
              setState(() => _topTitleOpacity = newOpacity);
            }
          });
        }

        if (_isProgrammaticScroll) {
          if (extentAfter <= kBottomThreshold) _scheduleExpand(true);
          return false;
        }
        if (extentAfter <= kBottomThreshold) {
          _scheduleExpand(true);
          return false;
        }
        if (extentAfter > kDecelThreshold && (notification is ScrollUpdateNotification || notification is UserScrollNotification)) {
          _scheduleExpand(false);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 120 + keyboardInset),
        itemCount: _messages.length + 1 + (_isGenerating ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) return _buildTopTitleHeader(context);
          final lastIndex = _messages.length + 1;
          if (_isGenerating && index == lastIndex) return _buildShimmerBubble(context);
          final message = _messages[index - 1];
          final isUser = message.sender == MessageSender.user;
          return MessageBubble(message: message)
              .animate()
              .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
              .slideX(begin: isUser ? 0.15 : -0.15, end: 0, curve: Curves.easeOutBack, duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildTopTitleHeader(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.35);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.04);

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _topTitleOpacity,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
          child: SizedBox(
            height: 200,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Gyde',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.0,
                      foreground: fill,
                    ),
                  ),
                  Text(
                    'Gyde',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.0,
                      foreground: stroke,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerBubble(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final onBase = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    Widget line(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(8),
          ),
        ).animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: onBase);

    final screenW = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenW * 0.9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              line(screenW * 0.6, 12),
              const SizedBox(height: 8),
              line(screenW * 0.8, 12),
              const SizedBox(height: 8),
              line(screenW * 0.45, 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 120 + viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App name on empty state
              Text(
                'Gyde',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const Gap(8),
              Text(
                "What can I help you with today?",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Gap(12),
              _buildInfiniteSuggestionsStrip(context),
              const Gap(8),
              _buildInfiniteSuggestionsStrip(context),
            ],
          ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut),
        ),
      ),
    );
  }

  Widget _buildInfiniteSuggestionsStrip(BuildContext context) {
    // Infinite horizontal scroll of suggestion chips by repeating the list.
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        itemBuilder: (context, index) {
          final s = _suggestions[index % _suggestions.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _SuggestionChip(
              label: s,
              onTap: () {
                setState(() { _textController.text = s; });
                _expandInputBar();
              },
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 16),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
