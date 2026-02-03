import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverName;
  final String receiverUid;
  final bool isDarkTheme;

  const ChatPage({
    Key? key,
    required this.receiverEmail,
    required this.receiverName,
    required this.receiverUid,
    required this.isDarkTheme,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;
  late String chatId;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String _lastMessageId = "";
  bool _initialLoadHandled = false;

  Color get backgroundColor => widget.isDarkTheme ? Colors.black : Colors.white;
  Color get messageBarColor => widget.isDarkTheme ? Colors.grey[850]! : Colors.grey[200]!;
  Color get inputTextColor => widget.isDarkTheme ? Colors.white : Colors.black87;
  Color get sentMessageColor => widget.isDarkTheme ? Colors.blue[700]! : Colors.blue;

  List<String> reactions = ['😄', '❤️', '😮', '😢', '🙏', '👍', '👎', '😂', '😒', '🔥'];

  final FocusNode _focusNode = FocusNode();
  Timestamp? _lastSeenTimestamp;

  final ScrollController _scrollController = ScrollController();
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _updateTypingStatus(bool isTyping) {
    FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'typingStatus': {currentUser.uid: isTyping}
    }, SetOptions(merge: true));
  }

  @override
  void initState() {
    super.initState();
    chatId = _generateChatId(currentUser.uid, widget.receiverUid);

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _updateTypingStatus(false);
      }
    });
  }
  @override
  void dispose() {
    _updateTypingStatus(false);
    _focusNode.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }


  String _generateChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1\_$uid2' : '$uid2\_$uid1';
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;// hide keyboard

    final currentUserId = currentUser.uid;
    final receiverId = widget.receiverUid;

    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    await messageRef.add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'reaction': "",
    });

    await chatDocRef.set({
      'users': [currentUserId, receiverId],
      'lastMessage': messageText,
      'lastMessageSenderId': currentUserId,
      'timestamp': Timestamp.now(),
    }, SetOptions(merge: true));

    _messageController.clear();
    setState(() {});
    _audioPlayer.play(AssetSource('sounds/send.mp3'));
    _scrollToBottom();

  }


  @override
  Widget build(BuildContext context) {return GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child:  Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: inputTextColor),
        // Inside the AppBar's title section
        title: StreamBuilder<DocumentSnapshot>(

          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text("Loading...", style: TextStyle(color: inputTextColor));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final bio = data['bio'] ?? "Hey there! I'm using BlueWave.";
            final statusEmoji = data['statusEmoji'] ?? "🙂";

            final typingStatus = data['typingStatus'] as Map<String, dynamic>?;

            final isTyping = typingStatus != null &&
                typingStatus[widget.receiverUid] == true;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: inputTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      statusEmoji,
                      style: TextStyle(
                        fontSize: 14,
                        color: inputTextColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isTyping ? "Typing..." : bio,
                      style: TextStyle(
                        fontSize: 12,
                        color: inputTextColor.withOpacity(0.7),
                        fontFamily: 'Poppins',
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  ],
                ),
              ],
            );
          },
        ),

      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (messages.isNotEmpty) {
                  final lastDoc = messages.last;
                  final lastData = lastDoc.data() as Map<String, dynamic>;
                  final newMessageId = lastDoc.id;
                  final newTimestamp = lastData['timestamp'] as Timestamp?;
                  final senderId = lastData['senderId'];

                  if (!_initialLoadHandled) {
                    _lastMessageId = newMessageId;
                    _lastSeenTimestamp = newTimestamp;
                    _initialLoadHandled = true;
                  } else if (
                  newMessageId != _lastMessageId &&
                      newTimestamp != null &&
                      (_lastSeenTimestamp == null || newTimestamp.seconds > _lastSeenTimestamp!.seconds)
                  ) {
                    _lastMessageId = newMessageId;
                    _lastSeenTimestamp = newTimestamp;

                    if (senderId != currentUser.uid) {
                      _audioPlayer.play(AssetSource('sounds/receive.mp3'));
                    }
                  }
                }

                if (messages.isEmpty) {
                  return const Center(child: Text("Say Hi 👋"));
                }

                return ListView.builder(
                  controller: _scrollController, // ✅ Attach controller here
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final messageText = data['text'];
                    final isMe = data['senderId'] == currentUser.uid;
                    final isImage = messageText.startsWith('http') &&
                        (messageText.contains('.png') ||
                            messageText.contains('.jpg') ||
                            messageText.contains('.jpeg'));

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: messageBarColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    children: reactions.map((emoji) {
                                      return IconButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await doc.reference.update({'reaction': emoji});
                                        },
                                        icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                                      );
                                    }).toList(),
                                  ),
                                  const Divider(),
                                  TextButton.icon(
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: widget.isDarkTheme ? Colors.grey[900] : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Text(
                                            "Delete Message?",
                                            style: TextStyle(
                                              color: widget.isDarkTheme ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            "Are you sure you want to delete this message?",
                                            style: TextStyle(
                                              color: widget.isDarkTheme ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                          actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          actions: [
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor: widget.isDarkTheme ? Colors.blue[200] : Colors.blue,
                                              ),
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                              ),
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        final messagesRef = FirebaseFirestore.instance
                                            .collection('chats')
                                            .doc(chatId)
                                            .collection('messages');

                                        await doc.reference.delete();

                                        // After deletion, fetch latest message to update chat preview
                                        final latestSnapshot = await messagesRef
                                            .orderBy('timestamp', descending: true)
                                            .limit(1)
                                            .get();

                                        String? newLastMessage;
                                        String? newLastMessageSenderId;
                                        Timestamp? newTimestamp;

                                        if (latestSnapshot.docs.isNotEmpty) {
                                          final lastData = latestSnapshot.docs.first.data() as Map<String, dynamic>;
                                          newLastMessage = lastData['text'];
                                          newLastMessageSenderId = lastData['senderId'];
                                          newTimestamp = lastData['timestamp'];
                                        }

                                        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
                                          'lastMessage': newLastMessage ?? '',
                                          'lastMessageSenderId': newLastMessageSenderId ?? '',
                                          'timestamp': newTimestamp ?? FieldValue.serverTimestamp(),
                                        });
                                      }

                                    },
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text("Delete Message", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: isImage
                                  ? const EdgeInsets.all(6)
                                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? sentMessageColor
                                    : widget.isDarkTheme
                                    ? Colors.grey[800]
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                ),
                                border: isMe ? null : Border.all(color: Colors.grey.shade300),
                              ),
                              child: isImage
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  messageText,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : Text(
                                messageText,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : widget.isDarkTheme
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if ((data['reaction'] ?? "").isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
                                child: Text(
                                  data['reaction'],
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                          ],
                        ),
                      ),

                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: messageBarColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  if (_messageController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, color: inputTextColor.withOpacity(0.7)),
                      tooltip: "Clear Message",
                      onPressed: () {
                        _messageController.clear();
                        setState(() {}); // To update the icon visibility
                      },
                    )
                  else
                    SizedBox(width: 0),

                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _messageController,
                      onChanged: (text) => setState(() {
                        setState(() {});
                        _updateTypingStatus(text.isNotEmpty);
                      }), // 🔥 This line makes the clear icon appear as you type
                      style: TextStyle(color: inputTextColor),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: inputTextColor.withOpacity(0.6)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: inputTextColor),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(child: SizedBox(height: 3)),
        ],
      ),
    ),
  );
  }
}