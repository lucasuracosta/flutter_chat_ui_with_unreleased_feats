import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';

/// Theme values for [FlyerChatTextMessage].
typedef _LocalTheme =
    ({
      TextStyle bodyMedium,
      TextStyle labelSmall,
      Color onPrimary,
      Color onSurface,
      Color primary,
      BorderRadiusGeometry shape,
      Color surfaceContainer,
    });

/// A widget that displays a regular text message.
///
/// Supports markdown rendering via [GptMarkdown].
class FlyerChatTextMessage extends StatelessWidget {
  /// The text message data model.
  final TextMessage message;

  /// The index of the message in the list.
  final int index;

  /// Padding around the text content.
  ///
  /// Does not apply to [topWidgets] or link preview widgets, allowing them
  /// to span the full width of the message bubble.
  final EdgeInsetsGeometry textPadding;

  /// Border radius of the message bubble.
  final BorderRadiusGeometry? borderRadius;

  /// Box constraints for the message bubble.
  final BoxConstraints? constraints;

  /// Font size for messages containing only emojis.
  final double? onlyEmojiFontSize;

  /// Background color for messages sent by the current user.
  final Color? sentBackgroundColor;

  /// Background color for messages received from other users.
  final Color? receivedBackgroundColor;

  /// Text style for messages sent by the current user.
  final TextStyle? sentTextStyle;

  /// Text style for messages received from other users.
  final TextStyle? receivedTextStyle;

  /// The color of the links in the sent messages.
  final Color? sentLinksColor;

  /// The color of the links in the received messages.
  final Color? receivedLinksColor;

  /// Text style for the message timestamp and status.
  final TextStyle? timeStyle;

  /// Whether to display the message timestamp.
  final bool showTime;

  /// Whether to display the message status (sent, delivered, seen) for sent messages.
  final bool showStatus;

  /// Position of the timestamp and status indicator relative to the text.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// Insets for the timestamp and status indicator when [timeAndStatusPosition] is [TimeAndStatusPosition.inline].
  final EdgeInsetsGeometry? timeAndStatusPositionInlineInsets;

  /// Alignment for the timestamp and status indicator when [timeAndStatusPosition] is [TimeAndStatusPosition.inline].
  final CrossAxisAlignment timeAndStatusPositionInlineAlignment;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// The position of the link preview widget relative to the text.
  /// If set to [LinkPreviewPosition.none], the link preview widget will not be displayed.
  /// A [LinkPreviewBuilder] must be provided for the preview to be displayed.
  final LinkPreviewPosition linkPreviewPosition;

  /// The widgets to display before the message.
  final List<Widget>? topWidgets;

  /// Size of the status icon.
  final double? statusIconSize;

  /// Color of the status icon.
  final Color? statusIconColor;

  /// Padding inside the message container which creates a border around the text.
  final EdgeInsetsGeometry? containerPadding;

  /// Whether to reserve space for the time and status indicator when positioned.
  ///
  /// When `true` (default), an invisible placeholder ensures the text doesn't wrap under
  /// the positioned time/status. When `false`, allows for a more compact layout where
  /// the time/status can potentially overlap with available space.
  ///
  /// Only applies when [timeAndStatusPosition] is not [TimeAndStatusPosition.inline].
  final bool reserveTimeAndStatusSpace;

  /// Creates a widget to display a text message.
  const FlyerChatTextMessage({
    super.key,
    required this.message,
    required this.index,
    this.textPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.borderRadius,
    this.constraints,
    this.onlyEmojiFontSize = 48,
    this.sentBackgroundColor,
    this.receivedBackgroundColor,
    this.sentTextStyle,
    this.receivedTextStyle,
    this.sentLinksColor,
    this.receivedLinksColor,
    this.timeStyle,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.timeAndStatusPositionInlineInsets = const EdgeInsets.only(bottom: 2),
    this.timeAndStatusPositionInlineAlignment = CrossAxisAlignment.end,
    this.onLinkTap,
    this.linkPreviewPosition = LinkPreviewPosition.bottom,
    this.topWidgets,
    this.statusIconSize,
    this.statusIconColor,
    this.containerPadding = EdgeInsets.zero,
    this.reserveTimeAndStatusSpace = true,
  });

  bool get _isOnlyEmoji => message.metadata?['isOnlyEmoji'] == true;

