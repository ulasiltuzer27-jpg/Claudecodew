#Requires -Version 5.1
<#
    Araç scriptlerinin ortak yolları ve yardımcıları.
    Diğer scriptler bu dosyayı  . (Join-Path $PSScriptRoot 'ortak.ps1')  ile yükler.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest ilerleme çubuğu indirmeyi çok yavaşlatıyor
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$AraclarDir        = $PSScriptRoot
$Kok               = Split-Path -Parent $AraclarDir
$SunucuDir         = Join-Path $Kok 'sunucu'
$EklentiDir        = Join-Path $SunucuDir 'plugins'
$YedekDir          = Join-Path $Kok 'yedekler'
$JavaDir           = Join-Path $Kok 'java'
$JavaExe           = Join-Path $JavaDir 'bin\java.exe'
$PlayitDir         = Join-Path $Kok 'playit'
$PlayitExe         = Join-Path $PlayitDir 'playit.exe'
$AyarDosyasi       = Join-Path $Kok 'AYARLAR.cmd'
$SurumDosyasi      = Join-Path $Kok 'SURUM.txt'
$DurumDosyasi      = Join-Path $AraclarDir 'durum.json'
$GunlukDosyasi     = Join-Path $AraclarDir 'gorevler.log'
$PropertiesDosyasi = Join-Path $SunucuDir 'server.properties'
$DuyuruDosyasi     = Join-Path $Kok 'DUYURULAR.txt'
$RestartSaati      = '05:00'   # gece restart saati (arkaplan.ps1)

$UserAgent  = 'mc-sunucu-kurulum/3.0 (Windows kurulum scripti)'
$Utf8BomsuZ = New-Object System.Text.UTF8Encoding $false

# ---------------------------------------------------------------------------
# Ekran ve günlük
# ---------------------------------------------------------------------------

function Baslik([string]$mesaj) { Write-Host ''; Write-Host "==> $mesaj" -ForegroundColor Cyan }
function Bilgi([string]$mesaj)  { Write-Host "    $mesaj" }
function Tamam([string]$mesaj)  { Write-Host "    [OK] $mesaj" -ForegroundColor Green }
function Uyari([string]$mesaj)  { Write-Host "    [!] $mesaj" -ForegroundColor Yellow }

# Görev Zamanlayıcı'dan gizli çalışan scriptler ekran yerine buraya yazar.
function Gunluk-Yaz([string]$mesaj) {
    $satir = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $mesaj
    try { [IO.File]::AppendAllText($GunlukDosyasi, "$satir`r`n", $Utf8BomsuZ) } catch { }
}

# ---------------------------------------------------------------------------
# İnternet
# ---------------------------------------------------------------------------

function Tekrar-Dene([scriptblock]$is, [string]$ne) {
    for ($deneme = 1; ; $deneme++) {
        try { return & $is }
        catch {
            # 404 kalıcıdır (ör. Modrinth'te olmayan eklenti adı); tekrar denemek boşuna bekletir.
            $bulunamadi = $_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404
            if ($bulunamadi -or $deneme -ge 3) { throw "$ne başarısız: $($_.Exception.Message)" }
            Start-Sleep -Seconds (2 * $deneme)
        }
    }
}

function Json-Al([string]$url) {
    $yanit = Tekrar-Dene { Invoke-RestMethod -Uri $url -UserAgent $UserAgent -UseBasicParsing -TimeoutSec 60 } "İstek ($url)"
    # Invoke-RestMethod JSON dizisini tek bir nesne olarak verir; değişken üzerinden döndürmek öğeleri tek tek çıkarır.
    return $yanit
}

function Dosya-Indir([string]$url, [string]$hedef) {
    Tekrar-Dene { Invoke-WebRequest -Uri $url -OutFile $hedef -UserAgent $UserAgent -UseBasicParsing -TimeoutSec 900 } "İndirme ($url)" | Out-Null
}

function Hash-Dogrula([string]$dosya, [string]$algoritma, [string]$beklenen) {
    $gercek = (Get-FileHash -LiteralPath $dosya -Algorithm $algoritma).Hash
    if ($gercek -ne $beklenen) {
        Remove-Item -LiteralPath $dosya -Force
        throw "$(Split-Path -Leaf $dosya) indirildi ama doğrulanamadı (hash uyuşmuyor). KUR.bat'ı tekrar çalıştır."
    }
}

