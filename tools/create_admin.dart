// create_admin.dart
// Tool sederhana untuk membuat akun admin
// Jalankan dengan: dart run create_admin.dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== TOOL PEMBUATAN ADMIN ===\n');

  // Input data admin
  stdout.write('Masukkan nama admin: ');
  final name = stdin.readLineSync() ?? '';

  stdout.write('Masukkan username admin: ');
  final username = stdin.readLineSync() ?? '';

  stdout.write('Masukkan email admin: ');
  final email = stdin.readLineSync() ?? '';

  stdout.write('Masukkan password admin: ');
  final password = stdin.readLineSync() ?? '';

  stdout.write('Masukkan URL API (contoh: http://localhost:8000/api): ');
  final apiUrl = stdin.readLineSync() ?? '';

  // Konfirmasi data
  print('\n=== KONFIRMASI DATA ===');
  print('Nama: $name');
  print('Username: $username');
  print('Email: $email');
  print('API URL: $apiUrl');

  stdout.write('\nApakah data sudah benar? (y/n): ');
  final confirm = stdin.readLineSync() ?? '';

  if (confirm.toLowerCase() != 'y') {
    print('Operasi dibatalkan.');
    return;
  }

  // Buat admin
  try {
    print('\nMembuat admin...');

    final response = await http.post(
      Uri.parse('$apiUrl/admin/register'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'role': 'admin',
        'admin_secret': 'ADMIN_SECRET_2025', // Sesuaikan dengan secret key Anda
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ Admin berhasil dibuat!');
      print('Username: $username');
      print('Password: $password');
      print('\nSekarang Anda bisa login sebagai admin.');
    } else {
      print('❌ Gagal membuat admin.');
      print('Status Code: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
    print('\nPastikan:');
    print('1. API server berjalan');
    print('2. URL API benar');
    print('3. Endpoint /admin/register tersedia');
  }
}