  @override
  Widget build(BuildContext context) {
    // Bail out gracefully if mounted in a context without the required Chat
    // providers — production has hit this transiently due to detached subtrees
    // (Hero flights, foreground-resume rebuilds, batch list inflation, etc.).
    // Throwing here would be reported as a non-fatal and replaced by a blank
    // ErrorWidget; rendering nothing is just as invisible and avoids the noise.
    try {
      Provider.of<ChatTheme>(context, listen: false);
      Provider.of<UserID>(context, listen: false);
      Provider.of<Builders>(context, listen: false);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final theme = context.select(
      (ChatTheme t) => (
        bodyMedium: t.typography.bodyMedium,
        labelSmall: t.typography.labelSmall,
        onPrimary: t.colors.onPrimary,
        onSurface: t.colors.onSurface,
        primary: t.colors.primary,
        shape: t.shape,
        surfaceContainer: t.colors.surfaceContainer,
      ),
    );
    final isSentByMe = context.read<UserID>() == message.authorId;
    final backgroundColor = _resolveBackgroundColor(isSentByMe, theme);
    final paragraphStyle = _resolveParagraphStyle(isSentByMe, theme);
    final timeStyle = _resolveTimeStyle(isSentByMe, theme);

    final timeAndStatus =
        showTime || (isSentByMe && showStatus)
            ? TimeAndStatus(
              time: message.resolvedTime,
              status: message.resolvedStatus,
              showTime: showTime,
              showStatus: isSentByMe && showStatus,
              textStyle: timeStyle,
              statusIconColor: statusIconColor,
              statusIconSize: statusIconSize,
              isEdited: message.metadata?['is_edited'] == true,
            )
            : null;

    final textContent = GptMarkdownTheme(
      gptThemeData: GptMarkdownTheme.of(context).copyWith(
        linkColor: isSentByMe ? sentLinksColor : receivedLinksColor,
        linkHoverColor: isSentByMe ? sentLinksColor : receivedLinksColor,
      ),
      child: GptMarkdown(
        message.text,
        style:
            _isOnlyEmoji
                ? paragraphStyle?.copyWith(fontSize: onlyEmojiFontSize)
                : paragraphStyle,
        onLinkTap: onLinkTap,
      ),
    );

    final Widget? linkPreviewWidget =
        linkPreviewPosition != LinkPreviewPosition.none
            ? context.read<Builders>().linkPreviewBuilder?.call(
              context,
              message,
              isSentByMe,
            )
            : null;

    final containerChild = Container(
      constraints: constraints,
      padding: containerPadding,
      decoration: _isOnlyEmoji ? null : BoxDecoration(color: backgroundColor),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildContentBasedOnPosition(
            context: context,
            textContent: textContent,
            timeAndStatus: timeAndStatus,
            paragraphStyle: paragraphStyle,
            linkPreviewWidget: linkPreviewWidget,
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius ?? theme.shape,
      child:
          topWidgets != null && topWidgets!.isNotEmpty
              ? IntrinsicWidth(child: containerChild)
              : containerChild,
    );
  }

  Widget _buildContentBasedOnPosition({
    required BuildContext context,
    required Widget textContent,
    TimeAndStatus? timeAndStatus,
    TextStyle? paragraphStyle,
    Widget? linkPreviewWidget,
  }) {
    final textDirection = Directionality.of(context);
    final effectiveLinkPreviewPosition =
        linkPreviewWidget != null
            ? linkPreviewPosition
            : LinkPreviewPosition.none;

    // Build invisible placeholder text that matches the time/status format.
    // This text is appended to the message and styled as invisible, allowing
    // the time to sit on the same line if there's space, or wrap naturally.
    String buildInvisiblePlaceholderText() {
      final timeFormat = context.read<DateFormat>();
      final buffer = StringBuffer('  ');

      final isEdited = message.metadata?['is_edited'] == true;
      if (isEdited) {
        buffer.write('Edited ');
      }

      if (showTime && message.resolvedTime != null) {
        buffer.write(timeFormat.format(message.resolvedTime!.toLocal()));
      }

      final isSentByMe = context.read<UserID>() == message.authorId;
      if (isSentByMe && showStatus && message.resolvedStatus != null) {
        buffer.write(' ✅');
      }

      return buffer.toString();
    }

    // Build text with inline invisible placeholder for time/status (WhatsApp-like behavior).
    // The invisible placeholder flows with the text as continuous content, allowing proper
    // line breaking. We use Text.rich to append an invisible placeholder that reserves
    // space for the time/status overlay.
    Widget buildTextWithInlinePlaceholder() {
      if (timeAndStatus == null ||
          timeAndStatusPosition ==
              TimeAndStatusPosition
                  .inline /*  ||
          !reserveTimeAndStatusSpace */ ) {
        return textContent;
      }

      final placeholderText = buildInvisiblePlaceholderText();

      // For simple text without markdown, use Text.rich for proper inline flow
      // This ensures the invisible placeholder is part of the same text flow
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: message.text,
              style:
                  _isOnlyEmoji
                      ? paragraphStyle?.copyWith(fontSize: onlyEmojiFontSize)
                      : paragraphStyle,
            ),
            TextSpan(
              text: placeholderText,
              // Use the time/status text style to occupy the same space
              style: (timeAndStatus.textStyle ?? const TextStyle()).copyWith(
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topWidgets != null) ...topWidgets!,
            if (effectiveLinkPreviewPosition == LinkPreviewPosition.top)
              linkPreviewWidget!,
            Padding(
              padding: textPadding,
              child:
                  timeAndStatusPosition == TimeAndStatusPosition.inline
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            timeAndStatusPositionInlineAlignment,
                        children: <Widget>[
                          Flexible(child: textContent),
                          const SizedBox(width: 4),
                          Padding(
                            padding:
                                timeAndStatusPositionInlineInsets ??
                                EdgeInsets.zero,
                            child: timeAndStatus,
                          ),
                        ],
                      )
                      : buildTextWithInlinePlaceholder(),
            ),
            if (effectiveLinkPreviewPosition == LinkPreviewPosition.bottom)
              linkPreviewWidget!,
          ],
        ),
        if (timeAndStatusPosition != TimeAndStatusPosition.inline &&
            timeAndStatus != null)
          Positioned.directional(
            textDirection: textDirection,
            end: timeAndStatusPosition == TimeAndStatusPosition.end ? 0 : null,
            start:
                timeAndStatusPosition == TimeAndStatusPosition.start ? 0 : null,
            bottom: 0,
            child: Padding(
              // This clamp removes the top and bottom padding
              padding: textPadding.clamp(
                const EdgeInsetsGeometry.all(0),
                const EdgeInsetsGeometry.fromLTRB(30, 0, 30, 0),
              ),
              child: timeAndStatus,
            ),
          ),
      ],
    );
  }

  Color? _resolveBackgroundColor(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return sentBackgroundColor ?? theme.primary;
    }
    return receivedBackgroundColor ?? theme.surfaceContainer;
  }

  TextStyle? _resolveParagraphStyle(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return sentTextStyle ?? theme.bodyMedium.copyWith(color: theme.onPrimary);
    }
    return receivedTextStyle ??
        theme.bodyMedium.copyWith(color: theme.onSurface);
  }

  TextStyle? _resolveTimeStyle(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return timeStyle ??
          theme.labelSmall.copyWith(
            color: _isOnlyEmoji ? theme.onSurface : theme.onPrimary,
          );
    }
    return timeStyle ?? theme.labelSmall.copyWith(color: theme.onSurface);
  }
}

