# Template Excel untuk Import Buku

## Format yang Disarankan:

Buat file Excel (.xlsx) dengan kolom-kolom berikut:

| id  | title       | author  | publisher | isbn      | category_id | publication_year | description    | cover_image                  |
| --- | ----------- | ------- | --------- | --------- | ----------- | ---------------- | -------------- | ---------------------------- |
| 1   | Contoh Buku | Penulis | Penerbit  | 123456789 | 1           | 2023             | Deskripsi buku | http://example.com/cover.jpg |

## Penjelasan Kolom:

- **id**: ID unik buku (integer)
- **title**: Judul buku (string, wajib)
- **author**: Nama penulis (string, wajib)
- **publisher**: Nama penerbit (string)
- **isbn**: Nomor ISBN (string)
- **category_id**: ID kategori (integer, sesuai dengan kategori yang ada)
- **publication_year**: Tahun terbit (integer)
- **description**: Deskripsi buku (string)
- **cover_image**: URL gambar sampul (string)

## Kategori yang Tersedia:

Gunakan ID kategori yang valid sesuai dengan data yang ada di sistem:

- 1: Fiction
- 2: Non-Fiction
- 3: Science
- 4: Technology
- 5: History
- 6: Biography
- 7: Education
- 8: Children

## Tips:

1. Pastikan kolom pertama adalah header
2. Data dimulai dari baris kedua
3. Gunakan format .xlsx (bukan .xls)
4. Pastikan category_id sesuai dengan kategori yang ada
5. Field title dan author wajib diisi