# Önce geçici adla indirip doğrular, sonra yerine koyar; yarım kalan indirme eski dosyayı bozmaz.
function Dogrulanmis-Indir([string]$url, [string]$hedef, [string]$algoritma, [string]$hash) {
    $gecici = "$hedef.indiriliyor"
    Dosya-Indir $url $gecici
    if ($hash) { Hash-Dogrula $gecici $algoritma $hash }
    Move-Item -LiteralPath $gecici -Destination $hedef -Force
}

# ---------------------------------------------------------------------------
# server.properties
# ---------------------------------------------------------------------------

function Properties-Oku([string]$anahtar) {
    if (-not (Test-Path -LiteralPath $PropertiesDosyasi)) { return $null }
    foreach ($satir in [IO.File]::ReadAllLines($PropertiesDosyasi)) {
        if ($satir.StartsWith("$anahtar=")) { return $satir.Substring($anahtar.Length + 1).Trim() }
    }
    return $null
}

# Verilen anahtarları günceller, olmayanları sona ekler; diğer satırlara dokunmaz.
function Properties-Ayarla([hashtable]$degerler) {
    $satirlar = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $PropertiesDosyasi) { $satirlar.AddRange([string[]][IO.File]::ReadAllLines($PropertiesDosyasi)) }
    $kalan = @{} + $degerler
    for ($i = 0; $i -lt $satirlar.Count; $i++) {
        foreach ($anahtar in @($kalan.Keys)) {
            if ($satirlar[$i].StartsWith("$anahtar=")) {
                $satirlar[$i] = "$anahtar=$($kalan[$anahtar])"
                $kalan.Remove($anahtar)
            }
        }
    }
    foreach ($anahtar in @($kalan.Keys | Sort-Object)) { $satirlar.Add("$anahtar=$($kalan[$anahtar])") }
    [IO.File]::WriteAllText($PropertiesDosyasi, (($satirlar -join "`r`n") + "`r`n"), $Utf8BomsuZ)
}

function Port-Dinleniyor-Mu([int]$port) {
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        try { return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) } catch { }
    }
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $deneme = $tcp.BeginConnect('127.0.0.1', $port, $null, $null)
        return ($deneme.AsyncWaitHandle.WaitOne(1000) -and $tcp.Connected)
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

function Sunucu-Acik-Mi {
    $port = Properties-Oku 'server-port'
    if ($port -notmatch '^\d+$') { $port = 25565 }
    return (Port-Dinleniyor-Mu ([int]$port))
}

# RCON cevabında bunlar varsa komut başarısızdır...
$HataDeseni = '(?i)unknown or incomplete|unknown command|unknown flag|incorrect argument|<--\[here\]|not loaded|too many blocks|invalid|expected|unknown (block|item|entity|feature|game ?rule|dimension)|failed to place|usage:|not a valid|does not exist|no such|rcon hatası'
# ...ama bunlar "zaten öyle" demektir (KUR.bat tekrar çalıştırıldığında olur).
$DegisiklikYokDeseni = '(?i)no blocks were filled|could not set the block|nothing changed|already|no entity was found'

# ---------------------------------------------------------------------------
# RCON: açık sunucuya bu bilgisayardan komut göndermek için (yedek, gece restart)
# ---------------------------------------------------------------------------

function Rcon-Ayarlari {
    if ((Properties-Oku 'enable-rcon') -ne 'true') { return $null }
    $sifre = Properties-Oku 'rcon.password'
    if (-not $sifre) { return $null }
    $port = Properties-Oku 'rcon.port'
    if ($port -notmatch '^\d+$') { $port = 25575 }
    return [pscustomobject]@{ Port = [int]$port; Sifre = $sifre }
}

function Rcon-Hazir {
    $ayar = Rcon-Ayarlari
    return [bool]($ayar -and (Port-Dinleniyor-Mu $ayar.Port))
}

function Rcon-Tam-Oku($akis, [int]$adet) {
    $tampon = New-Object byte[] $adet
    $okunan = 0
    while ($okunan -lt $adet) {
        $n = $akis.Read($tampon, $okunan, $adet - $okunan)
        if ($n -le 0) { throw 'RCON bağlantısı kapandı.' }
        $okunan += $n
    }
    return , $tampon
}

