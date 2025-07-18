# Fitur Filter dan Search untuk Admin - Perpustakaan

## Ringkasan Fitur yang Ditambahkan

Saya telah menambahkan fitur filter dan search yang komprehensif untuk admin dalam mengelola buku dan kategori buku.

## 🔍 Fitur Filter dan Search untuk Buku

### 1. **API Service Enhancement**

File: `lib/api/api_service.dart`

#### Enhanced `getBooksPaginated()` Method:

```dart
Future<Map<String, dynamic>> getBooksPaginated({
  int page = 1,
  int perPage = 10,
  String? search,        // Search dalam judul, pengarang
  int? categoryId,       // Filter berdasarkan kategori
  String? author,        // Filter berdasarkan pengarang
  String? publisher,     // Filter berdasarkan penerbit
  String? isbn,          // Filter berdasarkan ISBN
  String? sortBy,        // Urutkan berdasarkan (judul, pengarang, penerbit, tahun)
  String? sortOrder,     // Urutan (asc, desc)
  int? year,             // Filter berdasarkan tahun terbit
  String? status,        // Filter berdasarkan status (tersedia, dipinjam)
})
```

#### Filter Options Methods:

- `getAuthors()` - Mendapatkan daftar pengarang unik
- `getPublishers()` - Mendapatkan daftar penerbit unik
- `getPublicationYears()` - Mendapatkan daftar tahun terbit
- `getFilterStats()` - Statistik filter untuk dashboard
- `advancedSearchBooks()` - Pencarian lanjutan dengan kriteria multiple

### 2. **UI Enhancement**

File: `lib/screens/admin/admin_book_management_screen.dart`

#### Filter Components:

1. **Search Bar** - Pencarian teks dalam judul dan pengarang
2. **Category Dropdown** - Filter berdasarkan kategori buku
3. **Author Dropdown** - Filter berdasarkan pengarang
4. **Publisher Dropdown** - Filter berdasarkan penerbit
5. **Year Dropdown** - Filter berdasarkan tahun terbit
6. **Sort Options** - Pengurutan berdasarkan berbagai kriteria
7. **Reset Button** - Membersihkan semua filter

#### Pagination Support:

- Navigasi halaman dengan info jumlah data
- Pengaturan jumlah item per halaman
- Info total data dan halaman saat ini

## 📚 Fitur Filter dan Search untuk Kategori

### 1. **API Service Enhancement**

#### Enhanced `getCategoriesPaginated()` Method:

```dart
Future<Map<String, dynamic>> getCategoriesPaginated({
  int page = 1,
  int perPage = 10,
  String? search,        // Search dalam nama kategori
  String? sortBy,        // Urutkan berdasarkan (name, created_at, books_count)
  String? sortOrder,     // Urutan (asc, desc)
  bool? hasBooks,        // Filter kategori yang memiliki buku atau tidak
})
```

#### Additional Category Methods:

- `searchCategories()` - Pencarian kategori dengan opsi lanjutan

### 2. **UI Enhancement**

File: `lib/screens/admin/admin_category_management_screen.dart`

#### Filter Components:

1. **Search Bar** - Pencarian nama kategori
2. **Sort Options** - Pengurutan berdasarkan nama atau tanggal dibuat
3. **Has Books Filter** - Filter kategori yang memiliki buku atau tidak
4. **Reset Button** - Membersihkan semua filter

## 🎯 Keunggulan Fitur

### 1. **Fallback Strategy**

- Jika endpoint API khusus tidak tersedia, sistem akan menggunakan data yang ada
- Ekstraksi data dari endpoint yang tersedia (contoh: pengarang dari data buku)
- Graceful degradation untuk UX yang lebih baik

### 2. **Smart Filtering**

- Multiple filter dapat dikombinasikan
- Real-time filtering saat user mengubah pilihan
- Pagination tetap berfungsi dengan filter aktif

### 3. **User Experience**

- Loading indicators yang informatif
- Error handling yang user-friendly
- Clear visual feedback untuk filter aktif
- Reset option untuk membersihkan filter

### 4. **Performance Optimization**

- Lazy loading untuk dropdown options
- Efficient API calls dengan pagination
- Caching untuk filter options

## 📋 Filter Options yang Tersedia

### Untuk Buku:

| Filter     | Tipe     | Deskripsi                                      |
| ---------- | -------- | ---------------------------------------------- |
| Search     | Text     | Pencarian dalam judul dan pengarang            |
| Kategori   | Dropdown | Filter berdasarkan kategori buku               |
| Pengarang  | Dropdown | Filter berdasarkan pengarang                   |
| Penerbit   | Dropdown | Filter berdasarkan penerbit                    |
| Tahun      | Dropdown | Filter berdasarkan tahun terbit                |
| Status     | Dropdown | Filter berdasarkan ketersediaan                |
| Sort By    | Dropdown | Pengurutan (judul, pengarang, penerbit, tahun) |
| Sort Order | Dropdown | Urutan (A-Z, Z-A)                              |

### Untuk Kategori:

| Filter     | Tipe     | Deskripsi                         |
| ---------- | -------- | --------------------------------- |
| Search     | Text     | Pencarian nama kategori           |
| Has Books  | Dropdown | Kategori dengan/tanpa buku        |
| Sort By    | Dropdown | Pengurutan (nama, tanggal dibuat) |
| Sort Order | Dropdown | Urutan (A-Z, Z-A)                 |

## 🚀 Cara Penggunaan

### 1. **Akses Filter**

- Masuk sebagai Admin
- Navigasi ke "Manajemen Buku" atau "Manajemen Kategori"
- Panel filter terletak di bagian atas halaman

### 2. **Menggunakan Filter**

- Pilih kriteria filter dari dropdown yang tersedia
- Ketik kata kunci di search bar
- Filter akan otomatis diterapkan
- Gunakan tombol "Reset" untuk membersihkan semua filter

### 3. **Pagination**

- Navigasi antar halaman menggunakan tombol "Sebelumnya"/"Selanjutnya"
- Info halaman dan total data ditampilkan
- Filter tetap aktif saat navigasi halaman

## 🔧 Technical Implementation

### 1. **Backend Integration**

- Multiple endpoint fallback strategy
- Flexible parameter handling
- Error handling dan fallback data

### 2. **State Management**

- Efficient state updates
- Loading state management
- Filter state persistence

### 3. **UI Components**

- Responsive design
- Accessible form controls
- Clear visual hierarchy

## 📈 Benefits

1. **Improved Productivity** - Admin dapat menemukan data lebih cepat
2. **Better Organization** - Filtering membantu mengatur data
3. **Enhanced UX** - Interface yang intuitif dan responsif
4. **Scalability** - Pagination mendukung dataset besar
5. **Flexibility** - Multiple filter combinations

Fitur ini siap digunakan dan akan meningkatkan efisiensi pengelolaan perpustakaan secara signifikan!
