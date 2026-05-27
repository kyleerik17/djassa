import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../../core/services/supabase_service.dart';

class RemoteDataSource {
  final SupabaseClient client = SupabaseService.client;

  /// REGISTER
  Future<UserModel> register({
    required String email,
    required String password,
    String role = 'client',
    required String name,
    required String surname,
    required String phone,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final response = await client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'name': name,
          'surname': surname,
          'phone': phone,
          'role': role,
        },
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Erreur inscription');
      }

      await client.from('profiles').insert({
        'id': user.id,
        'name': name,
        'surname': surname,
        'phone': phone,
        'email': normalizedEmail,
        'role': role,
      });

      return UserModel(
        id: user.id,
        name: name,
        surname: surname,
        phone: phone,
        email: normalizedEmail,
        isVerified: false,
        role: role,
        createdAt: DateTime.now(),
      );
    } on AuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    } on PostgrestException catch (e) {
      if (e.code == '42703' && e.message.contains('role')) {
        throw Exception(
          'La colonne profiles.role manque. Ex?cute supabase/courier_orders.sql dans Supabase.',
        );
      }
      throw Exception(e.message);
    }
  }

  String _authErrorMessage(AuthException error) {
    switch (error.code) {
      case 'user_already_exists':
      case 'email_exists':
        return 'Un compte existe d?j? avec cet email. Connectez-vous ou utilisez un autre email.';
      case 'email_address_not_authorized':
        return 'Supabase refuse d’envoyer l’email de confirmation a cette adresse avec le SMTP par defaut. Utilisez un email membre de l’organisation Supabase, desactivez temporairement la confirmation email en developpement, ou configurez un SMTP personnalise.';
      case 'email_address_invalid':
        return 'Adresse email invalide ou domaine de test non accepte. Utilisez une vraie adresse email.';
      case 'email_provider_disabled':
        return 'Les inscriptions email/mot de passe sont desactivees dans Supabase Auth > Providers > Email.';
      case 'weak_password':
        return 'Mot de passe trop faible. Utilisez un mot de passe plus long et plus securise.';
      case 'signup_disabled':
        return 'Les inscriptions sont desactivees dans Supabase Auth.';
      case 'captcha_failed':
        return 'Captcha requis ou invalide dans Supabase Auth.';
      case 'over_email_send_rate_limit':
        return 'Trop d’emails envoyes. Patientez avant de refaire une inscription, ou configurez un SMTP personnalise.';
      case 'over_request_rate_limit':
        return 'Trop de tentatives depuis ce navigateur/reseau. Patientez quelques minutes puis reessayez.';
      case 'validation_failed':
        return 'Donnees d’inscription refusees par Supabase. Verifiez l’email, le mot de passe et les reglages Auth.';
      default:
        if (error.statusCode == '422') {
          return 'Inscription refusee par Supabase (${error.code ?? '422'}): ${error.message}';
        }
        return error.message;
    }
  }

  /// LOGIN (email ou numéro de téléphone)
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final String email;

    final isEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(identifier);

    if (isEmail) {
      email = identifier;
    } else {
      // Récupérer l'email associé au numéro de téléphone
      final profile = await client
          .from('profiles')
          .select('email')
          .eq('phone', identifier)
          .maybeSingle();

      if (profile == null || profile['email'] == null) {
        throw Exception('Aucun compte associé à ce numéro de téléphone');
      }

      email = profile['email'] as String;
    }

    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user == null) {
      throw Exception('Identifiants incorrects');
    }

    final profile =
        await client.from('profiles').select().eq('id', user.id).single();

    return UserModel.fromJson(profile);
  }

  /// CURRENT USER
  Future<UserModel?> getCurrentUser() async {
    final user = client.auth.currentUser;

    if (user == null) return null;

    final profile =
        await client.from('profiles').select().eq('id', user.id).single();

    return UserModel.fromJson(profile);
  }

  /// UPDATE PROFILE
  Future<UserModel> updateProfile(UserModel user) async {
    final updated = await client
        .from('profiles')
        .update({
          'name': user.name,
          'surname': user.surname,
          'phone': user.phone,
          'email': user.email,
          'avatar_url': user.avatarUrl,
          'role': user.role,
        })
        .eq('id', user.id)
        .select()
        .single();

    return UserModel.fromJson(updated);
  }

  /// LOGOUT
  Future<void> logout() async {
    await client.auth.signOut();
  }

  /// IS LOGGED IN
  bool isLoggedIn() {
    return client.auth.currentUser != null;
  }
}
