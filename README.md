# SiMikro - Media Pembelajaran Digital

SiMikro adalah aplikasi Android yang dirancang sebagai media pembelajaran digital untuk penggunaan bahasa pemrograman C pada sistem mikrokontroler. Aplikasi ini dibangun menggunakan Jetpack Compose dan mengikuti prinsip Material Design 3 dengan UI/UX yang modern dan responsif.

# SiMikro — Panduan Pengembang Lengkap

Dokumentasi ini ditujukan untuk developer yang ingin memahami, memodifikasi, atau berkontribusi pada aplikasi SiMikro (Android, Jetpack Compose). README ini sangat detail: menjelaskan struktur kode, cara mengganti logo (launcher + in-app + assets), pengaturan locale (id/en/jv), AssetHelper dan mekanisme bundling offline, FileProvider/SAF, proses build & signing, QA scripts, dan panduan kontribusi.

> Lokasi kerja utama: `app/` (kode sumber Android) — gunakan path yang disebutkan di bawah untuk navigasi cepat.

---

## Daftar Isi
- Tujuan dokumen
- Struktur proyek dan file penting
- Cara mengganti logo (launcher, in-app, settings/branding)
- Asset materi: struktur, konvensi, dan manipulasi
- I18n (locales) — di mana dan bagaimana berubah
- Komponen penting: `AssetHelper`, `AssetImage`, `SiMikroNavigation`
- FileProvider & sharing (share + SAF save)
- Offline bundles: install dan manajemen
- Build, signing, lint, dan release checklist
- QA scripts dan integrasi ke CI
- Testing manual (smoke tests)
- Kontribusi, code style, dan lisensi

---

## Tujuan dokumen
Memberi referensi teknis lengkap sehingga developer lain dapat:
- Mengganti icon/logo aplikasi dan semua referensinya.
- Menambah/mengubah materi di `assets/` dan memastikan konsistensi.
- Memahami mekanik i18n (id/jv/en) dan menambah terjemahan.
- Memakai AssetHelper untuk bundling offline.
- Menjalankan build, lint, dan proses rilis dengan aman.

---

## Struktur proyek (ringkas, path penting)
- `app/`
	- `src/main/java/com/example/simikro/`
		- `utils/AssetHelper.kt` — helper asset, bundle installer.
		- `components/AssetImage.kt` — image loader + retry placeholder.
		- `navigation/SiMikroNavigation.kt` — rute & transisi AnimatedContent.
		- `ui/` — screens: `MateriScreen`, `MateriDetailScreen`, `SettingsScreen`, komponen (AssetImage, LoadingSpinner)
		- `MainActivity.kt` — memasang locale & theme sebelum `setContent`.
	- `src/main/res/`
		- `drawable/` — vector/images UI (e.g. `ic_image_placeholder.xml`).
		- `mipmap-*/` — app launcher icons (adaptive recommended).
		- `values/`, `values-en/`, `values-jv/` — string resources per-locale.
		- `xml/file_paths.xml` — FileProvider path config.
	- `src/main/assets/`
		- `materi/` — konten berbasis file (per-locale folder `id/`, `en/`, `jv/`).
		- `Logo/`, `Icon/`, `Dashboard/` — asset yang dipakai langsung dari assets.
- `scripts/`
	- `check_assets.py` — validasi file referensi di `materi_list.json`.
	- `diff_strings.py` — validasi kunci strings antar-locale.
- `gradle.properties.example` — contoh config signing (JANGAN commit secret ke repo).

---

## Cara mengganti logo aplikasi — sangat rinci
Langkah di bawah memastikan perubahan konsisten di seluruh aplikasi.

### 1) Launcher icon (adaptive recommended)
- Lokasi: `app/src/main/res/mipmap-anydpi-v26/` (xml adaptive) dan raster di `mipmap-hdpi/`, `mipmap-mdpi/`, `mipmap-xhdpi/`, dsb.
- Rekomendasi: buka Android Studio -> New -> Image Asset -> Adaptive and Legacy.
- Manual (jika tidak memakai Studio):
	- Ganti semua file `ic_launcher.png` & `ic_launcher_round.png` pada folder `mipmap-*`.
	- Jika ada `ic_launcher.xml` di `mipmap-anydpi-v26/`, buka xml dan update `android:foreground` / `android:background` drawable.

