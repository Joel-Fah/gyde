// lib/ui/screens/home.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Paint, PaintingStyle, StrokeJoin;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:promptu/models/chat_message.dart';
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
  bool _isProgrammaticScroll =
      false; // guard to prevent shrink during auto scroll
  // Opacity for the big top title that fades as you scroll away from the top.
  double _topTitleOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _addInitialMessage();
    // Seed many messages shortly after the initial frame to test scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedSampleMessages());
  }

  void _addInitialMessage() {
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "Hello! I'm Promptu. Ask me anything or send an image or video!",
            sender: MessageSender.model,
          ),
        );
      });
    });
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
      // Markdown examples
      '# Heading 1\nSome paragraph text with a [link](https://example.com).',
      '## Heading 2\n- Bullet item A\n- Bullet item B\n- Bullet item C',
      '### Heading 3\n1. Ordered one\n2. Ordered two\n3. Ordered three',
      '> Blockquote\n> Another line in the quote.',
      'Inline code like `final x = 42;` and a code block:\n\n```dart\nvoid main() {\n  print(\'Hello Markdown!\');\n}\n```',
      '| Col A | Col B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |',
      'Image: ![Alt text](https://picsum.photos/400/200)',
    ];

    setState(() {
      for (int i = 0; i < 60; i++) {
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

    HapticFeedback.mediumImpact();

    // Unfocus the TextField to dismiss the keyboard after sending
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
    });

    // Smoothly scroll to bottom (no hero overlay)
    _scrollToBottom();

    _simulateModelResponse();
  }

  void _simulateModelResponse() {
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "This is a simulated response from the model.",
            sender: MessageSender.model,
          ),
        );
      });
      _scrollToBottom();
    });
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

  Future<void> _scrollToBottom({
    Duration duration = const Duration(milliseconds: 300),
  }) async {
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
    // Smooth: first scroll to bottom, then focus to open keyboard
    await _scrollToBottom(duration: const Duration(milliseconds: 250));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocusNode.requestFocus();
      }
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep chat list builder INSIDE the state class
  Widget _buildChatList(double keyboardInset) {
    const double kBottomThreshold = 56.0; // normal near-bottom expansion
    const double kDecelThreshold = 120.0; // slightly larger window on decel/overscroll
    const double kTitleFadeRange = 220.0; // px from top within which title fades in
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        final double extentAfter = metrics.extentAfter;

        // Update top title opacity based on how close we are to the very top.
        final double pixels = metrics.pixels;
        double newOpacity = 1.0 - (pixels / kTitleFadeRange);
        if (newOpacity < 0) newOpacity = 0;
        if (newOpacity > 1) newOpacity = 1;
        // Reduce setState churn with a tiny deadband
        if ((newOpacity - _topTitleOpacity).abs() > 0.02) {
          setState(() => _topTitleOpacity = newOpacity);
        }

        if (_isProgrammaticScroll) {
          if (extentAfter <= kBottomThreshold) {
            _scheduleExpand(true);
          }
          return false;
        }
        if (extentAfter <= kBottomThreshold) {
          _scheduleExpand(true);
          return false;
        }
        if ((notification is ScrollEndNotification || notification is OverscrollNotification) &&
            extentAfter <= kDecelThreshold) {
          _scheduleExpand(true);
          return false;
        }
        if (extentAfter > kDecelThreshold &&
            (notification is ScrollUpdateNotification || notification is UserScrollNotification)) {
          _scheduleExpand(false);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        // Slight top padding; big header occupies top area itself
        padding: EdgeInsets.fromLTRB(16, 16, 16, 120 + keyboardInset),
        itemCount: _messages.length + 1, // +1 for the top title header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTopTitleHeader(context);
          }
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
      ..color = color.withValues(alpha: 0.01);

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
                    'Promptu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1.0,
                      foreground: fill,
                    ),
                  ),
                  Text(
                    'Promptu',
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
}
