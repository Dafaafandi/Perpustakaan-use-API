import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:perpus_app/providers/auth_provider.dart';
import 'package:perpus_app/providers/book_provider.dart';
import 'package:perpus_app/providers/category_provider.dart';

class CredentialTestScreen extends StatefulWidget {
  const CredentialTestScreen({super.key});

  @override
  State<CredentialTestScreen> createState() => _CredentialTestScreenState();
}

class _CredentialTestScreenState extends State<CredentialTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String _loginResult = '';
  String _currentUser = '';

  // Test credentials based on the logs
  final List<Map<String, String>> _testCredentials = [
    {'username': '12345678', 'password': '12345678', 'note': 'Success in logs'},
    {
      'username': 'abidafaaa',
      'password': 'password123',
      'note': 'Success in logs (guess password)'
    },
    {'username': 'Admin123', 'password': '12345678', 'note': 'Failed in logs'},
    {'username': 'admin', 'password': 'admin123', 'note': 'Failed in logs'},
    {
      'username': 'admin',
      'password': 'password',
      'note': 'Common admin password'
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  void _checkCurrentUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      setState(() {
        _currentUser =
            'Logged in as: ${authProvider.userName} (${authProvider.userRole})';
      });
    }
  }

  Future<void> _testLogin(String username, String password) async {
    setState(() {
      _isLoading = true;
      _loginResult = 'Testing login for $username...';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(username, password);

      if (success) {
        setState(() {
          _loginResult = '✅ LOGIN SUCCESS for $username\n'
              'User: ${authProvider.userName}\n'
              'Role: ${authProvider.userRole}\n'
              'Email: ${authProvider.userEmail}';
          _currentUser =
              'Logged in as: ${authProvider.userName} (${authProvider.userRole})';
        });

        // Test API calls after successful login
        _testApiCalls();
      } else {
        setState(() {
          _loginResult = '❌ LOGIN FAILED for $username';
        });
      }
    } catch (e) {
      setState(() {
        _loginResult = '❌ LOGIN ERROR for $username: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testApiCalls() async {
    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Test fetching books
      await bookProvider.fetchBooks();
      final bookCount = bookProvider.books.length;

      // Test fetching categories
      await categoryProvider.fetchCategories();
      final categoryCount = categoryProvider.categories.length;

      setState(() {
        _loginResult += '\n\n📚 API Test Results:\n'
            '• Books loaded: $bookCount\n'
            '• Categories loaded: $categoryCount';
      });
    } catch (e) {
      setState(() {
        _loginResult += '\n\n❌ API Test Failed: $e';
      });
    }
  }

  Future<void> _manualLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await _testLogin(_usernameController.text, _passwordController.text);
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    setState(() {
      _currentUser = '';
      _loginResult = 'Logged out successfully';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Credential Test'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_currentUser.isNotEmpty)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current User Status
            if (_currentUser.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentUser,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Manual Login Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual Login Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _manualLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Test Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Test Buttons
            const Text(
              'Quick Test Credentials:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Column(
                children: [
                  // Test Credential Buttons
                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: _testCredentials.length,
                      itemBuilder: (context, index) {
                        final cred = _testCredentials[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                                '${cred['username']} / ${cred['password']}'),
                            subtitle: Text(cred['note']!),
                            trailing: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _testLogin(
                                        cred['username']!, cred['password']!),
                                    child: const Text('Test'),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Results Display
                  if (_loginResult.isNotEmpty)
                    Expanded(
                      flex: 1,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Test Results:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  _loginResult,
                                  style:
                                      const TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