Periksa: `AndroidManifest.xml` (biasanya tidak perlu diubah karena default icon menunjuk ke `@mipmap/ic_launcher`).

### 2) Logo in-app (toolbar/header, splash, settings)
- Lokasi yang umum dipakai:
	- `app/src/main/res/drawable/` (vector XML atau raster `logo.png`).
	- Alternatif: `app/src/main/assets/Logo/` jika app memuat logo dari assets.

Jika Compose menggunakan `painterResource(R.drawable.ic_app_logo)`, ganti resource `ic_app_logo` di `res/drawable`:
```kotlin
Image(
	painter = painterResource(R.drawable.ic_app_logo),
	contentDescription = stringResource(R.string.app_name),
	modifier = Modifier.size(36.dp)
)
```
Langkah:
- Tambah vector (recommended) `ic_app_logo.xml` ke `res/drawable/` atau ganti `logo.png` di `res/drawable/`.
- Cari seluruh referensi: search repository for `ic_app_logo`, `Logo/`, `Salinan logo`, `painterResource(` and update accordingly.

Accessibility: selalu set `contentDescription` (string resource).

### 3) Logo yang tersimpan di `assets/Logo/`
- Lokasi: `app/src/main/assets/Logo/` — beberapa UI dapat memuat dari AssetHelper/AssetImage.
- Ganti file di folder tersebut jika UI memuat logo lewat assets.

Checklist perubahan logo
- [ ] Ganti `mipmap-*` (launcher) semua ukuran
- [ ] Ganti `res/drawable/ic_app_logo.*` (in-app)
- [ ] Ganti file di `app/src/main/assets/Logo/` bila dipakai
- [ ] Cari & update semua referensi resource/path di kode
- [ ] Jalankan `./gradlew :app:assembleDebug` dan verifikasi icon/ logo

---

## Asset materi (struktur & konvensi)
Gunakan struktur berikut untuk kemudahan i18n dan fallback:
```
app/src/main/assets/materi/
	├─ id/
	│   ├─ materi_list.json
	│   ├─ materi_001.html
	│   └─ images/
	├─ en/
	└─ jv/
```

`materi_list.json` minimal berisi daftar objek dengan fields: `id`, `title`, `description`, `file`, `image`.

Akses di kode:
- `AssetHelper.readAssetFileAsStringForLocale(context, langCode, "materi", fileName)` — helper melakukan fallback ke folder default bila file tidak ada di locale.
- Untuk WebView: gunakan base URL `file:///android_asset/materi/{lang}/` saat memanggil `loadDataWithBaseURL`.

Naming rules:
- Gunakan `snake_case`, hindari spasi dan karakter non-ASCII pada nama file.
- Simpan gambar relatif ke file HTML (mis. `images/mikro_001.png`).

---

## I18n (lokalisasi)
- Default language: Bahasa Indonesia (`res/values/strings.xml`).
- Tambahkan folders `res/values-en/` dan `res/values-jv/` untuk English dan Jawa.
- `LocaleManager` menyimpan preference `pref_lang` dan `MainActivity` memanggil `applyLocale` sebelum `setContent`.

Menambah string baru:
1. Tambah di `res/values/strings.xml` (Indonesia).
2. Jalankan `python3 scripts/diff_strings.py` untuk melihat kunci yang hilang di `values-en/` dan `values-jv/`.
3. Tambahkan terjemahan di `values-en/strings.xml` dan `values-jv/strings.xml`.

---

## Komponen penting — penjelasan teknis

