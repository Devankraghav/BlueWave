// AuthPage.dart

import 'package:blue_wave/HomePage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'ForgetPasswordPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';


class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  final TextEditingController signupNameController = TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController signupPasswordController = TextEditingController();
  final TextEditingController signupConfirmPasswordController = TextEditingController();

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    loginEmailController.dispose();
    loginPasswordController.dispose();
    signupNameController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    signupConfirmPasswordController.dispose();
    super.dispose();
  }

 /* Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Save user to Firestore (if not already saved)
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    }
  }
*/
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
        clientId: '36931071790-99dt0kn81nkj4a27l0sq1c1kd959uqd8.apps.googleusercontent.com',
      )
          : GoogleSignIn(); // For Android/iOS

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Save user to Firestore (if not already saved)
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    }
  }

  Widget _buildLoginTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text("Your Email", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(
              controller: loginEmailController,
              decoration: InputDecoration(
                hintText: "Enter your email",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            const Text("Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(
              controller: loginPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Enter your password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ForgetPasswordPage()),
                ),
                child: const Text("Forget password?", style: TextStyle(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                  onPressed: () async {
                    final email = loginEmailController.text.trim();
                    final password = loginPasswordController.text.trim();

                    // Empty field check
                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please enter both email and password."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Email format validation
                    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
                    if (!emailRegex.hasMatch(email)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please enter a valid email address."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    // Password length validation
                    if (password.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Password must be at least 6 characters."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    // Firebase login attempt
                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      final credential = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(email: email, password: password);

                      Navigator.of(context).pop(); // Close loading

                      if (credential.user != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      Navigator.of(context).pop(); // Close loading
                      String errorMessage = "Login failed. Please try again.";

                      switch (e.code) {
                        case 'user-not-found':
                          errorMessage = "No user found with this email.";
                          break;
                        case 'wrong-password':
                          errorMessage = "Incorrect password.";
                          break;
                        case 'invalid-email':
                          errorMessage = "This email is invalid.";
                          break;
                        case 'too-many-requests':
                          errorMessage = "Too many attempts. Try again later.";
                          break;
                        case 'network-request-failed':
                          errorMessage = "Network error. Please check your connection.";
                          break;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      Navigator.of(context).pop(); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Unexpected error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Continue", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Expanded(child: Divider(indent: 50, endIndent: 10)),
                Text("or"),
                Expanded(child: Divider(indent: 10, endIndent: 50)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child:OutlinedButton.icon(
                onPressed: signInWithGoogle, // 🔗 connect to method
                icon: Image.asset("assets/images/google_icon.png", height: 24),
                label: const Text("Login with Google"),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: RichText(
                text: TextSpan(
                  text: "Don't have an account? ",
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    TextSpan(
                      text: "Sign Up",
                      style: const TextStyle(color: Colors.blue),
                      recognizer: TapGestureRecognizer()..onTap = () {
                        _tabController.animateTo(1);
                      },
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpTab() {
    bool isValidEmail(String email) {
      final emailRegex = RegExp(r"^[^@]+@[^@]+\.[^@]+");
      return emailRegex.hasMatch(email);
    }

    void showSnack(String message, {bool isError = false}) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }

    void signupUser() async {
      final name = signupNameController.text.trim();
      final email = signupEmailController.text.trim();
      final password = signupPasswordController.text;
      final confirmPassword = signupConfirmPasswordController.text;

      if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
        showSnack("All fields are required", isError: true);
        return;
      }
      if (!isValidEmail(email)) {
        showSnack("Enter a valid email address", isError: true);
        return;
      }
      if (password.length < 6) {
        showSnack("Password must be at least 6 characters", isError: true);
        return;
      }
      if (password != confirmPassword) {
        showSnack("Passwords do not match", isError: true);
        return;
      }

      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        final _auth = FirebaseAuth.instance;
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'name': name,
            'email': email,
          });

          Navigator.of(context).pop(); // remove loading
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        Navigator.of(context).pop();
        showSnack("Firebase error: ${e.message}", isError: true);
      } catch (e) {
        Navigator.of(context).pop();
        showSnack("Unexpected error: $e", isError: true);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text("Create a new account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(
              controller: signupNameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: signupEmailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: signupPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: signupConfirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: signupUser,
                icon: const Icon(Icons.person_add),
                label: const Text("Sign Up", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "Log In"),
                Tab(text: "Sign Up"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildSignUpTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
