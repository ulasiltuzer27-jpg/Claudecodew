# Minecraft Sunucusu — Windows için tek tıkla kurulum

Arkadaşlarınla oynamak için Windows bilgisayarında çalışan, kendi kendini kuran bir
**Minecraft Java Edition (Paper)** sunucusu. TLauncher ile girişe izin verir, isimleri şifreyle
korur ve modem ayarı gerektirmeden [playit.gg](https://playit.gg) tüneliyle internete açılır.

## Neler var?

- **Kurulum:** Java, Paper ve 27 eklentiyi indirir ve doğrular (SHA-256/512). Eklentilerin
  hepsiyle en uyumlu Minecraft sürümünü kendisi seçer.
- **Spawn meydanı:** Koyu temalı, 31×31. Canavar doğmaz ve çevresi korumalıdır. Rehber NPC'si
  ve dünya kapıları vardır.
- **Ek dünyalar:** Her ay sıfırlanan Kaynak Dünyası ve ayrı envanterli Yaratıcı Dünya.
- **Rütbeler:** `[Yönetici]` / `[Oyuncu]`. Yeni gelen oyuncular temel komutları kullanabilir.
- **Ödül ve ekonomi:** Günlük ve haftalık ödül kitleri, para, sandık marketleri ve arsa koruma.
- **Koruma:** Blok kaydı ve geri alma, hile ve X-ray koruması.
- **Görünüm:** Türkçe skor tablosu, renkli sohbet ve oyuncu listesi, 15 dakikada bir Türkçe ipuçları.
- **Web sayfaları:** 3D web haritası (BlueMap) ve istatistik sitesi (Plan).
- **İsteğe bağlı:** Sesli sohbet ve Discord bağlantısı.
- **Otomatik işler:** Her açılışta yedek, açıkken saatlik yedek, gece restart, çökünce yeniden
  başlatma, Windows açılınca başlama.

Ayrıntılı kullanım için: **[OKUBENI.txt](OKUBENI.txt)**

## Kurulum

1. Reponun ana sayfasında **Code → Download ZIP** ile indir.
2. ZIP'e sağ tık → Özellikler → **Engellemeyi kaldır** → Tamam.
3. ZIP'in içindeki **`minecraft-sunucu`** klasörünü `C:\MinecraftSunucu` gibi basit bir yere çıkar.
   Masaüstü veya OneDrive önerilmez. `KUR.bat` bu klasörün içinde olmalı.
4. **`KUR.bat`**'a çift tıkla. Script ne yapacağını gösterir ve onay ister. Birkaç sorudan sonra
   kendi kendine ilerler.
5. **`TUNEL.bat`** ile playit.gg tünelini kur (bir kez). Ardından **`BASLAT.bat`** ile sunucuyu aç.

Güncellemek için `KUR.bat`'ı tekrar çalıştırman yeterli. Minecraft sürümünü yükseltmeden ve var
olan bir dünyada spawn inşa etmeden önce sorar.

## Dosyalar

| Dosya | Görevi |
|---|---|
| `KUR.bat` → `araclar/kurulum.ps1` | Kurulum, güncelleme ve tek seferlik ayarlar |
| `BASLAT.bat` | Yedek alır, sunucuyu ve gizli yardımcıyı açar, çökünce yeniden başlatır |
| `TUNEL.bat` | playit.gg tüneli |
| `YEDEKLE.bat` → `araclar/yedekle.ps1` | Elle yedek (açık sunucuda kaydı durdurup alır) |
| `araclar/arkaplan.ps1` | Duyurular, saatlik yedek, gece restart (`gece-restart.ps1`) |
| `araclar/ortak.ps1` | Ortak yardımcılar: indirme, doğrulama, RCON |

Kurulumun oluşturduğu dosyalar (`sunucu/`, `java/`, `yedekler/`, `AYARLAR.cmd`,
`araclar/durum.json`...) repoya girmez. Bunlar `.gitignore` içinde. RCON şifresi kurulumda
rastgele üretilir ve bilgisayarda kalır.

## Geliştirme notları

- **Uyumluluk:** Scriptler Windows PowerShell 5.1 ile çalışır (Windows 10/11'de hazır gelir).
- **Dosya biçimi:** `.ps1` ve `.txt` dosyaları **UTF-8 BOM**, `.bat` dosyaları **ASCII** ve hepsi
  **CRLF** olmalı. BOM olmazsa Windows PowerShell Türkçe karakterleri bozar. `.gitattributes`
  bu dosyaları Git'in dönüştürmesini engeller.
- **Tek seferlik ayarlar:** Bunlar `kurulum.ps1` içindeki `$Adimlar` listesinde. Her adım bir
  kez yapılır ve `durum.json`'a yazılır. Yeni bir adım eklemek için listeye bir `Yeni-Adim`
  eklemek yeterli.
- **Komutların kontrolü:** Sunucu komutları RCON ile gönderilir, cevabı kontrol edilir. Kritik bir
  komut başarısız olursa adım bir sonraki çalıştırmada baştan denenir.