### `AssetHelper.kt` (`app/src/main/java/com/example/simikro/utils/AssetHelper.kt`)
Ringkasan fungsionalitas:
- Listing assets (`getAssetFiles`, `getAssetFilesForLocale`).
- Pemeriksaan eksistensi (`assetExists`).
- Membaca konten file sebagai string (`readAssetFileAsString`, `readAssetFileAsStringForLocale`).
- Menyalin folder asset ke `filesDir/bundles/` untuk instalasi offline (`installAssetBundle`, `copyAssetFolder`, `copyAssetFile`).
- Utility: `formatFileSize`, `isValidAssetPath`.

Catatan implementasi:
- `assetExists` membuka stream via `AssetManager.open()` untuk cek, pastikan ini cepat atau dipanggil jarang.
- `installAssetBundle` melakukan copy rekursif; panggil di background thread (Dispatchers.IO) dan tampilkan progress.

### `AssetImage.kt` (komponen gambar)
- Syarat: cek dahulu `AssetHelper.assetExists`.
- Jika tidak ada: tampilkan placeholder `res/drawable/ic_image_placeholder.xml` dan sediakan tap-to-retry yang menaikkan `retryKey` (memicu Coil reload).
- Saat Error painter: tampilkan pesan error + tombol `Coba Lagi`.
- Perbarui placeholder vector jika Anda mengganti icon.

### `SiMikroNavigation.kt`
- Mengandung definisi `Screen` sealed class dan `NavHost`.
- Menggunakan `AnimatedContent` untuk transisi antar layar. Catatan:
	- Lint rule `UnusedContentLambdaTargetStateParameter` memerlukan `targetState` untuk digunakan (atau disimpan ke `_` local val) agar lint bersih.
	- `EnterTransition.with(exit)` deprecated → ganti ke `togetherWith`.

---

## FileProvider & sharing
Untuk membagikan file yang tersimpan di internal storage gunakan `FileProvider`:
- Tambahkan provider di `AndroidManifest.xml`:
```xml
<provider
		android:name="androidx.core.content.FileProvider"
		android:authorities="${applicationId}.provider"
		android:exported="false"
		android:grantUriPermissions="true">
		<meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths" />
</provider>
```
- `res/xml/file_paths.xml` contoh:
```xml
<paths xmlns:android="http://schemas.android.com/apk/res/android">
	<files-path name="internal_files" path="." />
	<cache-path name="cache" path="." />
</paths>
```
- Share Intent contoh:
```kotlin
val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
val intent = Intent(Intent.ACTION_SEND).apply {
	putExtra(Intent.EXTRA_STREAM, uri)
	addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	type = "application/pdf"
}
context.startActivity(Intent.createChooser(intent, context.getString(R.string.share)))
```

---

## Save-to-Downloads (SAF)
Gunakan `ActivityResultContracts.CreateDocument` untuk menulis ke penyimpanan publik (Downloads) tanpa permission WRITE_EXTERNAL_STORAGE di Android modern.

Compose pattern:
```kotlin
val createLauncher = rememberLauncherForActivityResult(CreateDocument("text/html")) { uri ->
	if (uri != null) {
		context.contentResolver.openOutputStream(uri)?.use { out ->
			out.write(htmlString.toByteArray())
		}
	}
}
// panggil createLauncher.launch("materi-001.html")
```

---

## Offline bundles
- Gunakan `AssetHelper.installAssetBundle(context, assetDir, bundleName, overwrite)` untuk menyalin folder asset ke `filesDir/bundles/{bundleName}`.
- Daftarkan metadata bundle di SharedPreferences/DB untuk manajemen instalasi.
- Gunakan `getInstalledBundleFile(context, bundleName, relativePath)` untuk mengakses file yang sudah diinstal.

---

## Build, signing & release checklist
1. Siapkan `gradle.properties` lokal dari `gradle.properties.example` (isi keystore path/password).
2. Pastikan `app/build.gradle.kts` menggunakan property untuk membuat `signingConfigs.release`.
3. Jalankan lint & QA scripts:
```bash
./gradlew :app:lint
python3 scripts/check_assets.py
python3 scripts/diff_strings.py
```
4. Build signed bundle (setelah mengisi `gradle.properties`):
```bash
./gradlew :app:bundleRelease
```
5. Verifikasi AAB di internal testing sebelum produksi.

