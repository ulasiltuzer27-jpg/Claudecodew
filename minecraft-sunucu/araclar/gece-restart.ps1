#Requires -Version 5.1
<#
    Gece otomatik restart. arkaplan.ps1 her gece çalıştırır.

    Sunucu açıksa oyunculara geri sayımla haber verir ve sunucuyu durdurur;
    BASLAT.bat 10 saniye sonra yedek alıp sunucuyu yeniden açar.
    Ayın 1'inde, kaynak dünyası kuruluysa durdurmadan önce onu sıfırlar.
#>
param(
    [double]$ZamanCarpani = 1,   # testlerde bekleme sürelerini kısaltmak için
    [datetime]$Tarih = (Get-Date)
)

. (Join-Path $PSScriptRoot 'ortak.ps1')

# Kalan saniye ve oyunculara gösterilecek metin.
$Uyarilar = @(
    @(300, '5 dakika'),
    @(60, '1 dakika'),
    @(30, '30 saniye'),
    @(10, '10 saniye')
)

function Kaynak-Dunyasini-Sifirla {
    $durum = Kurulum-Durumu
    if (-not ($durum -and @($durum.Adimlar) -contains 'dunyalar-v1')) { return }
    # Kaynak dünyasındakiler önce spawn'a alınır; yoksa yeni dünyada eski konumlarında (havada, taşın içinde) belirirler.
    if ([string]$durum.Spawn -match '^(-?\d+) (-?\d+) (-?\d+)$') {
        Rcon-Komut "execute in minecraft:kaynak as @a[distance=0..] in minecraft:overworld run tp @s $($Matches[1]).5 $($Matches[2]) $($Matches[3]).5" | Out-Null
    }
    $yeni = Rcon-Dene @('mv regen kaynak --seed', 'mvregen kaynak -s')
    $onay = if ($null -ne $yeni) { Rcon-Dene @('mv confirm', 'mvconfirm') } else { $null }
    if ($null -ne $yeni -and $null -ne $onay) { Gunluk-Yaz 'Gece restart: kaynak dünyası yeni bir haritayla sıfırlandı.' }
    else { Gunluk-Yaz 'Gece restart: kaynak dünyası sıfırlanamadı (Multiverse komutu kabul edilmedi); elle: mv regen kaynak' }
}

try {
    if (-not (Rcon-Hazir)) { Gunluk-Yaz 'Gece restart: sunucu kapalı, atlandı.'; exit 0 }

    $ayBasi = $Tarih.Day -eq 1
    $oyuncu = Oyuncu-Sayisi
    if ($oyuncu -ne 0) {   # -1: sayı okunamadı, yine de uyar
        $ek = if ($ayBasi) { ' Kaynak dünyası da sıfırlanacak.' } else { '' }
        for ($i = 0; $i -lt $Uyarilar.Count; $i++) {
            Rcon-Komut "minecraft:say Günlük bakım: sunucu $($Uyarilar[$i][1]) sonra yeniden başlatılacak.$ek" | Out-Null
            $sonraki = if ($i + 1 -lt $Uyarilar.Count) { $Uyarilar[$i + 1][0] } else { 0 }
            Start-Sleep -Milliseconds ([int](($Uyarilar[$i][0] - $sonraki) * 1000 * $ZamanCarpani))
        }
    }
    if ($ayBasi) { Kaynak-Dunyasini-Sifirla }
    Rcon-Komut 'save-all' | Out-Null
    try { Rcon-Komut 'stop' | Out-Null } catch { }   # sunucu kapanırken bağlantı cevap vermeden kopabilir
    Gunluk-Yaz "Gece restart: sunucu durduruldu (çevrimiçi oyuncu: $oyuncu), BASLAT.bat yeniden açacak."
} catch {
    Gunluk-Yaz "Gece restart HATA: $($_.Exception.Message)"
    exit 1
}
