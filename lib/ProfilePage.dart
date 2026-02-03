import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class MoodStatus {
  final String emoji;
  final String text;

  MoodStatus({required this.emoji, required this.text});

  @override
  String toString() => '$emoji $text';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MoodStatus &&
              runtimeType == other.runtimeType &&
              emoji == other.emoji &&
              text == other.text;

  @override
  int get hashCode => emoji.hashCode ^ text.hashCode;
}

class ProfilePage extends StatefulWidget {
  final bool isDarkTheme;
  const ProfilePage({super.key, required this.isDarkTheme});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String name = '', phone = '', address = '', bio = '', photoUrl = '';
  bool _isLoading = true;
  File? _imageFile;

  MoodStatus? selectedStatus;

  final List<MoodStatus> moodOptions = [
    MoodStatus(emoji: '😄', text: 'Happy'),
    MoodStatus(emoji: '😢', text: 'Sad'),
    MoodStatus(emoji: '😡', text: 'Angry'),
    MoodStatus(emoji: '🤫', text: 'Silent'),
    MoodStatus(emoji: '😴', text: 'Sleepy'),
  ];

  void _showMoodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: widget.isDarkTheme ? Colors.grey[900] : Colors.white,
          title: Text(
            "Select Mood",
            style: TextStyle(
              fontFamily: 'Poppins',
              color: widget.isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: moodOptions.map((mood) {
                return ListTile(
                  title: Text(
                    '${mood.emoji} ${mood.text}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: widget.isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    setState(() => selectedStatus = mood);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Color get _textColor => widget.isDarkTheme ? Colors.white : Colors.black;

  ThemeData get _themeData => ThemeData(
    brightness: widget.isDarkTheme ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: widget.isDarkTheme ? Colors.black : Colors.white,
    primaryColor: Colors.blueAccent,
    fontFamily: 'Poppins', // ✅ Applies globally
    appBarTheme: AppBarTheme(
      backgroundColor: widget.isDarkTheme ? Colors.black : Colors.blueAccent,
      titleTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(
        color: widget.isDarkTheme ? Colors.white : Colors.white,
      ),
    ),
  );


  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      final emoji = data['statusEmoji'] ?? '';
      final text = data['statusText'] ?? '';
      setState(() {
        name = data['name'] ?? '';
        phone = data['phone'] ?? '';
        address = data['address'] ?? '';
        bio = data['bio'] ?? '';
        photoUrl = data['photoUrl'] ?? '';
        selectedStatus = moodOptions.firstWhere(
              (m) => m.emoji == emoji && m.text == text,
          orElse: () => MoodStatus(emoji: '', text: ''),
        );
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'name': name,
      'phone': phone,
      'address': address,
      'bio': bio,
      'photoUrl': photoUrl,
      'statusEmoji': selectedStatus?.emoji ?? '',
      'statusText': selectedStatus?.text ?? '',
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        photoUrl = picked.path; // for local display only
      });
    }
  }

  Future<void> _removeImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _imageFile = null;
      photoUrl = '';
    });

    await _firestore.collection('users').doc(user.uid).update({
      'photoUrl': FieldValue.delete(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Theme(
      data: _themeData,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _saveProfile();
                }
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (photoUrl.isNotEmpty
                          ? FileImage(File(photoUrl))
                          : const AssetImage('assets/images/profile_avatar.png')
                      as ImageProvider),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 10,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.blue, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.delete, color: Colors.red, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () => _showMoodDialog(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: selectedStatus != null ? '${selectedStatus!.emoji} ${selectedStatus!.text}' : '',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mood Status',
                        prefixIcon: const Icon(Icons.emoji_emotions_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down), // dropdown icon
                        filled: true,
                        fillColor: widget.isDarkTheme ? Colors.grey[850] : Colors.grey[200], // background by theme
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), // Rounded corners
                        ),
                      ),
                      style: TextStyle(
                        color: widget.isDarkTheme ? Colors.white : Colors.black,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  onChanged: (val) => name = val,
                  validator: (val) => val!.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  initialValue: phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (val) => phone = val,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  initialValue: address,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  onChanged: (val) => address = val,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  initialValue: bio,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  onChanged: (val) => bio = val,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _saveProfile();
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Save Profile"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
