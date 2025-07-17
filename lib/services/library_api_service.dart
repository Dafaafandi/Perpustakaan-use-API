import 'package:dio/dio.dart';
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart' as CategoryModel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LibraryApiService {
  final Dio _dio;
  static const String baseUrl = 'http://perpus-api.mamorasoft.com/api';

  LibraryApiService._()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(milliseconds: 15000),
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
            await _clearAuthData();
          }
          return handler.next(error);
        },
      ),
    );
  }

  static final LibraryApiService _instance = LibraryApiService._();
  factory LibraryApiService() => _instance;

  // Auth methods
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
  }

  Future<bool> login(String username, String password) async {
    try {
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
        final responseData = response.data;

        // Handle API response structure: {"status": 200, "data": {...}}
        if (responseData != null && responseData['status'] == 200) {
          final data = responseData['data'];

          if (data != null && data['token'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', data['token']);

            // Save user info if available
            if (data['user'] != null) {
              await prefs.setInt('user_id', data['user']['id'] ?? 0);
              await prefs.setString(
                  'user_name', data['user']['name'] ?? 'User');
              await prefs.setString('user_email', data['user']['email'] ?? '');

              // Check user roles array for admin/member
              if (data['user']['roles'] != null &&
                  data['user']['roles'] is List) {
                String userRole = 'member'; // default
                for (var role in data['user']['roles']) {
                  if (role['name'] == 'admin') {
                    userRole = 'admin';
                    break;
                  }
                }
                await prefs.setString('user_role', userRole);
              } else {
                await prefs.setString('user_role', 'member');
              }
            }

            return true;
          }
        }
      }

      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Login error: ${e.response?.statusCode}');
        print('Response: ${e.response?.data}');
      }

      // Check for specific API error responses
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      } else if (e.response?.statusCode == 409) {
        throw Exception('Username atau password tidak valid');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Username atau password salah');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Koneksi timeout, periksa internet Anda');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Tidak dapat terhubung ke server');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected login error: $e');
      }
      throw Exception('Terjadi kesalahan yang tidak terduga');
    }
  }

  Future<bool> register(Map<String, String> userData) async {
    try {
      final formData = FormData.fromMap(userData);

      final response = await _dio.post(
        '/register',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Register error: ${e.response?.data}');
      }
      return false;
    }
  }

  Future<void> logout() async {
    await _clearAuthData();
  }

  // Book methods
  Future<List<Book>> getAllBooks({int page = 1, int perPage = 100}) async {
    try {
      final response = await _dio.get('/book/all?page=$page&per_page=$perPage');
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is List) {
          final List<dynamic> bookList = responseData['data'];
          return bookList.map((json) => Book.fromJson(json)).toList();
        } else if (responseData['data'] is Map<String, dynamic> &&
            responseData['data']['data'] is List) {
          final List<dynamic> bookList = responseData['data']['data'];
          return bookList.map((json) => Book.fromJson(json)).toList();
        }
      }

      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching books: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil data buku');
    }
  }

  Future<Book> getBookById(int id) async {
    try {
      final response = await _dio.get('/book/$id');
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic>) {
          return Book.fromJson(responseData['data']);
        } else if (responseData['book'] is Map<String, dynamic>) {
          return Book.fromJson(responseData['book']);
        } else if (responseData['id'] != null) {
          return Book.fromJson(responseData);
        }
      }

      throw Exception('Struktur data tidak valid');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching book: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil detail buku');
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
    }
  }

  Future<bool> deleteBook(int id) async {
    try {
      final response = await _dio.delete('/book/$id/delete');
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error deleting book: ${e.response?.data}');
      }
      return false;
    }
  }

  Future<bool> addBook(Map<String, String> bookData) async {
    try {
      final formData = FormData.fromMap(bookData);

      final response = await _dio.post(
        '/book/create', // You might need to adjust this endpoint
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

  // Category methods
  Future<List<CategoryModel.Category>> getAllCategories() async {
    try {
      final response = await _dio.get('/category/all/all');
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is List) {
          final List<dynamic> categoryList = responseData['data'];
          return categoryList
              .map((json) => CategoryModel.Category.fromJson(json))
              .toList();
        } else if (responseData['categories'] is List) {
          final List<dynamic> categoryList = responseData['categories'];
          return categoryList
              .map((json) => CategoryModel.Category.fromJson(json))
              .toList();
        }
      } else if (responseData is List) {
        return responseData
            .map((json) => CategoryModel.Category.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching categories: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil data kategori');
    }
  }

  Future<CategoryModel.Category> getCategoryById(int id) async {
    try {
      final response = await _dio.get('/category/$id');
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] is Map<String, dynamic>) {
          return CategoryModel.Category.fromJson(responseData['data']);
        } else if (responseData['category'] is Map<String, dynamic>) {
          return CategoryModel.Category.fromJson(responseData['category']);
        } else if (responseData['id'] != null) {
          return CategoryModel.Category.fromJson(responseData);
        }
      }

      throw Exception('Struktur data tidak valid');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching category: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil detail kategori');
    }
  }

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
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      final response = await _dio.delete('/category/$id/delete');
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error deleting category: ${e.response?.data}');
      }
      return false;
    }
  }

  Future<bool> addCategory(String categoryName) async {
    try {
      final formData = FormData.fromMap({
        'nama_kategori': categoryName,
      });

      final response = await _dio.post(
        '/category/create', // You might need to adjust this endpoint
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return response.statusCode == 200 || response.statusCode == 201;
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

  // Peminjaman (Borrowing) methods
  Future<List<dynamic>> getAllBorrowings(
      {int page = 1, int perPage = 1000}) async {
    try {
      // Try using the same endpoint as admin first for consistency
      try {
        if (kDebugMode) {
          print('Trying /peminjaman/all endpoint (same as admin)...');
        }

        final response = await _dio.get('/peminjaman/all');
        final responseData = response.data;

        if (kDebugMode) {
          print('getAllBorrowings (/all) response: ${response.statusCode}');
        }

        if (responseData is Map<String, dynamic> &&
            responseData['status'] == 200 &&
            responseData['data'] is Map<String, dynamic>) {
          // Handle different response structures from /all endpoint
          List<dynamic> allBorrowings = [];

          if (responseData['data']['peminjaman'] is List) {
            allBorrowings = responseData['data']['peminjaman'];
          } else if (responseData['data'] is List) {
            allBorrowings = responseData['data'];
          }

          if (kDebugMode) {
            print(
                'Successfully fetched ${allBorrowings.length} borrowings from /all endpoint');
          }

          return allBorrowings;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to use /all endpoint, falling back to paginated: $e');
        }
      }

      // Fallback to paginated endpoint if /all fails
      if (kDebugMode) {
        print('Using paginated endpoint /peminjaman...');
      }

      List<dynamic> allBorrowings = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response =
            await _dio.get('/peminjaman?page=$currentPage&per_page=$perPage');
        final responseData = response.data;

        if (kDebugMode) {
          print(
              'getAllBorrowings response page $currentPage: ${response.statusCode}');
        }

        if (responseData is Map<String, dynamic> &&
            responseData['status'] == 200 &&
            responseData['data'] is Map<String, dynamic> &&
            responseData['data']['peminjaman'] is Map<String, dynamic>) {
          final borrowingsData = responseData['data']['peminjaman'];
          final List<dynamic> borrowingList = borrowingsData['data'] ?? [];
          final int currentPageNum = borrowingsData['current_page'] ?? 1;
          final int lastPage = borrowingsData['last_page'] ?? 1;
          final int total = borrowingsData['total'] ?? 0;

          if (kDebugMode) {
            print(
                'Found ${borrowingList.length} borrowings on page $currentPage');
            print(
                'Current page: $currentPageNum, Last page: $lastPage, Total: $total');
          }

          allBorrowings.addAll(borrowingList);

          // Check if there are more pages
          hasMorePages = currentPageNum < lastPage;
          currentPage++;

          // Safety check to prevent infinite loops
          if (currentPage > 100) {
            if (kDebugMode) {
              print(
                  'Warning: Stopped pagination at page 100 to prevent infinite loop');
            }
            break;
          }
        } else if (responseData is Map<String, dynamic> &&
            responseData['data'] is List) {
          // Fallback for direct data array (usually means no pagination)
          allBorrowings.addAll(responseData['data']);
          hasMorePages = false;
        } else if (responseData is Map<String, dynamic> &&
            responseData['data'] is Map<String, dynamic> &&
            responseData['data']['data'] is List) {
          // Another fallback structure (usually means no pagination)
          allBorrowings.addAll(responseData['data']['data']);
          hasMorePages = false;
        } else {
          if (kDebugMode) {
            print(
                'Unexpected borrowing response structure in getAllBorrowings on page $currentPage');
          }
          hasMorePages = false;
        }
      }

      if (kDebugMode) {
        print('Total borrowings fetched: ${allBorrowings.length}');
      }

      return allBorrowings;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error fetching borrowings: ${e.response?.statusCode}');
        print('Error response: ${e.response?.data}');
      }
      throw Exception('Gagal mengambil data peminjaman');
    }
  }

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

  Future<bool> createBorrowing(
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

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error creating borrowing: ${e.response?.data}');
      }
      return false;
    }
  }

  // Return a book - FUNGSI BARU UNTUK MENGEMBALIKAN BUKU
  Future<bool> returnBook(int peminjamanId) async {
    try {
      // Kita panggil endpoint 'accept' karena ia mengatur status ke '2' (Dikembalikan)
      final response = await _dio.get('/peminjaman/book/$peminjamanId/accept');

      if (kDebugMode) {
        print('Returning book with ID: $peminjamanId using accept endpoint');
        print('Return book response status: ${response.statusCode}');
        print('Return book response data: ${response.data}');
      }

      // Ingat: Konsekuensinya adalah stok buku tidak kembali bertambah.
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error returning book: ${e.response?.data}');
        print('Error status: ${e.response?.statusCode}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error returning book: $e');
      }
      return false;
    }
  }

  // Export methods
  Future<String?> exportBooksToPdf() async {
    try {
      final response = await _dio.get('/book/export/pdf');

      if (response.statusCode == 200) {
        return 'PDF exported successfully';
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error exporting to PDF: ${e.response?.data}');
      }
      return null;
    }
  }

  Future<String?> exportBooksToExcel() async {
    try {
      final response = await _dio.get('/book/export/excel');

      if (response.statusCode == 200) {
        return 'Excel exported successfully';
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error exporting to Excel: ${e.response?.data}');
      }
      return null;
    }
  }

  Future<String?> downloadTemplate() async {
    try {
      final response = await _dio.get('/book/download/template');

      if (response.statusCode == 200) {
        return 'Template downloaded successfully';
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Error downloading template: ${e.response?.data}');
      }
      return null;
    }
  }

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
        print('Error importing from Excel: ${e.response?.data}');
      }
      return false;
    }
  }

  // User profile methods
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final userName = prefs.getString('user_name');
      final userEmail = prefs.getString('user_email');

      if (userId != null) {
        return {
          'id': userId,
          'name': userName,
          'email': userEmail,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user profile: $e');
      }
      return null;
    }
  }

  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_name');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user name: $e');
      }
      return null;
    }
  }

  Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_id');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user ID: $e');
      }
      return null;
    }
  }
}
