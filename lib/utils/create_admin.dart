import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> createAdminUser() async {
  final supabase = Supabase.instance.client;

  // Sign up admin
  final response = await supabase.auth.signUp(
    email: 'admin@georoute.com',
    password: 'admin123',
  );

  final user = response.user;
  if (user == null) {
    print('Failed to create admin user.');
    return;
  }

  print('Admin created! Auth ID: ${user.id}');

  // Create matching profile
  await supabase.from('profiles').insert({
    'id': user.id,
    'full_name': 'Admin',
    'avatar_url': null,
    'preferences': [],
  });

  // Optional: create a row in your 'users' table with role and registration status
  await supabase.from('users').insert({
    'id': user.id,
    'email': 'admin@georoute.com',
    'full_name': 'Admin',
    'role': 'admin',
    'registration_status': 'approved',
  });

  print('Admin profile and users table row created!');
}
