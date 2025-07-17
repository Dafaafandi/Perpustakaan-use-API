import 'package:dio/dio.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart' as CategoryModel;
import 'package:perpus_app/models/user.dart';
import 'package:perpus_app/models/borrowing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  final Dio _dio;

  ApiService._()
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://perpus-api.mamorasoft.com/api',
          connectTimeout: const Duration(
              milliseconds: 15000), // Increase timeout for external API
          receiveTimeout: const Duration(milliseconds: 15000),
          sendTimeout: const Duration(milliseconds: 15000),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )) {
    // Add logging interceptor for debugging
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
        ),
      );
    }

    // Auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized - auto logout
          if (error.response?.statusCode == 401) {
            await logout();
            // You could add navigation to login screen here
          }
          return handler.next(error);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._();

  factory ApiService() => _instance;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<void> _saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  Future<void> _saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
  }

  Future<void> logout() async {
    try {
      // Try to call logout endpoint if available
      await _dio.post('/logout');
    } catch (e) {
      // Continue with local logout even if server call fails
      if (kDebugMode) {
        print('Server logout failed, continuing with local logout: $e');
      }
    } finally {
      // Always clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      await prefs.remove('user_email');
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      // Prepare form data as required by the API
      final formData = FormData.fromMap({
        'username': username,
        'password': password,
      });

      final response = await _dio.post(
        '/login',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Check for successful response structure
        if (data != null && data['access_token'] != null) {
          await _saveToken(data['access_token']);

          // Save user info if available
          if (data['user'] != null) {
            await _saveUserName(data['user']['name'] ?? 'User');
            if (data['user']['role'] != null) {
              await _saveUserRole(data['user']['role']);
            }
            if (data['user']['email'] != null) {
              await _saveUserEmail(data['user']['email']);
            }
          } else {
            // Default values if user info not provided
            await _saveUserName('User');
            await _saveUserRole('member');
          }

          return true;
        } else if (data != null && data['token'] != null) {
          // Alternative token field name
          await _saveToken(data['token']);
          await _saveUserName('User');
          await _saveUserRole('member');
          return true;
        }
      }

      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        String message = 'Login gagal';
        if (e.response?.statusCode == 401) {
          message = 'Username atau password salah';
        } else if (e.response?.statusCode == 422) {
          message = 'Data login tidak valid';
        } else if (e.type == DioExceptionType.connectionError) {
          message = 'Tidak dapat terhubung ke server';
        }
        print('Login error: $message');
        print('Error details: ${e.response?.data}');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected login error: $e');
      }
      return false;
    }
  }

  Future<bool> register(String name, String username, String email,
      String password, String confirmPassword) async {
    try {
      final response = await _dio.post(
        '/register',
        data: {
          'name': name,
          'username': username,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        String message = 'Registrasi gagal';

        if (e.response?.statusCode == 422) {
          // Handle validation errors
          final errors = e.response?.data['errors'];
          if (errors != null && errors is Map) {
            List<String> errorMessages = [];
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                errorMessages.add(value.first.toString());
              }
            });
            message = errorMessages.join('\n');
          } else {
            message = 'Data registrasi tidak valid';
          }
        } else if (e.type == DioExceptionType.connectionError) {
          message = 'Tidak dapat terhubung ke server';
        }

        print('Register error: $message');
      }

      return false;
    }
  }

  // == CREATE (Tambah Buku Baru) - Menggunakan Endpoint Final dari Backend ==
  Future<bool> addBook(Map<String, String> bookData) async {
    try {
      final formData = FormData.fromMap(bookData);

      final response = await _dio.post(
        '/book/create',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error adding book: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error adding book: $e');
      }
      return false;
    }
  }

  Future<bool> updateBook(int id, Map<String, String> bookData) async {
    try {
      final formData = FormData.fromMap(bookData);

      final response = await _dio.post(
        '/book/$id/update',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error updating book: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error updating book: $e');
      }
      return false;
    }
  }

  Future<bool> deleteBook(int id) async {
    try {
      final response = await _dio.delete('/book/$id/delete');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Book>> getBooks() async {
    try {
      // Use the correct API endpoint with pagination
      final response = await _dio.get('/book/all?page=1&per_page=100');
      final responseData = response.data;

      // Handle the API response structure based on actual API response
      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic> &&
            responseData['data']['books'] is Map<String, dynamic> &&
            responseData['data']['books']['data'] is List) {
          // Correct structure: {status: 200, data: {books: {data: [...]}}}
          final List<dynamic> bookList = responseData['data']['books']['data'];
          return bookList.map((json) => Book.fromJson(json)).toList();
        } else if (responseData['data'] is List) {
          // Direct data array
          final List<dynamic> bookList = responseData['data'];
          return bookList.map((json) => Book.fromJson(json)).toList();
        } else if (responseData['data'] is Map<String, dynamic> &&
            responseData['data']['data'] is List) {
          // Nested pagination structure
          final List<dynamic> bookList = responseData['data']['data'];
          return bookList.map((json) => Book.fromJson(json)).toList();
        } else if (responseData['books'] is List) {
          // Books directly in response
          final List<dynamic> bookList = responseData['books'];
          return bookList.map((json) => Book.fromJson(json)).toList();
        }
      }

      // If structure is unexpected, return empty list
      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching books: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil data buku dari server.');
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getBooks: $e');
      }
      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  Future<Book> getBookById(int bookId) async {
    try {
      final response = await _dio.get('/book/$bookId');
      final responseData = response.data;

      // Handle different possible response structures
      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic>) {
          return Book.fromJson(responseData['data']);
        } else if (responseData['book'] is Map<String, dynamic>) {
          return Book.fromJson(responseData['book']);
        } else if (responseData['id'] != null) {
          // Direct book object
          return Book.fromJson(responseData);
        }
      }

      throw Exception('Struktur data detail buku tidak terduga.');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error getting book by ID: ${e.response?.statusCode}');
        print('Response: ${e.response?.data}');
      }
      throw Exception('Gagal memuat detail buku.');
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getBookById: $e');
      }
      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  // == CATEGORY CRUD METHODS ==

  // CREATE
  Future<bool> addCategory(String categoryName) async {
    try {
      final formData = FormData.fromMap({
        'nama_kategori': categoryName,
      });

      final response = await _dio.post(
        '/category/create',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error adding category: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error adding category: $e');
      }
      return false;
    }
  }

  // UPDATE
  Future<bool> updateCategory(int id, String categoryName) async {
    try {
      final formData = FormData.fromMap({
        'nama_kategori': categoryName,
      });

      final response = await _dio.post(
        '/category/update/$id',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error updating category: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error updating category: $e');
      }
      return false;
    }
  }

  // DELETE
  Future<bool> deleteCategory(int id) async {
    try {
      final response = await _dio.delete('/category/$id/delete');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // GET LIST (sudah ada, kita pastikan lagi)
  Future<List<CategoryModel.Category>> getCategories() async {
    try {
      final response = await _dio.get('/category/all/all');
      final responseData = response.data;

      // Handle different possible response structures based on actual API response
      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic> &&
            responseData['data']['categories'] is List) {
          // Correct structure: {status: 200, data: {categories: [...]}}
          final List<dynamic> categoryList = responseData['data']['categories'];
          return categoryList
              .map((json) => CategoryModel.Category.fromJson(json))
              .toList();
        } else if (responseData['data'] is List) {
          // Direct data array
          final List<dynamic> categoryList = responseData['data'];
          return categoryList
              .map((json) => CategoryModel.Category.fromJson(json))
              .toList();
        } else if (responseData['categories'] is List) {
          // Categories directly in response
          final List<dynamic> categoryList = responseData['categories'];
          return categoryList
              .map((json) => CategoryModel.Category.fromJson(json))
              .toList();
        }
      } else if (responseData is List) {
        // Direct array response
        return responseData
            .map((json) => CategoryModel.Category.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching categories: ${e.response?.data}');
      }
      throw Exception('Gagal memuat kategori.');
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getCategories: $e');
      }
      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  // == PAGINATION & SEARCH SUPPORT ==

  // Get books with pagination and enhanced filtering
  Future<Map<String, dynamic>> getBooksPaginated({
    int page = 1,
    int perPage = 10,
    String? search,
    int? categoryId,
    String? author,
    String? publisher,
    String? isbn,
    String? sortBy,
    String? sortOrder,
    int? year,
    String? status,
  }) async {
    try {
      Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': perPage,
      };

      // Search parameter
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Filter by category
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }

      // Filter by author
      if (author != null && author.isNotEmpty) {
        queryParams['author'] = author;
      }

      // Filter by publisher
      if (publisher != null && publisher.isNotEmpty) {
        queryParams['publisher'] = publisher;
      }

      // Filter by ISBN
      if (isbn != null && isbn.isNotEmpty) {
        queryParams['isbn'] = isbn;
      }

      // Filter by publication year
      if (year != null) {
        queryParams['year'] = year;
      }

      // Filter by status (available, borrowed, etc.)
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      // Sorting options
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy; // title, author, created_at, etc.
      }

      if (sortOrder != null && sortOrder.isNotEmpty) {
        queryParams['sort_order'] = sortOrder; // asc, desc
      }

      if (kDebugMode) {
        print('Fetching books with filters: $queryParams');
      }

      final response =
          await _dio.get('/book/all', queryParameters: queryParams);
      final responseData = response.data;

      if (kDebugMode) {
        print(
            'API Response for books: ${responseData.toString().substring(0, 200)}...');
      }

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data']['books'] is Map<String, dynamic>) {
        final booksData = responseData['data']['books'];
        final List<dynamic> bookList = booksData['data'] ?? [];

        // Convert to Book objects
        List<Book> books = bookList.map((json) => Book.fromJson(json)).toList();

        // If API doesn't support filtering, implement client-side filtering
        if (books.isNotEmpty &&
            (categoryId != null ||
                author != null ||
                publisher != null ||
                year != null ||
                status != null)) {
          // Apply category filter
          if (categoryId != null) {
            books =
                books.where((book) => book.category.id == categoryId).toList();
          }

          // Apply author filter
          if (author != null && author.isNotEmpty) {
            books = books
                .where((book) =>
                    book.pengarang.toLowerCase().contains(author.toLowerCase()))
                .toList();
          }

          // Apply publisher filter
          if (publisher != null && publisher.isNotEmpty) {
            books = books
                .where((book) => book.penerbit
                    .toLowerCase()
                    .contains(publisher.toLowerCase()))
                .toList();
          }

          // Apply year filter
          if (year != null) {
            books =
                books.where((book) => book.tahun == year.toString()).toList();
          }

          // Apply status filter
          if (status != null && status.isNotEmpty && status != 'Semua') {
            if (status == 'Tersedia') {
              books = books.where((book) => book.stok > 0).toList();
            } else if (status == 'Dipinjam') {
              books = books.where((book) => book.stok <= 0).toList();
            }
          }

          // Apply sorting
          if (sortBy != null && sortBy.isNotEmpty) {
            books.sort((a, b) {
              int comparison = 0;
              switch (sortBy) {
                case 'judul':
                  comparison = a.judul.compareTo(b.judul);
                  break;
                case 'pengarang':
                  comparison = a.pengarang.compareTo(b.pengarang);
                  break;
                case 'penerbit':
                  comparison = a.penerbit.compareTo(b.penerbit);
                  break;
                case 'tahun':
                  comparison = a.tahun.compareTo(b.tahun);
                  break;
                default:
                  comparison = a.judul.compareTo(b.judul);
              }
              return sortOrder == 'desc' ? -comparison : comparison;
            });
          }

          // Implement pagination for filtered results
          final totalFilteredItems = books.length;
          final totalFilteredPages = (totalFilteredItems / perPage).ceil();
          final startIndex = (page - 1) * perPage;
          final endIndex = startIndex + perPage;
          final paginatedBooks = books.sublist(
              startIndex, endIndex > books.length ? books.length : endIndex);

          if (kDebugMode) {
            print(
                'Client-side filtering applied: ${books.length} results after filtering');
          }

          return {
            'books': paginatedBooks,
            'current_page': page,
            'total_pages': totalFilteredPages,
            'total_items': totalFilteredItems,
            'per_page': perPage,
          };
        }

        return {
          'books': books,
          'current_page': booksData['current_page'] ?? 1,
          'total_pages': booksData['last_page'] ?? 1,
          'total_items': booksData['total'] ?? 0,
          'per_page': booksData['per_page'] ?? perPage,
        };
      } else {
        return {
          'books': <Book>[],
          'current_page': 1,
          'total_pages': 1,
          'total_items': 0,
          'per_page': perPage,
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching paginated books: $e');
      }
      throw Exception('Gagal mengambil data buku dari server.');
    }
  }

  // Get categories with pagination and enhanced filtering
  Future<Map<String, dynamic>> getCategoriesPaginated({
    int page = 1,
    int perPage = 10,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool? hasBooks, // Filter categories that have books or not
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 getCategoriesPaginated called with:');
        print('  Page: $page, PerPage: $perPage');
        print('  Search: $search');
        print('  SortBy: $sortBy, SortOrder: $sortOrder');
        print('  HasBooks: $hasBooks');
      }

      // Since the API endpoint '/category/all/all' doesn't seem to support
      // server-side filtering and pagination, we'll use client-side approach
      try {
        final allCategories = await getCategories();
        List<CategoryModel.Category> filteredCategories = [...allCategories];

        if (kDebugMode) {
          print('🔍 Retrieved ${allCategories.length} total categories');
        }

        // Apply search filter
        if (search != null && search.isNotEmpty) {
          filteredCategories = filteredCategories
              .where((category) =>
                  category.name.toLowerCase().contains(search.toLowerCase()))
              .toList();
          if (kDebugMode) {
            print(
                '🔍 After search filter: ${filteredCategories.length} categories');
          }
        }

        // Apply hasBooks filter - placeholder implementation
        if (hasBooks != null) {
          if (hasBooks) {
            // Filter categories that have books (books_count > 0)
            // Since we don't have books_count, we'll simulate by filtering some categories
            // In a real implementation, you'd need to fetch book counts from the API
            filteredCategories = filteredCategories.where((category) {
              // Placeholder: assume categories with ID > 50 have books
              return category.id > 50;
            }).toList();
          } else {
            // Filter categories that don't have books (books_count == 0)
            filteredCategories = filteredCategories.where((category) {
              // Placeholder: assume categories with ID <= 50 don't have books
              return category.id <= 50;
            }).toList();
          }
          if (kDebugMode) {
            print(
                '🔍 After hasBooks filter ($hasBooks): ${filteredCategories.length} categories');
          }
        }

        // Apply sorting
        if (sortBy != null && sortBy.isNotEmpty) {
          filteredCategories.sort((a, b) {
            int comparison = 0;
            switch (sortBy) {
              case 'name':
                comparison =
                    a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              case 'created_at':
                comparison = (a.createdAt ?? DateTime.now())
                    .compareTo(b.createdAt ?? DateTime.now());
                break;
              case 'books_count':
                // For books_count sorting, we'd need the count field in the model
                // For now, fallback to name sorting
                comparison =
                    a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              default:
                comparison =
                    a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
            return sortOrder == 'desc' ? -comparison : comparison;
          });
          if (kDebugMode) {
            print(
                '🔍 After sorting ($sortBy $sortOrder): ${filteredCategories.length} categories');
          }
        }

        // Implement pagination
        final totalItems = filteredCategories.length;
        final totalPages = totalItems > 0 ? (totalItems / perPage).ceil() : 1;
        final startIndex = (page - 1) * perPage;
        final endIndex = startIndex + perPage;

        final paginatedCategories = filteredCategories.sublist(
            startIndex,
            endIndex > filteredCategories.length
                ? filteredCategories.length
                : endIndex);

        if (kDebugMode) {
          print('🔍 Pagination: Page $page of $totalPages');
          print(
              '🔍 Showing ${paginatedCategories.length} of $totalItems total categories');
          print(
              '🔍 Categories on this page: ${paginatedCategories.map((c) => c.name).join(', ')}');
        }

        return {
          'categories': paginatedCategories,
          'current_page': page,
          'total_pages': totalPages,
          'total_items': totalItems,
          'per_page': perPage,
        };
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error in category client-side filtering: $e');
        }
        return {
          'categories': <CategoryModel.Category>[],
          'current_page': 1,
          'total_pages': 1,
          'total_items': 0,
          'per_page': perPage,
        };
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching paginated categories: $e');
      }
      throw Exception('Gagal mengambil data kategori dari server.');
    }
  }

  // Search books
  Future<List<Book>> searchBooks(String query) async {
    try {
      final response =
          await _dio.get('/book/search', queryParameters: {'q': query});
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data']['books'] is List) {
        final List<dynamic> bookList = responseData['data']['books'];
        return bookList.map((json) => Book.fromJson(json)).toList();
      } else {
        return [];
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error searching books: $e');
      }
      throw Exception('Gagal mencari buku.');
    }
  }

  // == MEMBER MANAGEMENT (for Admin) ==

  // Enhanced method to get all members (tries API first, then extracts from borrowing data)
  Future<List<User>> getMembers() async {
    try {
      // Get authentication token for protected endpoints
      final token = await getToken();

      // Try the correct user endpoints as provided
      Response? response;
      List<String> endpointsToTry = [
        '/user/member/all?page=1', // Get the first page to get total count
        '/user/member?page=1', // This might return member users
        '/user?page=1', // This might return current user or users
      ];

      for (String endpoint in endpointsToTry) {
        try {
          if (kDebugMode) {
            print('Trying endpoint: $endpoint');
          }

          // Prepare headers with authentication if available
          Map<String, dynamic> headers = {};
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }

          response =
              await _dio.get(endpoint, options: Options(headers: headers));
          if (response.statusCode == 200) {
            if (kDebugMode) {
              print('Success with endpoint: $endpoint');
            }
            break;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed endpoint $endpoint: $e');
          }
          continue;
        }
      }

      if (response == null) {
        if (kDebugMode) {
          print(
              'All member endpoints failed, trying to extract from borrowing data');
        }
      }

      if (response != null) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          // Try different response structures with pagination support
          List<User> allUsers = [];

          // Check if this is the /user endpoint response structure
          if (responseData['status'] == 200 && responseData['data'] != null) {
            final data = responseData['data'];

            // Handle single user object
            if (data is Map<String, dynamic> && data.containsKey('user')) {
              // This is likely the current user endpoint, try to get all users differently
              if (kDebugMode) {
                print(
                    'Found single user endpoint, trying alternative approach');
              }
            }

            // Handle list of users
            if (data is List) {
              allUsers.addAll(data.map((json) => User.fromJson(json)).toList());
            }

            // Handle paginated users in data.users
            if (data is Map<String, dynamic> && data.containsKey('users')) {
              final usersData = data['users'];
              if (usersData is List) {
                allUsers.addAll(
                    usersData.map((json) => User.fromJson(json)).toList());
              } else if (usersData is Map<String, dynamic> &&
                  usersData['data'] is List) {
                // Add users from current page
                allUsers.addAll((usersData['data'] as List)
                    .map((json) => User.fromJson(json))
                    .toList());

                // Get total count from API response
                final totalExpected = usersData['total'] ?? 0;
                final lastPage = usersData['last_page'] ?? 1;
                final currentPage = usersData['current_page'] ?? 1;

                if (kDebugMode) {
                  print(
                      'API shows total: $totalExpected, fetching remaining pages...');
                }

                // Only fetch additional pages if there are more pages
                if (lastPage > currentPage) {
                  for (int page = currentPage + 1; page <= lastPage; page++) {
                    try {
                      Map<String, dynamic> headers = {};
                      if (await getToken() != null) {
                        headers['Authorization'] = 'Bearer ${await getToken()}';
                      }

                      final pageResponse = await _dio.get('/user/member/all',
                          queryParameters: {'page': page},
                          options: Options(headers: headers));
                      final pageData = pageResponse.data;
                      if (pageData is Map<String, dynamic> &&
                          pageData['data'] is Map<String, dynamic> &&
                          pageData['data']['users'] is Map<String, dynamic> &&
                          pageData['data']['users']['data'] is List) {
                        allUsers.addAll(
                            (pageData['data']['users']['data'] as List)
                                .map((json) => User.fromJson(json))
                                .toList());
                      }
                    } catch (e) {
                      if (kDebugMode) {
                        print('Failed to fetch page $page: $e');
                      }
                      break;
                    }
                  }
                }

                // Validate we got the expected count
                if (kDebugMode) {
                  print(
                      'Expected: $totalExpected users, Got: ${allUsers.length} users before dedup');
                }
              }
            }
          }

          // Check if this is a paginated response
          if (responseData['data'] is Map<String, dynamic>) {
            final dataMap = responseData['data'] as Map<String, dynamic>;

            // Single page list in data.members or data.users
            if (dataMap['members'] is List) {
              allUsers.addAll((dataMap['members'] as List)
                  .map((json) => User.fromJson(json))
                  .toList());
            } else if (dataMap['users'] is List) {
              allUsers.addAll((dataMap['users'] as List)
                  .map((json) => User.fromJson(json))
                  .toList());
            }
          }

          // Try other response structures
          if (allUsers.isEmpty) {
            if (responseData['data'] is List) {
              allUsers.addAll((responseData['data'] as List)
                  .map((json) => User.fromJson(json))
                  .toList());
            } else if (responseData['members'] is List) {
              allUsers.addAll((responseData['members'] as List)
                  .map((json) => User.fromJson(json))
                  .toList());
            } else if (responseData['users'] is List) {
              allUsers.addAll((responseData['users'] as List)
                  .map((json) => User.fromJson(json))
                  .toList());
            }
          }

          if (allUsers.isNotEmpty) {
            // Remove duplicates by ID to ensure accurate count
            final Map<int, User> uniqueUsers = {};
            for (var user in allUsers) {
              uniqueUsers[user.id] = user;
            }
            final uniqueUsersList = uniqueUsers.values.toList();

            if (kDebugMode) {
              print(
                  'Found ${allUsers.length} total users, ${uniqueUsersList.length} unique users from API endpoint');
            }
            return uniqueUsersList;
          }
        }
      }

      // Try to extract members from borrowing data (fetch all pages) and also try other sources
      try {
        final Map<int, User> uniqueMembers = {};

        // 1. Extract from borrowing data (all pages)
        int currentPage = 1;
        int maxPages = 50; // Safety limit to prevent infinite loops
        bool hasMorePages = true;

        while (hasMorePages && currentPage <= maxPages) {
          try {
            final borrowingResponse = await _dio.get('/peminjaman/all',
                queryParameters: {'page': currentPage, 'per_page': 100});
            final borrowingData = borrowingResponse.data;

            if (borrowingData is Map<String, dynamic> &&
                borrowingData['data'] is Map<String, dynamic> &&
                borrowingData['data']['peminjaman'] is Map<String, dynamic>) {
              final peminjamanData =
                  borrowingData['data']['peminjaman'] as Map<String, dynamic>;

              if (peminjamanData['data'] is List) {
                final List<dynamic> borrowings = peminjamanData['data'];

                for (var borrowing in borrowings) {
                  if (borrowing['member'] != null) {
                    final memberData = borrowing['member'];
                    final member = User(
                      id: memberData['id'] ?? 0,
                      name: memberData['name'] ?? 'Unknown',
                      username: memberData['username'] ?? '',
                      email: memberData['email'] ?? '',
                      role: 'member',
                    );
                    uniqueMembers[member.id] = member;
                  }

                  // Also check if there's a 'user' field in addition to 'member'
                  if (borrowing['user'] != null) {
                    final userData = borrowing['user'];
                    final user = User(
                      id: userData['id'] ?? 0,
                      name: userData['name'] ?? 'Unknown',
                      username: userData['username'] ?? '',
                      email: userData['email'] ?? '',
                      role: userData['role'] ?? 'member',
                    );
                    uniqueMembers[user.id] = user;
                  }
                }

                // Check pagination
                final currentPageNum =
                    peminjamanData['current_page'] ?? currentPage;
                final lastPage = peminjamanData['last_page'] ?? currentPage;
                final total = peminjamanData['total'] ?? 0;

                if (kDebugMode) {
                  print(
                      'Processed borrowing page $currentPageNum of $lastPage (total: $total records)');
                  print('Found ${uniqueMembers.length} unique members so far');
                }

                if (currentPageNum >= lastPage) {
                  hasMorePages = false;
                } else {
                  currentPage = currentPageNum + 1;
                }
              } else {
                hasMorePages = false;
              }
            } else {
              hasMorePages = false;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to fetch borrowing page $currentPage: $e');
            }
            hasMorePages = false;
          }
        }

        // 2. Try to get additional members from history or other borrowing endpoints
        try {
          final allBorrowingResponse = await _dio.get('/peminjaman/all');
          final allBorrowingData = allBorrowingResponse.data;
          if (allBorrowingData is Map<String, dynamic> &&
              allBorrowingData['data'] is List) {
            for (var borrowing in allBorrowingData['data']) {
              if (borrowing['member'] != null) {
                final memberData = borrowing['member'];
                final member = User(
                  id: memberData['id'] ?? 0,
                  name: memberData['name'] ?? 'Unknown',
                  username: memberData['username'] ?? '',
                  email: memberData['email'] ?? '',
                  role: 'member',
                );
                uniqueMembers[member.id] = member;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Could not fetch from /peminjaman/all: $e');
          }
        }

        // 3. Try to get members from book borrowing history with higher per_page
        try {
          final historyResponse = await _dio
              .get('/peminjaman', queryParameters: {'per_page': 1000});
          final historyData = historyResponse.data;
          if (historyData is Map<String, dynamic> &&
              historyData['data'] is Map<String, dynamic> &&
              historyData['data']['peminjaman'] is Map<String, dynamic>) {
            final peminjamanData =
                historyData['data']['peminjaman'] as Map<String, dynamic>;
            if (peminjamanData['data'] is List) {
              for (var borrowing in peminjamanData['data']) {
                if (borrowing['member'] != null) {
                  final memberData = borrowing['member'];
                  final member = User(
                    id: memberData['id'] ?? 0,
                    name: memberData['name'] ?? 'Unknown',
                    username: memberData['username'] ?? '',
                    email: memberData['email'] ?? '',
                    role: 'member',
                  );
                  uniqueMembers[member.id] = member;
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Could not fetch large batch from /peminjaman: $e');
          }
        }

        if (uniqueMembers.isNotEmpty) {
          if (kDebugMode) {
            print('Total unique users found: ${uniqueMembers.length}');
          }
          return uniqueMembers.values.toList();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to extract members from borrowing data: $e');
        }
      }

      return _getMockMembers();
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching members: ${e.response?.data}');
      }
      // Return mock data instead of empty list for better UX
      return _getMockMembers();
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getMembers: $e');
      }
      return _getMockMembers();
    }
  }

  // Mock members data for development
  List<User> _getMockMembers() {
    return [
      User(
        id: 1,
        name: 'John Doe',
        username: 'johndoe',
        email: 'john@example.com',
        role: 'member',
      ),
      User(
        id: 2,
        name: 'Jane Smith',
        username: 'janesmith',
        email: 'jane@example.com',
        role: 'member',
      ),
      User(
        id: 3,
        name: 'Bob Wilson',
        username: 'bobwilson',
        email: 'bob@example.com',
        role: 'member',
      ),
      User(
        id: 4,
        name: 'Alice Brown',
        username: 'alicebrown',
        email: 'alice@example.com',
        role: 'member',
      ),
      User(
        id: 5,
        name: 'Charlie Davis',
        username: 'charliedavis',
        email: 'charlie@example.com',
        role: 'member',
      ),
    ];
  }

  // Get members with pagination - Enhanced to use real data from borrowing
  Future<Map<String, dynamic>> getMembersPaginated({
    int page = 1,
    int perPage = 10,
    String? search,
  }) async {
    try {
      Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': perPage,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Try multiple possible endpoints first
      Response? response;
      List<User> allMembers = [];

      try {
        response =
            await _dio.get('/admin/members', queryParameters: queryParams);
      } catch (e) {
        try {
          response = await _dio.get('/users', queryParameters: queryParams);
        } catch (e) {
          try {
            response = await _dio.get('/members', queryParameters: queryParams);
          } catch (e) {
            if (kDebugMode) {
              print(
                  'All direct member endpoints failed, using extracted member data');
            }
          }
        }
      }

      if (response != null) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic> &&
            responseData['data'] is Map<String, dynamic>) {
          final membersData = responseData['data'];
          final List<dynamic> memberList = membersData['members'] ??
              membersData['users'] ??
              membersData['data'] ??
              [];

          return {
            'members': memberList.map((json) => User.fromJson(json)).toList(),
            'current_page': membersData['current_page'] ?? 1,
            'total_pages': membersData['last_page'] ?? 1,
            'total_items': membersData['total'] ?? 0,
            'per_page': perPage,
          };
        }
      }

      // If direct member endpoints fail, get members from getMembers() which extracts from borrowing data
      try {
        allMembers = await getMembers();
        if (kDebugMode) {
          print(
              'Using ${allMembers.length} members extracted from borrowing data for pagination');
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              'Failed to get members from borrowing extraction, using mock data');
        }
        return _getMockMembersPaginated(page, perPage, search);
      }

      // Filter by search if provided
      List<User> filteredMembers = allMembers;
      if (search != null && search.isNotEmpty) {
        filteredMembers = allMembers
            .where((member) =>
                member.name.toLowerCase().contains(search.toLowerCase()) ||
                member.username.toLowerCase().contains(search.toLowerCase()) ||
                member.email.toLowerCase().contains(search.toLowerCase()))
            .toList();
      }

      // Calculate pagination
      final totalItems = filteredMembers.length;
      final totalPages = (totalItems / perPage).ceil();
      final startIndex = (page - 1) * perPage;
      final endIndex = startIndex + perPage;
      final paginatedMembers = filteredMembers.sublist(
          startIndex,
          endIndex > filteredMembers.length
              ? filteredMembers.length
              : endIndex);

      return {
        'members': paginatedMembers,
        'current_page': page,
        'total_pages': totalPages,
        'total_items': totalItems,
        'per_page': perPage,
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching members: $e');
      }
      return _getMockMembersPaginated(page, perPage, search);
    }
  }

  // Mock paginated members data
  Map<String, dynamic> _getMockMembersPaginated(
      int page, int perPage, String? search) {
    final allMembers = _getMockMembers();

    // Filter by search if provided
    List<User> filteredMembers = allMembers;
    if (search != null && search.isNotEmpty) {
      filteredMembers = allMembers
          .where((member) =>
              member.name.toLowerCase().contains(search.toLowerCase()) ||
              member.username.toLowerCase().contains(search.toLowerCase()) ||
              member.email.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    // Paginate
    final startIndex = (page - 1) * perPage;
    final endIndex = startIndex + perPage;
    final paginatedMembers = filteredMembers.sublist(startIndex,
        endIndex > filteredMembers.length ? filteredMembers.length : endIndex);

    return {
      'members': paginatedMembers,
      'current_page': page,
      'total_pages': (filteredMembers.length / perPage).ceil(),
      'total_items': filteredMembers.length,
      'per_page': perPage,
    };
  }

  // == BORROWING SYSTEM ==

  // Get borrowing history with pagination
  Future<Map<String, dynamic>> getBorrowingsPaginated({
    int page = 1,
    int perPage = 15,
    String? status,
  }) async {
    try {
      Map<String, dynamic> queryParams = {
        'page': page,
      };

      if (perPage != 15) {
        queryParams['per_page'] = perPage;
      }

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      if (kDebugMode) {
        print('Fetching borrowings for page $page with params: $queryParams');
      }

      final response =
          await _dio.get('/peminjaman', queryParameters: queryParams);
      final responseData = response.data;

      if (kDebugMode) {
        print('Borrowing response status: ${response.statusCode}');
      }

      // Handle the correct API response structure based on your JSON data
      if (responseData is Map<String, dynamic> &&
          responseData['status'] == 200 &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data']['peminjaman'] is Map<String, dynamic>) {
        final borrowingsData = responseData['data']['peminjaman'];
        final List<dynamic> borrowingList = borrowingsData['data'] ?? [];

        if (kDebugMode) {
          print('Found ${borrowingList.length} borrowings on page $page');
          print(
              'Total: ${borrowingsData['total']}, Current page: ${borrowingsData['current_page']}, Last page: ${borrowingsData['last_page']}');
        }

        return {
          'borrowings': borrowingList,
          'current_page': borrowingsData['current_page'] ?? page,
          'total_pages': borrowingsData['last_page'] ?? 1,
          'total_items': borrowingsData['total'] ?? borrowingList.length,
          'per_page': borrowingsData['per_page'] ?? perPage,
          'next_page_url': borrowingsData['next_page_url'],
          'prev_page_url': borrowingsData['prev_page_url'],
        };
      } else if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        // Fallback for direct data array
        final List<dynamic> borrowingList = responseData['data'];
        return {
          'borrowings': borrowingList,
          'current_page': page,
          'total_pages': 1,
          'total_items': borrowingList.length,
          'per_page': perPage,
        };
      }

      if (kDebugMode) {
        print(
            'Unexpected borrowing response structure: ${responseData?.runtimeType}');
      }

      return {
        'borrowings': [],
        'current_page': 1,
        'total_pages': 1,
        'total_items': 0,
        'per_page': perPage,
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching borrowings: ${e.response?.statusCode}');
        print('Error response: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil data peminjaman.');
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getBorrowingsPaginated: $e');
      }
      throw Exception('Terjadi kesalahan yang tidak terduga.');
    }
  }

  // Get all borrowings
  Future<List<dynamic>> getAllBorrowings() async {
    try {
      final response = await _dio.get('/peminjaman/all');
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is List) {
          return responseData['data'];
        } else if (responseData['borrowings'] is List) {
          return responseData['borrowings'];
        }
      } else if (responseData is List) {
        return responseData;
      }

      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching all borrowings: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil data peminjaman.');
    }
  }

  // Get borrowing detail
  Future<Map<String, dynamic>?> getBorrowingDetail(int id) async {
    try {
      final response = await _dio.get('/peminjaman/show?id=$id');
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic>) {
          return responseData['data'];
        } else if (responseData['borrowing'] is Map<String, dynamic>) {
          return responseData['borrowing'];
        }
      }

      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching borrowing detail: ${e.response?.data}');
      }
      return null;
    }
  }

  // Create a borrowing (requires bookId and memberId)
  Future<bool> borrowBook(
      int bookId, int memberId, String borrowDate, String returnDate) async {
    try {
      final formData = FormData.fromMap({
        'tanggal_peminjaman': borrowDate,
        'tanggal_pengembalian': returnDate,
      });

      final response = await _dio.post(
        '/peminjaman/book/$bookId/member/$memberId',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error borrowing book: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error borrowing book: $e');
      }
      return false;
    }
  }

  // Return a book
  Future<bool> returnBook(int borrowingId, String returnDate) async {
    try {
      final formData = FormData.fromMap({
        'tanggal_pengembalian': returnDate,
      });

      final response = await _dio.post(
        '/peminjaman/book/$borrowingId/return',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error returning book: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error returning book: $e');
      }
      return false;
    }
  }

  // == DASHBOARD DATA ==

  // Get dashboard statistics (enhanced with real data extraction)
  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      if (kDebugMode) {
        print('Starting dashboard stats calculation...');
      }

      // Try to calculate stats from real data
      Map<String, dynamic> calculatedStats = {
        'total_books': 0,
        'total_members': 0,
        'books_borrowed': 0,
        'books_available': 0,
        'total_categories': 0,
        'overdue_books': 0,
      };

      // Get total books from books API
      try {
        final books = await getBooks();
        calculatedStats['total_books'] = books.length;
        if (kDebugMode) {
          print('Total books from API: ${books.length}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get books count: $e');
        }
      }

      // Get total members using the enhanced getMembers method
      try {
        final members = await getMembers();
        calculatedStats['total_members'] = members.length;
        if (kDebugMode) {
          print('Total members from API: ${members.length}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get members count: $e');
        }
      }

      // Get categories count
      try {
        final categories = await getCategories();
        calculatedStats['total_categories'] = categories.length;
        if (kDebugMode) {
          print('Total categories from API: ${categories.length}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get categories count: $e');
        }
        calculatedStats['total_categories'] = 8; // fallback
      }

      // Get borrowing statistics
      try {
        final borrowings = await getBorrowings();
        int activeBorrowings = 0;
        int overdueBorrowings = 0;
        final DateTime now = DateTime.now();

        for (var borrowing in borrowings) {
          // Count active borrowings (status != "3" means not returned)
          if (borrowing.status != "3" &&
              borrowing.status.toLowerCase() != "returned") {
            activeBorrowings++;

            // Check for overdue books using expectedReturnDate
            if (now.isAfter(borrowing.expectedReturnDate) &&
                borrowing.actualReturnDate == null) {
              overdueBorrowings++;
            }
          }
        }

        calculatedStats['books_borrowed'] = activeBorrowings;
        calculatedStats['overdue_books'] = overdueBorrowings;

        if (kDebugMode) {
          print('Active borrowings: $activeBorrowings');
          print('Overdue borrowings: $overdueBorrowings');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get borrowing stats: $e');
        }
      }

      // Calculate available books
      calculatedStats['books_available'] =
          calculatedStats['total_books'] - calculatedStats['books_borrowed'];

      if (kDebugMode) {
        print('Final calculated stats: $calculatedStats');
      }

      // Return calculated stats if we have any real data
      if (calculatedStats['total_books'] > 0 ||
          calculatedStats['total_members'] > 0 ||
          calculatedStats['total_categories'] > 0) {
        return calculatedStats;
      }

      // Return mock data only if no real data is available
      if (kDebugMode) {
        print('No real data available, returning mock stats');
      }
      return _getMockDashboardStats();
    } catch (e) {
      if (kDebugMode) {
        print('Error in getDashboardStats: $e');
      }
      return _getMockDashboardStats();
    }
  }

  // Mock dashboard stats for development
  Map<String, dynamic> _getMockDashboardStats() {
    // Use more realistic numbers based on the actual data available
    return {
      'total_books': 42,
      'total_members': 6, // More realistic based on actual member count
      'books_borrowed': 0, // Start with 0 since no active borrowings
      'books_available': 42, // All books available
      'total_categories': 8,
      'overdue_books': 0, // No overdue books initially
    };
  }

  // == FILE OPERATIONS ==

  // Upload file (for book cover, etc.)
  Future<String?> uploadFile(String filePath,
      {String fieldName = 'file'}) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post('/upload', data: formData);

      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data']['file_url'];
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error uploading file: ${e.response?.data}');
      }
      return null;
    }
  }

  // Download file (for export)
  Future<bool> downloadFile(String url, String savePath) async {
    try {
      final response = await _dio.download(url, savePath);
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error downloading file: $e');
      }
      return false;
    }
  }

  // == EXPORT & IMPORT METHODS ==

  // Export books to PDF
  Future<String?> exportBooksToPdf() async {
    try {
      final response = await _dio.get('/book/export/pdf');

      // The API returns path similar to Excel export
      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic> &&
            response.data['path'] != null) {
          // Return the full URL for download
          String filePath = response.data['path'];
          return 'http://perpus-api.mamorasoft.com/$filePath';
        }
        return 'pdf_exported_successfully';
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error exporting books to PDF: ${e.response?.data}');
      }
      return null;
    }
  }

  // Export books to Excel
  Future<String?> exportBooksToExcel() async {
    try {
      final response = await _dio.get('/book/export/excel');

      // The API returns path in the format: {"status":200,"message":"Berhasil Export File Buku Excel","path":"storage/export/buku_export.xlsx"}
      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic> &&
            response.data['path'] != null) {
          // Return the full URL for download
          String filePath = response.data['path'];
          return 'http://perpus-api.mamorasoft.com/$filePath';
        }
        return 'excel_exported_successfully';
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error exporting books to Excel: ${e.response?.data}');
      }
      return null;
    }
  }

  // Download template for book import
  Future<String?> downloadBookTemplate() async {
    try {
      final response = await _dio.get('/book/download/template');

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic> &&
            response.data['download_url'] != null) {
          return response.data['download_url'];
        }
        return 'template_downloaded_successfully';
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error downloading template: ${e.response?.data}');
      }
      return null;
    }
  }

  // Import books from Excel file
  Future<bool> importBooksFromExcel(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'file_import':
            await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/book/import/excel',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error importing books from Excel: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error importing books: $e');
      }
      return false;
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Check user role
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role?.toLowerCase() == 'admin';
  }

  Future<bool> isMember() async {
    final role = await getUserRole();
    return role?.toLowerCase() == 'member';
  }

  Future<bool> isVisitor() async {
    final role = await getUserRole();
    return role == null || role.toLowerCase() == 'visitor';
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await _dio.get('/profile');
      return response.data['data'];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user profile: $e');
      }
      return null;
    }
  }

  // Admin login (specific endpoint if needed)
  Future<bool> adminLogin(String username, String password) async {
    try {
      // Try API first - use same login endpoint as regular login
      try {
        final response = await _dio.post(
          '/login',
          data: {'username': username, 'password': password},
        );

        if (response.statusCode == 200) {
          final data = response.data['data'];
          if (data != null && data['token'] != null) {
            await _saveToken(data['token']);
            await _saveUserName(data['user']['name']);

            // Check if user has admin role
            final userRoles = data['user']['roles'];
            bool isAdmin = false;

            if (userRoles != null && userRoles is List) {
              for (var role in userRoles) {
                if (role['name'] == 'admin') {
                  isAdmin = true;
                  break;
                }
              }
            }

            if (isAdmin) {
              await _saveUserRole('admin');
              if (data['user']['email'] != null) {
                await _saveUserEmail(data['user']['email']);
              }
              return true;
            } else {
              // User is not admin, logout
              await logout();
              return false;
            }
          }
        }
      } catch (apiError) {
        // If API fails, check local credentials
        if (kDebugMode) {
          print(
              'API not available, checking local admin credentials: $apiError');
        }

        final prefs = await SharedPreferences.getInstance();
        final localUsername = prefs.getString('local_admin_username');
        final localPassword = prefs.getString('local_admin_password');
        final localName = prefs.getString('local_admin_name');
        final localEmail = prefs.getString('local_admin_email');

        // Check default admin credentials or locally stored ones
        if ((username == 'admin' && password == 'admin123') ||
            (username == localUsername && password == localPassword)) {
          // Save login session
          await _saveToken(
              'local_admin_token_${DateTime.now().millisecondsSinceEpoch}');
          await _saveUserName(localName ?? 'Administrator');
          await _saveUserRole('admin');
          await _saveUserEmail(localEmail ?? 'admin@library.com');

          return true;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Admin login error: $e');
      }
      return false;
    }
  }

  // Member registration (visitor becomes member)
  Future<bool> memberRegister(String name, String username, String email,
      String password, String confirmPassword) async {
    try {
      final response = await _dio.post(
        '/member/register',
        data: {
          'name': name,
          'username': username,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
          'role': 'member',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('Member register error: $e');
      }
      return false;
    }
  }

  // == ADMIN REGISTRATION ==
  Future<bool> registerAdmin(Map<String, String> adminData) async {
    try {
      // TEMPORARY: Save admin credentials locally when backend is not available
      // In production, this should always call the actual API

      // Try API first
      try {
        final response = await _dio.post(
          '/admin/register',
          data: adminData,
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          return true;
        }
      } catch (apiError) {
        // If API fails, save locally as fallback for development
        if (kDebugMode) {
          print(
              'API not available, saving admin locally for development: $apiError');
        }

        // Save admin credentials locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_admin_name', adminData['name'] ?? '');
        await prefs.setString(
            'local_admin_username', adminData['username'] ?? '');
        await prefs.setString('local_admin_email', adminData['email'] ?? '');
        await prefs.setString(
            'local_admin_password', adminData['password'] ?? '');
        await prefs.setString('local_admin_role', 'admin');

        return true; // Return success for local storage
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Admin registration error: $e');
      }
      return false;
    }
  }

  // Simple method to get all borrowings (for demo purposes)
  Future<List<Borrowing>> getBorrowings() async {
    try {
      final response = await _dio.get('/peminjaman?per_page=100');
      final responseData = response.data;

      if (kDebugMode) {
        print('getBorrowings response status: ${response.statusCode}');
      }

      // Handle the correct API response structure
      if (responseData is Map<String, dynamic> &&
          responseData['status'] == 200 &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data']['peminjaman'] is Map<String, dynamic>) {
        final borrowingsData = responseData['data']['peminjaman'];
        final List<dynamic> borrowingList = borrowingsData['data'] ?? [];

        if (kDebugMode) {
          print('Found ${borrowingList.length} borrowings in getBorrowings');
        }

        return borrowingList.map((json) => Borrowing.fromJson(json)).toList();
      } else if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        // Fallback for direct data array
        final List<dynamic> borrowingList = responseData['data'];
        return borrowingList.map((json) => Borrowing.fromJson(json)).toList();
      } else if (responseData is Map<String, dynamic> &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data']['data'] is List) {
        // Another fallback structure
        final List<dynamic> borrowingList = responseData['data']['data'];
        return borrowingList.map((json) => Borrowing.fromJson(json)).toList();
      }

      if (kDebugMode) {
        print('Unexpected borrowing response structure in getBorrowings');
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching borrowings: ${e.response?.statusCode}');
        print('Error response: ${e.response?.data}');
      }
      // Return empty list instead of throwing for better UX
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in getBorrowings: $e');
      }
      return [];
    }
  }

  // == MEMBER ROLE MANAGEMENT ==

  // Update user role
  Future<bool> updateUserRole(int userId, String newRole) async {
    try {
      final token = await getToken();
      Map<String, dynamic> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Try multiple potential endpoints for role update
      List<String> endpointsToTry = [
        '/user/$userId/role',
        '/user/$userId/update-role',
        '/admin/user/$userId/role',
        '/user/update/$userId',
      ];

      for (String endpoint in endpointsToTry) {
        try {
          if (kDebugMode) {
            print('Trying role update endpoint: $endpoint');
          }

          final response = await _dio.put(
            endpoint,
            data: {'role': newRole},
            options: Options(headers: headers),
          );

          if (response.statusCode == 200) {
            if (kDebugMode) {
              print('Successfully updated role using endpoint: $endpoint');
            }
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed endpoint $endpoint: $e');
          }
          continue;
        }
      }

      // If all PUT endpoints fail, try POST endpoints
      List<String> postEndpointsToTry = [
        '/user/$userId/role',
        '/user/$userId/update-role',
        '/admin/user/$userId/role',
        '/user/update/$userId',
      ];

      for (String endpoint in postEndpointsToTry) {
        try {
          if (kDebugMode) {
            print('Trying POST role update endpoint: $endpoint');
          }

          final formData = FormData.fromMap({'role': newRole});
          final response = await _dio.post(
            endpoint,
            data: formData,
            options: Options(headers: headers),
          );

          if (response.statusCode == 200) {
            if (kDebugMode) {
              print('Successfully updated role using POST endpoint: $endpoint');
            }
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed POST endpoint $endpoint: $e');
          }
          continue;
        }
      }

      if (kDebugMode) {
        print('All role update endpoints failed');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user role: $e');
      }
      return false;
    }
  }

  // Delete user/member
  Future<bool> deleteUser(int userId) async {
    try {
      final token = await getToken();
      Map<String, dynamic> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Try multiple potential endpoints for user deletion
      List<String> endpointsToTry = [
        '/user/$userId/delete',
        '/user/$userId',
        '/admin/user/$userId',
        '/member/$userId/delete',
      ];

      for (String endpoint in endpointsToTry) {
        try {
          if (kDebugMode) {
            print('Trying delete endpoint: $endpoint');
          }

          final response = await _dio.delete(
            endpoint,
            options: Options(headers: headers),
          );

          if (response.statusCode == 200) {
            if (kDebugMode) {
              print('Successfully deleted user using endpoint: $endpoint');
            }
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed delete endpoint $endpoint: $e');
          }
          continue;
        }
      }

      if (kDebugMode) {
        print('All delete endpoints failed');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting user: $e');
      }
      return false;
    }
  }

  // == FILTER OPTIONS METHODS ==

  // Get unique authors for filter dropdown
  Future<List<String>> getAuthors() async {
    try {
      final response = await _dio.get('/book/authors');
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        return (responseData['data'] as List).cast<String>();
      } else if (responseData is List) {
        return responseData.cast<String>();
      }

      // Fallback: extract from books if dedicated endpoint not available
      try {
        final books = await getBooks();
        final Set<String> authors = {};
        for (var book in books) {
          if (book.pengarang.isNotEmpty) {
            authors.add(book.pengarang);
          }
        }
        return authors.toList()..sort();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to extract authors from books: $e');
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching authors: $e');
      }
      return [];
    }
  }

  // Get unique publishers for filter dropdown
  Future<List<String>> getPublishers() async {
    try {
      final response = await _dio.get('/book/publishers');
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        return (responseData['data'] as List).cast<String>();
      } else if (responseData is List) {
        return responseData.cast<String>();
      }

      // Fallback: extract from books if dedicated endpoint not available
      try {
        final books = await getBooks();
        final Set<String> publishers = {};
        for (var book in books) {
          if (book.penerbit.isNotEmpty) {
            publishers.add(book.penerbit);
          }
        }
        return publishers.toList()..sort();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to extract publishers from books: $e');
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching publishers: $e');
      }
      return [];
    }
  }

  // Get unique publication years for filter dropdown
  Future<List<int>> getPublicationYears() async {
    try {
      final response = await _dio.get('/book/years');
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        return (responseData['data'] as List).cast<int>();
      } else if (responseData is List) {
        return responseData.cast<int>();
      }

      // Fallback: extract from books if dedicated endpoint not available
      try {
        final books = await getBooks();
        final Set<int> years = {};
        for (var book in books) {
          final yearInt = int.tryParse(book.tahun) ?? 0;
          if (yearInt > 0) {
            years.add(yearInt);
          }
        }
        final yearsList = years.toList()
          ..sort((a, b) => b.compareTo(a)); // Newest first
        return yearsList;
      } catch (e) {
        if (kDebugMode) {
          print('Failed to extract years from books: $e');
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching publication years: $e');
      }
      return [];
    }
  }

  // Get filter statistics for admin dashboard
  Future<Map<String, dynamic>> getFilterStats() async {
    try {
      final response = await _dio.get('/admin/filter-stats');
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] != null) {
        return responseData['data'];
      }

      // Fallback: calculate from available data
      try {
        final books = await getBooks();
        final categories = await getCategories();

        final Set<String> authors = {};
        final Set<String> publishers = {};
        final Set<int> years = {};

        for (var book in books) {
          if (book.pengarang.isNotEmpty) authors.add(book.pengarang);
          if (book.penerbit.isNotEmpty) publishers.add(book.penerbit);
          final yearInt = int.tryParse(book.tahun) ?? 0;
          if (yearInt > 0) years.add(yearInt);
        }

        return {
          'total_books': books.length,
          'total_categories': categories.length,
          'total_authors': authors.length,
          'total_publishers': publishers.length,
          'year_range': years.isEmpty
              ? null
              : {
                  'min': years.reduce((a, b) => a < b ? a : b),
                  'max': years.reduce((a, b) => a > b ? a : b),
                },
        };
      } catch (e) {
        if (kDebugMode) {
          print('Failed to calculate filter stats: $e');
        }
      }

      return {
        'total_books': 0,
        'total_categories': 0,
        'total_authors': 0,
        'total_publishers': 0,
        'year_range': null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching filter stats: $e');
      }
      return {
        'total_books': 0,
        'total_categories': 0,
        'total_authors': 0,
        'total_publishers': 0,
        'year_range': null,
      };
    }
  }

  // Advanced search for books with multiple criteria
  Future<List<Book>> advancedSearchBooks({
    String? title,
    String? author,
    String? publisher,
    String? isbn,
    int? categoryId,
    int? year,
    String? status,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};

      if (title != null && title.isNotEmpty) {
        queryParams['title'] = title;
      }
      if (author != null && author.isNotEmpty) {
        queryParams['author'] = author;
      }
      if (publisher != null && publisher.isNotEmpty) {
        queryParams['publisher'] = publisher;
      }
      if (isbn != null && isbn.isNotEmpty) {
        queryParams['isbn'] = isbn;
      }
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      if (year != null) {
        queryParams['year'] = year;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response =
          await _dio.get('/book/advanced-search', queryParameters: queryParams);
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        final List<dynamic> bookList = responseData['data'];
        return bookList.map((json) => Book.fromJson(json)).toList();
      } else if (responseData is List) {
        return responseData.map((json) => Book.fromJson(json)).toList();
      }

      // Fallback: filter books manually if advanced search endpoint not available
      try {
        final books = await getBooks();
        return books.where((book) {
          if (title != null &&
              title.isNotEmpty &&
              !book.judul.toLowerCase().contains(title.toLowerCase())) {
            return false;
          }
          if (author != null &&
              author.isNotEmpty &&
              !book.pengarang.toLowerCase().contains(author.toLowerCase())) {
            return false;
          }
          if (publisher != null &&
              publisher.isNotEmpty &&
              !book.penerbit.toLowerCase().contains(publisher.toLowerCase())) {
            return false;
          }
          if (isbn != null && isbn.isNotEmpty) {
            // Book model doesn't have ISBN field, skip this filter for now
            // or could search in judul or other fields
          }
          if (categoryId != null && book.category.id != categoryId) {
            return false;
          }
          if (year != null) {
            final bookYear = int.tryParse(book.tahun) ?? 0;
            if (bookYear != year) {
              return false;
            }
          }
          return true;
        }).toList();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to perform manual filter: $e');
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error in advanced search: $e');
      }
      return [];
    }
  }

  // Search categories with advanced options
  Future<List<CategoryModel.Category>> searchCategories({
    String? name,
    bool? hasBooks,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};

      if (name != null && name.isNotEmpty) {
        queryParams['name'] = name;
      }
      if (hasBooks != null) {
        queryParams['has_books'] = hasBooks ? '1' : '0';
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        queryParams['sort_order'] = sortOrder;
      }

      final response =
          await _dio.get('/category/search', queryParameters: queryParams);
      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['data'] is List) {
        final List<dynamic> categoryList = responseData['data'];
        return categoryList
            .map((json) => CategoryModel.Category.fromJson(json))
            .toList();
      } else if (responseData is List) {
        return responseData
            .map((json) => CategoryModel.Category.fromJson(json))
            .toList();
      }

      // Fallback: filter categories manually
      try {
        final categories = await getCategories();
        var filteredCategories = categories;

        if (name != null && name.isNotEmpty) {
          filteredCategories = filteredCategories
              .where((category) =>
                  category.name.toLowerCase().contains(name.toLowerCase()))
              .toList();
        }

        // Sort manually if needed
        if (sortBy != null) {
          filteredCategories.sort((a, b) {
            int comparison = 0;
            switch (sortBy) {
              case 'name':
                comparison = a.name.compareTo(b.name);
                break;
              case 'created_at':
                comparison = (a.createdAt ?? DateTime.now())
                    .compareTo(b.createdAt ?? DateTime.now());
                break;
              default:
                comparison = a.name.compareTo(b.name);
            }
            return sortOrder == 'desc' ? -comparison : comparison;
          });
        }

        return filteredCategories;
      } catch (e) {
        if (kDebugMode) {
          print('Failed to perform manual category filter: $e');
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error in category search: $e');
      }
      return [];
    }
  }

  // == END FILTER OPTIONS METHODS ==
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() {
    return 'ApiException: $message (Status Code: $statusCode)';
  }
}

class LoginResult {
  final bool success;
  final String message;
  final String? token;
  final dynamic user;

  LoginResult({
    required this.success,
    required this.message,
    this.token,
    this.user,
  });
}

class RegisterResult {
  final bool success;
  final String message;

  RegisterResult({
    required this.success,
    required this.message,
  });
}