/// A widget to display the message timestamp and status indicator.
class TimeAndStatus extends StatelessWidget {
  /// The time the message was created.
  final DateTime? time;

  /// The status of the message.
  final MessageStatus? status;

  /// Whether to display the timestamp.
  final bool showTime;

  /// Whether to display the status indicator.
  final bool showStatus;

  /// The text style for the time and status.
  final TextStyle? textStyle;

  /// Size of the status icon.
  final double? statusIconSize;

  /// Color of the status icon.
  final Color? statusIconColor;

  /// Whether the message has been edited.
  final bool isEdited;

  /// Creates a widget for displaying time and status.
  const TimeAndStatus({
    super.key,
    required this.time,
    this.status,
    this.showTime = true,
    this.showStatus = true,
    this.textStyle,
    this.statusIconSize,
    this.statusIconColor,
    this.isEdited = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = context.watch<DateFormat>();

    return Row(
      spacing: 2,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text('Edited', style: textStyle),
          ),
        if (showTime && time != null)
          Text(timeFormat.format(time!.toLocal()), style: textStyle),
        if (showStatus && status != null)
          if (status == MessageStatus.sending)
            SizedBox(
              width: 6,
              height: 6,
              child: CircularProgressIndicator(
                color: textStyle?.color,
                strokeWidth: 2,
              ),
            )
          else
            Icon(
              getIconForStatus(status!),
              color: statusIconColor ?? textStyle?.color,
              size: statusIconSize ?? 12,
            ),
      ],
    );
  }
}
