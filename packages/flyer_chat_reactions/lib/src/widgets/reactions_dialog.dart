import 'dart:ui';

import 'package:animate_do/animate_do.dart' show FadeInLeft, Pulse;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ChatProviders, buildMessageContent;
import 'package:provider/provider.dart';

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
    required this.messageWidget,
    required this.messageId,
    required this.onReactionTap,
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
    this.reactionsPickerBackgroundColor,
    this.reactionsPickerReactedBackgroundColor,
    this.menuItemTapAnimationDuration,
    this.reactionTapAnimationDuration,
    this.reactionPickerFadeLeftAnimationDuration,
  });

  /// The id of the message for which the dialog is displayed
  /// Used for Hero animation tag
  final String messageId;

  /// The message widget to be displayed in the dialog
  final Widget messageWidget;

  /// The callback function to be called when a reaction is tapped
  final OnReactionTapCallback onReactionTap;

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

  /// The background color for reactions picker
  final Color? reactionsPickerBackgroundColor;

  /// The color for the reactions reacted by the user
  final Color? reactionsPickerReactedBackgroundColor;

  /// Animation duration when a reaction is selected
  final Duration? reactionTapAnimationDuration;

  /// Animation duration to display the reactions row
  final Duration? reactionPickerFadeLeftAnimationDuration;

  @override
  State<ReactionsDialogWidget> createState() => _ReactionsDialogWidgetState();
}

class _ReactionsDialogWidgetState extends State<ReactionsDialogWidget>
    with SingleTickerProviderStateMixin {
  bool reactionClicked = false;
  int? clickedReactionIndex;
  int? clickedContextMenuIndex;
  bool _showPickerAndMenu = false;

  @override
  void initState() {
    super.initState();
    // Wait for Hero animation to complete before showing picker and menu
    /* WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showPickerAndMenu = true;
          });
        }
      });
    }); */
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _hidePickerAndMenuBeforePop();
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () {
          _hidePickerAndMenuBeforePop();
          Future.delayed(const Duration(milliseconds: 100)).whenComplete(() {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          });
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, left: 8),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _showPickerAndMenu ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: buildReactionsPicker(context, theme),
                ),
                const SizedBox(height: 10),
                buildMessage(),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _showPickerAndMenu ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: buildMenuItems(context, theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Align buildMenuItems(BuildContext context, _LocalTheme theme) {
    final destructiveColor = widget.menuItemDestructiveColor ?? Colors.red;
    return Align(
      alignment: widget.widgetAlignment ?? Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          /// TODO: maybe use pixels, for desktop?
          width:
              MediaQuery.of(context).size.width *
              (widget.menuItemsWidthRatio ?? 0.45),
          decoration: BoxDecoration(
            color: widget.menuItemBackgroundColor ?? theme.surface,
            borderRadius: theme.shape,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var item in widget.menuItems ?? const [])
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            clickedContextMenuIndex = widget.menuItems?.indexOf(
                              item,
                            );
                          });

                          _hidePickerAndMenuBeforePop();
                          Future.delayed(
                            widget.menuItemTapAnimationDuration ??
                                const Duration(milliseconds: 200),
                          ).whenComplete(() {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            item.onTap?.call();
                          });
                        },
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
                            Pulse(
                              infinite: false,
                              duration:
                                  widget.menuItemTapAnimationDuration ??
                                  const Duration(milliseconds: 100),
                              animate:
                                  clickedContextMenuIndex ==
                                  widget.menuItems?.indexOf(item),
                              child: Icon(
                                item.icon,
                                color:
                                    item.isDestructive
                                        ? destructiveColor
                                        : theme.onSurface,
                              ),
                            ),
                          ],
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
      ),
    );
  }

  Align buildMessage() {
    return Align(
      alignment: widget.widgetAlignment ?? Alignment.centerRight,
      child: Hero(
        tag: widget.messageId,
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          animation.addListener(() {
            // We want to start the menu animation a bit before the hero animation ends
            // to avoid a "sluggish" feeling
            if (animation.value > 0.9 &&
                !_showPickerAndMenu &&
                animation.isForwardOrCompleted) {
              if (mounted) {
                setState(() {
                  _showPickerAndMenu = true;
                });
              }
            }
          });
          return widget.messageWidget;
        },
        child: widget.messageWidget,
      ),
    );
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
                  FadeInLeft(
                    from: 0 + (i * 20).toDouble(),
                    duration:
                        widget.reactionPickerFadeLeftAnimationDuration ??
                        const Duration(milliseconds: 200),
                    delay: Duration.zero,
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
                        _hidePickerAndMenuBeforePop();
                        Future.delayed(
                          reactionTapAnimationDuration,
                        ).whenComplete(() {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          widget.onReactionTap(allReactions[i]);
                        });
                      },
                    ),
                  ),
                if (widget.onMoreReactionsTap != null)
                  FadeInLeft(
                    from: 0 + (allReactions.length * 20).toDouble(),
                    duration:
                        widget.reactionPickerFadeLeftAnimationDuration ??
                        const Duration(milliseconds: 200),
                    delay: Duration.zero,
                    child: InkWell(
                      onTap: () {
                        _hidePickerAndMenuBeforePop();
                        Future.delayed(
                          const Duration(milliseconds: 100),
                        ).whenComplete(() {
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
void showReactionsDialog(
  BuildContext context,
  Message message, {
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
}) {
  final providers = ChatProviders.from(context);

  final widget = buildMessageContent(
    context,
    context.read<Builders>(),
    message,
    0,
    isSentByMe: isSentByMe,
    isInsideMenu: true,
  );

  Navigator.push(
    context,
    new PageRouteBuilder(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      fullscreenDialog: true,
      opaque: false,
      transitionDuration: Duration(milliseconds: 500),
      pageBuilder: (BuildContext context, animation1, animation2) {
        return MultiProvider(
          providers: providers,
          child: SafeArea(
            child: ReactionsDialogWidget(
              messageWidget: widget,
              messageId: message.id,
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
            ),
          ),
        );
      },
    ),
  );
  return;
}
