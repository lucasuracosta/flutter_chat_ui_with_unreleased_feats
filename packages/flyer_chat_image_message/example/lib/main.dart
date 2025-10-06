import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_reactions/flyer_chat_reactions.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flyer Chat Image Message Example',
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

class _ImageMessageExampleState extends State<ImageMessageExample> {
  final _chatController = InMemoryChatController();
  final String _currentUserId = 'user1';

  // Sample hardcoded text messages
  final List<TextMessage> _sampleTextMessages = [
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
      text: 'I\'m doing great! Thanks for asking 😊',
      status: MessageStatus.seen,
    ),
    TextMessage(
      id: 'txt3',
      authorId: 'user2',
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      text: 'That\'s awesome! I wanted to share some cool images with you.',
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
      text: 'Here they are! Let me know what you think:',
    ),
  ];

  // Sample hardcoded image messages
  final List<ImageMessage> _sampleMessages = [
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

  // Additional text messages after images
  final List<TextMessage> _sampleTextMessagesAfter = [
    TextMessage(
      id: 'txt6',
      authorId: 'user1',
      createdAt: DateTime.now().add(const Duration(minutes: 1)),
      text: 'Wow! These are absolutely beautiful! 📸',
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
      text: 'Where did you go? The scenery looks amazing! 🌄',
    ),
    TextMessage(
      id: 'txt9',
      authorId: 'user2',
      createdAt: DateTime.now().add(const Duration(minutes: 4)),
      text: 'It was up in the mountains. Perfect weather for photography!',
      status: MessageStatus.delivered,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Add all messages in chronological order
    final allMessages = <Message>[
      ..._sampleTextMessages,
      ..._sampleMessages,
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
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Image Message Examples'),
        centerTitle: true,
      ),
      body: MultiProvider(
        providers: [
          Provider<ChatController>.value(value: _chatController),
          Provider<UserID>.value(value: _currentUserId),
        ],
        child: Chat(
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
            textMessageBuilder: (
              BuildContext context,
              TextMessage message,
              int index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
              bool? isInsideMenu,
            }) {
              final messageWidget = MultiProvider(
                providers: [
                  Provider.value(value: _currentUserId),
                  Provider.value(value: () {}),
                  Provider.value(value: _chatController),
                  Provider.value(
                    value: ChatTheme.light().copyWith(
                      colors: ChatColors(
                        primary: Color(0xFF545AFA),
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Color(0xFF1F1F1F),
                        surfaceContainer: const Color(0xffF5F6FF),
                        surfaceContainerLow: Color(
                          0xFFFFF5CE,
                        ).withValues(alpha: 1),
                        surfaceContainerHigh: const Color(
                          0xfff5f5f7,
                        ).withValues(alpha: 0.95),
                        surfaceContainerHighest: const Color(0xfff5f5f7),
                      ),
                    ),
                  ),
                  Provider.value(value: Builders()),
                  //Provider.value(value: _crossCache),
                  /* if (widget.userCache != null)
                          ChangeNotifierProvider.value(value: _userCache)
                        else
                          ChangeNotifierProvider(create: (_) => _userCache), */
                  Provider.value(value: DateFormat.Hm()),
                  /* Provider.value(value: widget.onMessageSend),
                        Provider.value(value: widget.onMessageTap),
                        Provider.value(value: widget.onMessageLongPress),
                        Provider.value(value: widget.onAttachmentTap), */
                  ChangeNotifierProvider(
                    create: (_) => ComposerHeightNotifier(),
                  ),
                  ChangeNotifierProvider(create: (_) => LoadMoreNotifier()),
                ],

                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  child: FlyerChatTextMessage(
                    message: message,
                    index: index,
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
                            : ((groupStatus?.isLast == true ||
                                    groupStatus == null)
                                ? 0
                                : 12),
                      ),
                      bottomRight: Radius.circular(
                        isSentByMe
                            ? ((groupStatus?.isLast == true ||
                                    groupStatus == null)
                                ? 0
                                : 12)
                            : 12,
                      ),
                    ),
                    /* isSentByMe: isSentByMe,
                      groupStatus: groupStatus, */
                  ),
                ),
              );
              return isInsideMenu != true
                  ? Hero(tag: message.id, child: messageWidget)
                  : messageWidget;
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
                constraints: const BoxConstraints(
                  maxHeight: 300,
                  maxWidth: 250,
                ),
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
                        transform: const GradientRotation(
                          20 * (-math.pi / 180),
                        ),
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
            composerBuilder: (p0) {
              return Composer(
                backgroundColor: Color.fromARGB(223, 247, 247, 247),
              );
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
              return ChatMessage(
                message: message,
                index: index,
                animation: animation,
                headerWidget: Center(
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
                child: child,
              );
            },
          ),
          chatController: _chatController,
          currentUserId: _currentUserId,
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
            LongPressStartDetails? details,
            int? index,
            required isSentByMe,
          }) {
            showReactionsDialog(
              context,
              message,
              isSentByMe: isSentByMe,
              onReactionTap: (_) {},
              menuItems: [
                MenuItem(title: 'Like', icon: Icons.thumb_up),
                MenuItem(title: 'Love', icon: Icons.favorite),
                MenuItem(title: 'Laugh', icon: Icons.emoji_emotions),
              ],
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
      ),
      /* floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showImageVariations();
        },
        label: const Text('Show Variations'),
        icon: const Icon(Icons.image),
      ), */
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
