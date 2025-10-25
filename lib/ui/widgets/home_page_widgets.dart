import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/chat_message.dart';
import '../../utils/time.dart';

/// A widget to display a single chat message bubble.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUserMessage = message.sender == MessageSender.user;

    // Width constraints: user 75%, model 90%
    final maxWidthFactor = isUserMessage ? 0.75 : 0.90;
    final maxWidth = MediaQuery.of(context).size.width * maxWidthFactor;

    if (isUserMessage) {
      // Use theme containers so it looks right in both light and dark themes
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.mediaFile != null)
                _buildMediaPreview(message.mediaFile!),
              if (message.text != null && message.text!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    message.text!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16.0,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Model message: no background, up to 90% width, render Markdown
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          // No decoration => no background
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.mediaFile != null)
                _buildMediaPreview(message.mediaFile!),
              if (message.text != null && message.text!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: _buildMarkdown(context, message.text!),
                ),
              if (message.text != null && message.text!.trim().isNotEmpty)
                _buildModelActions(context, message.text!.trim()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, String data) {
    final theme = Theme.of(context);
    final style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      code: GoogleFonts.jetBrainsMono(
        fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * 0.95,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        color: theme.colorScheme.onSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outline, width: 3),
        ),
      ),
      listBullet: theme.textTheme.bodyMedium,
      a: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      tableBorder: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        width: 0.6,
      ),
      tableHead: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: style,
      softLineBreak: true,
      onTapLink: (text, href, title) {
        // no-op for now; you can wire up url_launcher later
      },
      sizedImageBuilder: (config) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(
          config.uri.toString(),
          fit: BoxFit.cover,
          width: config.width,
          height: config.height,
        ),
      ),
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
    );
  }

  Widget _buildMediaPreview(File file) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MediaPreview(file: file),
      ),
    );
  }

  Widget _buildModelActions(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurface.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIconButton(
            tooltip: 'Copy',
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 18),
            color: iconColor,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  backgroundColor: colorScheme.inverseSurface,
                ),
              );
            },
          ),
          _ActionIconButton(
            tooltip: 'Share',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedShare08,
              size: 18,
            ),
            color: iconColor,
            onPressed: () {
              Share.share(text);
            },
          ),
        ],
      ),
    );
  }
}

class MediaPreview extends StatefulWidget {
  final File file;

  const MediaPreview({super.key, required this.file});

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  VideoPlayerController? _videoController;
  Future<void>? _initVideoFuture;
  late final bool _isVideo;

  static const _videoExts = ['.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm'];

  @override
  void initState() {
    super.initState();
    final path = widget.file.path.toLowerCase();
    _isVideo = _videoExts.any((ext) => path.endsWith(ext));
    if (_isVideo) {
      _videoController = VideoPlayerController.file(widget.file);
      _initVideoFuture = _videoController!.initialize().then((_) {
        if (mounted) setState(() {});
      });
      _videoController!
        ..setLooping(false)
        ..setVolume(1.0);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVideo) {
      return Image.file(
        widget.file,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      ).animate().fadeIn(duration: 250.ms);
    }

    return FutureBuilder<void>(
      future: _initVideoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: 200,
            child: Center(
              child: SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
            ),
          );
        }
        final controller = _videoController!;
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            _PlayButtonOverlay(controller: controller),
          ],
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }
}

class _PlayButtonOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const _PlayButtonOverlay({required this.controller});

  @override
  State<_PlayButtonOverlay> createState() => _PlayButtonOverlayState();
}

class _PlayButtonOverlayState extends State<_PlayButtonOverlay> {
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _showOverlay = !widget.controller.value.isPlaying;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.controller.value.isPlaying) {
              widget.controller.pause();
            } else {
              widget.controller.play();
            }
          },
          child: AnimatedOpacity(
            opacity: _showOverlay ? 1 : 0,
            duration: 200.ms,
            child: Container(
              color: Colors.black26,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A widget for the text input area that can be expanded or shrunk.
class ChatInputArea extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onExpand;
  final TextEditingController textController;
  final VoidCallback onSendMessage;
  final VoidCallback onAttachMedia;
  final File? pickedMediaFile;
  final VoidCallback onRemoveMedia;
  final FocusNode? focusNode;

  const ChatInputArea({
    super.key,
    required this.isExpanded,
    required this.onExpand,
    required this.textController,
    required this.onSendMessage,
    required this.onAttachMedia,
    this.pickedMediaFile,
    required this.onRemoveMedia,
    this.focusNode,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chipBorderController;

  @override
  void initState() {
    super.initState();
    _chipBorderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _chipBorderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always transparent background to avoid a fixed bar look.
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: 300.ms,
          switchInCurve: Curves.easeOutQuart,
          switchOutCurve: Curves.easeInQuart,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          // SizeTransition(sizeFactor: animation, child: child),
          child: widget.isExpanded
              ? _buildExpandedInput(context)
              : _buildShrunkInput(context),
        ),
      ),
    );
  }

  Widget _buildShrunkInput(BuildContext context) {
    final gradientColors = [
      const Color(0xFF00E5FF),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF4081),
      const Color(0xFF00E5FF),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: widget.onExpand,
        child: AnimatedBuilder(
          animation: _chipBorderController,
          builder: (context, child) {
            final angle = _chipBorderController.value * 2 * math.pi;
            return Container(
              key: const ValueKey('shrunkInput'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: SweepGradient(
                  colors: gradientColors,
                  startAngle: 0,
                  endAngle: 2 * math.pi,
                  transform: GradientRotation(angle),
                ),
              ),
              padding: const EdgeInsets.all(1.6),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedEdit03, size: 18),
                    const Gap(6),
                    Text(
                      'Tap to type...',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 14.0),
                    ),
                  ],
                ).animate().scale(duration: 220.ms, curve: Curves.easeOutBack),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedInput(BuildContext context) {
    return Column(
      key: const ValueKey('expandedInput'),
      children: [
        if (widget.pickedMediaFile != null)
          _buildMediaAttachmentPreview(context),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filled(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedAttachment),
              onPressed: widget.onAttachMedia,
              tooltip: 'Attach Media',
            ),
            Expanded(
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.textController,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => widget.onSendMessage(),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.textController,
              builder: (context, value, _) {
                final hasContent =
                    value.text.trim().isNotEmpty ||
                    widget.pickedMediaFile != null;
                return AnimatedScale(
                  scale: hasContent ? 1.0 : 0.98,
                  duration: 200.ms,
                  curve: Curves.easeOutBack,
                  child: IconButton.filled(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedSent),
                    onPressed: hasContent ? widget.onSendMessage : null,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaAttachmentPreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: MediaPreview(file: widget.pickedMediaFile!),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              radius: 14,
              child: IconButton(
                iconSize: 14,
                padding: EdgeInsets.zero,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: Colors.white,
                ),
                onPressed: widget.onRemoveMedia,
              ),
            ),
          ),
        ],
      ),
    ).animate().slide(begin: const Offset(0, 0.5)).fadeIn();
  }
}

class _ActionIconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: IconTheme(
        data: IconThemeData(color: color, size: 18),
        child: icon,
      ),
    );
  }
}
