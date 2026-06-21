import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/supabase_config.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static bool get _isInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Authentication Operations ---

  /// Sign up a new user with email and password
  static Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in an existing user with email and password
  static Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Google (Native flow on Android/iOS, OAuth redirect on web/other platforms)
  static Future<void> signInWithGoogle({bool isSignUp = false}) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final googleSignIn = GoogleSignIn(
          clientId: SupabaseConfig.googleWebClientId,
          serverClientId: SupabaseConfig.googleWebClientId,
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In was cancelled by the user.');
        }

        if (!isSignUp) {
          final isDeleted = await isAccountDeleted(googleUser.email);
          if (isDeleted) {
            await googleSignIn.signOut();
            throw Exception('This account has been deleted. Please sign up to create a new account.');
          }
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception('Google Sign-In failed: No ID Token found.');
        }

        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      } else {
        // Fallback to standard web-redirect OAuth flow
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? Uri.base.origin : 'io.supabase.meditrack://login-callback',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Completely delete the current user's account and data
  static Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _client.rpc('delete_user_account');
      await signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if an email is marked as deleted in the database
  static Future<bool> isAccountDeleted(String email) async {
    try {
      final response = await _client
          .from('deleted_accounts')
          .select()
          .eq('email', email)
          .maybeSingle();
      return response != null;
    } catch (e) {
      // If the table doesn't exist yet, we treat it as not deleted
      return false;
    }
  }

  /// Remove an email from the deleted accounts tracking list
  static Future<void> removeDeletedAccount(String email) async {
    try {
      await _client
          .from('deleted_accounts')
          .delete()
          .eq('email', email);
    } catch (e) {
      // Ignore errors if the table doesn't exist yet
    }
  }

  // --- Emergency Contact Operations ---

  /// Fetch all emergency contacts for the current user
  static Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    if (!_isInitialized) {
      return [];
    }
    final user = currentUser;
    if (user == null) return [];

    try {
      final List<dynamic> data = await _client
          .from('emergency_contacts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Fallback: If table doesn't exist yet, return empty list
      return [];
    }
  }

  /// Add a new emergency contact
  static Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String relation,
    required String phone,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final data = await _client.from('emergency_contacts').insert({
        'user_id': user.id,
        'name': name,
        'relation': relation,
        'phone': phone,
      }).select().single();
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an emergency contact
  static Future<void> deleteEmergencyContact(String contactId) async {
    try {
      await _client.from('emergency_contacts').delete().eq('id', contactId);
    } catch (e) {
      rethrow;
    }
  }


  /// Check if a user is currently logged in
  static User? get currentUser {
    if (!_isInitialized) {
      return User(
        id: 'mock-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: '',
        createdAt: '',
        email: 'jane.doe@email.com',
      );
    }
    return _client.auth.currentUser;
  }

  /// Check if active session exists
  static Session? get currentSession {
    if (!_isInitialized) {
      return Session(
        accessToken: 'mock-access-token',
        tokenType: 'bearer',
        user: currentUser!,
      );
    }
    return _client.auth.currentSession;
  }

  /// Send a password reset OTP/email
  static Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Verify the OTP code sent for password reset
  static Future<AuthResponse> verifyPasswordResetOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Update the user's password
  static Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // --- Profile Operations ---

  /// Get the current user's profile details
  static Future<Map<String, dynamic>?> getProfile() async {
    if (!_isInitialized) {
      return {
        'id': 'mock-user-id',
        'full_name': 'Jane Doe',
        'age': 68,
        'blood_type': 'O-',
        'weight': 64.0,
        'height': 162.0,
        'avatar_url': null,
      };
    }
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Update the current user's profile details
  static Future<void> updateProfile({
    required String fullName,
    required int age,
    required String bloodType,
    required double weight,
    required double height,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': fullName,
        'age': age,
        'blood_type': bloodType,
        'weight': weight,
        'height': height,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // --- Medication Operations ---

  /// Fetch all medications for the current user
  static Future<List<Map<String, dynamic>>> getMedications() async {
    if (!_isInitialized) {
      return [
        {
          'id': '1',
          'user_id': 'mock-user-id',
          'name': 'Metformin 500mg',
          'type': 'Tablet',
          'dosage': 500.0,
          'unit': 'mg',
          'reminder_time': '8:00 AM',
          'stock_count': 5,
          'refill_alert': 10,
          'meal_instruction': 'After Breakfast',
        },
        {
          'id': '2',
          'user_id': 'mock-user-id',
          'name': 'Lisinopril 10mg',
          'type': 'Capsule',
          'dosage': 10.0,
          'unit': 'mg',
          'reminder_time': '12:00 PM',
          'stock_count': 20,
          'refill_alert': 5,
          'meal_instruction': 'Before Lunch',
        },
        {
          'id': '3',
          'user_id': 'mock-user-id',
          'name': 'Atorvastatin 20mg',
          'type': 'Tablet',
          'dosage': 20.0,
          'unit': 'mg',
          'reminder_time': '8:00 PM',
          'stock_count': 25,
          'refill_alert': 5,
          'meal_instruction': 'After Dinner',
        },
      ];
    }
    final user = currentUser;
    if (user == null) return [];

    try {
      final List<dynamic> data = await _client
          .from('medications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Add a new medication
  static Future<Map<String, dynamic>> addMedication({
    required String name,
    required String type,
    required double dosage,
    required String unit,
    required String reminderTime,
    required int stockCount,
    required int refillAlert,
    required String mealInstruction,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final data = await _client.from('medications').insert({
        'user_id': user.id,
        'name': name,
        'type': type,
        'dosage': dosage,
        'unit': unit,
        'reminder_time': reminderTime,
        'stock_count': stockCount,
        'refill_alert': refillAlert,
        'meal_instruction': mealInstruction,
      }).select().single();
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a medication
  static Future<void> deleteMedication(String medicationId) async {
    try {
      // Clean up adherence logs first to prevent foreign key constraint violations
      await _client.from('adherence_logs').delete().eq('medication_id', medicationId);
      // Delete the medication itself
      await _client.from('medications').delete().eq('id', medicationId);
    } catch (e) {
      rethrow;
    }
  }

  /// Update the stock count of a medication
  static Future<void> updateMedicationStock(String medicationId, int newStock) async {
    try {
      await _client.from('medications').update({
        'stock_count': newStock,
      }).eq('id', medicationId);
    } catch (e) {
      rethrow;
    }
  }

  // --- Adherence Logs Operations ---

  /// Fetch adherence logs for the current user
  static Future<List<Map<String, dynamic>>> getAdherenceLogs() async {
    if (!_isInitialized) {
      return [];
    }
    final user = currentUser;
    if (user == null) return [];

    try {
      final List<dynamic> data = await _client
          .from('adherence_logs')
          .select()
          .eq('user_id', user.id);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Log adherence for a medication on a specific date
  static Future<void> logAdherence({
    required String medicationId,
    required DateTime date,
    required bool taken,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    // Format date as YYYY-MM-DD
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    try {
      await _client.from('adherence_logs').upsert({
        'user_id': user.id,
        'medication_id': medicationId,
        'date': dateString,
        'taken': taken,
      }, onConflict: 'medication_id,date');
    } catch (e) {
      rethrow;
    }
  }

  // --- Family Monitoring Operations ---

  /// Fetch all sent family monitoring invitations/requests
  static Future<List<Map<String, dynamic>>> getSentInvitations() async {
    if (!_isInitialized) {
      return [];
    }
    final user = currentUser;
    if (user == null) return [];

    try {
      final List<dynamic> data = await _client
          .from('family_monitoring')
          .select()
          .eq('inviter_id', user.id);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting sent invitations: $e');
      return [];
    }
  }

  /// Fetch all received pending family monitoring invitations
  static Future<List<Map<String, dynamic>>> getReceivedInvitations() async {
    if (!_isInitialized) {
      return [];
    }
    final user = currentUser;
    if (user == null || user.email == null) return [];

    try {
      final List<dynamic> data = await _client
          .from('family_monitoring')
          .select('*, profiles:inviter_id(full_name, avatar_url, email)')
          .or('invitee_id.eq.${user.id},invitee_email.eq.${user.email}')
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting received invitations: $e');
      return [];
    }
  }

  /// Send a family monitoring invitation to another user by email
  static Future<void> sendFamilyInvitation({
    required String email,
    required String relation,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      // Look up if a profile exists with this email address
      final inviteeProfile = await _client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      final inviteeId = inviteeProfile?['id'] as String?;

      await _client.from('family_monitoring').insert({
        'inviter_id': user.id,
        'invitee_email': email,
        'invitee_id': inviteeId,
        'relation': relation,
        'status': 'pending',
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Respond to a pending family monitoring invitation (accept/decline)
  static Future<void> respondToInvitation({
    required String requestId,
    required bool accept,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final status = accept ? 'accepted' : 'declined';
    try {
      await _client.from('family_monitoring').update({
        'status': status,
        'invitee_id': user.id,
      }).eq('id', requestId);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch a monitored family member's medication profile, schedule, and logs
  /// Runs a secure RPC function to verify authorization and fetch the data safely.
  static Future<Map<String, dynamic>?> getMonitoredMemberData(String memberId) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _client.rpc(
        'get_monitored_member_data',
        params: {'p_member_id': memberId},
      );
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error getting monitored member data: $e');
      return null;
    }
  }
}