# Paket: uzunluk, istek no, tür, UTF-8 metin, iki sıfır bayt (hepsi little-endian int32).
function Rcon-Yaz([System.IO.Stream]$akis, [int]$no, [int]$tur, [string]$govde) {
    $veri = [Text.Encoding]::UTF8.GetBytes($govde)
    $paket = New-Object byte[] (14 + $veri.Length)
    [BitConverter]::GetBytes([int](10 + $veri.Length)).CopyTo($paket, 0)
    [BitConverter]::GetBytes($no).CopyTo($paket, 4)
    [BitConverter]::GetBytes($tur).CopyTo($paket, 8)
    $veri.CopyTo($paket, 12)
    $akis.Write($paket, 0, $paket.Length)
    $akis.Flush()
}

function Rcon-Oku([System.IO.Stream]$akis) {
    $uzunluk = [BitConverter]::ToInt32((Rcon-Tam-Oku $akis 4), 0)
    $cevap = Rcon-Tam-Oku $akis $uzunluk
    return [pscustomobject]@{
        No    = [BitConverter]::ToInt32($cevap, 0)
        Govde = [Text.Encoding]::UTF8.GetString($cevap, 8, [Math]::Max(0, $uzunluk - 10))
    }
}

# Birden çok komut gönderilecekse bağlantı açık tutulur (kurulumdaki spawn inşası yüzlerce komut).
function Rcon-Baglan {
    $ayar = Rcon-Ayarlari
    if (-not $ayar) { throw 'RCON kapalı (server.properties).' }
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $tcp.ReceiveTimeout = 120000   # büyük dünyada save-all flush uzun sürebilir
        $tcp.SendTimeout = 10000
        $tcp.Connect('127.0.0.1', $ayar.Port)
        $akis = $tcp.GetStream()
        Rcon-Yaz $akis 1 3 $ayar.Sifre
        if ((Rcon-Oku $akis).No -eq -1) { throw 'RCON şifresi kabul edilmedi.' }
        return [pscustomobject]@{ Tcp = $tcp; Akis = $akis; No = 1 }
    } catch {
        $tcp.Close()
        throw
    }
}

function Rcon-Gonder($baglanti, [string]$komut) {
    $baglanti.No++
    Rcon-Yaz $baglanti.Akis $baglanti.No 2 $komut
    # 4 KB'tan uzun cevaplar birden çok pakete bölünür; önceki komutun kalan paketleri atlanır.
    do { $cevap = Rcon-Oku $baglanti.Akis } while ($cevap.No -ne $baglanti.No)
    return $cevap.Govde
}

function Rcon-Kapat($baglanti) {
    if ($baglanti) { try { $baglanti.Tcp.Close() } catch { } }
}

function Rcon-Komut([string]$komut) {
    $baglanti = Rcon-Baglan
    try { return (Rcon-Gonder $baglanti $komut) }
    finally { Rcon-Kapat $baglanti }
}

# EssentialsX "list" komutunu Türkçeleştirdiği için Minecraft'ın kendi komutu kullanılır. Anlaşılamazsa -1.
function Oyuncu-Sayisi {
    if ((Rcon-Komut 'minecraft:list') -match 'There are (\d+)') { return [int]$Matches[1] }
    return -1
}

# Kurulumun kaydettiği durum; arka plan işleri hangi özelliklerin açık olduğunu buradan öğrenir.
function Kurulum-Durumu {
    if (-not (Test-Path -LiteralPath $DurumDosyasi)) { return $null }
    try { return (Get-Content -LiteralPath $DurumDosyasi -Raw | ConvertFrom-Json) } catch { return $null }
}

# Seçenekleri sırayla dener; hata vermeyen ilk komutun cevabını, hiçbiri olmazsa $null döndürür.
function Rcon-Dene([string[]]$secenekler) {
    foreach ($komut in $secenekler) {
        $yanit = [string](Rcon-Komut $komut)
        if (($yanit -notmatch $HataDeseni) -or ($yanit -match $DegisiklikYokDeseni)) { return $yanit }
    }
    return $null
}
