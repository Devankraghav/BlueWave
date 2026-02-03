// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:blue_wave/ChatPage.dart';
import 'AuthPage.dart';
import 'ProfilePage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool isDarkTheme;
  String searchQuery = "";

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text("Light Theme"),
              onTap: () {
                setState(() => isDarkTheme = false);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text("Dark Theme"),
              onTap: () {
                setState(() => isDarkTheme = true);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    isDarkTheme = false;

    patchMissingTimestampsInChats();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void patchMissingTimestampsInChats() async {
    final snapshot = await FirebaseFirestore.instance.collection('chats').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // ✅ Fix chat timestamp
      if (!data.containsKey('timestamp') || data['timestamp'] == null) {
        await doc.reference.update({
          'timestamp': Timestamp.now(), // <-- This is the key fix
        });
        print("✅ Patched chat timestamp: ${doc.id}");
      }

      // ✅ Fix messages inside each chat
      final messagesRef = doc.reference.collection('messages');
      final messagesSnapshot = await messagesRef.get();

      for (var messageDoc in messagesSnapshot.docs) {
        final messageData = messageDoc.data();
        if (!messageData.containsKey('timestamp') || messageData['timestamp'] == null) {
          await messageDoc.reference.update({
            'timestamp': Timestamp.now(), // <-- Also use this here
          });
          print("🧩 Patched message timestamp in chat ${doc.id}, message ${messageDoc.id}");
        }
      }
    }
  }
  void _showAddContactDialog() {
    String email = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Contact by Email"),
          content: Form(
            key: formKey,
            child: TextFormField(
              decoration: const InputDecoration(hintText: "Enter friend's email"),
              validator: (value) => value == null || value.isEmpty ? 'Email required' : null,
              onChanged: (value) => email = value.trim(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Add"),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _startChatWithEmail(email);
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return "";

    final dateTime = timestamp.toDate();
    final now = DateTime.now();

    final isToday = dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year;

    return isToday
        ? "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}"
        : "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }


  Future<void> _startChatWithEmail(String email) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No user found with this email."),
        ));
        return;
      }

      final otherUser = query.docs.first;
      final otherUserId = otherUser.id;
      final myUid = FirebaseAuth.instance.currentUser!.uid;

      if (myUid == otherUserId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("You can't add yourself."),
        ));
        return;
      }

      final chatId = myUid.compareTo(otherUserId) < 0
          ? '$myUid\_$otherUserId'
          : '$otherUserId\_$myUid';

      final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final chatSnapshot = await chatDoc.get();

      if (!chatSnapshot.exists) {
        final timestamp = FieldValue.serverTimestamp();

        await chatDoc.set({
          'users': [myUid, otherUserId],
          'lastMessage': "Chat started",
          'lastMessageSenderId': myUid,
          'timestamp': timestamp,
        });

        await chatDoc.collection('messages').add({
          'senderId': myUid,
          'receiverId': otherUserId,
          'text': "Chat started",
          'timestamp': timestamp,
        });
      } else {
        await chatDoc.update({
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // ✅ Navigate to ChatPage immediately
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            receiverEmail: otherUser['email'],
            receiverName: otherUser['name'],
            receiverUid: otherUserId,
            isDarkTheme: isDarkTheme,
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }
  void _onMenuSelected(String value) {
    if (value == 'theme') {
      _showThemeSelector();
    } else if (value == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(isDarkTheme: isDarkTheme)),
      );
    } else if (value == 'addContact') {
      _showAddContactDialog();
    } else if (value == 'logout') {
      FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
            (route) => false,
      );
    }
  }

  ThemeData get _themeData => isDarkTheme
      ? ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Colors.black,
    primaryColor: Colors.grey[900],
    appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
  )
      : ThemeData.light().copyWith(
    scaffoldBackgroundColor: Colors.white,
    primaryColor: Colors.blue,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
  );

  Color get _textColor => isDarkTheme ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _themeData,
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 1,
            title: Row(
              children: [
                Icon(Icons.chat_bubble, color: _textColor),
                const SizedBox(width: 8),
                Text(
                  "BlueWave",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: _textColor),
                tooltip: "Refresh",
                onPressed: () {

                  setState(() {});
                },
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  popupMenuTheme: PopupMenuThemeData(
                    color: isDarkTheme ? Colors.grey[900] : Colors.white, // Background color
                    textStyle: TextStyle(
                      color: isDarkTheme ? Colors.white : Colors.black, // Text color
                    ),
                  ),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: _textColor),
                  onSelected: _onMenuSelected,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "theme",
                      child: Text("Change Theme", style: TextStyle(color: _textColor)),
                    ),
                    PopupMenuItem(
                      value: "profile",
                      child: Text("View Profile", style: TextStyle(color: _textColor)),
                    ),
                    PopupMenuItem(
                      value: "logout",
                      child: Text("Logout", style: TextStyle(color: _textColor)),
                    ),
                  ],
                )
              )
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: _textColor,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(
                  child: Text(
                    "Chats",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold, // optional
                    ),
                  ),
                ),

                // Tab(text: "Calls"),
              ],
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() => searchQuery = value);
                  },
                  style: TextStyle(color: _textColor,
                  fontFamily: 'Poppins',
                  ),
                  decoration: InputDecoration(
                    hintText: "Search user...",
                    hintStyle: TextStyle(color: _textColor),
                    filled: true,
                    fillColor: isDarkTheme ? Colors.grey[850] : Colors.grey[200],
                    prefixIcon: Icon(Icons.search, color: _textColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ✅ Fixed Chats Tab with FutureBuilder + StreamBuilder
                    // 🔄 CHATS TAB — shows only current user's chats sorted by latest message
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .where('users', arrayContains: FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox();
                        }

                        final chats = snapshot.data!.docs;

                        chats.sort((a, b) {
                          final tA = a['timestamp'] as Timestamp?;
                          final tB = b['timestamp'] as Timestamp?;
                          if (tA == null && tB == null) return 0;
                          if (tA == null) return 1;
                          if (tB == null) return -1;
                          return tB.compareTo(tA);
                        });

                        // Pre-fetch all user IDs
                        final myUid = FirebaseAuth.instance.currentUser!.uid;
                        final userIds = chats.map((chat) {
                          final users = List<String>.from(chat['users']);
                          return users.firstWhere((uid) => uid != myUid, orElse: () => '');
                        }).toSet();

                        return FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .where(FieldPath.documentId, whereIn: userIds.toList())
                              .get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                            final userMap = {
                              for (var doc in userSnapshot.data!.docs) doc.id: doc.data() as Map<String, dynamic>
                            };

                            return ListView.builder(
                              itemCount: chats.length,
                              itemBuilder: (context, index) {
                                final chat = chats[index];
                                final users = List<String>.from(chat['users']);
                                final otherUserId = users.firstWhere((uid) => uid != myUid, orElse: () => '');
                                final userData = userMap[otherUserId];

                                if (otherUserId.isEmpty || userData == null) return const SizedBox();

                                final name = (userData['name'] ?? '').toLowerCase();
                                final email = (userData['email'] ?? '').toLowerCase();
                                if (!name.contains(searchQuery.toLowerCase()) &&
                                    !email.contains(searchQuery.toLowerCase())) {
                                  return const SizedBox();
                                }

                                return ListTile(
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userData['name'] ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.bold,
                                          fontFamily: 'poppins'),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (chat['timestamp'] != null)
                                        Text(
                                          _formatTimestamp(chat['timestamp']),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chat['lastMessage'] ?? "(No message)",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          receiverEmail: userData['email'],
                                          receiverName: userData['name'],
                                          receiverUid: otherUserId,
                                          isDarkTheme: isDarkTheme,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),


                    // 📞 CALLS TAB
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            onPressed: _showAddContactDialog,
            child: const Icon(Icons.person_add),
          ),
        ),
      ),
    );
  }
}
