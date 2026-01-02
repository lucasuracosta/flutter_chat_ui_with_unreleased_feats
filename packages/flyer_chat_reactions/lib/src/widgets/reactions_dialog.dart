import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animate_do/animate_do.dart' show FadeInLeft, Pulse, FadeInRight;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../models/default_data.dart';
import '../models/menu_item.dart';
import '../utils/typedef.dart';

//// Theme values for [ReactionsDialogWidget].
typedef _LocalTheme =
    ({
      Color onSurface,
      Color surface,
      Color primary,
      BorderRadiusGeometry shape,
    });

class ReactionsDialogWidget extends StatefulWidget {
  const ReactionsDialogWidget({
    super.key,
    required this.message,
    required this.onReactionTap,
    required this.isSentByMe,
    required this.needsPositionAdjustment,
    required this.messageOffset,
    required this.messageSize,
    this.moreReactionsWidget,
    this.onMoreReactionsTap,
    this.menuItems,
    this.reactions,
    this.userReactions,
    this.widgetAlignment,
    this.menuItemsWidthRatio,
    this.menuItemBackgroundColor,
    this.menuItemDestructiveColor,
    this.menuItemDividerColor,
    this.menuItemPadding,
    this.reactionsPickerBackgroundColor,
    this.reactionsPickerReactedBackgroundColor,
    this.menuItemTapAnimationDuration,
    this.reactionTapAnimationDuration,
    this.reactionPickerFadeLeftAnimationDuration,
    this.horizontalMessagePadding = 8,
    this.onlyMenu = false,
  });

  /// The message for which the dialog is displayed
  /// Used to build the message widget
  final Message message;

  /// Whether to show only the menu without reactions picker
  final bool onlyMenu;

  /// The horizontal padding for the message widget
  final double horizontalMessagePadding;

  /// The callback function to be called when a reaction is tapped
  final OnReactionTapCallback onReactionTap;

  /// Whether the message is sent by the current user
  final bool isSentByMe;

  /// Whether the position needs to be adjusted to fit within safe area
  final bool needsPositionAdjustment;

  /// More Reactions Widget
  final Widget? moreReactionsWidget;

  /// The callback function to be called when the "more" reactions  widget is tapped
  /// If not provided the widget will not be displayed
  final VoidCallback? onMoreReactionsTap;

  /// The list of menu items to be displayed in the context menu
  final List<MenuItem>? menuItems;

  /// The list of default reactions to be displayed
  final List<String>? reactions;

  /// The list of user reactions to be displayed
  /// This allow user to remove them from here
  final List<String>? userReactions;

  /// The alignment of the widget
  /// Only left right is taken into account
  final Alignment? widgetAlignment;

  /// The width ratio of the menu items
  final double? menuItemsWidthRatio;

  /// Animation duration when a menu item is selected
  final Duration? menuItemTapAnimationDuration;

  /// The background color for menu items
  final Color? menuItemBackgroundColor;

  /// Destructive color for menu items
  final Color? menuItemDestructiveColor;

  /// The divider color for menu items
  final Color? menuItemDividerColor;

  /// The padding for menu items
  final EdgeInsetsGeometry? menuItemPadding;

  /// The background color for reactions picker
  final Color? reactionsPickerBackgroundColor;

  /// The color for the reactions reacted by the user
  final Color? reactionsPickerReactedBackgroundColor;

  /// Animation duration when a reaction is selected
  final Duration? reactionTapAnimationDuration;

  /// Animation duration to display the reactions row
  final Duration? reactionPickerFadeLeftAnimationDuration;

  /// These two properties (offset and size) are calculated before calling this function
  /// we could consider calculating that inside here

  /// The offset of the message widget in the parent Hero
  final Offset messageOffset;

  /// The size of the message widget
  final Size messageSize;

  @override
  State<ReactionsDialogWidget> createState() => _ReactionsDialogWidgetState();
}