Jika ingin melewati lint lama di CI sementara, lebih baik perbaiki; alternatif: buat `lint-baseline.xml`.

---

## QA scripts (gunakan di lokal / CI)
- `python3 scripts/check_assets.py` — validasi bahwa setiap file disebutkan di `materi_list.json` benar-benar ada.
- `python3 scripts/diff_strings.py` — laporkan key yang hilang antar-locale.

Integrasikan kedua skrip ini ke CI (workflow job) untuk mencegah PR yang mematahkan assets/i18n.

---

## Testing manual (smoke test)
- Install debug build ke emulator/device.
- Buka Settings -> ganti bahasa -> lihat preview -> muat ulang activity -> pastikan string berubah.
- Buka Materi -> buka HTML -> tekan Download -> Save-to-Downloads -> cek Files/Downloads.
- Gambar hilang -> placeholder muncul -> tekan "Coba Lagi" -> cek logcat (`AssetImage` logs).
- Jalankan `python3 scripts/check_assets.py`.

---

## Contributing & Code Style
- Branch: gunakan `feature/<descriptive-name>`.
- PR: sertakan perubahan UI screenshot, steps to reproduce, dan hasil `./gradlew :app:lint`.
- I18n: tambahkan key di default `values/` dulu, jalankan `scripts/diff_strings.py`.
- Jangan commit file berisi secret (keystore). Gunakan `gradle.properties` di mesin lokal atau secret manager di CI.

---

## License
Tambahkan file `LICENSE` (mis. MIT) di root jika ingin open-source. Contoh singkat MIT:
```
MIT License
...
```

---

## File quick-links (untuk reviewer cepat)
- `app/src/main/java/com/example/simikro/utils/AssetHelper.kt` — bundle & asset helpers
- `app/src/main/java/com/example/simikro/components/AssetImage.kt` — image placeholder + retry
- `app/src/main/java/com/example/simikro/navigation/SiMikroNavigation.kt` — navigation/transitions
- `app/src/main/assets/materi/` — materi sumber
- `scripts/check_assets.py`, `scripts/diff_strings.py` — QA scripts

---

Jika Anda ingin, saya bisa menambahkan ke repo:
- `CHECKLIST_RELEASE.md` (dengan langkah granular) atau
- `ISSUE_TEMPLATE.md` / `PULL_REQUEST_TEMPLATE.md` untuk membantu kontribusi, atau
- contoh `assets/materi/id/materi_001.html` + `materi_list.json` minimal.

Pilih salah satu ("checklist" / "templates" / "contoh-materi" / "tidak sekarang") dan saya akan langsung membuat file yang dipilih di repo.

---

## Kode sumber — walkthrough lengkap (potongan kode & penjelasan)
Bagian ini memuat potongan kode penting dari repository dan penjelasan teknis baris-per-baris untuk membantu developer memahami alur program.

Catatan: potongan di sini adalah rekonstruksi ringkas berdasarkan file yang ada di repo — untuk pengeditan, buka file sumber yang disebutkan.

### 1) `AssetHelper.kt` — helper asset & bundle
Contoh fungsi kunci dan penjelasannya:

```kotlin
object AssetHelper {
		fun assetExists(context: Context, filePath: String): Boolean {
				return try {
						context.assets.open(filePath).use { true }
				} catch (e: IOException) {
						false
				}
		}

		fun readAssetFileAsStringForLocale(
				context: Context,
				langCode: String?,
				directory: String,
				fileName: String
		): String? {
				val localizedPath = if (!langCode.isNullOrBlank()) "$directory/$langCode/$fileName" else null
				localizedPath?.let {
						try { return context.assets.open(it).bufferedReader().use { r -> r.readText() } }
						catch (_: IOException) { }
				}
				return try { context.assets.open("$directory/$fileName").bufferedReader().use { it.readText() } }
				catch (_: IOException) { null }
		}

		fun installAssetBundle(context: Context, assetDir: String, bundleName: String, overwrite: Boolean = false): Boolean {
				if (!isValidAssetPath(assetDir) || bundleName.isBlank()) return false
				val bundlesRoot = File(context.filesDir, "bundles")
				val targetDir = File(bundlesRoot, bundleName)
				if (targetDir.exists()) {
						if (!overwrite) return true
						targetDir.deleteRecursively()
				}
				if (!bundlesRoot.exists()) bundlesRoot.mkdirs()
				try {
						copyAssetFolder(context.assets, assetDir, targetDir)
						return true
				} catch (e: Exception) {
						return false
				}
		}
}
```

