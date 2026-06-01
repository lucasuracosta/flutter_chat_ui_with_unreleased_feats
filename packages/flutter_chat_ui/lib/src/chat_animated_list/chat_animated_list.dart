import 'dart:async';
import 'dart:math';

import 'package:diffutil_dart/diffutil.dart' as diffutil;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import '../empty_chat_list.dart';
import '../load_more.dart';
import '../scroll_to_bottom.dart';
import '../utils/load_more_notifier.dart';
import '../utils/message_list_diff.dart';
import '../utils/typedefs.dart';
import 'sliver_spacing.dart';

/// Enum controlling the initial scroll behavior of the chat list.
enum InitialScrollToEndMode {
  /// Do not scroll initially.
  none,

  /// Jump directly to the end without animation.
  jump,

  /// Animate scrolling to the end.
  animate,
}

/// An animated list widget specifically designed for displaying chat messages.
///
/// Handles message insertion/removal animations, pagination (loading older messages),
/// automatic scrolling, keyboard handling, and scroll-to-bottom functionality.
/// It listens to a [ChatController] for message updates.
class ChatAnimatedList extends StatefulWidget {
  /// Builder function for creating individual chat message widgets.
  final ChatItem itemBuilder;

  /// Optional scroll controller for the underlying [CustomScrollView].
  final ScrollController? scrollController;

  /// Whether the list should be laid out and scrolled in reverse order.
  /// When true, new items are added at the bottom and the list grows upwards.
  final bool reversed;

  /// Default duration for message insertion animations.
  final Duration insertAnimationDuration;

  /// Default duration for message removal animations.
  final Duration removeAnimationDuration;

  /// Optional function to resolve custom insertion animation duration per message.
  final MessageAnimationDurationResolver? insertAnimationDurationResolver;

  /// Optional function to resolve custom removal animation duration per message.
  final MessageAnimationDurationResolver? removeAnimationDurationResolver;

  /// Duration for scrolling to the end/bottom of the list.
  final Duration scrollToEndAnimationDuration;

  /// Delay before the scroll-to-bottom button appears after scrolling up.
  final Duration scrollToBottomAppearanceDelay;

  /// Threshold for triggering scroll-to-bottom button appearance.
  final double scrollToBottomAppearanceThreshold;

  /// Padding added above the first item in the list.
  final double? topPadding;

  /// Padding added below the last item (before the composer).
  final double? bottomPadding;

  /// Optional sliver widget to place at the very top of the scroll view.
  final Widget? topSliver;

  /// Optional sliver widget to place at the very bottom of the scroll view.
  final Widget? bottomSliver;

  /// Whether to handle bottom safe area padding automatically.
  final bool? handleSafeArea;

  /// How the scroll view should dismiss the keyboard.
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  /// How the list should initially scroll to the end.
  /// Note: has no effect if [reversed] is true, as list starts at the bottom.
  final InitialScrollToEndMode? initialScrollToEndMode;

  /// Whether to automatically scroll to the end when a new message is sent (inserted).
  final bool? shouldScrollToEndWhenSendingMessage;

  /// Whether to automatically scroll to the end if the user is already at the bottom
  /// when a new message arrives.
  /// Note: has no effect if [reversed] is true, as new items appear at the bottom.
  final bool? shouldScrollToEndWhenAtBottom;

  /// Callback triggered when the user scrolls near the top, requesting older messages.
  final PaginationCallback? onEndReached;

  /// Threshold for triggering pagination, represented as a value between 0 and 1.
  /// 0 represents the top of the list, while 1 represents the bottom.
  /// A value of 0.2 means pagination will trigger when scrolled to 20% from the top.
  final double? paginationThreshold;

  /// Callback triggered when the user scrolls near the bottom, requesting newer messages.
  final PaginationCallback? onStartReached;

  /// Threshold for triggering start pagination, represented as a value between 0 and 1.
  /// 0 represents the top of the list, while 1 represents the bottom.
  /// A value of 0.8 means pagination will trigger when scrolled to 80% from the top.
  final double? onStartReachedThreshold;

  /// Callback triggered when the user clicks the scroll-to-bottom button.
  final VoidCallback? onScrollToBottom;

  /// The mode to use for grouping messages.
  final MessagesGroupingMode? messagesGroupingMode;

  /// Timeout in seconds for grouping consecutive messages from the same author.
  final int? messageGroupingTimeoutInSeconds;

  /// Physics for the scroll view.
  final ScrollPhysics? physics;

