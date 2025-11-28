import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_reactions/flyer_chat_reactions.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:flyer_chat_video_message/flyer_chat_video_message.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flyer Chat Image & Video Message Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ImageMessageExample(),
    );
  }
}

class ImageMessageExample extends StatefulWidget {
  const ImageMessageExample({super.key});

  @override
  State<ImageMessageExample> createState() => _ImageMessageExampleState();
}

class _ImageMessageExampleState extends State<ImageMessageExample>
    with TickerProviderStateMixin {
  final _chatController = InMemoryChatController();
  final String _currentUserId = 'user1';
  final Set<String> _selectedMessageIds = {};
  bool _isSelectMode = false;

  // Pagination state
  int _olderMessagesPage = 0;
  int _newerMessagesPage = 0;
  final int _messagesPerPage = 5;

  // Sample hardcoded text messages
  final List<TextMessage> _sampleTextMessages = [
    TextMessage(
      id: 'txt0',
      authorId: 'user1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 11)),
      metadata: {'is_edited': true},
      text: 'Hello!',
      status: MessageStatus.seen,
    ),
    TextMessage(
      id: 'txt1',
      authorId: 'user2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      text: 'Hey! How are you doing?',
    ),
    TextMessage(
      id: 'txt2',
      authorId: 'user1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
      metadata: {'is_edited': true},
      text: 'I\'m doing great! Thanks for asking 😊',
      status: MessageStatus.seen,
    ),
    TextMessage(
      id: 'txt3',
      authorId: 'user2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      metadata: {'is_edited': true},
      text:
          'That\'s awesome! I wanted to share some cool images with you. (I edited this message)',
    ),
    TextMessage(
      id: 'txt4',
      authorId: 'user1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 7)),
      text: 'Sure! I\'d love to see them.',
      status: MessageStatus.delivered,
    ),
    TextMessage(
      id: 'txt5',
      authorId: 'user2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
      metadata: {'is_edited': true},
      text: 'Here they are! Let me know what you think:',
    ),
  ];

  // Sample hardcoded image messages
  final List<ImageMessage> _sampleImageMessages = [
    ImageMessage(
      id: 'img1',
      authorId: 'user2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      source: 'https://picsum.photos/400/300',
      width: 400,
      height: 300,
      hasOverlay: true, // This will show an overlay if we provide one
    ),
    ImageMessage(
      id: 'img2',
      authorId: 'user1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      source: 'https://picsum.photos/300/400',
      width: 300,
      height: 400,
      hasOverlay: true, // This will show an overlay if we provide one
    ),
    ImageMessage(
      id: 'img3',
      authorId: 'user2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      source: 'https://picsum.photos/500/250',
      width: 500,
      height: 250,
      // Sample BlurHash for placeholder
      blurhash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
      hasOverlay: true, // This will show an overlay if we provide one
    ),
    ImageMessage(
      id: 'img4',
      authorId: 'user1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      source: 'https://picsum.photos/350/350',
      width: 350,
      height: 350,
      status: MessageStatus.seen,
      hasOverlay: true, // This will show an overlay if we provide one
    ),
    ImageMessage(
      id: 'img5',
      authorId: 'user2',
      createdAt: DateTime.now(),
      source: 'https://picsum.photos/600/200',
      width: 600,
      height: 200,
      hasOverlay: true, // This will show an overlay if we provide one
    ),
    ImageMessage(
      id: 'img6',
      authorId: 'user1',
      createdAt: DateTime.now().add(const Duration(seconds: 30)),
      source: 'https://picsum.photos/400/600',
      width: 400,
      height: 600,
      hasOverlay: true, // WhatsApp-style gradient will be applied
    ),
  ];

  // Sample hardcoded video messages
  final List<VideoMessage> _sampleVideoMessages = [
    VideoMessage(
      id: 'vid1',
      authorId: 'user2',
      createdAt: DateTime.now().add(const Duration(minutes: 5)),
      source:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      width: 640,
      height: 360,
    ),
    VideoMessage(
      id: 'vid2',
      authorId: 'user1',
      createdAt: DateTime.now().add(const Duration(minutes: 6)),
      source:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      width: 640,
      height: 360,
      status: MessageStatus.sent,
    ),
    VideoMessage(
      id: 'vid3',
      authorId: 'user2',
      createdAt: DateTime.now().add(const Duration(minutes: 7)),
      source:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      width: 1280,
      height: 720,
    ),
  ];

  // Additional text messages after images and videos
  final List<TextMessage> _sampleTextMessagesAfter = [
    TextMessage(
      id: 'txt6',
      authorId: 'user1',
      createdAt: DateTime.now().add(const Duration(minutes: 1)),
      metadata: {'is_edited': true},
      text: 'Wow! These are absolutely beautiful! 📸 (edited)',
      status: MessageStatus.sent,
    ),
    TextMessage(
      id: 'txt7',
      authorId: 'user2',
      createdAt: DateTime.now().add(const Duration(minutes: 2)),
      text: 'Thanks! I took them during my trip last weekend.',
    ),
    TextMessage(
      id: 'txt8',
      authorId: 'user1',
      createdAt: DateTime.now().add(const Duration(minutes: 3)),
      metadata: {'is_edited': true},
      text: 'Where did you go? The scenery looks amazing! 🌄',
    ),
    TextMessage(
      id: 'txt9',
      authorId: 'user2',
      createdAt: DateTime.now().add(const Duration(minutes: 4)),
      text: 'It was up in the mountains. Perfect weather for photography!',
      status: MessageStatus.delivered,
    ),
    TextMessage(
      id: 'txt10',
      authorId: 'user2',
      createdAt: DateTime.now().add(const Duration(minutes: 8)),
      text: 'I also took some videos! Check them out:',
    ),
    TextMessage(
      id: 'txt11',
      authorId: 'user1',
      createdAt: DateTime.now().add(const Duration(minutes: 9)),
      metadata: {'is_edited': true},
      text:
          'Amazing videos! The scenery is breathtaking! 🎥 (this was edited too)',
      status: MessageStatus.sent,
    ),
  ];

  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<Offset>> _slideAnimations = {};
  final Map<String, Animation<double>> _sizeAnimations = {};

  // Animation controllers for composer and bottom bar
  late AnimationController _composerAnimationController;
  late AnimationController _bottomBarAnimationController;
  late Animation<Offset> _composerSlideAnimation;
  late Animation<Offset> _bottomBarSlideAnimation;

  AnimationController _getOrCreateAnimationController(String messageId) {
    return _animationControllers.putIfAbsent(
      messageId,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  Animation<Offset> _getOrCreateSlideAnimation(String messageId) {
    return _slideAnimations.putIfAbsent(messageId, () {
      final controller = _getOrCreateAnimationController(messageId);
      return Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    });
  }

  Animation<double> _getOrCreateSizeAnimation(String messageId) {
    return _sizeAnimations.putIfAbsent(messageId, () {
      final controller = _getOrCreateAnimationController(messageId);
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    });
  }

  void _enterSelectMode() {
    setState(() {
      _isSelectMode = true;
    });
    // Animate composer out (slide down)
    _composerAnimationController.forward();
    // Animate bottom bar in (slide up)
    _bottomBarAnimationController.forward();
    // Animate all message leading widgets in
    for (final controller in _animationControllers.values) {
      controller.forward();
    }
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedMessageIds.clear();
    });
    // Animate composer in (slide up)
    _composerAnimationController.reverse();
    // Animate bottom bar out (slide down)
    _bottomBarAnimationController.reverse();
    // Animate all message leading widgets out
    for (final controller in _animationControllers.values) {
      controller.reverse();
    }
  }

  // Load older messages (pagination from the top)
  Future<void> _loadOlderMessages() async {
    debugPrint('Loading older messages...');
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    _olderMessagesPage++;

    // Generate older messages
    final olderMessages = List.generate(_messagesPerPage, (index) {
      final messageNumber = _olderMessagesPage * _messagesPerPage + index;
      return TextMessage(
        id: 'older_txt_$messageNumber',
        authorId: messageNumber % 2 == 0 ? 'user2' : 'user1',
        createdAt: DateTime.now().subtract(
          Duration(minutes: 100 + messageNumber),
        ),
        text: 'This is older message #$messageNumber loaded via onEndReached',
        status: MessageStatus.delivered,
      );
    });

    // Add older messages to the chat
    for (final message in olderMessages) {
      _chatController.insertMessage(message);
    }

    debugPrint('Loaded ${olderMessages.length} older messages');
  }

  // Load newer messages (pagination from the bottom)
  Future<void> _loadNewerMessages() async {
    debugPrint('Loading newer messages...');
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    _newerMessagesPage++;

    // Generate newer messages
    final newerMessages = List.generate(_messagesPerPage, (index) {
      final messageNumber = _newerMessagesPage * _messagesPerPage + index;
      return TextMessage(
        id: 'newer_txt_$messageNumber',
        authorId: messageNumber % 2 == 0 ? 'user1' : 'user2',
        createdAt: DateTime.now().add(Duration(minutes: 100 + messageNumber)),
        text: 'This is newer message #$messageNumber loaded via onStartReached',
        status: MessageStatus.sent,
      );
    });

    // Add newer messages to the chat
    for (final message in newerMessages) {
      _chatController.insertMessage(message);
    }

    debugPrint('Loaded ${newerMessages.length} newer messages');
  }

  @override
  void initState() {
    super.initState();

    // Initialize composer and bottom bar animation controllers
    _composerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bottomBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Composer slides down when hiding (Offset(0, 1) means down by 100%)
    _composerSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(
      CurvedAnimation(
        parent: _composerAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Bottom bar slides up from bottom when showing (Offset(0, 1) means below screen)
    _bottomBarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _bottomBarAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Add all messages in chronological order
    final allMessages = <Message>[
      ..._sampleTextMessages,
      ..._sampleImageMessages,
      ..._sampleVideoMessages,
      ..._sampleTextMessagesAfter,
    ];

    // Sort messages by creation time to ensure proper order
    allMessages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    // Add messages to the chat controller
    for (final message in allMessages) {
      _chatController.insertMessage(message);
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
    _slideAnimations.clear();
    _sizeAnimations.clear();
    _composerAnimationController.dispose();
    _bottomBarAnimationController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          _isSelectMode
              ? 'Select Messages'
              : 'Pagination Test (onStartReached)',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        leading: _isSelectMode ? null : null,
        automaticallyImplyLeading: false,
        actions:
            _isSelectMode
                ? [
                  TextButton(
                    onPressed: _exitSelectMode,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                ]
                : null,
      ),
      body: Chat(
        theme: ChatTheme.light().copyWith(
          colors: ChatColors(
            primary: Color(0xFF545AFA),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1F1F1F),
            surfaceContainer: const Color(0xffF5F6FF),
            surfaceContainerLow: Color(0xFFFFF5CE).withValues(alpha: 1),
            surfaceContainerHigh: const Color(
              0xfff5f5f7,
            ).withValues(alpha: 0.95),
            surfaceContainerHighest: const Color(0xfff5f5f7),
          ),
        ),
        builders: Builders(
          chatAnimatedListBuilder: (p0, itemBuilder) {
            return ChatAnimatedList(
              itemBuilder: itemBuilder,
              physics: const BouncingScrollPhysics(),
              bottomPadding: _isSelectMode ? 8 : 20,
              handleSafeArea: !_isSelectMode,
              // Test onEndReached - loads older messages when scrolling to top
              onEndReached: _loadOlderMessages,
              paginationThreshold: 0.1,
              // Test onStartReached - loads newer messages when scrolling to bottom
              onStartReached: _loadNewerMessages,
              onStartReachedThreshold: 0.9,
            );
          },
          textMessageBuilder: (
            BuildContext context,
            TextMessage message,
            int index, {
            required bool isSentByMe,
            MessageGroupStatus? groupStatus,
          }) {
            return DefaultTextStyle(
              style: const TextStyle(fontSize: 14, color: Colors.black),
              child: FlyerChatTextMessage(
                message: message,
                index: index,
                textPadding: const EdgeInsets.only(left: 4, right: 6),
                containerPadding: EdgeInsets.fromLTRB(6, 6, 6, 10),
                topWidgets:
                    true
                        ? null
                        : [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.3,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              border: Border(
                                left: BorderSide(color: Colors.grey, width: 4),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text('Fake reply'),
                                Spacer(),
                                Icon(Icons.image),
                              ],
                            ),
                          ),
                        ],
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                receivedTextStyle: TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                sentTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(
                    isSentByMe
                        ? 12
                        : ((groupStatus?.isLast == true || groupStatus == null)
                            ? 0
                            : 12),
                  ),
                  bottomRight: Radius.circular(
                    isSentByMe
                        ? ((groupStatus?.isLast == true || groupStatus == null)
                            ? 0
                            : 12)
                        : 12,
                  ),
                ),
                timeAndStatusPosition:
                    message.text.length > 25
                        ? TimeAndStatusPosition.end
                        : TimeAndStatusPosition.end,
                reserveTimeAndStatusSpace:
                    message.text.length > 25 ? true : false,
              ),
            );
          },
          imageMessageBuilder: (
            BuildContext context,
            ImageMessage message,
            int index, {
            required bool isSentByMe,
            MessageGroupStatus? groupStatus,
          }) {
            return FlyerChatImageMessage(
              message: message,
              index: index,
              customImageProvider: NetworkImage(message.source),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(
                  isSentByMe
                      ? 12
                      : ((groupStatus?.isLast == true || groupStatus == null)
                          ? 0
                          : 12),
                ),
                bottomRight: Radius.circular(
                  isSentByMe
                      ? ((groupStatus?.isLast == true || groupStatus == null)
                          ? 0
                          : 12)
                      : 12,
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 250),
              containerPadding: const EdgeInsets.all(3),
              overlay: Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: isSentByMe ? 135 : 110,
                    maxWidth: isSentByMe ? 135 : 110,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomRight,
                      transform: const GradientRotation(20 * (-math.pi / 180)),
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.6),
                      ],
                      stops: const [0.0, 0.75, 0.90, 1.0],
                    ),
                  ),
                  child: Center(child: null),
                ),
              ),
              placeholderColor: Colors.grey[200],
              loadingOverlayColor: Colors.blue.withOpacity(0.3),
              loadingIndicatorColor: Colors.blue,
              uploadOverlayColor: Colors.green.withOpacity(0.3),
              uploadIndicatorColor: Colors.green,
              timeStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              timeBackground: Colors.black.withOpacity(0.7),
              showTime: true,
              showStatus: true,
              timeAndStatusPosition: TimeAndStatusPosition.end,
            );
          },
          videoMessageBuilder: (
            BuildContext context,
            VideoMessage message,
            int index, {
            required bool isSentByMe,
            MessageGroupStatus? groupStatus,
          }) {
            return FlyerChatVideoMessage(
              message: message,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(
                  isSentByMe
                      ? 12
                      : ((groupStatus?.isLast == true || groupStatus == null)
                          ? 0
                          : 12),
                ),
                bottomRight: Radius.circular(
                  isSentByMe
                      ? ((groupStatus?.isLast == true || groupStatus == null)
                          ? 0
                          : 12)
                      : 12,
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 250),
              containerPadding: const EdgeInsets.all(3),
              uploadOverlayColor: Colors.green.withOpacity(0.3),
              uploadIndicatorColor: Colors.green,
              timeStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              timeBackground: Colors.black.withOpacity(0.7),
              showTime: true,
              showStatus: true,
              openFullScreenPlayerOnTap: false,
              timeAndStatusPosition: TimeAndStatusPosition.end,
              playIconColor: Colors.white,
              playIconSize: 56,
              onThumbnailGenerated: (thumbnail) {
                // Save thumbnail to message metadata to avoid regenerating
                final updatedMessage = message.copyWith(
                  metadata: {...?message.metadata, 'thumbnail': thumbnail},
                );
                _chatController.updateMessage(message, updatedMessage);
              },
            );
          },
          composerBuilder: (p0) {
            return Composer(
              backgroundColor: Color.fromARGB(223, 247, 247, 247),
            );
            /* return SlideTransition(
              position: _composerSlideAnimation,
              child: Composer(
                backgroundColor: Color.fromARGB(223, 247, 247, 247),
              ),
            ); */
          },
          chatMessageBuilder: (
            p0,
            message,
            index,
            animation,
            child, {
            groupStatus,
            isRemoved,
            required isSentByMe,
          }) {
            final slideAnimation = _getOrCreateSlideAnimation(message.id);
            final sizeAnimation = _getOrCreateSizeAnimation(message.id);

            return ChatMessage(
              message: message,
              index: index,
              animation: animation,
              horizontalPadding: 0,
              sentMessageRowAlignment: CrossAxisAlignment.center,
              receivedMessageRowAlignment: CrossAxisAlignment.center,
              /* headerWidget: Center(
                child: Container(
                  margin: EdgeInsets.only(bottom: 8, top: 8),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'Monday, 24th April 2025',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      
               */
              rightPadding: isSentByMe ? 12 : null,
              leadingWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSentByMe || _isSelectMode) SizedBox(width: 12),
                  SizeTransition(
                    sizeFactor: sizeAnimation,
                    axis: Axis.horizontal,
                    axisAlignment: -1,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          _selectedMessageIds.contains(message.id)
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color:
                              _selectedMessageIds.contains(message.id)
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              isSelectMode: _isSelectMode,
              child: child,
            );
          },
        ),
        chatController: _chatController,
        currentUserId: _currentUserId,
        onMessageTap: (
          context,
          message, {
          int index = 0,
          TapUpDetails? details,
          required bool isSentByMe,
        }) {
          // Only handle taps in select mode
          if (!_isSelectMode) return;

          setState(() {
            if (_selectedMessageIds.contains(message.id)) {
              _selectedMessageIds.remove(message.id);
            } else {
              _selectedMessageIds.add(message.id);
            }
          });
        },
        onAttachmentTap: () {
          // Add a new random image when attachment button is tapped
          final newMessage = ImageMessage(
            id: 'img_${DateTime.now().millisecondsSinceEpoch}',
            authorId: _currentUserId,
            createdAt: DateTime.now(),
            source:
                'https://picsum.photos/${300 + (DateTime.now().millisecondsSinceEpoch % 200)}/${200 + (DateTime.now().millisecondsSinceEpoch % 300)}',
            width:
                300.0 +
                (DateTime.now().millisecondsSinceEpoch % 200).toDouble(),
            height:
                200.0 +
                (DateTime.now().millisecondsSinceEpoch % 300).toDouble(),
            //status: MessageStatus.sending,
          );
          _chatController.insertMessage(newMessage);

          // Simulate upload completion after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            _chatController.updateMessage(
              newMessage,
              newMessage.copyWith(status: MessageStatus.sent),
            );
          });
        },
        onMessageLongPress: (
          context,
          message, {
          required LongPressStartDetails details,
          required isSentByMe,
          int? index,
        }) {
          showReactionsDialog(
            context,
            message,
            details,
            isSentByMe: isSentByMe,
            horizontalMessagePadding: 12,
            onReactionTap: (_) {},
            onlyMenu: false,
            reactions: const ['👍', '❤️', '😂', '🐱', '😢', '🙏'],
            userReactions: ['🐱'],
            menuItems: [
              MenuItem(
                title: 'Select',
                icon: Icons.check_circle_outline,
                onTap: () {
                  _enterSelectMode();
                },
              ),
              MenuItem(title: 'Copy', icon: Icons.copy_outlined, onTap: () {}),
              MenuItem(
                title: 'Like',
                icon: Icons.favorite_outline,
                onTap: () {},
              ),
              MenuItem(
                title: 'Delete',
                icon: Icons.delete_outline,
                isDestructive: true,
                onTap: () {},
              ),
            ],
            menuItemDividerColor: Colors.grey.shade300,
            menuItemsWidthRatio: 0.6,
            menuItemPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          );
        },
        onMessageSend: (text) {
          // Handle text messages
          final textMessage = TextMessage(
            id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
            authorId: _currentUserId,
            createdAt: DateTime.now(),
            text: text,
            status: MessageStatus.sent,
          );
          _chatController.insertMessage(textMessage);
        },
        resolveUser: (UserID id) async {
          return User(
            id: id,
            name: id == 'user1' ? 'You' : 'John Doe',
            /* avatarUrl:
                id == 'user1'
                    ? 'https://api.dicebear.com/7.x/avataaars/png?seed=user1'
                    : 'https://api.dicebear.com/7.x/avataaars/png?seed=user2', */
          );
        },
      ),
      extendBody: _isSelectMode,
      bottomNavigationBar:
          _isSelectMode
              ? ClipRect(
                child: SlideTransition(
                  position: _bottomBarSlideAnimation,
                  child: Container(
                    color: Colors.grey.shade200,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${_selectedMessageIds.length} Selected'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  void _showImageVariations() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => MultiProvider(
            providers: [
              Provider<ChatController>.value(value: _chatController),
              Provider<UserID>.value(value: _currentUserId),
            ],
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Image Message Variations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: MultiProvider(
                      providers: [
                        Provider<ChatTheme>.value(value: ChatTheme.dark()),
                        Provider<DateFormat>.value(value: DateFormat.Hm()),
                      ],
                      child: ListView(
                        children: [
                          _buildVariationExample(
                            'Basic Image',
                            _createSampleMessage(),
                          ),
                          const SizedBox(height: 16),
                          _buildVariationExample(
                            'With BlurHash',
                            _createSampleMessage(withBlurHash: true),
                          ),
                          const SizedBox(height: 16),
                          _buildVariationExample(
                            'Square Image',
                            _createSampleMessage(isSquare: true),
                          ),
                          const SizedBox(height: 16),
                          _buildVariationExample(
                            'With Overlay',
                            _createSampleMessage(hasOverlay: true),
                          ),
                          const SizedBox(height: 16),
                          _buildVariationExample(
                            'WhatsApp Style Gradient',
                            _createSampleMessage(hasGradientOverlay: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildVariationExample(String title, ImageMessage message) {
    Widget? buildOverlay() {
      if (title == 'WhatsApp Style Gradient') {
        // Create WhatsApp-style bottom right gradient
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: const GradientRotation(-40 * (-math.pi / 180)),
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.7, 0.87, 1],
            ),
          ),
        );
      } else if (message.hasOverlay == true && title == 'With Overlay') {
        return Container(
          color: Colors.red.withOpacity(0.3),
          child: const Center(
            child: Text(
              'WAIT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: FlyerChatImageMessage(
            customImageProvider: NetworkImage(message.source),
            message: message,
            index: 0,
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(maxHeight: 150, maxWidth: 200),
            overlay: buildOverlay(),
          ),
        ),
      ],
    );
  }

  ImageMessage _createSampleMessage({
    bool withBlurHash = false,
    bool isSquare = false,
    bool hasOverlay = false,
    bool hasGradientOverlay = false,
  }) {
    final id = 'sample_${DateTime.now().millisecondsSinceEpoch}';
    final dimensions = isSquare ? (250, 250) : (300, 200);

    return ImageMessage(
      id: id,
      authorId: 'user2',
      createdAt: DateTime.now(),
      source:
          'https://picsum.photos/${dimensions.$1}/${dimensions.$2}?random=$id',
      width: dimensions.$1.toDouble(),
      height: dimensions.$2.toDouble(),
      blurhash: withBlurHash ? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4' : null,
      hasOverlay: true,
      status: MessageStatus.delivered,
    );
  }
}