Penjelasan:
- `assetExists`: membuka stream dari `assets/` untuk memastikan file ada. Cepat tapi jangan panggil terlalu sering pada UI thread untuk file besar.
- `readAssetFileAsStringForLocale`: mencoba versi localized dulu (`/materi/id/...`) lalu fallback ke default. Berguna untuk multi-locale content.
- `installAssetBundle`: copy rekursif asset ke `filesDir/bundles/{bundleName}`; harus dijalankan di background (Dispatchers.IO) dan laporkan progress ke UI.

Implementation notes:
- `copyAssetFolder` dan `copyAssetFile` harus menangani folder kosong dan menutup InputStream/OutputStream dengan `use {}`.
- `isValidAssetPath` minimal memeriksa input kosong dan karakter berbahaya.

### 2) `AssetImage.kt` — loading gambar dari assets dengan retry
Potongan inti:

```kotlin
@Composable
fun AssetImage(assetPath: String, contentDescription: String?, modifier: Modifier = Modifier) {
		val context = LocalContext.current
		var retryKey by remember { mutableStateOf(0) }
		var animateTrigger by remember { mutableStateOf(false) }
		val scale by animateFloatAsState(targetValue = if (animateTrigger) 1.06f else 1f)
		val exists = AssetHelper.assetExists(context, assetPath)

		if (!exists) {
				// placeholder with tap-to-retry
				Box(modifier = modifier.clickable { retryKey++; animateTrigger = true }) {
						Image(painterResource(R.drawable.ic_image_placeholder), contentDescription = null)
				}
				return
		}

		val painter = rememberAsyncImagePainter(
				ImageRequest.Builder(context)
						.data("file:///android_asset/$assetPath?retry=$retryKey")
						.crossfade(true)
						.build()
		)

		when (painter.state) {
				is AsyncImagePainter.State.Loading -> LoadingSpinner()
				is AsyncImagePainter.State.Error -> { /* show retry button that increments retryKey */ }
				else -> Image(painter = painter, contentDescription = contentDescription, modifier = modifier)
		}
}
```

Penjelasan:
- `retryKey` ditambahkan ke query string untuk memaksa Coil membuat ulang request saat user menekan retry.
- `assetExists` mencegah situasi loading yang tidak pernah selesai jika file memang tidak ada.
- Animasi kecil (`scale`) dipakai untuk memberi feedback visual saat retry ditekan.

### 3) `LocaleManager.kt` & `MainActivity.kt` — apply locale sebelum setContent
Contoh desain `LocaleManager`:

```kotlin
object LocaleManager {
	private const val KEY_LANG = "pref_lang"
	fun getEffectiveLanguage(context: Context): String {
		val prefs = context.getSharedPreferences("simikro_prefs", Context.MODE_PRIVATE)
		return prefs.getString(KEY_LANG, "id") ?: "id"
	}
	fun saveLanguage(context: Context, lang: String) {
		context.getSharedPreferences("simikro_prefs", Context.MODE_PRIVATE).edit().putString(KEY_LANG, lang).apply()
	}
}
```