  /// Creates an animated chat list.
  const ChatAnimatedList({
    super.key,
    required this.itemBuilder,
    this.scrollController,
    this.reversed = false,
    this.insertAnimationDuration = const Duration(milliseconds: 250),
    this.removeAnimationDuration = const Duration(milliseconds: 250),
    this.insertAnimationDurationResolver,
    this.removeAnimationDurationResolver,
    this.scrollToEndAnimationDuration = const Duration(milliseconds: 250),
    this.scrollToBottomAppearanceDelay = const Duration(milliseconds: 250),
    this.scrollToBottomAppearanceThreshold = 0,
    this.topPadding = 8,
    this.bottomPadding = 20,
    this.topSliver,
    this.bottomSliver,
    this.handleSafeArea = true,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.initialScrollToEndMode = InitialScrollToEndMode.jump,
    this.shouldScrollToEndWhenSendingMessage = true,
    this.shouldScrollToEndWhenAtBottom = true,
    this.onEndReached,
    // Threshold for triggering pagination, represented as a value between 0 (top)
    // and 1 (bottom).
    //
    // IMPORTANT: This value defaults to a very small number (e.g., 0.01 or 1%)
    // for a critical reason. The scroll anchoring mechanism used to prevent
    // content jumps during pagination relies on accurately identifying the
    // *actual* topmost visible item *before* loading new content.
    //
    // A small threshold ensures that pagination is triggered only when the user
    // is very close to the top, making it highly likely that the scroll observer
    // correctly identifies the visually topmost item as the anchor.
    //
    // WARNING: Increasing this value significantly (e.g., to 0.2 or higher)
    // means pagination might trigger when items further down the viewport are
    // technically the "first visible" according to the observer. This will cause
    // the anchoring logic to select the wrong item, resulting in the list
    // jumping incorrectly after new items are loaded, potentially appearing to
    // scroll to a random position.
    //
    // Modify this value at your own risk. If you increase it and experience
    // unstable pagination jumps, revert to a smaller value like 0.01.
    this.paginationThreshold = 0.01,
    this.onStartReached,
    this.onStartReachedThreshold = 0.99,
    this.onScrollToBottom,
    this.messagesGroupingMode,
    this.messageGroupingTimeoutInSeconds,
    this.physics,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ChatAnimatedListState createState() => _ChatAnimatedListState();
}

/// State for [ChatAnimatedList].
class _ChatAnimatedListState extends State<ChatAnimatedList>
    with TickerProviderStateMixin {
  // Reassigned on a non-reversed setMessages to force the SliverAnimatedList to
  // rebuild cleanly from the new messages (see ChatOperationType.set).
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  late final ChatController _chatController;
  late final SliverObserverController _observerController;
  late final ScrollController _scrollController;
  late List<Message> _oldList;
  late ValueNotifier<bool> _oldListEmptyNotifier;

  // --- Center-pivot pagination (non-reversed lists only) ---
  // The non-reversed list is rendered as two regions around a zero-size center
  // sliver in a CustomScrollView with `anchor: 0`:
  //   * messages [0.._centerIndex)  -> "history", rendered ABOVE the center by a
  //     plain SliverList. Slivers before the center occupy NEGATIVE scroll
  //     offset, so prepending older messages here grows the content upward and
  //     never shifts the visible viewport — jump-free pagination, natively, with
  //     no scroll-offset correction.
  //   * messages [_centerIndex..]   -> "live", rendered BELOW the center by the
  //     SliverAnimatedList (keeps insert/remove animations for realtime/sent
  //     messages). `anchor: 0` puts offset 0 at the top, so a short chat is
  //     top-aligned (disclaimer + messages at the top, gap above the composer).
  // _centerIndex == 0 means no history has been split out (initial / short chat).
  // Only meaningful when !widget.reversed; reversed keeps the legacy single-list.
  int _centerIndex = 0;
  final GlobalKey _centerKey = GlobalKey();
  late final StreamSubscription<ChatOperation> _operationsSubscription;

  // Queue of operations to be processed
  final List<ChatOperation> _operationsQueue = [];
  bool _isProcessingOperations = false;

  late final AnimationController _scrollAnimationController;
  late final AnimationController _scrollToBottomController;
  late final Animation<double> _scrollToBottomAnimation;
  Timer? _scrollToBottomShowTimer;

  bool _userHasScrolled = false;
  bool _isScrollingToBottom = false;
  // This flag is used to determine if we already adjusted the initial
  // scroll position (so we can see latest messages when we enter chat)
  late bool _needsInitialScrollPositionAdjustment;

  // --- Initial open: hide-until-stable (non-reversed jump mode) ---
  // On open, a forward list must jump to maxScrollExtent, but maxScrollExtent is
  // a LAZY ESTIMATE computed from the few laid-out (top) items; as the list pins
  // to the bottom and the real items lay out, the estimate collapses (observed
  // ~5800 -> ~4080), and the view visibly chases the shrinking bottom — the
  // "bounce". We keep the content invisible while a periodic pin drives the
  // bottom items to lay out and the estimate to STABILISE, then reveal at the
  // settled bottom. Bounded by a tick cap + fallback timer so it can never hang.
  bool _initialScrollSettled = false;
  Timer? _initialPinTimer;
  double _lastPinnedMax = -1;
  int _stablePinTicks = 0;
  int _totalPinTicks = 0;
  MessageID _lastInsertedMessageId = '';
  // Controls whether pagination should be triggered when scrolling to the top.
  // Set to true when user scrolls up, and false after pagination is triggered.
  // This prevents infinite pagination loops when reaching the end of available messages,
  // ensuring onEndReached only fires once per user scroll gesture.
  bool _paginationShouldTrigger = false;

  // Controls whether start pagination should be triggered when scrolling to the bottom.
  // Set to true when user scrolls down, and false after start pagination is triggered.
  // This prevents infinite pagination loops when reaching the start of available messages,
  // ensuring onStartReached only fires once per user scroll gesture.
  bool _startPaginationShouldTrigger = false;

  // True while processing a ChatOperation.set (setMessages replacement).
  // _scrollToEnd is suppressed during this window so that bulk inserts from
  // a setMessages diff do not trigger an auto-scroll-to-bottom that races
  // against the caller's own scroll intent (e.g. scrollToMessage after
  // loadMessagesAround).
  bool _isReplacingMessages = false;

  @override
  void initState() {
    super.initState();
    _chatController = context.read<ChatController>();
    _scrollController = widget.scrollController ?? ScrollController();
    _observerController = SliverObserverController(
      controller: _scrollController,
    )..cacheJumpIndexOffset = false;

    _oldList = List.from(_chatController.messages);
    _oldListEmptyNotifier = ValueNotifier(_oldList.isEmpty);
    _operationsSubscription = _chatController.operationsStream.listen((event) {
      _operationsQueue.add(event);
      _processOperationsQueue();
    });

    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: Duration.zero,
    );
    _scrollAnimationController.addListener(_linkAnimationToScroll);

    _scrollToBottomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scrollToBottomAnimation = CurvedAnimation(
      parent: _scrollToBottomController,
      curve: Curves.linearToEaseOut,
    );

    if (widget.reversed) {
      // For reversed lists, the list naturally starts at the visual bottom (end).
      // So, initial scroll modes (animate/jump to end) have no effect.
      _needsInitialScrollPositionAdjustment = false;
    } else {
      // Logic for non-reversed lists
      if (widget.initialScrollToEndMode == InitialScrollToEndMode.animate) {
        _handleScrollToBottom();
        // If we animate to bottom, no further jump adjustment is needed.
        _needsInitialScrollPositionAdjustment = false;
      } else {
        // For .jump, we need adjustment. For .none, we don't.
        _needsInitialScrollPositionAdjustment =
            widget.initialScrollToEndMode == InitialScrollToEndMode.jump;
      }
    }

    // Hide content only while an initial jump-to-bottom is pending. The pin
    // (started once the first page arrives) is bounded by its own tick cap, so
    // no initState-relative timer is needed — and one would be wrong, since the
    // first page can arrive after an arbitrary network delay.
    _initialScrollSettled = !_needsInitialScrollPositionAdjustment;

    // If controller supports ScrollToMessageMixin, attach the scroll methods
    if (_chatController is ScrollToMessageMixin) {
      (_chatController as ScrollToMessageMixin).attachScrollMethods(
        scrollToMessageId: _scrollToMessageId,
        scrollToIndex: _scrollToIndex,
      );
    }
  }

  void onKeyboardHeightChanged(double height) {
    // Reversed lists handle keyboard automatically
    if (widget.reversed) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients || height == 0) {
        return;
      }

      if (widget.scrollToEndAnimationDuration == Duration.zero) {
        _scrollController.jumpTo(
          min(
            _scrollController.offset + height,
            _scrollController.position.maxScrollExtent,
          ),
        );
      } else {
        await _scrollController.animateTo(
          min(
            _scrollController.offset + height,
            _scrollController.position.maxScrollExtent,
          ),
          duration: widget.scrollToEndAnimationDuration,
          curve: Curves.linearToEaseOut,
        );
      }
      // we don't want to show the scroll to bottom button when automatically scrolling content with keyboard
      _scrollToBottomShowTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _oldListEmptyNotifier.dispose();
    _scrollToBottomShowTimer?.cancel();
    _initialPinTimer?.cancel();
    _scrollToBottomController.dispose();
    _scrollAnimationController.removeListener(_linkAnimationToScroll);
    _scrollAnimationController.dispose();
    _operationsSubscription.cancel();

    // Only try to dispose scroll controller if it's not provided, let
    // user handle disposing it how they want.
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }

