#Requires -Version 5.1
<#
    Dünyayı ve sunucu ayarlarını yedekler klasörüne ZIP olarak yedekler.

      (parametresiz)  YEDEKLE.bat: elle yedek. Sunucu açıksa yedek süresince otomatik kaydı durdurur.
      -Otomatik       BASLAT.bat: sunucu açılmadan hemen önce, soru sormadan.
      -Saatlik        Görev Zamanlayıcı: yalnızca sunucu açıkken ve oyuncu varsa ya da dünya değiştiyse.
#>
param([switch]$Otomatik, [switch]$Saatlik)

. (Join-Path $PSScriptRoot 'ortak.ps1')

$Onek       = if ($Saatlik) { 'saatlik_' } else { 'yedek_' }
$Saklanacak = if ($Saatlik) { 12 } else { 10 }

# Yeniden indirilebilen, yeniden oluşturulabilen ya da çok büyüyen dosyalar yedeğe girmez.
$Haric = @(
    'sunucu/cache', 'sunucu/libraries', 'sunucu/versions', 'sunucu/logs', 'sunucu/paper.jar',
    'sunucu/bluemap',                            # BlueMap'in çizdiği harita, yeniden çizilebilir
    'sunucu/plugins/CoreProtect/database.db',    # blok kayıtları, zamanla GB'larca büyür
    'session.lock', '*.indiriliyor'
)
# Sunucu açıkken kilitli olan H2 veritabanları (ör. QuickShop marketleri); kapalıyken alınan yedeklerde vardır.
$AcikkenHaric = @('*.mv.db', '*.lock.db', '*.trace.db')

function Mesaj([string]$mesaj, [string]$renk = 'Gray') {
    if ($Saatlik) { Gunluk-Yaz "Saatlik yedek: $mesaj" } else { Write-Host "    $mesaj" -ForegroundColor $renk }
}

# Son yedekten sonra bölge dosyaları (.mca) değişti mi? level.dat her otomatik kayıtta değiştiği için sayılmaz.
function Dunya-Degisti-Mi {
    $sonYedek = Get-ChildItem -LiteralPath $YedekDir -Filter '*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $sonYedek) { return $true }
    # -Path 'world*' ile -Recurse birlikte kullanılırsa joker her alt klasörde ada uygulanır; klasörler ayrı bulunmalı.
    $degisen = Get-ChildItem -LiteralPath $SunucuDir -Directory -Filter 'world*' |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter '*.mca' -ErrorAction SilentlyContinue } |
        Where-Object { $_.LastWriteTime -gt $sonYedek.LastWriteTime } | Select-Object -First 1
    return [bool]$degisen
}

try {
    if (-not (Test-Path -LiteralPath $PropertiesDosyasi)) {
        if (-not $Otomatik -and -not $Saatlik) { Mesaj 'Henüz yedeklenecek bir sunucu yok.' }
        exit 0
    }
    if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
        Mesaj '[!] tar.exe bulunamadı (Windows 10 1803 veya daha yenisi gerekir), yedek alınamadı.' 'Yellow'
        exit 0
    }

    # Açık sunucuda yedek: kaydı durdur, her şeyi diske yaz, kopyala, kaydı geri aç.
    $sicak = $false
    if ($Saatlik) {
        if (-not (Sunucu-Acik-Mi)) { exit 0 }   # sunucu kapalıyken BASLAT.bat zaten yedek alıyor
        if (-not (Rcon-Hazir)) { Mesaj 'RCON kapalı, atlandı (KUR.bat''ı tekrar çalıştır).'; exit 0 }
        if ((Oyuncu-Sayisi) -eq 0 -and -not (Dunya-Degisti-Mi)) { Mesaj 'kimse yok ve dünya değişmedi, atlandı.'; exit 0 }
        $sicak = $true
    } elseif (-not $Otomatik -and (Sunucu-Acik-Mi)) {
        if (Rcon-Hazir) {
            Mesaj 'Sunucu açık: yedek süresince otomatik kayıt durduruluyor.'
            $sicak = $true
        } else {
            Mesaj '[!] Sunucu açık ve RCON kapalı. Açıkken alınan yedekte son değişiklikler eksik olabilir.' 'Yellow'
            $cevap = (Read-Host '    Yine de yedek alınsın mı? (e/H)').Trim().ToLowerInvariant()
            if ($cevap -notin @('e', 'evet', 'y', 'yes')) { exit 0 }
        }
    }

    New-Item -ItemType Directory -Force -Path $YedekDir | Out-Null
    $hedef = Join-Path $YedekDir ('{0}{1:yyyy-MM-dd_HH-mm-ss}.zip' -f $Onek, (Get-Date))
    $haricler = $Haric + $(if ($sicak) { $AcikkenHaric } else { @() })
    $tarArgumanlari = @('-a', '-c', '-f', $hedef) + @($haricler | ForEach-Object { "--exclude=$_" }) + @('-C', $Kok, 'sunucu')

    if ($sicak) {
        Rcon-Komut 'save-off' | Out-Null
        Rcon-Komut 'save-all flush' | Out-Null
    }
    try {
        & tar.exe @tarArgumanlari
        $cikisKodu = $LASTEXITCODE
    } finally {
        if ($sicak) {
            try { Rcon-Komut 'save-on' | Out-Null }
            catch { Mesaj "[!] Otomatik kayıt geri açılamadı: $($_.Exception.Message). Sunucu konsoluna save-on yaz." 'Yellow' }
        }
    }

    # tar okunamayan tek bir dosya için de hata kodu verir; arşiv oluştuysa yedeği tut ve uyar.
    $arsiv = Get-Item -LiteralPath $hedef -ErrorAction SilentlyContinue
    if (-not $arsiv -or $arsiv.Length -lt 1024) {
        Remove-Item -LiteralPath $hedef -Force -ErrorAction SilentlyContinue
        throw "Yedek alınamadı (tar çıkış kodu $cikisKodu)."
    }
    if ($cikisKodu -ne 0) { Mesaj "[!] Bazı dosyalar okunamadı (tar çıkış kodu $cikisKodu), yedeğin geri kalanı alındı." 'Yellow' }

    Get-ChildItem -LiteralPath $YedekDir -Filter "$Onek*.zip" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $Saklanacak |
        Remove-Item -Force

    $boyutMb = [math]::Round($arsiv.Length / 1MB, 1)
    $renk = if ($cikisKodu -eq 0) { 'Green' } else { 'Yellow' }
    Mesaj "[OK] Yedek alındı: yedekler\$($arsiv.Name) ($boyutMb MB)" $renk
} catch {
    Mesaj "HATA: $($_.Exception.Message)" 'Red'
    exit 1
}
