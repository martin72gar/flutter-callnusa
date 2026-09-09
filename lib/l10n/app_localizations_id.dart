// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'CallNusa';

  @override
  String get loginTitle => 'Masuk';

  @override
  String get loginSubtitle => 'Masuk dengan akun CallNusa Anda';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Kata sandi';

  @override
  String get signIn => 'Masuk';

  @override
  String get signingIn => 'Sedang masuk…';

  @override
  String get emailRequired => 'Masukkan alamat email Anda';

  @override
  String get emailInvalid => 'Alamat email tidak valid';

  @override
  String get passwordRequired => 'Masukkan kata sandi Anda';

  @override
  String get tabDialer => 'Panggil';

  @override
  String get tabHistory => 'Riwayat';

  @override
  String get tabSettings => 'Pengaturan';

  @override
  String get registrationConnecting => 'Menghubungkan…';

  @override
  String get registrationRegistered => 'Siap';

  @override
  String get registrationRefreshing => 'Memperbarui…';

  @override
  String get registrationFailed => 'Tidak terhubung';

  @override
  String get registrationUnregistered => 'Luring';

  @override
  String registrationRetryIn(int seconds) {
    return 'Mencoba lagi dalam $seconds dtk';
  }

  @override
  String extensionLabel(String extension) {
    return 'Ekstensi $extension';
  }

  @override
  String get dialerHint => 'Masukkan nomor atau ekstensi';

  @override
  String get call => 'Panggil';

  @override
  String get outboundCallingDisabled =>
      'Panggilan keluar dinonaktifkan untuk akun Anda';

  @override
  String get incomingCall => 'Panggilan masuk';

  @override
  String get outgoingCall => 'Memanggil…';

  @override
  String get callRinging => 'Berdering…';

  @override
  String get callConnected => 'Tersambung';

  @override
  String get callOnHold => 'Ditahan';

  @override
  String get callEnding => 'Mengakhiri…';

  @override
  String get callEnded => 'Panggilan berakhir';

  @override
  String get callFailed => 'Panggilan gagal';

  @override
  String get unknownCaller => 'Tidak dikenal';

  @override
  String get mute => 'Bisukan';

  @override
  String get unmute => 'Aktifkan mik';

  @override
  String get hold => 'Tahan';

  @override
  String get resume => 'Lanjutkan';

  @override
  String get speaker => 'Pengeras suara';

  @override
  String get keypad => 'Tombol';

  @override
  String get accept => 'Terima';

  @override
  String get decline => 'Tolak';

  @override
  String get hangUp => 'Akhiri';

  @override
  String get recordingNotice => 'Panggilan ini dapat direkam';

  @override
  String get historyTitle => 'Riwayat panggilan';

  @override
  String get filterAll => 'Semua';

  @override
  String get filterMissed => 'Tak terjawab';

  @override
  String get filterInbound => 'Masuk';

  @override
  String get filterOutbound => 'Keluar';

  @override
  String get historyEmpty => 'Belum ada panggilan';

  @override
  String get missed => 'Tak terjawab';

  @override
  String get rejected => 'Ditolak';

  @override
  String get failed => 'Gagal';

  @override
  String get today => 'Hari ini';

  @override
  String get yesterday => 'Kemarin';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get sectionAudio => 'Audio';

  @override
  String get sectionNotifications => 'Notifikasi';

  @override
  String get sectionAbout => 'Tentang';

  @override
  String get defaultSpeaker => 'Gunakan pengeras suara secara bawaan';

  @override
  String get autoAnswer => 'Jawab otomatis panggilan masuk';

  @override
  String get vibrate => 'Getar saat ada panggilan masuk';

  @override
  String get ringtone => 'Nada dering';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSystem => 'Ikuti sistem';

  @override
  String get diagnostics => 'Diagnostik';

  @override
  String get appVersion => 'Versi';

  @override
  String get sourceCode => 'Kode sumber';

  @override
  String get license => 'Lisensi';

  @override
  String get licenseGpl => 'GNU GPL v3.0 only';

  @override
  String get openSourceNotices => 'Pemberitahuan sumber terbuka';

  @override
  String get logout => 'Keluar';

  @override
  String get logoutConfirmTitle => 'Keluar?';

  @override
  String get logoutConfirmBody =>
      'Akun SIP Anda akan dilepas dan kredensial yang tersimpan dihapus dari perangkat ini.';

  @override
  String get cancel => 'Batal';

  @override
  String get retry => 'Coba lagi';

  @override
  String get ok => 'OK';

  @override
  String get errorNetwork =>
      'Tidak ada koneksi. Periksa jaringan Anda lalu coba lagi.';

  @override
  String get errorTimeout => 'Server terlalu lama merespons.';

  @override
  String get errorInvalidCredentials => 'Email atau kata sandi salah.';

  @override
  String get errorSessionExpired =>
      'Sesi Anda telah berakhir. Silakan masuk kembali.';

  @override
  String get errorAccountDisabled => 'Akun ini telah dinonaktifkan.';

  @override
  String get errorNoExtension =>
      'Belum ada ekstensi untuk akun Anda. Hubungi administrator.';

  @override
  String get errorInvalidConfig =>
      'Konfigurasi telepon Anda tidak valid. Hubungi administrator.';

  @override
  String get errorDeviceLimit =>
      'Terlalu banyak perangkat terdaftar. Keluar dari perangkat lain terlebih dahulu.';

  @override
  String get errorServer =>
      'Terjadi kesalahan pada sistem kami. Silakan coba lagi.';

  @override
  String get errorSipRegistration =>
      'Tidak dapat terhubung ke layanan telepon.';

  @override
  String get errorCallFailed => 'Panggilan tidak dapat diselesaikan.';

  @override
  String get errorBusy => 'Saluran sedang sibuk.';

  @override
  String get errorNotFound => 'Nomor tersebut tidak ada.';

  @override
  String get errorMicPermission =>
      'Akses mikrofon diperlukan untuk melakukan panggilan.';

  @override
  String get errorUnknown => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get errorRateLimited =>
      'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';

  @override
  String get errorPlanLimit =>
      'Paket organisasi Anda tidak mengizinkan perangkat ini disiapkan. Hubungi administrator.';

  @override
  String get errorDeviceUnavailable =>
      'Perangkat ini telah dicabut. Keluar lalu masuk kembali untuk mendaftarkannya sebagai perangkat baru.';

  @override
  String get forgotPassword => 'Lupa kata sandi?';

  @override
  String get forgotPasswordBody =>
      'Masukkan email Anda dan kami akan mengirimkan tautan reset.';

  @override
  String get forgotPasswordSent => 'Jika akun ada, tautan reset telah dikirim.';

  @override
  String get send => 'Kirim';

  @override
  String get phoneNotReady => 'Layanan telepon belum siap.';
}