    // If controller supports ScrollToMessageMixin, detach the scroll methods
    if (_chatController is ScrollToMessageMixin) {
      (_chatController as ScrollToMessageMixin).detachScrollMethods();
    }

    super.dispose();
  }

  /// Checks if the scroll view is currently at the very end of the chat list.
  /// For a reversed list, this means the scroll offset is at or before 0.
  /// For a normal list, this means the scroll offset is at or beyond `maxScrollExtent`.
  bool get _isAtChatEndScrollPosition {
    return widget.reversed
        ? _scrollController.offset <= _chatEndScrollPosition
        : _scrollController.offset >= _chatEndScrollPosition;
  }

  /// The scroll position that represents the end of the chat list.
  /// For a reversed list, this is 0.
  /// For a normal list, this is `maxScrollExtent`.
  double get _chatEndScrollPosition {
    return widget.reversed ? 0 : _scrollController.position.maxScrollExtent;
  }

  /// The user's scroll position as a fraction from the top (0) to the bottom
  /// (1) of the full scrollable range. Uses the full
  /// [minScrollExtent, maxScrollExtent] range so it stays correct when the
  /// center pivot pushes history into negative offset (minScrollExtent < 0).
  double _scrollFractionFromTop() {
    final position = _scrollController.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    if (range <= 0) return 0;
    return (position.pixels - position.minScrollExtent) / range;
  }

  /// If the scroll-to-bottom button should be shown.
  bool get _shouldShowScrollToBottomButton {
    final scrollOffsetFromBottom =
        widget.reversed
            ? _scrollController.offset
            : _chatEndScrollPosition - _scrollController.offset;

    return scrollOffsetFromBottom > widget.scrollToBottomAppearanceThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final builders = context.read<Builders>();

    // The SliverAnimatedList renders the "live" region: the whole list when
    // reversed, or messages [_centerIndex..] (below the center) when not.
    final sliverAnimatedList = SliverAnimatedList(
      key: _listKey,
      initialItemCount: widget.reversed ? _oldList.length : _belowCount,
      itemBuilder: (
        BuildContext context,
        int index,
        Animation<double> animation,
      ) {
        final contentIndex = _belowToContent(index);
        // Guard against transient out-of-range indices during inserts/removes.
        if (contentIndex < 0 || contentIndex >= _oldList.length) {
          return const SizedBox.shrink();
        }
        final message = _oldList[contentIndex];

        return widget.itemBuilder(
          context,
          message,
          contentIndex,
          animation,
          messagesGroupingMode: widget.messagesGroupingMode,
          messageGroupingTimeoutInSeconds:
              widget.messageGroupingTimeoutInSeconds,
        );
      },
    );

    // The "history" region (non-reversed only): messages [0.._centerIndex)
    // rendered ABOVE the center sliver by a plain SliverList (no animations
    // needed — history loads in bulk). Children are laid out in the reverse
    // growth direction (before the center), so child 0 is the newest history
    // message sitting just above the center, growing older/upward.
    final historySliver = SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final contentIndex = _centerIndex - 1 - i;
          if (contentIndex < 0 || contentIndex >= _oldList.length) {
            return const SizedBox.shrink();
          }
          return widget.itemBuilder(
            context,
            _oldList[contentIndex],
            contentIndex,
            kAlwaysCompleteAnimation,
            messagesGroupingMode: widget.messagesGroupingMode,
            messageGroupingTimeoutInSeconds:
                widget.messageGroupingTimeoutInSeconds,
          );
        },
        childCount: _centerIndex,
        findChildIndexCallback: (key) {
          if (key is ValueKey<String>) {
            final idx = _oldList.indexWhere((m) => m.id == key.value);
            if (idx >= 0 && idx < _centerIndex) {
              return _centerIndex - 1 - idx;
            }
          }
          return null;
        },
      ),
    );

    // Zero-size pivot. Everything listed before it occupies negative scroll
    // offset (history, grows upward); everything after occupies positive offset.
    final centerSliver = SliverToBoxAdapter(
      key: _centerKey,
      child: const SizedBox.shrink(),
    );

    List<Widget> buildSlivers() {
      if (widget.reversed) {
        // Order for CustomScrollView(reverse: true) -> Visual Bottom to Top
        return <Widget>[
          // Visually at the bottom (first in sliver list for reverse: true)
          _buildComposerHeightSliver(context),
          if (widget.bottomSliver != null) widget.bottomSliver!,
          if (widget.onStartReached != null) _buildLoadMoreStartSliver(builders),
          sliverAnimatedList,
          if (widget.onEndReached != null) _buildLoadMoreSliver(builders),
          if (widget.topSliver != null) widget.topSliver!,
          if (widget.topPadding != null)
            SliverPadding(padding: EdgeInsets.only(top: widget.topPadding!)),
          // Visually at the top (last in sliver list for reverse: true)
        ];
      } else {
        // Non-reversed: two regions around the center pivot. Slivers BEFORE the
        // center are laid out in REVERSE order from the center upward, so the
        // last entry before the center sits closest to it.
        //
        // topPadding stays permanently above the center (topmost). It must NOT
        // migrate across the pivot when history first appears, or the live
        // region would shift by its height on the first load-older.
        //
        // topSliver (e.g. the "start of chat" disclaimer) sits above the history
        // when history exists, otherwise at the top of the live region so a
        // short chat shows it at the top instead of in negative (off-screen)
        // offset. This never actually migrates: topSliver is only non-null once
        // the start is reached, and by then `hasHistory` is already settled for
        // that conversation (a short chat keeps _centerIndex == 0; a paginated
        // chat reaches the start with _centerIndex > 0).
        final bool hasHistory = _centerIndex > 0;
        return <Widget>[
          // ----- before center (negative offset, grows upward) -----
          if (widget.topPadding != null)
            SliverPadding(padding: EdgeInsets.only(top: widget.topPadding!)),
          if (hasHistory && widget.topSliver != null) widget.topSliver!,
          if (widget.onEndReached != null) _buildLoadMoreSliver(builders),
          historySliver,
          // ----- center pivot (scroll offset 0, top of viewport) -----
          centerSliver,
          // ----- after center (positive offset, grows downward) -----
          if (!hasHistory && widget.topSliver != null) widget.topSliver!,
          sliverAnimatedList,
          if (widget.onStartReached != null) _buildLoadMoreStartSliver(builders),
          if (widget.bottomSliver != null) widget.bottomSliver!,
          _buildComposerHeightSliver(context),
        ];
      }
    }

    // Hide the content while the initial jump-to-bottom + extent stabilisation
    // runs, so the lazy maxScrollExtent correction isn't visible as a bounce.
    final bool hideForInitialScroll =
        !widget.reversed && !_initialScrollSettled && _oldList.isNotEmpty;

    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is ScrollMetricsNotification) {
          // Handle initial scroll to bottom so you see latest messages
          _adjustInitialScrollPosition();
          _handleToggleScrollToBottom();
          _handlePagination();
          _handleStartPagination();
        }

        if (notification is UserScrollNotification) {
          // When user scrolls up (toward older messages), enable end pagination
          if (notification.direction ==
              (widget.reversed
                  ? ScrollDirection.reverse
                  : ScrollDirection.forward)) {
            _paginationShouldTrigger = true;
            _userHasScrolled = true;
          } else {
            // When user scrolls down (toward newer messages), enable start pagination
            if (notification.direction ==
                (widget.reversed
                    ? ScrollDirection.forward
                    : ScrollDirection.reverse)) {
              _startPaginationShouldTrigger = true;
            }
            // When user overscrolls to the bottom or stays idle at the bottom, set `_userHasScrolled` to false
            if (_isAtChatEndScrollPosition) {
              _userHasScrolled = false;
            }
          }
        }

        if (notification is ScrollUpdateNotification) {
          _handleToggleScrollToBottom();
        }

        // Allow other listeners to get the notification
        return false;
      },
      child: Stack(
        children: [
          Opacity(
            opacity: hideForInitialScroll ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: hideForInitialScroll,
              child: SliverViewObserver(
                controller: _observerController,
                sliverContexts: () {
                  // Using the key's context ensures we always have the latest, valid
                  // context for the SliverAnimatedList, or null if it's not built.
                  // This is safer than storing a BuildContext.
                  final context = _listKey.currentContext;
                  return [if (context != null) context];
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  reverse: widget.reversed,
                  // Non-reversed lists pivot around the center sliver so prepended
                  // history grows into negative offset (jump-free). anchor: 0 keeps
                  // offset 0 at the top of the viewport (top-aligned short chats).
                  center: widget.reversed ? null : _centerKey,
                  anchor: 0,
                  physics: widget.physics,
                  keyboardDismissBehavior:
                      widget.keyboardDismissBehavior ??
                      ScrollViewKeyboardDismissBehavior.manual,
                  slivers: buildSlivers(), // Use the new helper method
                ),
              ),
            ),
          ),
          builders.scrollToBottomBuilder?.call(
                context,
                _scrollToBottomAnimation,
                _handleScrollToBottom,
              ) ??
              ScrollToBottom(
                animation: _scrollToBottomAnimation,
                onPressed: _handleScrollToBottom,
              ),
          ValueListenableBuilder<bool>(
            valueListenable: _oldListEmptyNotifier,
            builder: (context, isEmpty, child) {
              if (isEmpty) {
                return Positioned.fill(
                  child:
                      builders.emptyChatListBuilder?.call(context) ??
                      const EmptyChatList(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComposerHeightSliver(BuildContext context) => SliverSpacing(
    bottomPadding: widget.bottomPadding,
    handleSafeArea: widget.handleSafeArea,
    onKeyboardHeightChanged: widget.reversed ? null : onKeyboardHeightChanged,
  );

  Widget _buildLoadMoreSliver(Builders builders) {
    return SliverToBoxAdapter(
      child: Consumer<LoadMoreNotifier>(
        builder: (context, notifier, child) {
          return Visibility(
            visible: notifier.isLoading,
            maintainState: true,
            child: child!,
          );
        },
        child: builders.loadMoreBuilder?.call(context) ?? LoadMore(),
      ),
    );
  }

  Widget _buildLoadMoreStartSliver(Builders builders) {
    return SliverToBoxAdapter(
      child: Consumer<LoadMoreNotifier>(
        builder: (context, notifier, child) {
          return Visibility(
            visible: notifier.isLoadingStart,
            maintainState: true,
            child: child!,
          );
        },
        child: builders.loadMoreBuilder?.call(context) ?? LoadMore(isStart: true),
      ),
    );
  }

  /// Joins the `AnimationController` to the `ScrollController`, providing ample
  /// time for the lazy list to render its contents while scrolling to the bottom.
  /// See https://stackoverflow.com/a/77175903 for more details.
  void _linkAnimationToScroll() {
    // In reversed lists, scrolling to the bottom corresponds to a position of 0,
    // which eliminates concerns about the dynamic nature of maxScrollExtent.
    if (widget.reversed) {
      return;
    }

    _scrollController.jumpTo(
      _scrollAnimationController.value *
          _scrollController.position.maxScrollExtent,
    );
  }

  void _initialScrollToEnd() async {
    // Delay the scroll to the end animation so new message is painted, otherwise
    // maxScrollExtent is not yet updated and the animation might not work.
    await Future.delayed(widget.insertAnimationDuration);

    if (!_scrollController.hasClients ||
        !mounted ||
        _isAtChatEndScrollPosition) {
      return;
    }

    if (widget.scrollToEndAnimationDuration == Duration.zero) {
      _scrollController.jumpTo(_chatEndScrollPosition);
    } else {
      await _scrollController.animateTo(
        _chatEndScrollPosition,
        duration: widget.scrollToEndAnimationDuration,
        curve: Curves.linearToEaseOut,
      );
    }
  }

  void _subsequentScrollToEnd(Message data) async {
    // Skip auto-scrolling based on configuration.
    // For reversed lists, scrolling is skipped if `shouldScrollToEndWhenSendingMessage` is false.
    // For non-reversed lists, scrolling is skipped if *both* `shouldScrollToEndWhenSendingMessage`
    // and `shouldScrollToEndWhenAtBottom` are false.
    if (widget.shouldScrollToEndWhenSendingMessage == false &&
        (widget.reversed || widget.shouldScrollToEndWhenAtBottom == false)) {
      return;
    }

    // Skip scroll logic if this is not the most recently inserted message
    // or if the list is already scrolled to the bottom. This prevents
    // duplicate scrolling when multiple messages are inserted at once.
    if (data.id != _lastInsertedMessageId || _isAtChatEndScrollPosition) {
      return;
    }

    // When user hasn't manually scrolled up, automatically scroll to show new messages.
    // This matches typical chat behavior where you stay at the bottom to see incoming
    // messages unless you've explicitly scrolled up to view history.
    // After scrolling, exit the function since no other scroll behavior is needed.
    if (!widget.reversed &&
        widget.shouldScrollToEndWhenAtBottom == true &&
        !_userHasScrolled) {
      if (widget.scrollToEndAnimationDuration == Duration.zero) {
        _scrollController.jumpTo(_chatEndScrollPosition);
      } else {
        await _scrollController.animateTo(
          _chatEndScrollPosition,
          duration: widget.scrollToEndAnimationDuration,
          curve: Curves.linearToEaseOut,
        );
      }
      return;
    }

    final currentUserId = context.read<UserID>();

    // When the user sends a new message, automatically scroll back to
    // the bottom to show their message.
    // This matches common chat UX where sending a message returns focus
    // to the most recent messages. After scrolling, exit the function since
    // no other scroll behavior is needed.
    if (widget.shouldScrollToEndWhenSendingMessage == true &&
        currentUserId == data.authorId &&
        _oldList.last.id == data.id) {
      // When scrolled up in chat history use fling to guarantee scrolling
      // to the very end of the list.
      // See https://stackoverflow.com/a/77175903 for more details.
      if (!widget.reversed && _userHasScrolled) {
        _scrollAnimationController.value =
            _scrollController.offset /
            _scrollController.position.maxScrollExtent;
        await _scrollAnimationController.fling();
      } else {
        if (widget.scrollToEndAnimationDuration == Duration.zero) {
          _scrollController.jumpTo(_chatEndScrollPosition);
        } else {
          await _scrollController.animateTo(
            _chatEndScrollPosition,
            duration: widget.scrollToEndAnimationDuration,
            curve: Curves.linearToEaseOut,
          );
        }
      }
      return;
    }
  }

  void _scrollToEnd(Message data) {
    if (_isReplacingMessages) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;

      // We need this condition because if scroll view is not yet scrollable,
      // we want to wait for the insert animation to finish before scrolling to the end.
      if (!widget.reversed && _scrollController.position.maxScrollExtent == 0) {
        // Scroll view is not yet scrollable, scroll to the end if
        // new message makes it scrollable.
        _initialScrollToEnd();
      } else {
        _subsequentScrollToEnd(data);
      }
    });
  }

  void _adjustInitialScrollPosition() {
    // Reversed lists start at the bottom already; nothing to do.
    if (widget.reversed || !_needsInitialScrollPositionAdjustment) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;
      if (!_needsInitialScrollPositionAdjustment) return;
      // Wait for the first page to arrive; keep the flag so we still jump once
      // it does (do NOT clear it, or the chat would open at the top).
      if (_oldList.isEmpty) return;
      // Start the pin once we have content. The pin handles both a scrollable
      // chat (jump to bottom, wait for the extent to stabilise) and a short
      // chat that fits (maxScrollExtent stays 0 -> reveal top-aligned).
      if (_initialPinTimer == null) {
        _startInitialPin();
      }
    });
  }

  /// Pins the viewport to the bottom on a periodic tick so the lazy list lays
  /// out its bottom items and [ScrollPosition.maxScrollExtent] converges from
  /// its initial (over-)estimate to the real value. The content stays hidden
  /// (see `_initialScrollSettled`) until the extent is STABLE for a few ticks,
  /// so the user never sees the estimate-correction "bounce". Bounded by a hard
  /// tick cap (~640ms) so it always reveals.
  void _startInitialPin() {
    _initialPinTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        timer.cancel();
        _initialPinTimer = null;
        return;
      }
      final position = _scrollController.position;
      final max = position.maxScrollExtent;
      _totalPinTicks++;

      // Snap exactly to the bottom each tick. This both drives the bottom items
      // to lay out (refining the extent estimate) AND snaps back instantly when
      // the estimate shrinks below the current offset (which would otherwise
      // leave us overscrolled and slowly settling — a visible bounce).
      if (max > 0 && (position.pixels - max).abs() > 0.5) {
        _scrollController.jumpTo(max);
      }

      // Has the content height stopped changing?
      if ((max - _lastPinnedMax).abs() < 1.0) {
        _stablePinTicks++;
      } else {
        _stablePinTicks = 0;
        _lastPinnedMax = max;
      }

      // Settle once the extent is stable and we're pinned at the bottom, or
      // after a hard cap (~640ms) so a never-settling chat still reveals.
      final atBottom = max == 0 || (position.pixels - max).abs() < 1.0;
      final stableAtBottom = _stablePinTicks >= 4 && atBottom;
      if (stableAtBottom || _totalPinTicks >= 40) {
        timer.cancel();
        _initialPinTimer = null;
        _finishInitialScroll();
      }
    });
  }

  /// Stops the initial-open adjustment, snaps to the bottom one last time, and
  /// reveals the content.
  void _finishInitialScroll() {
    _needsInitialScrollPositionAdjustment = false;
    _initialPinTimer?.cancel();
    _initialPinTimer = null;
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      if (max > 0 && _scrollController.offset < max - 0.5) {
        _scrollController.jumpTo(max);
      }
    }
    if (mounted && !_initialScrollSettled) {
      setState(() => _initialScrollSettled = true);
    }
  }

  void _handleScrollToBottom() {
    // Trigger callback immediately when button is clicked
    widget.onScrollToBottom?.call();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;

      _isScrollingToBottom = true;

      _scrollToBottomController.reverse();

      if (widget.reversed) {
        if (widget.scrollToEndAnimationDuration == Duration.zero) {
          _scrollController.jumpTo(_chatEndScrollPosition);
        } else {
          _scrollController.animateTo(
            _chatEndScrollPosition,
            duration: widget.scrollToEndAnimationDuration,
            curve: Curves.linearToEaseOut,
          );
        }
      } else {
        // Use fling to guarantee scrolling to the very end of the list.
        // See https://stackoverflow.com/a/77175903 for more details.
        // N/A for reversed list above as position 0 is stable, while
        // maxScrollExtent is not.
        _scrollAnimationController.value =
            _scrollController.offset /
            _scrollController.position.maxScrollExtent;
        _scrollAnimationController.fling();
      }

      _userHasScrolled = false;
      _isScrollingToBottom = false;
    });
  }

  void _handleToggleScrollToBottom() {
    if (!_isScrollingToBottom) {
      _scrollToBottomShowTimer?.cancel();
      if (_shouldShowScrollToBottomButton) {
        _scrollToBottomShowTimer = Timer(
          widget.scrollToBottomAppearanceDelay,
          () {
            if (mounted) {
              // If we show scroll to bottom that means user is viewing the history
              // so we set `_userHasScrolled` to true.
              _userHasScrolled = true;
              _scrollToBottomController.forward();
            }
          },
        );
      } else {
        if (_scrollToBottomController.status == AnimationStatus.completed ||
            _scrollToBottomController.status == AnimationStatus.forward) {
          _scrollToBottomController.reverse();
        }
      }
    }
  }

  void _handlePagination() async {
    if (!_scrollController.hasClients ||
        !mounted ||
        _needsInitialScrollPositionAdjustment ||
        widget.onEndReached == null ||
        context.read<LoadMoreNotifier>().isLoading ||
        !_paginationShouldTrigger) {
      return;
    }

    // Get the threshold for pagination, defaulting to the very top of the list
    var threshold = (widget.paginationThreshold ?? 0);
    if (widget.reversed) {
      threshold = 1 - threshold;
    }

    // Calculate the user's scroll position as a percentage of the total scrollable area, ranging from 0 to 1.
    // In a standard list, 0 represents the topmost position and 1 represents the bottommost position.
    // In a reversed list, the values are inverted: 1 indicates the top and 0 indicates the bottom.
    final scrollPercentage = _scrollFractionFromTop();

    final shouldTrigger =
        widget.reversed
            ? scrollPercentage >= threshold
            : scrollPercentage <= threshold;

    // Trigger pagination if user scrolled past the threshold towards the top.
    if (shouldTrigger) {
      // Prevent multiple triggers during one scroll gesture.
      _paginationShouldTrigger = false;

      // Ensure mounted before using context or calling async widget callbacks
      if (!mounted) return;

      // Show loading indicator.
      context.read<LoadMoreNotifier>().setLoading(true);

      // Load older messages. _onInsertedAll handles scroll preservation.
      await widget.onEndReached!();

      // Ensure mounted after await, as onEndReached might unmount the widget
      if (!mounted) return;

      // Hide the loading indicator once items are inserted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<LoadMoreNotifier>().setLoading(false);
      });
    }
  }

  void _handleStartPagination() async {
    if (!_scrollController.hasClients ||
        !mounted ||
        _needsInitialScrollPositionAdjustment ||
        widget.onStartReached == null ||
        context.read<LoadMoreNotifier>().isLoadingStart ||
        !_startPaginationShouldTrigger) {
      return;
    }

    // Get the threshold for start pagination, defaulting to the very bottom of the list
    var threshold = (widget.onStartReachedThreshold ?? 0.99);
    if (widget.reversed) {
      threshold = 1 - threshold;
    }

    // Calculate the user's scroll position as a percentage of the total scrollable area, ranging from 0 to 1.
    // In a standard list, 0 represents the topmost position and 1 represents the bottommost position.
    // In a reversed list, the values are inverted: 1 indicates the top and 0 indicates the bottom.
    final scrollPercentage = _scrollFractionFromTop();

    final shouldTrigger =
        widget.reversed
            ? scrollPercentage <= threshold
            : scrollPercentage >= threshold;

    // Trigger start pagination if user scrolled past the threshold towards the bottom.
    if (shouldTrigger) {
      // Prevent multiple triggers during one scroll gesture.
      _startPaginationShouldTrigger = false;

      // Store the ID of the bottommost visible item before loading new messages.
      // This item will be used as an anchor to maintain scroll position.
      MessageID? anchorMessageId;
      int? initialMessagesCount;

      // --- Scroll Anchoring Setup: Only for reversed lists ---
      if (widget.reversed) {
        try {
          // We can only anchor the scroll position if the list is actually
          // in the widget tree and has a context.
          if (_listKey.currentContext != null) {
            final notificationResult = await _observerController
                .dispatchOnceObserve(
                  sliverContext: _listKey.currentContext!,
                  isForce: true,
                  isDependObserveCallback: false,
                );
            final lastItem =
                notificationResult
                    .observeResult
                    ?.innerDisplayingChildModelList
                    .lastOrNull;
            final anchorIndex = lastItem?.index;

            if (anchorIndex != null &&
                anchorIndex >= 0 &&
                anchorIndex < _oldList.length) {
              anchorMessageId = _oldList[anchorIndex].id;
            }
          }
        } catch (e) {
          debugPrint('Error observing scroll position for start anchoring: $e');
        }
        if (!mounted) return;
        initialMessagesCount = _oldList.length;
      }
      // --- End Scroll Anchoring Setup ---

      // Ensure mounted before using context or calling async widget callbacks
      if (!mounted) return;

      // Show loading indicator.
      context.read<LoadMoreNotifier>().setLoadingStart(true);

      // Load newer messages.
      await widget.onStartReached!();

      // Ensure mounted after await, as onStartReached might unmount the widget
      if (!mounted) return;

      // Wait for the next frame for UI updates.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || !mounted) return;

        final notifier = context.read<LoadMoreNotifier>();

        // --- Scroll Anchoring Action: Only for reversed lists ---
        if (widget.reversed) {
          // initialMessageCount will be non-null here if widget.reversed
          final didAddMessages = _oldList.length > initialMessagesCount!;
          if (didAddMessages && anchorMessageId != null) {
            final newIndex = _oldList.indexWhere(
              (m) => m.id == anchorMessageId,
            );
            if (newIndex != -1) {
              _scrollToIndex(
                newIndex,
                duration: Duration.zero, // Jump immediately
                alignment: 1, // Align to the bottom edge
                offset: 0, // Keep item bottom edge aligned with viewport bottom edge
              );
            }
          }
        }
        // --- End Scroll Anchoring Action ---

        // Hide loading indicator.
        notifier.setLoadingStart(false);
      });
    }
  }

  /// Scrolls to a specific message by ID.
  Future<void> _scrollToMessageId(
    MessageID messageId, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linearToEaseOut,
    double alignment = 0,
    double offset = 0,
  }) async {
    final index = _oldList.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return;
    }

    return _scrollToIndex(
      index,
      duration: duration,
      curve: curve,
      alignment: alignment,
      offset: offset,
    );
  }

  /// Scrolls to a specific index in the message list.
  Future<void> _scrollToIndex(
    int index, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linearToEaseOut,
    double alignment = 0,
    double offset = 0,
  }) async {
    if (index < 0 || index >= _oldList.length) {
      return;
    }

    if (!widget.reversed) {
      await _scrollToIndexWithPivot(
        index,
        duration: duration,
        curve: curve,
        alignment: alignment,
        offset: offset,
      );
      return;
    }

    // Reversed lists keep the scrollview_observer path (its native alignment
    // behaviour is what the reversed onStartReached anchor relies on).
    if (_listKey.currentContext == null) return;
    final visualIndex = _contentToBelow(index);
    try {
      if (duration == Duration.zero) {
        await _observerController.jumpTo(
          index: visualIndex,
          alignment: alignment,
          offset: (targetOffset) => offset,
          renderSliverType: ObserverRenderSliverType.list,
        );
      } else {
        await _observerController.animateTo(
          index: visualIndex,
          duration: duration,
          curve: curve,
          alignment: alignment,
          offset: (targetOffset) => offset,
          renderSliverType: ObserverRenderSliverType.list,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Deterministic, observer-free scroll-to-index for non-reversed lists.
  ///
  /// scrollview_observer's gradual scroll-to-an-offscreen-index is unreliable
  /// on the center-pivot CustomScrollView (especially right after a setMessages
  /// rebuild): it overshoots / lands on the wrong item. Instead we use the
  /// pivot itself: make [index] the first item of the live region, which puts
  /// its leading edge at scroll offset 0 (the center) — an EXACT position with
  /// no measurement. Then scroll up by `alignment * viewportExtent` so the
  /// message lands at that fraction of the viewport (0 = top, 0.5 = middle,
  /// 1 = bottom), clamped to whatever history exists above it.
  Future<void> _scrollToIndexWithPivot(
    int index, {
    required Duration duration,
    required Curve curve,
    required double alignment,
    required double offset,
  }) async {
    // Re-pivot so the target heads the live region. A fresh key forces the
    // SliverAnimatedList to rebuild with the new initialItemCount.
    _centerIndex = index;
    _listKey = GlobalKey<SliverAnimatedListState>();
    if (mounted) setState(() {});

    // Let the new layout settle so min/maxScrollExtent are valid.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    // Target leading edge is at scroll offset 0; scroll up (negative) by
    // alignment * viewport to bring it down to that viewport fraction.
    final double desired = -(alignment * position.viewportDimension) - offset;
    final double target = desired.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (duration == Duration.zero) {
      _scrollController.jumpTo(target);
    } else {
      await _scrollController.animateTo(target, duration: duration, curve: curve);
    }
  }

  void _onInserted(final int position, final Message data) {
    // If for some reason `_userHasScrolled` is true and the user is not at the bottom of the list,
    // set `_userHasScrolled` to false
    if (_userHasScrolled && _isAtChatEndScrollPosition) {
      _userHasScrolled = false;
    }

    // Insertion into the history region (above the center): no animated-list
    // op, just grow `_oldList` and the pivot and rebuild the plain history
    // sliver. Grows into negative offset -> no viewport shift.
    if (_isHistory(position)) {
      _oldList.insert(position, data);
      _updateOldListEmptyNotifier();
      _lastInsertedMessageId = data.id;
      if (mounted) setState(() => _centerIndex += 1);
      return;
    }

    final Duration duration;
    // Determine the animation duration for inserting the item.
    // - For reversed lists, always use the specified insert animation duration.
    // - For non-reversed lists, use the animation duration only if the list is not yet scrollable.
    //   If it's already scrollable, the item is added instantly (Duration.zero),
    //   and the _scrollToEnd logic handles the visual scroll to the new item.
    if (widget.reversed || _scrollController.position.maxScrollExtent == 0) {
      if (widget.insertAnimationDurationResolver != null) {
        duration =
            widget.insertAnimationDurationResolver!(data) ??
            widget.insertAnimationDuration;
      } else {
        duration = widget.insertAnimationDuration;
      }
    } else {
      // Non-reversed and already scrollable
      duration = Duration.zero;
    }

    _oldList.insert(position, data);
    _updateOldListEmptyNotifier();
    // The insertItem method requires the position of the item after the insert
    _listKey.currentState!.insertItem(
      _contentToBelow(position),
      // We are only animating items when scroll view is not yet scrollable,
      // otherwise we just insert the item without animation.
      // (animation is replaced with scroll to bottom animation)
      duration: duration,
    );

    // Used later to trigger scroll to end only for the last inserted message.
    _lastInsertedMessageId = data.id;

    _scrollToEnd(data);
  }

  void _onInsertedAll(final int position, List<Message> messagesToInsert) {
    // If for some reason `_userHasScrolled` is true and the user is not at the bottom of the list,
    // set `_userHasScrolled` to false
    if (_userHasScrolled && _isAtChatEndScrollPosition) {
      _userHasScrolled = false;
    }

    // Inserting at/above the pivot (non-reversed, non-empty list, not a
    // replace-diff): route into the history region above the center. The common
    // case is load-older at position 0 — these grow into negative scroll offset,
    // so the viewport never shifts (jump-free pagination, no scroll correction).
    // Covering `position <= _centerIndex` (not just == 0) also keeps any
    // bulk insert that lands inside the history window out of the live
    // SliverAnimatedList, which would otherwise get a negative visual index.
    // Skipped for the initial load (empty list -> everything below the center)
    // and for setMessages diffs (history is collapsed first).
    final bool routeToHistory = !widget.reversed &&
        position <= _centerIndex &&
        _oldList.isNotEmpty &&
        !_isReplacingMessages;
    if (routeToHistory) {
      _oldList.insertAll(0, messagesToInsert);
      _updateOldListEmptyNotifier();
      if (mounted) {
        setState(() => _centerIndex += messagesToInsert.length);
      } else {
        _centerIndex += messagesToInsert.length;
      }
      return;
    }

    final Duration duration;
    // Determine the animation duration for inserting the item.
    // - For reversed lists, always use the specified insert animation duration.
    // - For non-reversed lists, use the animation duration only if the list is not yet scrollable.
    //   If it's already scrollable, the item is added instantly (Duration.zero),
    //   and the _scrollToEnd logic handles the visual scroll to the new item.
    if (widget.reversed || _scrollController.position.maxScrollExtent == 0) {
      if (widget.insertAnimationDurationResolver != null) {
        duration =
            widget.insertAnimationDurationResolver!(messagesToInsert.last) ??
            widget.insertAnimationDuration;
      } else {
        duration = widget.insertAnimationDuration;
      }
    } else {
      // Non-reversed and already scrollable
      duration = Duration.zero;
    }

    _oldList.insertAll(position, messagesToInsert);
    _updateOldListEmptyNotifier();

    int visualStartIndexForInsertAllItems;

    if (widget.reversed) {
      // For a reversed list, the `index` for insertAllItems should be the
      // visual index of the item that will appear "earliest" (visually lowest index)
      // in the rendering of the newly inserted block.
      // Since the block itself is also visually reversed when rendered,
      // this corresponds to the visual position of the last content item in the block.
      // Example: Block [C,D] (C=content[pos], D=content[pos+1]) is visually [D, C].
      // We need the visual index of D for insertAllItems.
      visualStartIndexForInsertAllItems = visualPosition(
        position + messagesToInsert.length - 1,
      );
    } else {
      // Normal list: map the content position into the live (below-center)
      // SliverAnimatedList index.
      visualStartIndexForInsertAllItems = _contentToBelow(position);
    }

    _listKey.currentState!.insertAllItems(
      visualStartIndexForInsertAllItems,
      messagesToInsert.length,
      duration: duration,
    );

    // _scrollToEnd is intentionally NOT called here. Bulk insertions always
    // come from pagination (load older / load newer / missing messages) and
    // the caller owns the resulting scroll position. Auto-scroll-to-end only
    // makes sense for single real-time messages (_onInserted).
  }

  void _onRemoved(final int position, final Message data) {
    // Removal from the history region (above the center): no animated-list op,
    // just shrink `_oldList` and the pivot and rebuild the plain history sliver.
    if (_isHistory(position)) {
      _oldList.removeAt(position);
      _updateOldListEmptyNotifier();
      if (mounted) setState(() => _centerIndex -= 1);
      return;
    }

    // Use animation duration resolver if provided, otherwise use default duration.
    final duration =
        widget.removeAnimationDurationResolver != null
            ? (widget.removeAnimationDurationResolver!(data) ??
                widget.removeAnimationDuration)
            : widget.removeAnimationDuration;

    // Calculate the visual index for SliverAnimatedList.removeItem BEFORE modifying _oldList.
    // SliverAnimatedList.removeItem expects the index of the item *before* it's removed.
    final visualIndex = _contentToBelow(position);

    _oldList.removeAt(position);
    _updateOldListEmptyNotifier();

    _listKey.currentState!.removeItem(
      visualIndex, // Use the pre-calculated visual index.
      (context, animation) => widget.itemBuilder(
        context,
        data, // Pass the actual message data being removed.
        position, // Pass its original position.
        animation,
        messagesGroupingMode: widget.messagesGroupingMode,
        messageGroupingTimeoutInSeconds: widget.messageGroupingTimeoutInSeconds,
        isRemoved: true,
      ),
      duration: duration,
    );
  }

  void _onChanged(int position, Message oldData, Message newData) {
    _onRemoved(position, oldData);
    _onInserted(position, newData);
  }

  /// Handles a `Move` operation as identified by `diffutil.calculateDiff`.
  /// A move operation is treated as a removal from the `oldPos` followed by an
  /// insertion at an adjusted `newPos`.
  ///
  /// Parameters from `diffutil.DataMove<Message>`:
  ///  - `oldPos`: The original index of the item in `_oldList` before any
  ///    operations from the current diff batch have been applied.
  ///  - `newPos`: The target index for the item in the list *after* it has been
  ///    notionally removed from `oldPos` (and other preceding removals in the
  ///    batch might have occurred, though this method only considers the local
  ///    effect of its own `_onRemoved` call when adjusting `newPos`).
  ///    `diffutil_dart` seems to provide `newPos` as the target index in the list
  ///    state if the item at `oldPos` was the only one removed.
  ///  - `data`: The message data being moved.
  ///
  /// The method first calls `_onRemoved` using `oldPos`. Then, it uses `newPos`
  /// (clamped to valid list bounds) as the `insertionPos` for the subsequent
  /// `_onInserted` call. This sequence correctly updates `_oldList` and drives
  /// the `SliverAnimatedList` removal and insertion animations to visually
  /// represent the move.
  void _onMove(int oldPosition, int newPosition, Message data) {
    // Moves only arrive via the setMessages diff, which collapses history first
    // (so _centerIndex == 0 and every position is in the live region). This
    // assert locks that invariant: a move crossing the pivot would desync the
    // SliverAnimatedList count, since the two halves route independently.
    assert(
      widget.reversed || _centerIndex == 0,
      '_onMove must run with history collapsed (_centerIndex == 0).',
    );
    // 1. Perform the removal part of the move.
    // This removes the item from _oldList at oldPos and triggers removeItem animation.
    _onRemoved(oldPosition, data);

    // 2. Determine the insertion position.
    // Based on testing, diffutil_dart's `newPos` for a Move operation appears
    // to be the target index *after* the item at `oldPos` is removed.
    // We use this `newPos` directly, after clamping it to the current list bounds.
    var insertionPos = newPosition;

    // Sanity check: Ensure insertionPos is within the bounds of _oldList,
    // which has now shrunk by one item due to the preceding _onRemoved call.
    // Valid insertion indices for _oldList.insert() are 0 to _oldList.length (inclusive).
    if (_oldList.isNotEmpty) {
      insertionPos = insertionPos.clamp(0, _oldList.length);
    } else {
      // If _oldList becomes empty after removal, the only valid insertion index is 0.
      insertionPos = 0;
    }

    // 3. Perform the insertion part of the move.
    // This inserts the item back into _oldList at the calculated insertionPos
    // and triggers insertItem animation.
    _onInserted(insertionPos, data);
  }

  /// Maps a conceptual item position from `_oldList` (content order) to its
  /// visual position in the `SliverAnimatedList` (rendering order).
  /// For non-reversed lists, content and visual positions are the same.
  /// For reversed lists, this transforms the index to account for the reversed rendering order
  /// (e.g., content item 0 becomes the last visual item).
  /// The `indexPosition` refers to the index in the `_oldList`.
  int visualPosition(int indexPosition) {
    return widget.reversed
        ? max(_oldList.length - indexPosition - 1, 0)
        : indexPosition;
  }

  /// Number of messages rendered by the "live" SliverAnimatedList (below the
  /// center). For reversed lists this is the whole list.
  int get _belowCount =>
      widget.reversed ? _oldList.length : _oldList.length - _centerIndex;

  /// Maps a SliverAnimatedList visual index -> index in `_oldList` (content).
  int _belowToContent(int sliverIndex) =>
      widget.reversed ? visualPosition(sliverIndex) : sliverIndex + _centerIndex;

  /// Maps an `_oldList` index (content) -> SliverAnimatedList visual index.
  /// Only valid for content indices in the live region ([_centerIndex..]).
  int _contentToBelow(int contentIndex) =>
      widget.reversed ? visualPosition(contentIndex) : contentIndex - _centerIndex;

  /// Whether the given content index lives in the history region (above the
  /// center) and is therefore NOT rendered by the SliverAnimatedList.
  bool _isHistory(int contentIndex) =>
      !widget.reversed && contentIndex < _centerIndex;

  void _onDiffUpdate(diffutil.DataDiffUpdate<Message> update) {
    update.when<void>(
      insert: (pos, data) => _onInserted(pos, data),
      remove: (pos, data) => _onRemoved(pos, data),
      change: (pos, oldData, newData) => _onChanged(pos, oldData, newData),
      move: (oldPos, newPos, data) => _onMove(oldPos, newPos, data),
    );
  }

  /// Update the _oldListEmptyNotifier if necessary
  void _updateOldListEmptyNotifier() {
    final newIsEmpty = _oldList.isEmpty;
    if (newIsEmpty != _oldListEmptyNotifier.value) {
      _oldListEmptyNotifier.value = newIsEmpty;
    }
  }

  /// Processes the queue of chat operations.
  void _processOperationsQueue() {
    // Safety to no process twice, should not really happen
    if (_isProcessingOperations) return;
    _isProcessingOperations = true;
    while (_operationsQueue.isNotEmpty) {
      final ops = List.of(_operationsQueue);
      _operationsQueue.clear();
      for (final op in ops) {
        switch (op.type) {
          case ChatOperationType.insert:
            assert(
              op.index != null,
              'Index must be provided when inserting a message.',
            );
            assert(
              op.message != null,
              'Message must be provided when inserting a message.',
            );
            _onInserted(op.index!, op.message!);
            break;
          case ChatOperationType.remove:
            assert(
              op.index != null,
              'Index must be provided when removing a message.',
            );
            assert(
              op.message != null,
              'Message must be provided when removing a message.',
            );
            _onRemoved(op.index!, op.message!);
            break;
          case ChatOperationType.set:
            // If op.messages is provided (even if empty), it's the new desired state.
            // If op.messages is null, it signifies that the list should be cleared.
            final newList = op.messages ?? const <Message>[];

            if (!widget.reversed) {
              // Non-reversed: a setMessages is always a full replace (jump-to-
              // message / refresh / first-page). Swap the data and give the
              // SliverAnimatedList a fresh key so it rebuilds directly over the
              // new messages — no per-item diff, no history rebuild churn, pivot
              // back to 0 (top-aligned). The caller re-positions the scroll.
              _oldList = List.of(newList);
              _centerIndex = 0;
              _listKey = GlobalKey<SliverAnimatedListState>();
              _updateOldListEmptyNotifier();
              if (mounted) setState(() {});
              break;
            }

            final updates =
                diffutil
                    .calculateDiff<Message>(
                      MessageListDiff(_oldList, newList),
                      detectMoves: true,
                    )
                    .getUpdatesWithData();

            _isReplacingMessages = true;
            for (final update in updates) {
              _onDiffUpdate(update);
            }
            _isReplacingMessages = false;
            break;
          case ChatOperationType.insertAll:
            assert(
              op.index != null,
              'Index must be provided when inserting all messages.',
            );
            assert(
              op.messages != null && op.messages!.isNotEmpty,
              'Messages must be provided and be non-empty when inserting all.',
            );
            _onInsertedAll(op.index!, op.messages!);
            break;
          case ChatOperationType.update:
            assert(
              op.index != null,
              'Index must be provided when updating a message.',
            );
            _oldList[op.index!] = op.message!;
            // If the updated message lives in the history region, rebuild the
            // plain history sliver so the change is reflected (the live region
            // is driven by the SliverAnimatedList / message widgets themselves).
            if (_isHistory(op.index!) && mounted) {
              setState(() {});
            }
            break;
        }
      }
    }
    _isProcessingOperations = false;
  }
}
