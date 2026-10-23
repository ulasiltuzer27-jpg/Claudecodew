#Requires -Version 5.1
<#
    Sunucuyla birlikte çalışan gizli yardımcı. BASLAT.bat her açılışta başlatır; zaten çalışan
    bir kopya varsa yenisi hemen kapanır. Sunucu 5 dakika kapalı kalınca kendisi de kapanır.

      - 15 dakikada bir DUYURULAR.txt'deki sıradaki duyuru (yalnızca oyuncu varken)
      - her saatin 30. dakikasında saatlik yedek           (kurulumda istendiyse)
      - her gece $RestartSaati'nde restart, ayın 1'inde kaynak dünyası sıfırlama (kurulumda istendiyse)

    Görev Zamanlayıcı kullanılmaz: orada her çalışmada bir an açılan pencere tam ekran oyunu alta atar.
#>
param(
    [Nullable[datetime]]$SahteSaat = $null,   # testler: saat bu andan başlar...
    [double]$Hizlandir = 1     # ...ve bu kadar kat hızlı akar
)

. (Join-Path $PSScriptRoot 'ortak.ps1')

$DuyuruAraligi   = 15   # dakika
$KapaliSiniri    = 5    # sunucu açıldıktan sonra bu kadar dakika kapalı kalırsa yardımcı kapanır
$IlkAcilisSiniri = 20   # sunucu hiç açılmazsa bu kadar dakika sonra kapanır
$TurSaniyesi     = 20   # kontroller arası

$gercekBaslangic = Get-Date
function Simdi {
    if ($null -ne $SahteSaat) { return $SahteSaat.AddSeconds(((Get-Date) - $gercekBaslangic).TotalSeconds * $Hizlandir) }
    return (Get-Date)
}

$script:duyuruSirasi = 0
function Duyuru-Gonder {
    if (-not (Test-Path -LiteralPath $DuyuruDosyasi)) { return }
    $duyurular = @(Get-Content -LiteralPath $DuyuruDosyasi -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') })
    if ($duyurular.Count -eq 0 -or (Oyuncu-Sayisi) -eq 0) { return }
    $metin = $duyurular[$script:duyuruSirasi % $duyurular.Count]
    $script:duyuruSirasi++
    # &-renk kodları Minecraft'ın § kodlarına çevrilir; tellraw metni tırnak içinde olduğu için kaçırılır.
    $metin = ('&8[&dİpucu&8] &r' + $metin) -replace '&([0-9a-fk-or])', ([string][char]0x00A7 + '$1')
    $metin = $metin.Replace('\', '\\').Replace('"', '\"')
    Rcon-Komut "tellraw @a {`"text`":`"$metin`"}" | Out-Null
}

# Aynı anda tek yardımcı çalışsın (BASLAT.bat her yeniden başlatmada tekrar çağırır).
$kilit = New-Object System.Threading.Mutex($false, 'Local\MinecraftSunucuYardimci')
try { $sahip = $kilit.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $sahip = $true }
if (-not $sahip) { exit 0 }

$simdi = Simdi
$baslangic = $simdi
$sonAcik = $null
$sonDuyuru = $simdi
$sonYedekSaati = $simdi.ToString('yyyyMMddHH')   # BASLAT.bat açılışta zaten yedek aldı
$restartSaat = [TimeSpan]::Parse($RestartSaati)
# Restart saatinden sonra açıldıysa bugünkü restart yapılmış sayılır; yoksa sunucu açılır açılmaz kapanırdı.
$sonRestartGunu = if ($simdi.TimeOfDay -ge $restartSaat) { $simdi.ToString('yyyyMMdd') } else { '' }
Gunluk-Yaz 'Yardımcı başladı.'
try {
    while ($true) {
        Start-Sleep -Milliseconds ([int]($TurSaniyesi * 1000 / $Hizlandir))
        $simdi = Simdi
        if (-not (Rcon-Hazir)) {
            $kapaliSure = if ($sonAcik) { ($simdi - $sonAcik).TotalMinutes } else { ($simdi - $baslangic).TotalMinutes }
            if ($kapaliSure -ge $(if ($sonAcik) { $KapaliSiniri } else { $IlkAcilisSiniri })) { break }
            continue
        }
        $sonAcik = $simdi
        $durum = Kurulum-Durumu
        $gorevlerAcik = $durum -and $durum.Gorevler -eq 'evet'
        try {
            if (($simdi - $sonDuyuru).TotalMinutes -ge $DuyuruAraligi) {
                $sonDuyuru = $simdi
                Duyuru-Gonder
            }
            $saat = $simdi.ToString('yyyyMMddHH')
            if ($gorevlerAcik -and $simdi.Minute -ge 30 -and $saat -ne $sonYedekSaati) {
                $sonYedekSaati = $saat
                & (Join-Path $AraclarDir 'yedekle.ps1') -Saatlik
            }
            # Bilgisayar restart saatinde uykudaysa bir saat içinde uyanınca yine yapılır.
            $gun = $simdi.ToString('yyyyMMdd')
            if ($gorevlerAcik -and $gun -ne $sonRestartGunu -and $simdi.TimeOfDay -ge $restartSaat -and $simdi.TimeOfDay -lt $restartSaat.Add([TimeSpan]::FromHours(1))) {
                $sonRestartGunu = $gun
                & (Join-Path $AraclarDir 'gece-restart.ps1') -ZamanCarpani (1 / $Hizlandir) -Tarih $simdi
            }
        } catch {
            Gunluk-Yaz "Yardımcı HATA: $($_.Exception.Message)"
        }
    }
} finally {
    Gunluk-Yaz 'Yardımcı kapandı (sunucu kapalı).'
    $kilit.ReleaseMutex()
}