`MainActivity` panggil sebelum `setContent`:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
	super.onCreate(savedInstanceState)
	applyLocale(LocaleManager.getEffectiveLanguage(this))
	setContent { SiMikroApp() }
}
```

Penjelasan:
- Mengaplikasikan locale sebelum Compose diinisialisasi memastikan resource strings yang dimuat sudah sesuai bahasa pengguna.
- `applyLocale` perlu memperbarui `Configuration` pada `Resources` (context.resources.configuration.setLocale(...)).

### 4) `MateriDetailScreen` — Save-to-Downloads (SAF) contoh
Contoh pattern untuk menyimpan HTML ke Downloads:

```kotlin
val createDoc = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/html")) { uri ->
	if (uri != null) {
		coroutineScope.launch(Dispatchers.IO) {
			context.contentResolver.openOutputStream(uri)?.use { out -> out.write(htmlString.toByteArray()) }
		}
	}
}

// to launch
createDoc.launch("${materiId}.html")
```

Penjelasan:
- `CreateDocument` memungkinkan user memilih lokasi (Downloads) tanpa memerlukan legacy storage permissions.
- Tulis file pada background thread.

### 5) `AndroidManifest.xml` + `res/xml/file_paths.xml` untuk FileProvider
Manifest provider snippet:

```xml
<provider
		android:name="androidx.core.content.FileProvider"
		android:authorities="${applicationId}.provider"
		android:exported="false"
		android:grantUriPermissions="true">
		<meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths" />
</provider>
```

`res/xml/file_paths.xml`:

```xml
<paths xmlns:android="http://schemas.android.com/apk/res/android">
	<files-path name="internal_files" path="." />
	<cache-path name="cache" path="." />
</paths>
```

Penjelasan:
- `FileProvider` meng-encapsulate file:// menjadi content:// yang aman untuk di-share ke aplikasi lain.

### 6) `app/build.gradle.kts` — signing snippet dan resourceConfigurations
Contoh potongan: 

```kotlin
android {
	defaultConfig { resourceConfigurations.addAll(listOf("id","jv","en")) }
	signingConfigs {
		create("release") {
			val ks: String? = project.findProperty("KEYSTORE_PATH") as String?
			if (!ks.isNullOrEmpty()) { storeFile = file(ks); storePassword = project.findProperty("KEYSTORE_PASSWORD") as String? }
		}
	}
}
```

Penjelasan:
- `resourceConfigurations` menjaga agar resources untuk locales tidak di-strip saat building.
- Signing config dibuat hanya jika properties tersedia sehingga repo tidak menyimpan secrets.

### 7) QA scripts usage
- `scripts/check_assets.py` — pastikan semua file yang direferensikan ada.
- `scripts/diff_strings.py` — pastikan keys string konsisten antar-locale.

Jalankan kedua script sebagai bagian dari PR CI check.

---

Jika Anda mau, saya bisa juga:
- Menambahkan potongan `LocaleManager.kt`, `AssetHelper.kt`, `AssetImage.kt`, `MateriDetailScreen.kt` lengkap ke direktori `docs/` atau `DEVELOPER_GUIDE.md` di repo.
- Atau membuat `CHECKLIST_RELEASE.md`/`ISSUE_TEMPLATE.md` sekarang.

Pilih tindakan berikut: `docs` / `checklist` / `templates` / `tidak sekarang`.

---

## Dokumentasi terhubung (baca di GitHub)
Semua dokumen penting sudah dibuat dan saling terhubung. Untuk navigasi cepat, buka file berikut di GitHub:

- Root README (halaman ini): `README.md`
- Panduan pengembang lengkap: `DEVELOPER_GUIDE.md`
- Release & QA checklist: `CHECKLIST_RELEASE.md`
- Contoh materi & daftar: `app/src/main/assets/materi/id/materi_001.html` dan `app/src/main/assets/materi/id/materi_list.json`
- Dokumentasi sumber / walkthrough: `docs/source_walkthrough.md`
- GitHub templates: `.github/ISSUE_TEMPLATE/bug_report.md` dan `.github/PULL_REQUEST_TEMPLATE.md`
- CI workflow: `.github/workflows/ci.yml`

Semua file di atas saling merujuk—baca `README.md` lalu klik link ke dokumen spesifik untuk detail implementasi, contoh kode, dan langkah rilis.