class _ReactionsDialogWidgetState extends State<ReactionsDialogWidget>
    with SingleTickerProviderStateMixin {
  bool reactionClicked = false;
  int? clickedReactionIndex;
  int? clickedContextMenuIndex;
  bool _showPickerAndMenu = false;
  final GlobalKey _reactionsPickerKey = GlobalKey();
  final GlobalKey _menuItemsKey = GlobalKey();
  double _reactionsPickerHeight = 0;
  double _menuItemsHeight = 0;
  bool _useFloatingMenu = false;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToTop = true;
  double _topPadding = 0;

  @override
  void initState() {
    super.initState();

    // Add scroll listener for floating menu scenario
    _scrollController.addListener(_onScroll);

    // Calculate reactions picker and menu items height after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateHeights();
      if (mounted && widget.needsPositionAdjustment == false) {
        Timer(const Duration(milliseconds: 50), () {
          setState(() {
            _showPickerAndMenu = true;
          });
        });
      } else if (mounted && widget.needsPositionAdjustment) {
        // If position adjustment is needed, this adds redundancy to ensure
        // the menu and picker are shown after the position is settled
        // in case the flightShuttleBuilder logic doesn't trigger it
        Timer(const Duration(milliseconds: 150), () {
          if (!_showPickerAndMenu && mounted) {
            setState(() {
              _showPickerAndMenu = true;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Check if we're at the top (with a small threshold)
    final isAtTop = _scrollController.offset <= 5.0;

    if (isAtTop != _isScrolledToTop) {
      setState(() {
        _isScrolledToTop = isAtTop;
      });
    }
  }

  void _calculateHeights() {
    final pickerRenderBox =
        _reactionsPickerKey.currentContext?.findRenderObject() as RenderBox?;
    final menuRenderBox =
        _menuItemsKey.currentContext?.findRenderObject() as RenderBox?;

    if (pickerRenderBox != null && menuRenderBox != null && mounted) {
      setState(() {
        _reactionsPickerHeight =
            pickerRenderBox.size.height + 0; // +10 for bottom padding
        _menuItemsHeight =
            menuRenderBox.size.height + 10; // +10 for top padding
      });
    }
  }

  void _hidePickerAndMenuBeforePop() {
    setState(() {
      _showPickerAndMenu = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select(
      (ChatTheme t) => (
        onSurface: t.colors.onSurface,
        surface: t.colors.surface,
        primary: t.colors.primary,
        shape: t.shape,
      ),
    );

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom =
        mediaQuery.padding.bottom + 20; // Extra padding at bottom

    // Calculate top position ensuring it's not below 0 and accounts for SafeArea
    late double calculatedTop;
    final desiredTop = widget.messageOffset.dy;

    // Calculate total height needed for message + menu
    final totalHeight = (widget.messageSize.height ?? 0) + _menuItemsHeight;

    // Calculate the top position of the reactions picker
    // The reactions picker is positioned above the message
    final reactionsPickerTop =
        desiredTop - _reactionsPickerHeight - 10; // 10 is the bottom padding

    // Check if we need to adjust for bottom safe area
    final needsBottomAdjustment =
        (desiredTop + totalHeight) > (screenHeight - safeAreaBottom);

    // Check if we need to adjust for top safe area (reactions picker going above)
    final needsTopAdjustment =
        !widget.onlyMenu && reactionsPickerTop < safeAreaTop;

    // Determine if we need both adjustments (message is too large to fit)
    final needsBothAdjustments = needsTopAdjustment && needsBottomAdjustment;

    if (needsBothAdjustments) {
      // Message is too large - position to keep reactions picker below top safe area
      // and float the menu at the bottom
      calculatedTop =
          safeAreaTop + _reactionsPickerHeight + 10; // 10 is the bottom padding
      _useFloatingMenu = true;
      _topPadding = calculatedTop; // Store for scroll padding
    } else if (needsBottomAdjustment) {
      // Adjust top to fit within screen bottom, accounting for SafeArea
      calculatedTop = math.max(
        safeAreaTop,
        screenHeight - safeAreaBottom - totalHeight,
      );
      _useFloatingMenu = false;
    } else if (needsTopAdjustment) {
      // Adjust top to ensure reactions picker is below top safe area
      // Move the message down so the reactions picker sits at safeAreaTop
      calculatedTop =
          safeAreaTop + _reactionsPickerHeight + 10; // 10 is the bottom padding
      _useFloatingMenu = false;
    } else {
      calculatedTop = desiredTop;
      _useFloatingMenu = false;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _hidePickerAndMenuBeforePop();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Background tap area to dismiss dialog
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _hidePickerAndMenuBeforePop();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Message (and menu if not floating)
              Positioned.directional(
                textDirection:
                    widget.isSentByMe ? TextDirection.rtl : TextDirection.ltr,
                start: widget.horizontalMessagePadding,
                top: _useFloatingMenu ? 0 : calculatedTop,
                width: widget.messageSize.width,
                height: _useFloatingMenu ? screenHeight : null,
                child:
                    _useFloatingMenu
                        ? SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _hidePickerAndMenuBeforePop();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: Container(
                                  height: _topPadding,
                                  color: Colors.transparent,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _hidePickerAndMenuBeforePop();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: buildMessage(),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _hidePickerAndMenuBeforePop();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: Container(
                                  height: 40,
                                  color: Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _hidePickerAndMenuBeforePop();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: buildMessage(),
                            ),
                            AnimatedScale(
                              key: _menuItemsKey,
                              scale: _showPickerAndMenu ? 1.0 : 0.5,
                              duration: const Duration(milliseconds: 150),
                              alignment:
                                  widget.isSentByMe
                                      ? Alignment.topRight
                                      : Alignment.topLeft,
                              child: AnimatedOpacity(
                                opacity: _showPickerAndMenu ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: buildMenuItems(context, theme),
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
              // Floating menu at bottom when message is too large
              if (_useFloatingMenu)
                Positioned.directional(
                  textDirection:
                      widget.isSentByMe ? TextDirection.rtl : TextDirection.ltr,
                  start: widget.horizontalMessagePadding,
                  bottom: safeAreaBottom,
                  width: widget.messageSize.width,
                  child: GestureDetector(
                    onTap: () {}, // Absorb taps on menu
                    child: AnimatedScale(
                      key: _menuItemsKey,
                      scale: _showPickerAndMenu && _isScrolledToTop ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 150),
                      alignment:
                          widget.isSentByMe
                              ? Alignment.topRight
                              : Alignment.topLeft,
                      child: AnimatedOpacity(
                        opacity:
                            _showPickerAndMenu && _isScrolledToTop ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: buildMenuItems(context, theme),
                      ),
                    ),
                  ),
                ),
              // Reactions are in a separate positioned widget so that we can
              // use the message offset for the message itself and then set
              // the reactions above it avoiding calculations to compensate for the reactions
              if (!widget.onlyMenu)
                Positioned.directional(
                  textDirection:
                      widget.isSentByMe ? TextDirection.rtl : TextDirection.ltr,
                  start: widget.horizontalMessagePadding,
                  bottom:
                      _useFloatingMenu
                          ? (mediaQuery.size.height - _topPadding)
                          : (mediaQuery.size.height - calculatedTop),
                  width: widget.messageSize.width,
                  child: GestureDetector(
                    onTap: () {}, // Absorb taps on reactions
                    child: AnimatedOpacity(
                      key: _reactionsPickerKey,
                      opacity:
                          _showPickerAndMenu &&
                                  (!_useFloatingMenu || _isScrolledToTop)
                              ? 1.0
                              : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: buildReactionsPicker(context, theme),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Align buildMenuItems(BuildContext context, _LocalTheme theme) {
    final destructiveColor = widget.menuItemDestructiveColor ?? Colors.red;
    return Align(
      alignment: widget.widgetAlignment ?? Alignment.centerRight,
      child: Container(
        /// TODO: maybe use pixels, for desktop?
        width:
            MediaQuery.of(context).size.width *
            (widget.menuItemsWidthRatio ?? 0.45),
        decoration: BoxDecoration(
          color: widget.menuItemBackgroundColor ?? theme.surface,
          borderRadius: theme.shape,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var item in widget.menuItems ?? const [])
              Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          clickedContextMenuIndex = widget.menuItems?.indexOf(
                            item,
                          );
                        });

                        Future.delayed(
                          widget.menuItemTapAnimationDuration ??
                              const Duration(milliseconds: 200),
                        ).whenComplete(() {
                          _hidePickerAndMenuBeforePop();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          item.onTap?.call();
                        });
                      },
                      child: Padding(
                        padding:
                            widget.menuItemPadding ?? const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                color:
                                    item.isDestructive
                                        ? destructiveColor
                                        : theme.onSurface,
                              ),
                            ),
                            item.customIcon ??
                                Icon(
                                  item.icon,
                                  color:
                                      item.isDestructive
                                          ? destructiveColor
                                          : theme.onSurface,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.menuItems?.last != item)
                    Divider(
                      color: widget.menuItemDividerColor ?? Colors.white,
                      thickness: 0.5,
                      height: 0.5,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget buildMessage() {
    // It needs to have a Material widget so that it can capture the clicks in
    // the transparent section to close the dialog.
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: widget.widgetAlignment ?? Alignment.centerRight,
        child: Hero(
          tag: widget.message.id,
          flightShuttleBuilder: (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            late VoidCallback showListener;

            showListener = () {
              // We want to start the menu animation a bit before the hero animation ends
              // to avoid a "sluggish" feeling
              if (animation.value > 0.9 &&
                  !_showPickerAndMenu &&
                  animation.isForwardOrCompleted &&
                  widget.needsPositionAdjustment) {
                if (mounted) {
                  setState(() {
                    _showPickerAndMenu = true;
                  });

                  // Proper cleanup of the listener
                  animation.removeListener(showListener);
                }
              }
            };

            animation.addListener(showListener);

            return GestureDetector(
              onTap: () {},
              child: buildMessageWithProviders(),
            );
          },
          child: GestureDetector(
            onTap: () {},
            child: buildMessageWithProviders(),
          ),
        ),
      ),
    );
  }

  Widget buildMessageWithProviders() {
    final providers = ChatProviders.from(context);
    return MultiProvider(
      providers: providers,
      child: buildMessageContent(
        context,
        context.read<Builders>(),
        widget.message,
        0,
        isSentByMe: widget.isSentByMe,
        isInsideMenu: true,
      ),
    );
  }

  Widget fadeDependingOnPosition({
    required double from,
    required InkWell child,
  }) {
    if (widget.isSentByMe) {
      return FadeInRight(
        duration:
            widget.reactionPickerFadeLeftAnimationDuration ??
            const Duration(milliseconds: 200),
        delay: Duration.zero,
        child: child,
      );
    } else {
      return FadeInLeft(
        duration:
            widget.reactionPickerFadeLeftAnimationDuration ??
            const Duration(milliseconds: 200),
        delay: Duration.zero,
        child: child,
      );
    }
  }

  Align buildReactionsPicker(BuildContext context, _LocalTheme theme) {
    // Merge default reactions with user reactions, removing duplicates
    final allReactions =
        <String>{
          ...(widget.reactions ?? DefaultData.reactions),
          ...(widget.userReactions ?? const []),
        }.toList();

    final reactionTapAnimationDuration =
        widget.reactionTapAnimationDuration ??
        const Duration(milliseconds: 200);
    return Align(
      alignment: widget.widgetAlignment ?? Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: widget.reactionsPickerBackgroundColor ?? theme.surface,
            borderRadius: theme.shape,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < allReactions.length; i++)
                  fadeDependingOnPosition(
                    from: 0 + (i * 20).toDouble(),
                    child: InkWell(
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        padding: const EdgeInsets.fromLTRB(4.0, 2.0, 4.0, 2),
                        decoration: BoxDecoration(
                          color:
                              (widget.userReactions ?? const []).contains(
                                    allReactions[i],
                                  )
                                  ? widget.reactionsPickerReactedBackgroundColor ??
                                      theme.onSurface.withValues(alpha: 0.2)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Pulse(
                          infinite: false,
                          duration: reactionTapAnimationDuration,
                          animate: reactionClicked && clickedReactionIndex == i,
                          child: Text(
                            allReactions[i],
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          reactionClicked = true;
                          clickedReactionIndex = i;
                        });
                        Future.delayed(
                          reactionTapAnimationDuration,
                        ).whenComplete(() {
                          _hidePickerAndMenuBeforePop();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          widget.onReactionTap(allReactions[i]);
                        });
                      },
                    ),
                  ),
                if (widget.onMoreReactionsTap != null)
                  fadeDependingOnPosition(
                    from: 0 + (allReactions.length * 20).toDouble(),
                    child: InkWell(
                      onTap: () {
                        Future.delayed(
                          const Duration(milliseconds: 100),
                        ).whenComplete(() {
                          _hidePickerAndMenuBeforePop();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          widget.onMoreReactionsTap?.call();
                        });
                      },
                      child:
                          widget.moreReactionsWidget ??
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              4.0,
                              2.0,
                              4.0,
                              2,
                            ),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              color: theme.onSurface,
                            ),
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Method to display the reactions dialog for a message
/// Refer to [ReactionsDialogWidget] for the available parameters
///
dynamic showReactionsDialog(
  BuildContext context,
  Message message,
  LongPressStartDetails details, {
  required bool isSentByMe,
  required Function(String) onReactionTap,
  VoidCallback? onMoreReactionsTap,
  List<MenuItem>? menuItems,
  List<String>? reactions,
  List<String>? userReactions,
  Alignment? widgetAlignment,
  double? menuItemsWidthRatio,
  Color? menuItemBackgroundColor,
  Color? menuItemDestructiveColor,
  Color? menuItemDividerColor,
  Color? reactionsPickerBackgroundColor,
  Color? reactionsPickerReactedBackgroundColor,
  Duration? menuItemTapAnimationDuration,
  Duration? reactionTapAnimationDuration,
  Duration? reactionPickerFadeLeftAnimationDuration,
  Widget? moreReactionsWidget,
  EdgeInsetsGeometry? menuItemPadding,
  double horizontalMessagePadding = 8,
  bool onlyMenu = false,
}) async {
  HapticFeedback.mediumImpact();

  final List<SingleChildWidget> providers = ChatProviders.from(context);

  // Get the message widget's position and size
  final renderBox = context.findRenderObject() as RenderBox?;
  Offset? messageOffset;
  Size? messageSize;

  if (renderBox != null) {
    // Use the long press details to calculate the message position
    // details.globalPosition is where the user pressed in global coordinates
    // details.localPosition is where the user pressed relative to the ChatMessage widget
    // The top of the ChatMessage = globalPosition.dy - localPosition.dy
    final chatMessageTop = details.globalPosition.dy - details.localPosition.dy;

    // Get the size from renderBox
    messageSize = renderBox.size;

    // Use chatMessageTop as the offset
    // This gives us the top of the entire ChatMessage widget
    // The Row with the actual message is inside, but this should be close enough
    messageOffset = Offset(
      renderBox.localToGlobal(Offset.zero).dx,
      chatMessageTop,
    );
  }

  // Calculate if position needs adjustment to determine animation duration
  final mediaQuery = MediaQuery.of(context);
  final screenHeight = mediaQuery.size.height;
  final safeAreaTop = mediaQuery.padding.top;
  final safeAreaBottom = mediaQuery.padding.bottom;

  var needsPositionAdjustment = false;
  if (messageOffset != null && messageSize != null) {
    // Rough estimate of total height (actual calculation happens in widget)
    final estimatedTotalHeight =
        60 + messageSize.height + 150; // picker + message + menu estimate
    final desiredTop = messageOffset.dy - 60;

    needsPositionAdjustment =
        (desiredTop + estimatedTotalHeight > screenHeight - safeAreaBottom) ||
        (desiredTop < safeAreaTop);
  }

  return await Navigator.push(
    context,
    new PageRouteBuilder(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.1),
      fullscreenDialog: true,
      opaque: false,
      transitionDuration: Duration(
        milliseconds: needsPositionAdjustment ? 200 : 150,
      ),
      reverseTransitionDuration: Duration(
        milliseconds: needsPositionAdjustment ? 200 : 150,
      ),
      pageBuilder: (BuildContext context, animation1, animation2) {
        return MultiProvider(
          providers: providers,
          child: ReactionsDialogWidget(
            message: message,
            onlyMenu: onlyMenu,
            horizontalMessagePadding: horizontalMessagePadding,
            isSentByMe: isSentByMe,
            needsPositionAdjustment: needsPositionAdjustment,
            widgetAlignment:
                widgetAlignment ??
                (isSentByMe ? Alignment.centerRight : Alignment.centerLeft),
            onReactionTap: (reaction) {
              onReactionTap(reaction);
            },
            onMoreReactionsTap: onMoreReactionsTap,
            menuItems: menuItems,
            reactions: reactions,
            userReactions: userReactions,
            menuItemsWidthRatio: menuItemsWidthRatio,
            menuItemBackgroundColor: menuItemBackgroundColor,
            menuItemDestructiveColor: menuItemDestructiveColor,
            menuItemDividerColor: menuItemDividerColor,
            reactionsPickerBackgroundColor: reactionsPickerBackgroundColor,
            reactionsPickerReactedBackgroundColor:
                reactionsPickerReactedBackgroundColor,
            menuItemTapAnimationDuration: menuItemTapAnimationDuration,
            reactionTapAnimationDuration: reactionTapAnimationDuration,
            reactionPickerFadeLeftAnimationDuration:
                reactionPickerFadeLeftAnimationDuration,
            moreReactionsWidget: moreReactionsWidget,
            messageOffset: messageOffset!, //TODO: Handle null with a fallback
            messageSize: messageSize!, //TODO: Handle null with a fallback
            menuItemPadding: menuItemPadding,
          ),
        );
      },
    ),
  );
}
