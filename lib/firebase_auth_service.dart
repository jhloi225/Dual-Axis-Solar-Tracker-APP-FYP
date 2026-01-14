import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

// --- Authentication and Database Service ---

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  // *** Updated: Added serverClientId from google-services.json for robust Google Sign-In ***
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '829107565046-8c5cs2anihrali59cjkbtle3an3rvttt.apps.googleusercontent.com',
  );

  final String _initialDeviceId = 'PROTOTYPE-1';

  Future<User?> registerAndRecordUser({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;

      if (user != null) {
        await user.sendEmailVerification();
        await _recordNewUserData(user.uid, email, user.displayName);
        await _updateDeviceOwner(user.uid);
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final snapshot = await _dbRef.child('users/${user.uid}').get();
        if (!snapshot.exists) {
          await _recordNewUserData(user.uid, user.email, user.displayName);
        }
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> _recordNewUserData(String uid, String? email, String? displayName) async {
    final userRef = _dbRef.child('users/$uid');
    final userData = {
      'email': email,
      'displayName': displayName ?? email?.split('@')[0] ?? 'User',
      'created_at': ServerValue.timestamp,
    };
    await userRef.set(userData);
  }

  Future<void> _updateDeviceOwner(String uid) async {
    final deviceRef = _dbRef.child('devices/$_initialDeviceId');
    await deviceRef.update({
      'owner_uid': uid,
    });
    await _dbRef.child('users/$uid/owned_devices/$_initialDeviceId').set(true);
  }

  Future<bool> pairDevice({required String deviceId, required String pin}) async {
    try {
      final pinSnapshot = await _dbRef.child('devices/$deviceId/pin').get();

      if (pinSnapshot.exists && pinSnapshot.value == pin) {
        final user = _auth.currentUser;
        if (user != null) {
          await _dbRef.child('devices/$deviceId').update({'owner_uid': user.uid});
          await _dbRef.child('users/${user.uid}/owned_devices/$deviceId').set(true);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error pairing device: $e');
      return false;
    }
  }

  Future<bool> disconnectDevice(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _dbRef.child('devices/$deviceId/owner_uid').remove();
        await _dbRef.child('users/${user.uid}/owned_devices/$deviceId').remove();
        return true;
      }
      return false;
    } catch (e) {
      print('Error disconnecting device: $e');
      return false;
    }
  }

  Future<User?> signIn({required String email, required String password}) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<bool> hasPairedDevice() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final snapshot = await _dbRef.child('users/${user.uid}/owned_devices').get();
    return snapshot.exists;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    var acs = ActionCodeSettings(url: 'https://solartrackpro-594b9.firebaseapp.com/__/auth/action');
    await _auth.sendPasswordResetEmail(email: email, actionCodeSettings: acs);
  }

  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
