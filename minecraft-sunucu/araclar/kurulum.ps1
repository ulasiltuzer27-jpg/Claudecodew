#Requires -Version 5.1
<#
    Minecraft Paper sunucusu - otomatik kurulum (Windows)

    KUR.bat tarafından çalıştırılır. Tekrar çalıştırılırsa güncellemeleri ve yeni
    eklentileri kurar; Minecraft sürümünü yükseltmeden ve var olan dünyada spawn
    inşa etmeden önce sorar.

    Herhangi bir değişiklik yapmadan önce ne yapılacağını özetler ve onay ister.
#>

. (Join-Path $PSScriptRoot 'ortak.ps1')

$PaperApi       = 'https://fill.papermc.io/v3/projects/paper'
$ModrinthApi    = 'https://api.modrinth.com/v2'
$AdoptiumApi    = 'https://api.adoptium.net/v3'
$PlayitApi      = 'https://api.github.com/repos/playit-cloud/playit-agent/releases/latest'
$PlayitVarlik   = 'playit-windows-x86_64-signed.exe'
$DevreDisiDir   = Join-Path $EklentiDir 'devre-disi'
$BaslangicDir   = [Environment]::GetFolderPath('Startup')
$AdayLimiti     = 4       # AuthMe ile uyumlu en yeni kaç Paper sürümü karşılaştırılır
$KomutBekleme   = 15      # ayar komutlarından sonra sunucuyu kapatmadan önce beklenen saniye
$RconBekleme    = 60      # sunucu açıldıktan sonra RCON'un hazır olması için beklenen saniye
$BeklemeCarpani = 1       # testlerde "#bekle" sürelerini kısaltmak için
$ChunkyYaricap  = 2000
$DunyaSiniri    = 20000   # kenar uzunluğu (blok), merkez spawn
$SpawnKorumasi  = 17      # server.properties spawn-protection; meydanın yarıçapı 15
$KaynakSiniri   = 8000    # kaynak dünyasının sınırı (kenar uzunluğu, blok)
# Önceki sürümlerin Görev Zamanlayıcı görevleri; artık işleri arkaplan.ps1 yapar.
$EskiGorevler   = @('Minecraft Sunucusu - Gece Restart', 'Minecraft Sunucusu - Saatlik Yedek')

# Spawn meydanının malzemeleri (koyu tema).
$SpawnTema = @{
    Temel = 'deepslate'; Kenar = 'polished_blackstone_bricks'; Zemin = 'deepslate_tiles'; Yol = 'polished_deepslate'
    Orta = 'chiseled_polished_blackstone'; Isik = 'sea_lantern'; Duvar = 'polished_blackstone_brick_wall'
    Direk = 'polished_blackstone_wall'; Fener = 'soul_lantern'; Bank = 'deepslate_tile_stairs'
    Agac = 'minecraft:dark_oak'; Cicekler = @('allium', 'blue_orchid', 'azure_bluet', 'lily_of_the_valley')
}

function Yeni-Eklenti([string]$ad, [string[]]$slug, [string]$aciklama, [string]$sayfa, [switch]$Zorunlu, [switch]$HerSurum, [string[]]$EkDosyalar = @()) {
    [pscustomobject]@{ Ad = $ad; Slug = $slug; Aciklama = $aciklama; Sayfa = $sayfa; Zorunlu = [bool]$Zorunlu; HerSurum = [bool]$HerSurum; EkDosyalar = $EkDosyalar; Surumler = @() }
}

# AuthMe zorunlu: online-mode=false iken isimleri şifreyle korur.
# Slug: Modrinth proje adı; birden çok verilirse sırayla denenir.
# HerSurum: Minecraft koduna dokunmayan API eklentisi; sürüm listesinde yoksa en yeni kararlı sürümü kurulur.
# EkDosyalar: aynı Modrinth sürümünde gelen ek jar'lar (ör. EssentialsX'in /spawn ve sohbet modülleri).
$Eklentiler = @(
    (Yeni-Eklenti 'AuthMe'           'authmereloaded'   'şifreyle giriş (/register, /login)'       'https://modrinth.com/plugin/authmereloaded' -Zorunlu)
    (Yeni-Eklenti 'EssentialsX'      'essentialsx'      '/home, /tpa, /spawn, /tpr, para, sohbet'  'https://essentialsx.net/downloads.html' -EkDosyalar '^EssentialsXSpawn', '^EssentialsXChat')
    (Yeni-Eklenti 'LuckPerms'        'luckperms'        'yetkiler ve rütbeler'                      'https://luckperms.net/download')
    (Yeni-Eklenti 'VaultUnlocked'    'vaultunlocked'    'eklentiler arası para ve önek köprüsü'     'https://modrinth.com/plugin/vaultunlocked' -HerSurum)
    (Yeni-Eklenti 'QuickShop-Hikari' 'quickshop-hikari' 'sandık marketleri'                         'https://modrinth.com/plugin/quickshop-hikari')
    (Yeni-Eklenti 'ViaVersion'       'viaversion'       'daha yeni sürümlerle giriş'                'https://modrinth.com/plugin/viaversion')
    (Yeni-Eklenti 'ViaBackwards'     'viabackwards'     'daha eski sürümlerle giriş'                'https://modrinth.com/plugin/viabackwards')
    (Yeni-Eklenti 'CoreProtect'      'coreprotect'      'blok kaydı ve geri alma (/co)'             'https://modrinth.com/plugin/coreprotect')
    (Yeni-Eklenti 'GriefPrevention'  'griefprevention'  'arsa koruma (altın kürek)'                 'https://modrinth.com/plugin/griefprevention')
    (Yeni-Eklenti 'GrimAC'           'grimac'           'hile koruması'                             'https://modrinth.com/plugin/grimac')
    (Yeni-Eklenti 'SkinsRestorer'    'skinsrestorer'    'skinler (/skin)'                           'https://modrinth.com/plugin/skinsrestorer')
    (Yeni-Eklenti 'TAB'              'tab-was-taken'    'renkli oyuncu listesi, rütbe önekleri'     'https://modrinth.com/plugin/tab-was-taken')
    (Yeni-Eklenti 'GravesX'          'gravesx'          'ölünce eşyalar mezarda kalır'              'https://modrinth.com/plugin/gravesx')
    (Yeni-Eklenti 'AuraSkills'       'auraskills'       'RPG yetenekleri (/skills)'                 'https://modrinth.com/plugin/auraskills')
    (Yeni-Eklenti 'VeinMiner'        @('all-in-one-veinminer', 'veinminer') 'ağaç ve maden damarını tek seferde kırma' 'https://modrinth.com/plugins?q=veinminer')
    (Yeni-Eklenti 'GSit'             'gsit'             'oturma ve uzanma (/sit, /lay)'             'https://modrinth.com/plugin/gsit')
    (Yeni-Eklenti 'Chunky'           'chunky'           'dünyayı önceden oluşturma'                 'https://modrinth.com/plugin/chunky')
    (Yeni-Eklenti 'BlueMap'          'bluemap'          '3D web haritası'                           'https://modrinth.com/plugin/bluemap')
    (Yeni-Eklenti 'WorldEdit'        'worldedit'        'büyük yapı düzenleme (yönetici)'           'https://modrinth.com/plugin/worldedit')
    (Yeni-Eklenti 'DecentHolograms'  'decentholograms'  'havada yazılar (yönetici, /dh)'            'https://modrinth.com/plugin/decentholograms')
    (Yeni-Eklenti 'Multiverse-Core'  'multiverse-core'  'ek dünyalar: kaynak ve yaratıcı'           'https://modrinth.com/plugin/multiverse-core')
    (Yeni-Eklenti 'Multiverse-Inventories' 'multiverse-inventories' 'yaratıcı dünyada ayrı envanter' 'https://modrinth.com/plugin/multiverse-inventories')
    (Yeni-Eklenti 'FancyNpcs'        'fancynpcs'        'spawn rehberi ve dünya kapıları (NPC)'     'https://modrinth.com/plugin/fancynpcs')
    (Yeni-Eklenti 'PlaceholderAPI'   @('placeholderapi', 'lKEzGugV') 'skor tablosunda para gösterimi' 'https://modrinth.com/plugin/placeholderapi' -HerSurum)
    (Yeni-Eklenti 'Plan'             'plan'             'oyuncu istatistikleri sitesi'              'https://modrinth.com/plugin/plan')
    (Yeni-Eklenti 'SimpleVoiceChat'  'simple-voice-chat' 'yakındakilerle sesli sohbet'             'https://modrinth.com/plugin/simple-voice-chat')
    (Yeni-Eklenti 'Towny'            'towny'            'kasabalar ve uluslar (/town)'              'https://modrinth.com/plugin/towny')
    (Yeni-Eklenti 'CrazyAuctions'    'crazyauctions'    'açık artırma pazarı (/ah)'                 'https://modrinth.com/plugin/crazyauctions')
    (Yeni-Eklenti 'DiscordSRV'       'discordsrv'       'Discord sohbet köprüsü'                    'https://modrinth.com/plugin/discordsrv')
)

# Normal oyuncuların (LuckPerms "default" grubu) kullanabileceği komutlar.
$VarsayilanYetkiler = @(
    'essentials.home', 'essentials.sethome', 'essentials.delhome', 'essentials.sethome.multiple', 'essentials.sethome.multiple.default',
    'essentials.tpa', 'essentials.tpahere', 'essentials.tpaccept', 'essentials.tpdeny', 'essentials.tpacancel', 'essentials.tpr',
    'essentials.back', 'essentials.back.ondeath', 'essentials.spawn', 'essentials.warp', 'essentials.warp.list',
    'essentials.msg', 'essentials.r', 'essentials.reply', 'essentials.mail', 'essentials.mail.send', 'essentials.ignore',
    'essentials.afk', 'essentials.list', 'essentials.help', 'essentials.helpop', 'essentials.rules', 'essentials.motd',
    'essentials.seen', 'essentials.getpos', 'essentials.compass', 'essentials.depth',
    'essentials.balance', 'essentials.balancetop', 'essentials.pay', 'essentials.sell', 'essentials.worth',
    'essentials.kit', 'essentials.kits.gunluk', 'essentials.kits.haftalik',
    'quickshop.player',
    'skinsrestorer.player', 'skinsrestorer.command', 'skinsrestorer.command.set', 'skinsrestorer.command.set.url', 'skinsrestorer.command.clear',
    'griefprevention.createclaims',
    'tab.scoreboard.toggle',
    'voicechat.listen', 'voicechat.speak', 'voicechat.groups',
    'crazyauctions.access', 'crazyauctions.view', 'crazyauctions.sell', 'crazyauctions.bid'
)

# Towny ayarları (plugins/Towny/settings/config.yml): kasaba kurmak başlangıç parasıyla mümkün olsun ve
# oyuncular birkaç gün girmeyince günlük bakım ücreti yüzünden kasabaları silinmesin.
$TownyFiyatlari = [ordered]@{ price_new_town = '100.0'; price_new_nation = '500.0'; price_town_upkeep = '0.0'; price_nation_upkeep = '0.0' }

# Yeni özelliklerle gelen ipuçları; DUYURULAR.txt'de yoksa sona eklenir.
$EkDuyurular = @(
    '&7Arkadaşlarınla kasaba kur: &e/town new isim &7(100 para), davet: &e/town add isim',
    '&7Açık artırma pazarı: &e/ah &7ile göz at, elindekini satmak için &e/ah sell fiyat'
)

# EssentialsX kits.yml'ye eklenen ödül kitleri: ad, bekleme (saniye), içerik ("$" para verir).
$OdulKitleri = @(
    @('gunluk', 86400, @('bread 16', 'cooked_beef 8', 'iron_ingot 6', 'experience_bottle 8', '$50')),
    @('haftalik', 604800, @('diamond 3', 'golden_apple 2', 'emerald 6', 'experience_bottle 32', '$250'))
)

# Paper API önerilen ayarları vermezse kullanılır (Aikar'ın ayarları).
$VarsayilanJvmAyarlari = @(
    '-XX:+AlwaysPreTouch', '-XX:+DisableExplicitGC', '-XX:+ParallelRefProcEnabled', '-XX:+PerfDisableSharedMem',
    '-XX:+UnlockExperimentalVMOptions', '-XX:+UseG1GC', '-XX:G1HeapRegionSize=8M', '-XX:G1HeapWastePercent=5',
    '-XX:G1MaxNewSizePercent=40', '-XX:G1MixedGCCountTarget=4', '-XX:G1MixedGCLiveThresholdPercent=90',
    '-XX:G1NewSizePercent=30', '-XX:G1RSetUpdatingPauseTimePercent=5', '-XX:G1ReservePercent=20',
    '-XX:InitiatingHeapOccupancyPercent=15', '-XX:MaxGCPauseMillis=200', '-XX:MaxTenuringThreshold=1',
    '-XX:SurvivorRatio=32', '-Dusing.aikars.flags=https://mcflags.emc.gs', '-Daikars.new.flags=true'
)

$EssentialsMotd = @(
    '&5&m                                                   ',
    '&d&l  Hoş geldin, &f&l{PLAYER}&d&l!',
    '&7  Şu an çevrimiçi: &f{ONLINE} &7oyuncu',
    '&7  Keşfe çık: &e/tpr   &7Ev kur: &e/sethome   &7Eve dön: &e/home',
    '&7  Arsa koruma: &faltın kürekle &7iki köşeye sağ tıkla',
    '&7  Kurallar: &e/rules   &7Yardım iste: &e/helpop mesaj',
    '&5&m                                                   '
)
$EssentialsKurallar = @(
    '&d&lSunucu Kuralları',
    '&f1. &7Başkalarının yapılarını bozma, sandıklarını boşaltma.',
    '&f2. &7Hile, X-ray ve hile istemcisi yasak.',
    '&f3. &7Küfür, hakaret ve spam yok.',
    '&f4. &7Spawn meydanının yakınına yapı yapma; /tpr ile uzaklaş.',
    '&f5. &7Bir sorun olursa yöneticiye yaz: &e/helpop mesaj'
)


# Kurulumdan sonra bir kez yapılan ayarlar; yapılanlar durum.json'a yazılır.
#   Dosya:    eklentinin oluşturduğu ayar dosyası (sunucu bir kez açılınca oluşur)
#   Yama:     o dosyada yapılacak değişiklik
#   Komutlar: sunucu açıkken çalıştırılacak komutlar (yamalardan sonra, listedeki sırayla)
#             "?" ile başlayan isteğe bağlıdır; "a || b" önce a'yı, olmazsa b'yi dener; "#bekle N" N saniye bekler
#             Hiç komut üretmezse adım bu sefer atlanır ve sonraki çalıştırmada tekrar denenir.
#   Hemen:    komutlar başarılı olunca, sunucu hâlâ açıkken (sonraki adımlar sonucu kullanabilsin diye)
#   Sonra:    komutlar başarılı olduysa sunucu kapandıktan sonra yapılacaklar
#   Kosul:    kurulumda verilen cevaplara veya önceki adımlara bağlı adımlar
# Scriptblock'lar ($secenekler, $durum) alır; Yama ilk olarak ayar dosyasının yolunu, Hemen/Sonra komut sonuçlarını alır.
function Yeni-Adim([string]$id, [string]$ad, [string]$eklenti, $dosya = $null, $yama = $null, $komutlar = $null, $hemen = $null, $sonra = $null, $kosul = $null) {
    [pscustomobject]@{ Id = $id; Ad = $ad; Eklenti = $eklenti; Dosya = $dosya; Yama = $yama; Komutlar = $komutlar; Hemen = $hemen; Sonra = $sonra; Kosul = $kosul }
}

# Spawn çevresi: rehber güneyde (tabelanın arkasında), dünya kapıları doğu ve batı yollarında.
$NpcKonumlari = @{ rehber = @(0, 7); kaynak_kapisi = @(8, 0); yaratici_kapisi = @(-8, 0) }

$Adimlar = @(
    (Yeni-Adim 'authme-ayar' 'AuthMe ayarları' 'AuthMe' { Eklenti-Dosyasi 'AuthMe*' 'config.yml' } {
        param($dosya)
        # playit tüneli herkesi 127.0.0.1'den gösterir; IP başına kayıt sınırı kalkmazsa tek kişi kayıt olabilir.
        Yaml-Degistir $dosya '^([ \t]*)maxRegPerIp:[^\r\n]*' '${1}maxRegPerIp: 0' 'AuthMe: IP başına kayıt sınırı kaldırıldı'
        # Aynı sebeple oturum hatırlama kapalı olmalı; yoksa biri başkasının adıyla şifresiz girebilir.
        Yaml-Degistir $dosya '^([ \t]*sessions:[ \t]*\r?\n(?:[ \t]*#[^\r\n]*\r?\n)*[ \t]*)enabled:[^\r\n]*' '${1}enabled: false' 'AuthMe: otomatik oturum hatırlama kapalı'
        Yaml-Degistir $dosya '^([ \t]*)messagesLanguage:[^\r\n]*' "`${1}messagesLanguage: 'tr'" 'AuthMe: Türkçe mesajlar'
    })
    (Yeni-Adim 'essentials-ayar' 'EssentialsX dili' 'EssentialsX' { Eklenti-Dosyasi 'Essentials' 'config.yml' } {
        param($dosya) Yaml-Degistir $dosya '^locale:[^\r\n]*' 'locale: tr' 'EssentialsX: Türkçe mesajlar'
    })
    (Yeni-Adim 'essentials-ekonomi' 'EssentialsX ekonomi' 'EssentialsX' { Eklenti-Dosyasi 'Essentials' 'config.yml' } {
        param($dosya) Yaml-Degistir $dosya '^starting-balance:[^\r\n]*' 'starting-balance: 100' 'EssentialsX: yeni oyunculara 100 başlangıç parası'
    })
    (Yeni-Adim 'essentials-yeni-oyuncu' 'Başlangıç kiti ve Türkçe mesajlar' 'EssentialsX' { Eklenti-Dosyasi 'Essentials' 'config.yml' } {
        param($dosya)
        Yaml-Degistir $dosya '^(newbies:[^\r\n]*(?:\r?\n(?![^ \t\r\n])[^\r\n]*)*?\r?\n[ \t]+)kit:[^\r\n]*' '${1}kit: tools' 'EssentialsX: yeni gelenlere taş alet kiti'
        Yaml-Degistir $dosya '^([ \t]+)announce-format:[^\r\n]*' '${1}announce-format: ''&d{DISPLAYNAME} &dsunucuya ilk kez katıldı, hoş geldin!''' 'EssentialsX: Türkçe ilk giriş duyurusu'
        $klasor = Split-Path -Parent $dosya
        [IO.File]::WriteAllText((Join-Path $klasor 'motd.txt'), (($EssentialsMotd -join "`r`n") + "`r`n"), $Utf8BomsuZ)
        [IO.File]::WriteAllText((Join-Path $klasor 'rules.txt'), (($EssentialsKurallar -join "`r`n") + "`r`n"), $Utf8BomsuZ)
        Tamam 'EssentialsX: Türkçe giriş mesajı (motd) ve kurallar (/rules) yazıldı'
    })
    (Yeni-Adim 'essentials-sohbet' 'Renkli sohbet' 'EssentialsX' { Eklenti-Dosyasi 'Essentials' 'config.yml' } {
        param($dosya) Yaml-Degistir $dosya '^([ \t]+)format: ''<\{DISPLAYNAME\}> \{MESSAGE\}''' '${1}format: ''{PREFIX}{USERNAME}&8: &f{MESSAGE}''' 'EssentialsX: sohbette rütbe önekleri'
    })
    (Yeni-Adim 'luckperms-yaml' 'LuckPerms kayıt biçimi' 'LuckPerms' { Eklenti-Dosyasi 'LuckPerms' 'config.yml' } {
        # Varsayılan H2 veritabanı sunucu açıkken kilitli olduğu için saatlik yedeğe giremez; YAML dosyaları girer.
        param($dosya) Yaml-Degistir $dosya '^storage-method:[^\r\n]*' 'storage-method: yaml' 'LuckPerms: yetkiler YAML dosyalarında saklanacak'
    })
    (Yeni-Adim 'tab-gruplar' 'TAB rütbe önekleri' 'TAB' { Eklenti-Dosyasi 'TAB' 'groups.yml' } {
        param($dosya)
        $icerik = @(
            '# Kurulum scripti: önekler LuckPerms rütbelerinden alınır.',
            '# Değiştirmek için oyunda: lp group <grup> meta setprefix <öncelik> "<önek>"',
            '_DEFAULT_:',
            '  tabprefix: "%luckperms-prefix%"',
            '  tagprefix: "%luckperms-prefix%"',
            '  tabsuffix: "%luckperms-suffix%"',
            '  tagsuffix: "%luckperms-suffix%"'
        )
        [IO.File]::WriteAllText($dosya, (($icerik -join "`r`n") + "`r`n"), $Utf8BomsuZ)
        Tamam 'TAB: oyuncu listesinde ve isimlerin üstünde rütbe önekleri'
    })
    (Yeni-Adim 'paper-antixray' 'X-ray koruması' $null { Paper-Ayar-Dosyasi 'paper-world-defaults.yml' } {
        param($dosya) Yaml-Degistir $dosya '^([ \t]*anti-xray:[ \t]*\r?\n(?:[ \t]*#[^\r\n]*\r?\n)*[ \t]*)enabled:[^\r\n]*' '${1}enabled: true' 'Paper: X-ray koruması açıldı'
    })
    (Yeni-Adim 'chunky-ayar' 'Chunky ayarı' 'Chunky' { Eklenti-Dosyasi 'Chunky' 'config.yml' } {
        param($dosya) Yaml-Degistir $dosya '^continue-on-restart:[^\r\n]*' 'continue-on-restart: true' 'Chunky: yeniden başlayınca kaldığı yerden devam eder'
    })
    (Yeni-Adim 'bluemap-ayar' 'BlueMap ayarı' 'BlueMap' { Eklenti-Dosyasi 'BlueMap' 'core.conf' } {
        # BlueMap haritayı çizmek için Mojang'ın istemci dosyalarını indirir; Mojang EULA'sı kurulumda kabul edildi.
        param($dosya) Yaml-Degistir $dosya '^accept-download:[^\r\n]*' 'accept-download: true' 'BlueMap: harita çizimi açıldı'
    })
    (Yeni-Adim 'discord-ayar' 'Discord ayarı' 'DiscordSRV' { Eklenti-Dosyasi 'DiscordSRV' 'config.yml' } {
        param($dosya, $s)
        Yaml-Degistir $dosya '^BotToken:[^\r\n]*' "BotToken: `"$($s.DiscordToken)`"" 'DiscordSRV: bot token yazıldı'
        Yaml-Degistir $dosya '^Channels:[^\r\n]*' "Channels: {`"global`": `"$($s.DiscordKanal)`"}" 'DiscordSRV: sohbet kanalı ayarlandı'
    } -kosul { param($s) [bool]$s.DiscordToken })
    (Yeni-Adim 'odul-kitleri' 'Günlük ve haftalık ödül kitleri' 'EssentialsX' { Eklenti-Dosyasi 'Essentials' 'kits.yml' } {
        param($dosya) Kitleri-Ekle $dosya
    })
    (Yeni-Adim 'tab-skor' 'Skor tablosu' 'TAB' { Eklenti-Dosyasi 'TAB' 'config.yml' } {
        param($dosya, $s, $d)
        $papi = Eklenti-Kurulu-Mu $d 'PlaceholderAPI'
        $kasaba = $papi -and (Eklenti-Kurulu-Mu $d 'Towny')
        Yaml-Bolum-Degistir $dosya 'scoreboard' (Skor-Tablosu $s.SunucuAdi $papi $kasaba) 'TAB: Türkçe skor tablosu (/skor ile gizlenir)'
    })
    (Yeni-Adim 'towny-ayar' 'Towny fiyatları' 'Towny' { Eklenti-Dosyasi 'Towny' (Join-Path 'settings' 'config.yml') } {
        param($dosya)
        foreach ($anahtar in $TownyFiyatlari.Keys) {
            Yaml-Degistir $dosya "^([ \t]*)$($anahtar):[^\r\n]*" "`${1}$($anahtar): $($TownyFiyatlari[$anahtar])" "Towny: $anahtar = $($TownyFiyatlari[$anahtar])"
        }
    })
    (Yeni-Adim 'duyurular-v2' 'Kasaba ve pazar ipuçları' $null { if (Test-Path -LiteralPath $DuyuruDosyasi) { $DuyuruDosyasi } } {
        param($dosya) Duyurulara-Ekle $dosya
    })
    (Yeni-Adim 'sesli-sohbet' 'Sesli sohbet adresi' 'SimpleVoiceChat' { Eklenti-Dosyasi 'voicechat' 'voicechat-server.properties' } {
        param($dosya, $s) Yaml-Degistir $dosya '^voice_host=[^\r\n]*' "voice_host=$($s.SesHost)" "Sesli sohbet: oyuncular $($s.SesHost) adresine bağlanacak"
    } -kosul { param($s) [bool]$s.SesHost })

    (Yeni-Adim 'op' 'Yönetici (op)' $null -komutlar { param($s) "op $($s.OpIsmi)" } -kosul { param($s) [bool]$s.OpIsmi })
    (Yeni-Adim 'rutbeler' 'Rütbeler: [Yönetici] ve [Oyuncu]' 'LuckPerms' -komutlar {
        param($s)
        'lp creategroup yonetici'
        'lp group yonetici setweight 100'
        'lp group yonetici meta setprefix 100 "&5[Yönetici] &d"'
        'lp group default meta setprefix 1 "&8[Oyuncu] &7"'
        if ($s.OpIsmi) { "lp user $($s.OpIsmi) parent add yonetici" }
    })
    (Yeni-Adim 'yetkiler-v4' 'Oyuncu yetkileri (/home, /tpa, /tpr, /kit, /ah, /sell, /skin...)' 'LuckPerms' -komutlar {
        $VarsayilanYetkiler | ForEach-Object { "lp group default permission set $_ true" }
    })
    (Yeni-Adim 'oyun-kurallari' "Uyku %50, dünya sınırı $DunyaSiniri, /tpr 300-3000 blok" $null -komutlar {
        $dunya = Dunya-Adi
        '?gamerule minecraft:players_sleeping_percentage 50 || gamerule players_sleeping_percentage 50 || gamerule playersSleepingPercentage 50'
        'worldborder center ~ ~'
        "worldborder set $DunyaSiniri"
        "?settpr $dunya minrange 300"
        "?settpr $dunya maxrange 3000"
    })
    (Yeni-Adim 'spawn-v1' 'Spawn meydanı (koyu tema)' $null -komutlar { param($s) Spawn-Komutlari $s.SunucuAdi } -hemen {
        param($sonuclar, $durum)
        $yer = @($sonuclar | Where-Object { $_.Komut -like '*setworldspawn*' -and $_.Yanit -match '(-?\d+), ?(-?\d+), ?(-?\d+)' })[0]
        if ($yer -and $yer.Yanit -match '(-?\d+), ?(-?\d+), ?(-?\d+)') { $durum.Spawn = "$($Matches[1]) $($Matches[2]) $($Matches[3])" }
    } -sonra {
        Properties-Ayarla @{ 'spawn-protection' = "$SpawnKorumasi" }
    })
    (Yeni-Adim 'dunyalar-v1' 'Ek dünyalar: kaynak ve yaratıcı' 'Multiverse-Core' -komutlar { Dunya-Komutlari } -kosul {
        # Ayrı envanter olmadan yaratıcı dünyadan normal dünyaya bedava eşya taşınabilir.
        param($s, $d) Eklenti-Kurulu-Mu $d 'Multiverse-Inventories'
    })
    (Yeni-Adim 'npc-rehber' 'Spawn rehberi (NPC)' 'FancyNpcs' -komutlar { param($s, $d) Npc-Komutlari $d 'rehber' } -kosul {
        param($s, $d) Spawn-Bilinecek-Mi $d
    })
    (Yeni-Adim 'npc-kapilar' 'Dünya kapıları (NPC)' 'FancyNpcs' -komutlar {
        param($s, $d)
        if ($d.Adimlar -contains 'dunyalar-v1') { Npc-Komutlari $d 'kaynak_kapisi'; Npc-Komutlari $d 'yaratici_kapisi' }
    } -kosul {
        param($s, $d) (Spawn-Bilinecek-Mi $d) -and (($d.Adimlar -contains 'dunyalar-v1') -or ((Eklenti-Kurulu-Mu $d 'Multiverse-Core') -and (Eklenti-Kurulu-Mu $d 'Multiverse-Inventories')))
    })
    (Yeni-Adim 'papi-vault' 'Skor tablosunda para (PlaceholderAPI)' 'PlaceholderAPI' -komutlar {
        '?papi ecloud download Vault'
        '#bekle 5'
        '?papi reload'
    })
    (Yeni-Adim 'chunky-baslat' "Dünya ön oluşturma ($ChunkyYaricap blok)" 'Chunky' -komutlar {
        "chunky world $(Dunya-Adi)"
        '?chunky spawn'
        "chunky radius $ChunkyYaricap"
        'chunky start'
    } -kosul { param($s) [bool]$s.ChunkyBaslat })
)

# ---------------------------------------------------------------------------
# Ek dünyalar, NPC'ler, ödül kitleri ve skor tablosu
# ---------------------------------------------------------------------------

# Multiverse 5 ve 4'ün sözdizimi farklı; önce yenisi denenir.
function Dunya-Komutlari {
    'mv create kaynak normal || mvcreate kaynak normal'
    "?execute in minecraft:kaynak run worldborder set $KaynakSiniri"
    'mv create yaratici normal --world-type flat || mv create yaratici normal -t FLAT'
    # Kaynak dünyası ana dünyayla aynı envanteri kullanır; yaratıcı dünya ayrı kalır (Multiverse-Inventories varsayılanı).
    'mvinv add-worlds default kaynak || mvinv addworld kaynak default'
    '?mv modify yaratici set gamemode creative || mv modify set gamemode creative yaratici'
    '?mv modify yaratici set difficulty peaceful || mv modify set difficulty peaceful yaratici'
    '?execute in minecraft:yaratici run gamerule minecraft:advance_time false || execute in minecraft:yaratici run gamerule doDaylightCycle false'
    '?execute in minecraft:yaratici run time set noon'
}

# Rehber spawn'ın kendisine, kapılar kurulu dünyalara bağlı; spawn bu çalıştırmada kurulacaksa da olur.
function Spawn-Bilinecek-Mi($durum) {
    return [bool]$durum.Spawn -or ($durum.Adimlar -notcontains 'spawn-v1')
}

function Npc-Komutlari($durum, [string]$ad) {
    if (-not $durum.Spawn) { return }   # spawn kurulamadıysa bir sonraki çalıştırmaya kalır
    $p = @($durum.Spawn -split ' ' | ForEach-Object { [int]$_ })
    $ofset = $NpcKonumlari[$ad]
    $konum = "$($p[0] + $ofset[0] + 0.5) $($p[1]) $($p[2] + $ofset[1] + 0.5)"
    $dunya = Dunya-Adi
    $tanim = switch ($ad) {
        'rehber' { @{ Tur = 'VILLAGER'; Isim = '<light_purple><b>Rehber</b></light_purple> <gray>(tıkla)'; Eylemler = @(
            'message <dark_gray>━━━━━━━━ <light_purple><b>Rehber</b></light_purple> ━━━━━━━━',
            'message <yellow>/tpr</yellow> <gray>uzak bir yere ışınlan, kendi yerini kur',
            'message <yellow>/sethome</yellow> <gray>ev kur,</gray> <yellow>/home</yellow> <gray>eve dön',
            'message <gold>Altın kürek</gold><gray>: iki köşeye sağ tıkla, arsan korunsun',
            'message <yellow>/kit gunluk</yellow> <gray>günlük ödülün,</gray> <yellow>/kit haftalik</yellow> <gray>haftalık',
            'message <yellow>/skills</yellow> <gray>yeteneklerin,</gray> <yellow>/bal</yellow> <gray>paran,</gray> <yellow>/rules</yellow> <gray>kurallar',
            'message <gray>Madencilik ve inşa dünyaları için yanımdaki kapı bekçilerine tıkla.'
        ) } }
        'kaynak_kapisi' { @{ Tur = 'IRON_GOLEM'; Isim = '<green><b>Kaynak Dünyası</b></green> <gray>(tıkla)'; Eylemler = @(
            'message <green>Kaynak dünyasına ışınlanıyorsun!</green> <gray>Her ayın 1''inde sıfırlanır, buraya yapı yapma. Dönmek için</gray> <yellow>/spawn',
            'console_command mvtp {player} kaynak'
        ) } }
        'yaratici_kapisi' { @{ Tur = 'ALLAY'; Isim = '<aqua><b>Yaratıcı Dünya</b></aqua> <gray>(tıkla)'; Eylemler = @(
            'message <aqua>Yaratıcı dünyaya ışınlanıyorsun!</aqua> <gray>Oradaki eşyalar ayrı bir envanterde kalır. Dönmek için</gray> <yellow>/spawn',
            'console_command mvtp {player} yaratici'
        ) } }
    }
    "?npc remove $ad"   # tekrar kurulunca eylemler iki kez eklenmesin
    "npc create $ad --position $konum --world $dunya --type $($tanim.Tur) || npc create $ad --location $konum $dunya --type $($tanim.Tur)"
    "?npc displayname $ad $($tanim.Isim)"
    "?npc turn_to_player $ad true"
    foreach ($eylem in $tanim.Eylemler) { "npc action $ad ANY_CLICK add $eylem" }
}

# kits.yml'deki "kits:" altına ödül kitlerini ekler; girinti dosyadakiyle aynı tutulur.
function Kitleri-Ekle([string]$dosya) {
    $metin = [IO.File]::ReadAllText($dosya)
    $nl = if ($metin.Contains("`r`n")) { "`r`n" } else { "`n" }
    $eksikler = @($OdulKitleri | Where-Object { $metin -notmatch "(?m)^[ \t]+$($_[0]):" })
    if ($eksikler.Count -eq 0) { Tamam 'EssentialsX: ödül kitleri zaten var'; return }
    $girinti = if ($metin -match '(?m)^kits:[ \t]*\r?\n([ \t]+)\S') { $Matches[1] } else { '  ' }
    $blok = foreach ($kit in $eksikler) {
        "$girinti$($kit[0]):"
        "$girinti${girinti}delay: $($kit[1])"
        "$girinti${girinti}items:"
        foreach ($esya in $kit[2]) { "$girinti$girinti$girinti- $esya" }
    }
    $eklenecek = ($blok -join $nl) + $nl
    if ($metin -match '(?m)^kits:[ \t]*\{\}[ \t]*$') { $metin = $metin -replace '(?m)^kits:[ \t]*\{\}[ \t]*$', "kits:$nl$($eklenecek.TrimEnd())" }
    elseif ($metin -match '(?m)^kits:[ \t]*\r?\n') { $metin = ([regex]'(?m)^kits:[ \t]*\r?\n').Replace($metin, "kits:$nl$eklenecek", 1) }
    else { $metin = $metin.TrimEnd() + "${nl}kits:$nl$eklenecek" }
    [IO.File]::WriteAllText($dosya, $metin, $Utf8BomsuZ)
    Tamam "EssentialsX: ödül kitleri eklendi (/kit $(@($eksikler | ForEach-Object { $_[0] }) -join ', /kit '))"
}

# DUYURULAR.txt kullanıcının dosyası: yalnızca eksik ipuçları sona eklenir, diğer satırlara dokunulmaz.
function Duyurulara-Ekle([string]$dosya) {
    $metin = [IO.File]::ReadAllText($dosya)
    $eksik = @($EkDuyurular | Where-Object { -not $metin.Contains($_) })
    if ($eksik.Count -eq 0) { return }
    $nl = if ($metin.Contains("`r`n")) { "`r`n" } else { "`n" }
    if ($metin -and -not $metin.EndsWith("`n")) { $metin += $nl }
    [IO.File]::WriteAllText($dosya, $metin + (($eksik -join $nl) + $nl), (New-Object System.Text.UTF8Encoding $true))
    Tamam "DUYURULAR.txt: $($eksik.Count) yeni ipucu eklendi (kasaba, pazar)"
}

function Skor-Tablosu([string]$sunucuAdi, [bool]$paraVar, [bool]$kasabaVar = $false) {
    $baslik = $sunucuAdi.Replace('\', '\\').Replace('"', '\"')
    $satirlar = @(
        'scoreboard:',
        '  enabled: true',
        '  toggle-command: /skor',
        '  remember-toggle-choice: true',
        '  hidden-by-default: false',
        '  delay-on-join-milliseconds: 0',
        '  scoreboards:',
        '    ana:',
        "      title: `"&5&l$baslik`"",
        '      lines:',
        '      - "&8&m                         "',
        '      - "&7Oyuncu: &f%player%"',
        '      - "&7Rütbe: %luckperms-prefix%"'
    )
    if ($paraVar) { $satirlar += '      - "&7Para: &e%vault_eco_balance_formatted%"' }
    if ($kasabaVar) { $satirlar += '      - "&7Kasaba: &f%townyadvanced_town_unformatted%"' }
    $satirlar += @(
        '      - ""',
        '      - "&7Çevrimiçi: &a%online%"',
        '      - "&7Ping: &f%ping% ms"',
        '      - "&7Dünya: &f%world%"',
        '      - " "',
        '      - "&d/tpr &7keşfe çık"',
        '      - "&d/kit gunluk &7ödülün"',
        '      - "&8&m                         &r"'
    )
    return $satirlar
}

# Üst düzey bir YAML bölümünü (anahtarı ve altındaki girintili satırları) verilen satırlarla değiştirir.
function Yaml-Bolum-Degistir([string]$dosya, [string]$anahtar, [string[]]$yeniSatirlar, [string]$aciklama) {
    $metin = [IO.File]::ReadAllText($dosya)
    $nl = if ($metin.Contains("`r`n")) { "`r`n" } else { "`n" }
    $satirlar = New-Object System.Collections.Generic.List[string]
    $satirlar.AddRange([string[]]($metin -split '\r?\n'))
    $bas = -1
    for ($i = 0; $i -lt $satirlar.Count; $i++) { if ($satirlar[$i] -match "^$([regex]::Escape($anahtar)):") { $bas = $i; break } }
    if ($bas -lt 0) { Uyari "$aciklama yapılamadı: '$anahtar' bölümü bulunamadı ($dosya)."; return }
    $son = $bas + 1
    while ($son -lt $satirlar.Count -and ($satirlar[$son] -match '^[ \t]' -or $satirlar[$son].Trim() -eq '')) { $son++ }
    while ($son - 1 -gt $bas -and $satirlar[$son - 1].Trim() -eq '') { $son-- }   # bölümler arası boş satırlar kalsın
    $satirlar.RemoveRange($bas, $son - $bas)
    $satirlar.InsertRange($bas, $yeniSatirlar)
    [IO.File]::WriteAllText($dosya, ($satirlar -join $nl), $Utf8BomsuZ)
    Tamam $aciklama
}

# ---------------------------------------------------------------------------
# Spawn meydanı
# ---------------------------------------------------------------------------

# SNBT metni içinde tırnak ve ters bölüyü kaçırır.
function Snbt-Metin([string]$metin) { return $metin.Replace('\', '\\').Replace('"', '\"') }

function Tabela-Satiri([double]$y, [string]$metin, [string]$renk, [string]$ek = '', [string]$ekRenk = 'yellow', [switch]$Baslik) {
    $bilesen = "text:`"$(Snbt-Metin $metin)`",color:`"$renk`""
    if ($Baslik) { $bilesen += ',bold:true' }
    if ($ek) { $bilesen += ",extra:[{text:`"$(Snbt-Metin $ek)`",color:`"$ekRenk`",bold:false}]" }
    $olcek = if ($Baslik) { ',transformation:{left_rotation:[0f,0f,0f,1f],right_rotation:[0f,0f,0f,1f],translation:[0f,0f,0f],scale:[1.5f,1.5f,1.5f]}' } else { '' }
    return "?summon text_display ~ ~$y ~4 {Tags:[`"spawn_tabela`"],billboard:`"center`",shadow:true,background:0$olcek,text:{$bilesen}}"
}

# Dünyanın doğma noktasında 31x31'lik bir meydan inşa eden komutlar (konsoldaki ~ = doğma noktası).
# Doğma noktası önce zeminin üstüne taşınır; meydanın zemini onun bir altına döşenir.
function Spawn-Komutlari([string]$sunucuAdi) {
    $t = $SpawnTema
    $r = 15
    $k = New-Object System.Collections.Generic.List[string]

    # Oyuncu yokken doğma noktası yüklü olmayabilir; inşa süresince yüklü tut.
    $k.Add('forceload add ~-32 ~-32 ~32 ~32')
    $k.Add('#bekle 5')
    $k.Add('execute positioned over motion_blocking_no_leaves run setworldspawn ~ ~ ~')
    $k.Add('?gamerule minecraft:respawn_radius 0 || gamerule respawn_radius 0 || gamerule spawnRadius 0')
    $k.Add('?kill @e[type=minecraft:text_display,tag=spawn_tabela]')

    # Arazi: üstünü aç, altını doldur (göl, vadi veya deniz kenarındaysa).
    $k.Add('fill ~-18 ~ ~-18 ~18 ~19 ~18 air')
    $k.Add('?fill ~-18 ~20 ~-18 ~18 ~39 ~18 air')
    $k.Add("?fill ~-16 ~-12 ~-16 ~16 ~-2 ~16 $($t.Temel) replace #minecraft:replaceable")

    # Zemin, yollar ve orta meydan.
    $k.Add("fill ~-$r ~-1 ~-$r ~$r ~-1 ~$r $($t.Kenar)")
    $k.Add("fill ~-14 ~-1 ~-14 ~14 ~-1 ~14 $($t.Zemin)")
    $k.Add("fill ~-1 ~-1 ~-$r ~1 ~-1 ~$r $($t.Yol)")
    $k.Add("fill ~-$r ~-1 ~-1 ~$r ~-1 ~1 $($t.Yol)")
    $k.Add("fill ~-3 ~-1 ~-3 ~3 ~-1 ~3 $($t.Yol)")
    $k.Add("fill ~-2 ~-1 ~-2 ~2 ~-1 ~2 $($t.Kenar)")
    $k.Add("fill ~-1 ~-1 ~-1 ~1 ~-1 ~1 $($t.Orta)")
    $k.Add("setblock ~ ~-1 ~ $($t.Isik)")

    # Zemine gömülü ışıklar: meydanda karanlık nokta kalmaz, canavar doğmaz.
    foreach ($x in -12, -8, -4, 0, 4, 8, 12) {
        foreach ($z in -12, -8, -4, 0, 4, 8, 12) {
            if ([Math]::Abs($x) -le 3 -and [Math]::Abs($z) -le 3) { continue }
            $k.Add("setblock ~$x ~-1 ~$z $($t.Isik)")
        }
    }

    # Köşelerde alçak duvarlı bahçeler, ortalarında ağaç.
    $i = 0
    foreach ($sx in -1, 1) {
        foreach ($sz in -1, 1) {
            $a1 = 8 * $sx; $a2 = 12 * $sx; $b1 = 8 * $sz; $b2 = 12 * $sz
            $k.Add("fill ~$(7 * $sx) ~ ~$(7 * $sz) ~$(13 * $sx) ~ ~$(13 * $sz) $($t.Duvar)")
            $k.Add("fill ~$a1 ~ ~$b1 ~$a2 ~ ~$b2 air")
            $k.Add("fill ~$a1 ~-1 ~$b1 ~$a2 ~-1 ~$b2 grass_block")
            foreach ($kose in @(@($a1, $b1), @($a1, $b2), @($a2, $b1), @($a2, $b2))) {
                $k.Add("?setblock ~$($kose[0]) ~ ~$($kose[1]) $($t.Cicekler[$i % $t.Cicekler.Count])")
                $i++
            }
            $k.Add("?place feature $($t.Agac) ~$(10 * $sx) ~ ~$(10 * $sz)")
        }
    }

    # Kenarda alçak duvar, dört yönde giriş.
    $k.Add("fill ~-$r ~ ~-$r ~$r ~ ~-$r $($t.Duvar)")
    $k.Add("fill ~-$r ~ ~$r ~$r ~ ~$r $($t.Duvar)")
    $k.Add("fill ~-$r ~ ~-$r ~-$r ~ ~$r $($t.Duvar)")
    $k.Add("fill ~$r ~ ~-$r ~$r ~ ~$r $($t.Duvar)")
    $k.Add("fill ~-1 ~ ~-$r ~1 ~ ~-$r air")
    $k.Add("fill ~-1 ~ ~$r ~1 ~ ~$r air")
    $k.Add("fill ~-$r ~ ~-1 ~-$r ~ ~1 air")
    $k.Add("fill ~$r ~ ~-1 ~$r ~ ~1 air")

    # Girişlerin iki yanında ve köşelerde fenerli direkler.
    $direkler = @(@(-2, -$r), @(2, -$r), @(-2, $r), @(2, $r), @(-$r, -2), @(-$r, 2), @($r, -2), @($r, 2),
                  @(-$r, -$r), @($r, -$r), @(-$r, $r), @($r, $r))
    foreach ($d in $direkler) {
        $k.Add("setblock ~$($d[0]) ~1 ~$($d[1]) $($t.Direk)")
        $k.Add("setblock ~$($d[0]) ~2 ~$($d[1]) $($t.Fener)")
    }

    # Orta meydana bakan banklar (merdivenin sırtı dışarıda).
    foreach ($yon in @(@('z', -5, 'north'), @('z', 5, 'south'), @('x', -5, 'west'), @('x', 5, 'east'))) {
        foreach ($aralik in @(@(-4, -3), @(3, 4))) {
            $blok = "$($t.Bank)[facing=$($yon[2])]"
            if ($yon[0] -eq 'z') { $k.Add("fill ~$($aralik[0]) ~ ~$($yon[1]) ~$($aralik[1]) ~ ~$($yon[1]) $blok") }
            else { $k.Add("fill ~$($yon[1]) ~ ~$($aralik[0]) ~$($yon[1]) ~ ~$($aralik[1]) $blok") }
        }
    }

    # Oyuncular güneye bakarak doğar; bilgi tabelası tam karşılarında.
    $k.Add((Tabela-Satiri 3.3 $sunucuAdi 'light_purple' -Baslik))
    $k.Add((Tabela-Satiri 2.9 'Hoş geldin!' 'white'))
    $k.Add((Tabela-Satiri 2.5 'İlk girişte: ' 'gray' '/register şifre şifre'))
    $k.Add((Tabela-Satiri 2.2 'Keşfe çık: ' 'gray' '/tpr'))
    $k.Add((Tabela-Satiri 1.9 'Ev kur: ' 'gray' '/sethome  /home'))
    $k.Add((Tabela-Satiri 1.6 'Arsa: ' 'gray' 'altın kürekle iki köşeye sağ tıkla'))
    $k.Add((Tabela-Satiri 1.3 'Kurallar: ' 'gray' '/rules'))

    $k.Add('?forceload remove ~-32 ~-32 ~32 ~32')
    return $k.ToArray()
}

function Dunya-Adi {
    $ad = Properties-Oku 'level-name'
    if ($ad) { return $ad }
    return 'world'
}

# ---------------------------------------------------------------------------
# Soru yardımcıları
# ---------------------------------------------------------------------------

function Sor-EvetHayir([string]$soru, [bool]$varsayilan = $true) {
    $ipucu = if ($varsayilan) { '(E/h)' } else { '(e/H)' }
    while ($true) {
        $cevap = (Read-Host "    $soru $ipucu").Trim().ToLowerInvariant()
        if ($cevap -eq '') { return $varsayilan }
        if ($cevap -in @('e', 'evet', 'y', 'yes')) { return $true }
        if ($cevap -in @('h', 'hayir', 'hayır', 'n', 'no')) { return $false }
        Bilgi 'Lütfen E (evet) veya H (hayır) yaz.'
    }
}

function Sor-Metin([string]$soru, [string]$varsayilan, [string]$desen, [string]$hataMesaji, [switch]$Gizli) {
    while ($true) {
        if ($Gizli) {
            $guvenli = Read-Host "    $soru" -AsSecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($guvenli)
            try { $cevap = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        } else {
            $cevap = Read-Host "    $soru"
        }
        $cevap = ([string]$cevap).Trim()
        if ($cevap -eq '') { return $varsayilan }
        if ($cevap -match $desen) { return $cevap }
        Bilgi $hataMesaji
    }
}

# ---------------------------------------------------------------------------
# Durum dosyası (kurulu sürüm, eklentiler, yapılan adımlar, verilen cevaplar)
# ---------------------------------------------------------------------------

function Durum-Oku {
    $durum = @{ McSurum = ''; PaperBuild = 0; JavaGerekli = 0; Eklentiler = @{}; Adimlar = @(); Gorevler = ''; Baslangic = ''
                OpIsmi = ''; SunucuAdi = ''; Spawn = '' }
    if (-not (Test-Path -LiteralPath $DurumDosyasi)) { return $durum }
    $ham = Get-Content -LiteralPath $DurumDosyasi -Raw | ConvertFrom-Json
    foreach ($alan in @('McSurum', 'Gorevler', 'Baslangic', 'OpIsmi', 'SunucuAdi', 'Spawn')) { $durum[$alan] = [string]$ham.$alan }
    $durum.PaperBuild = [int]$ham.PaperBuild
    $durum.JavaGerekli = [int]$ham.JavaGerekli
    if ($ham.Eklentiler) {
        foreach ($p in $ham.Eklentiler.PSObject.Properties) { $durum.Eklentiler[$p.Name] = @($p.Value) }
    }
    $durum.Adimlar = @($ham.Adimlar | Where-Object { $_ })
    # Kurulumun ilk sürümü bu adımları "IlkAcilis" adıyla tek seferde yapıyordu.
    if ($ham.IlkAcilis) { $durum.Adimlar += @('dunya', 'authme-ayar', 'essentials-ayar', 'op') }
    $durum.Adimlar = @($durum.Adimlar | Select-Object -Unique)
    return $durum
}

function Durum-Yaz($durum) {
    [IO.File]::WriteAllText($DurumDosyasi, ($durum | ConvertTo-Json -Depth 5), $Utf8BomsuZ)
}

function Adim-Tamam($durum, [string]$id) {
    if ($durum.Adimlar -notcontains $id) { $durum.Adimlar = @($durum.Adimlar) + $id }
}

function Eklenti-Kurulu-Mu($durum, [string]$ad) {
    return ($durum.Eklentiler.ContainsKey($ad) -and @($durum.Eklentiler[$ad]).Count -gt 0)
}

function Bekleyen-Adim-Mi($durum, [string]$id) {
    $adim = @($Adimlar | Where-Object { $_.Id -eq $id })[0]
    return ($durum.Adimlar -notcontains $id) -and (-not $adim.Eklenti -or (Eklenti-Kurulu-Mu $durum $adim.Eklenti))
}

# ---------------------------------------------------------------------------
# Paper ve eklenti sürümü seçimi
# ---------------------------------------------------------------------------

# "26.2" ve "1.21.11" gibi sürümleri sıralanabilir hale getirir; ön sürümler (pre/rc) için $null döner.
function Surum-Anahtari([string]$id) {
    if ($id -notmatch '^\d+(\.\d+){0,3}$') { return $null }
    $p = @($id.Split('.') | ForEach-Object { [int]$_ }) + @(0, 0, 0, 0)
    return ('{0:D5}.{1:D5}.{2:D5}.{3:D5}' -f $p[0], $p[1], $p[2], $p[3])
}

function Kararli-Build-Mi($build) {
    return ($build -and ($build.channel -in @('STABLE', 'RECOMMENDED')) -and $build.downloads.'server:default'.url)
}

function Paper-KararliBuild($surumKaydi) {
    $id = $surumKaydi.version.id
    try {
        $hepsi = @(Json-Al "$PaperApi/versions/$id/builds")
        $uygun = @($hepsi | Where-Object { Kararli-Build-Mi $_ } | Sort-Object { [int]$_.id } -Descending)
        if ($uygun.Count -gt 0) { return $uygun[0] }
        if ($hepsi.Count -gt 0 -and $hepsi[0].channel) { return $null }   # liste geldi ama kararlı build yok
    } catch { }
    # Toplu liste alınamadıysa build'leri tek tek dene.
    foreach ($no in @(@($surumKaydi.builds) | Sort-Object { [int]$_ } -Descending | Select-Object -First 10)) {
        try { $build = Json-Al "$PaperApi/versions/$id/builds/$no" } catch { continue }
        if (Kararli-Build-Mi $build) { return $build }
    }
    return $null
}

function Eklenti-Surumlerini-Al($eklenti) {
    $yukleyiciler = [Uri]::EscapeDataString('["paper","spigot","bukkit"]')
    $sonHata = $null
    foreach ($slug in @($eklenti.Slug)) {
        try { return @(Json-Al "$ModrinthApi/project/$slug/version?loaders=$yukleyiciler") }
        catch { $sonHata = $_.Exception.Message }
    }
    Uyari "$($eklenti.Ad) sürüm listesi alınamadı: $sonHata"
    return @()
}

# Verilen Minecraft sürümü için eklentinin en uygun sürümü: Paper jar'ı ve "release" olanlar öncelikli.
function Eklenti-Surumu-Bul($eklenti, [string]$mcSurum) {
    $uygun = @($eklenti.Surumler | Where-Object { (@($_.game_versions) -contains $mcSurum) -and $_.version_type -ne 'alpha' })
    if ($uygun.Count -eq 0 -and $eklenti.HerSurum) { $uygun = @($eklenti.Surumler | Where-Object { $_.version_type -eq 'release' }) }
    if ($uygun.Count -eq 0) { return $null }
    $paperIcin = @($uygun | Where-Object { @($_.loaders) -contains 'paper' })
    if ($paperIcin.Count -gt 0) { $uygun = $paperIcin }
    $sirali = @($uygun | Sort-Object -Property @{ Expression = { if ($_.version_type -eq 'release') { 0 } else { 1 } }; Ascending = $true },
                                               @{ Expression = { $_.date_published }; Descending = $true })
    return $sirali[0]
}

# Bir Paper sürümü için aday: kararlı build ve hangi eklentilerin uyumlu olduğu. Build yoksa Build = $null.
function Aday-Olustur([string]$id, $kayit) {
    $build = if ($kayit) { Paper-KararliBuild $kayit } else { $null }
    $bilinenler = @($Eklentiler | Where-Object { $_.Surumler.Count -gt 0 })
    $uyumlu = @($bilinenler | Where-Object { Eklenti-Surumu-Bul $_ $id } | ForEach-Object { $_.Ad })
    return [pscustomobject]@{
        Id     = $id
        Kayit  = $kayit
        Build  = $build
        Uyumlu = $uyumlu
        Eksik  = @($bilinenler | Where-Object { $uyumlu -notcontains $_.Ad } | ForEach-Object { $_.Ad })
    }
}

# AuthMe ile uyumlu en yeni birkaç Paper sürümünden en çok eklentiyi destekleyeni seçer (eşitlikte yenisi).
# Kurulu sürümden eskisi seçilmez: dünya eski sürüme döndürülemez.
function Surum-Sec($paperSurumleri, [string]$enAz) {
    $zorunlular = @($Eklentiler | Where-Object { $_.Zorunlu })
    $enAzAnahtar = if ($enAz) { Surum-Anahtari $enAz } else { $null }
    $secilen = $null
    $sayi = 0
    foreach ($kayit in $paperSurumleri) {
        if ($sayi -ge $AdayLimiti) { break }
        $id = $kayit.version.id
        if ($enAzAnahtar -and (Surum-Anahtari $id) -lt $enAzAnahtar) { break }
        if (@($zorunlular | Where-Object { -not (Eklenti-Surumu-Bul $_ $id) }).Count -gt 0) { continue }
        $aday = Aday-Olustur $id $kayit
        if (-not $aday.Build) { continue }
        $sayi++
        if (-not $secilen -or $aday.Uyumlu.Count -gt $secilen.Uyumlu.Count) { $secilen = $aday }
    }
    return $secilen
}

# Bir eklenti sürümünden indirilecek dosyalar: ana jar ve bulunan ek jar'lar.
function Eklenti-Dosyalari($eklenti, $surum, [switch]$Sessiz) {
    $dosyalar = @($surum.files)
    $ana = @($dosyalar | Where-Object { $_.primary })[0]
    if (-not $ana) { $ana = $dosyalar[0] }
    $secilenler = @($ana)
    foreach ($desen in $eklenti.EkDosyalar) {
        $ek = @($dosyalar | Where-Object { $_.filename -match $desen -and $_.filename -ne $ana.filename })[0]
        if ($ek) { $secilenler += $ek }
        elseif (-not $Sessiz) { Uyari "$($eklenti.Ad) için ek dosya bulunamadı ($desen). Gerekirse elle indir: $($eklenti.Sayfa)" }
    }
    return $secilenler
}

# Her eklenti için ne yapılacağı: yeni | guncelle | guncel | uyumsuz | devre-disi | sorulacak
function Eklenti-Plani($durum, $secim, [bool]$mcDegisiyor) {
    foreach ($eklenti in $Eklentiler) {
        $surum = Eklenti-Surumu-Bul $eklenti $secim.Id
        $eskiler = @($durum.Eklentiler[$eklenti.Ad] | Where-Object { $_ })
        $kurulu = $eskiler.Count -gt 0
        $islem = 'uyumsuz'
        if (-not $surum) {
            # Eski sürüm için kurulmuş jar yeni Minecraft sürümünde sunucuyu bozabilir.
            if ($kurulu) { $islem = if ($mcDegisiyor) { 'devre-disi' } else { 'guncel' } }
        } else {
            $beklenen = @(Eklenti-Dosyalari $eklenti $surum -Sessiz | ForEach-Object { $_.filename })
            $yerinde = @($beklenen | Where-Object { ($eskiler -notcontains $_) -or -not (Test-Path -LiteralPath (Join-Path $EklentiDir $_)) }).Count -eq 0
            if ($yerinde) { $islem = 'guncel' }
            elseif ($kurulu) { $islem = 'guncelle' }
            elseif ($eklenti.Ad -eq 'DiscordSRV') { $islem = 'sorulacak' }
            else { $islem = 'yeni' }
        }
        [pscustomobject]@{ Eklenti = $eklenti; Surum = $surum; Eskiler = $eskiler; Islem = $islem }
    }
}

# ---------------------------------------------------------------------------
# Java
# ---------------------------------------------------------------------------

function Kurulu-Java-Surumu {
    $release = Join-Path $JavaDir 'release'
    if (-not (Test-Path -LiteralPath $JavaExe) -or -not (Test-Path -LiteralPath $release)) { return 0 }
    $eslesme = Select-String -LiteralPath $release -Pattern '^JAVA_VERSION="(\d+)' | Select-Object -First 1
    if ($eslesme) { return [int]$eslesme.Matches[0].Groups[1].Value }
    return 0
}

function Java-LTS-Sec([int]$gerekli) {
    try {
        $bilgi = Json-Al "$AdoptiumApi/info/available_releases"
        $uygun = @($bilgi.available_lts_releases | ForEach-Object { [int]$_ } | Where-Object { $_ -ge $gerekli } | Sort-Object)
        if ($uygun.Count -gt 0) { return $uygun[0] }
    } catch { }
    return $gerekli
}

function Java-Kur([int]$surum) {
    $mimari = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x64' }
    $paket = $null
    foreach ($tur in @('jre', 'jdk')) {
        try {
            $sonuc = @(Json-Al "$AdoptiumApi/assets/latest/$surum/hotspot?architecture=$mimari&image_type=$tur&os=windows&vendor=eclipse")
            $zipli = @($sonuc | Where-Object { $_.binary.package.link -like '*.zip' })
            if ($zipli.Count -gt 0) { $paket = $zipli[0].binary.package; break }
        } catch { }
    }
    if (-not $paket) { throw "Java $surum indirilemedi (api.adoptium.net). İnternet bağlantını kontrol edip tekrar dene." }

    # Taşıma aynı diskte olsun diye geçici klasör sunucu klasörünün içinde.
    $gecici = Join-Path $Kok '.gecici-java'
    if (Test-Path -LiteralPath $gecici) { Remove-Item -LiteralPath $gecici -Recurse -Force }
    New-Item -ItemType Directory -Path $gecici | Out-Null
    try {
        $zip = Join-Path $gecici 'java.zip'
        Bilgi "İndiriliyor: $($paket.name)"
        Dosya-Indir $paket.link $zip
        Hash-Dogrula $zip 'SHA256' $paket.checksum
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $acilan = Join-Path $gecici 'ac'
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $acilan)
        $ic = @(Get-ChildItem -LiteralPath $acilan -Directory)[0]
        if (Test-Path -LiteralPath $JavaDir) { Remove-Item -LiteralPath $JavaDir -Recurse -Force }
        Move-Item -LiteralPath $ic.FullName -Destination $JavaDir
    } finally {
        Remove-Item -LiteralPath $gecici -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Eklentiler
# ---------------------------------------------------------------------------

function Eklenti-Kur($eklenti, $surum, $eskiDosyalar) {
    $yeniAdlar = @()
    foreach ($dosya in @(Eklenti-Dosyalari $eklenti $surum)) {
        Dogrulanmis-Indir $dosya.url (Join-Path $EklentiDir $dosya.filename) 'SHA512' $dosya.hashes.sha512
        $yeniAdlar += $dosya.filename
    }
    # Eski sürümün jar'larını kaldır; iki sürüm aynı anda yüklenirse sunucu hata verir.
    foreach ($eski in @($eskiDosyalar)) {
        if ($eski -and ($yeniAdlar -notcontains $eski)) {
            Remove-Item -LiteralPath (Join-Path $EklentiDir $eski) -Force -ErrorAction SilentlyContinue
        }
    }
    Tamam "$($eklenti.Ad) $($surum.version_number): $($yeniAdlar -join ', ')"
    return $yeniAdlar
}

# Paper alt klasörlerdeki jar'ları yüklemez; eklenti uyumlu sürüm çıkınca KUR.bat yeniden kurar.
function Eklenti-Devre-Disi($eklenti, $dosyalar) {
    New-Item -ItemType Directory -Force -Path $DevreDisiDir | Out-Null
    foreach ($dosya in @($dosyalar)) {
        $yol = Join-Path $EklentiDir $dosya
        if (Test-Path -LiteralPath $yol) { Move-Item -LiteralPath $yol -Destination (Join-Path $DevreDisiDir $dosya) -Force }
    }
    Uyari "$($eklenti.Ad) yeni sürümle uyumlu değil, plugins\devre-disi klasörüne taşındı."
}

function Eklenti-Dosyasi([string]$klasorDeseni, [string]$dosyaAdi) {
    if (-not (Test-Path -LiteralPath $EklentiDir)) { return $null }
    $klasor = @(Get-ChildItem -LiteralPath $EklentiDir -Directory | Where-Object { $_.Name -like $klasorDeseni })[0]
    if (-not $klasor) { return $null }
    $dosya = Join-Path $klasor.FullName $dosyaAdi
    if (Test-Path -LiteralPath $dosya) { return $dosya }
    return $null
}

function Paper-Ayar-Dosyasi([string]$dosyaAdi) {
    $dosya = Join-Path (Join-Path $SunucuDir 'config') $dosyaAdi
    if (Test-Path -LiteralPath $dosya) { return $dosya }
    return $null
}

function Yaml-Degistir([string]$dosya, [string]$desen, [string]$yeni, [string]$aciklama) {
    $metin = [IO.File]::ReadAllText($dosya)
    $rx = New-Object System.Text.RegularExpressions.Regex($desen, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $rx.IsMatch($metin)) { Uyari "$aciklama yapılamadı: ayar bulunamadı ($dosya)."; return }
    [IO.File]::WriteAllText($dosya, $rx.Replace($metin, $yeni, 1), $Utf8BomsuZ)
    Tamam $aciklama
}

# ---------------------------------------------------------------------------
# Sunucu dosyaları
# ---------------------------------------------------------------------------

# .properties dosyaları için ASCII dışı karakterleri \uXXXX olarak yazar.
function Properties-Kacisla([string]$metin) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($karakter in $metin.ToCharArray()) {
        if ([int]$karakter -lt 128) { [void]$sb.Append($karakter) }
        else { [void]$sb.AppendFormat('\u{0:x4}', [int]$karakter) }
    }
    return $sb.ToString()
}

function Rastgele-Sifre {
    $baytlar = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($baytlar)
    return (($baytlar | ForEach-Object { $_.ToString('x2') }) -join '')
}

function ServerProperties-Yaz([string]$sunucuAdi) {
    $s = [char]0x00A7   # Minecraft renk kodu işareti
    $motd = (Properties-Kacisla "${s}d${s}l$sunucuAdi") + '\n' + (Properties-Kacisla "${s}7Hoş geldin! İlk girişte /register şifre şifre")
    $satirlar = @(
        '# Kurulum scripti tarafindan olusturuldu. Degisiklikten sonra sunucuyu yeniden baslat.',
        "motd=$motd",
        'online-mode=false',
        'enforce-secure-profile=false',
        'gamemode=survival',
        'difficulty=normal',
        'pvp=true',
        'white-list=false',
        'enforce-whitelist=false',
        'max-players=20',
        'view-distance=10',
        'simulation-distance=8',
        'spawn-protection=16',
        'enable-command-block=false',
        'server-port=25565'
    )
    [IO.File]::WriteAllText($PropertiesDosyasi, (($satirlar -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
}

# Kurulum, gece restart ve saatlik yedek açık sunucuya RCON ile komut gönderir. Şifre rastgeledir ve
# yalnızca bu bilgisayardaki scriptler kullanır; tünel sadece oyun portunu (25565) dışarı açar.
function Rcon-Ayarla {
    if ((Properties-Oku 'enable-rcon') -eq 'true' -and (Properties-Oku 'rcon.password')) { return $false }
    $degerler = @{ 'enable-rcon' = 'true'; 'rcon.password' = (Rastgele-Sifre); 'broadcast-rcon-to-ops' = 'false' }
    if (-not (Properties-Oku 'rcon.port')) { $degerler['rcon.port'] = '25575' }
    Properties-Ayarla $degerler
    return $true
}

function Bellek-Sec {
    $toplamGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $ram = if ($toplamGb -le 4) { '1536M' } elseif ($toplamGb -le 6) { '2G' } elseif ($toplamGb -le 10) { '3G' } elseif ($toplamGb -le 20) { '4G' } else { '6G' }
    return [pscustomobject]@{ ToplamGb = $toplamGb; Ram = $ram }
}

function JvmAyarlari-Sec($paperKaydi) {
    $onerilen = @($paperKaydi.version.java.flags.recommended | Where-Object { $_ -and $_ -notmatch '^-Xm[sx]' })
    # Toplu iş dosyasında sorun çıkarabilecek karakter varsa güvenli varsayılanı kullan.
    $guvenli = $onerilen.Count -gt 0 -and -not @($onerilen | Where-Object { $_ -notmatch '^-[A-Za-z0-9:+=._/-]+$' }).Count
    if ($guvenli) { return ($onerilen -join ' ') }
    return ($VarsayilanJvmAyarlari -join ' ')
}

function Ayarlar-Yaz([string]$ram, [string]$jvmAyarlari) {
    $satirlar = @(
        '@echo off',
        'rem Sunucuya ayrilan bellek. Ornek: 4G = 4 GB. Degistirdikten sonra BASLAT.bat penceresini kapatip yeniden ac.',
        "set `"RAM=$ram`"",
        'rem Java performans ayarlari. Emin degilsen dokunma.',
        "set `"JVM_FLAGS=$jvmAyarlari`""
    )
    [IO.File]::WriteAllText($AyarDosyasi, (($satirlar -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
}

function Ayarlanan-Ram {
    $ram = Get-Content -LiteralPath $AyarDosyasi | Where-Object { $_ -match '^set "RAM=(.+)"$' } | ForEach-Object { $Matches[1] } | Select-Object -First 1
    if ($ram) { return $ram }
    return '2G'
}

# ---------------------------------------------------------------------------
# Sunucuyu kurulum sırasında çalıştırma
# ---------------------------------------------------------------------------

$script:Islem = $null         # çalışan sunucu süreci
$script:OkumaGorevi = $null   # konsoldan bekleyen satır okuma
$script:Cikti = $null         # okunan konsol satırları
$script:Rcon = $null          # kurulum komutları için açık RCON bağlantısı

# Konsol çıktısını okur ve ekrana yazar; en fazla $beklemeMs kadar yeni satır bekler.
# Sunucu kapandıysa $false döner. Okunmayan çıktı dolarsa sunucu donacağı için sık çağrılmalı.
function Cikti-Bosalt([int]$beklemeMs = 0) {
    $bitis = (Get-Date).AddMilliseconds($beklemeMs)
    while ($true) {
        if (-not $script:OkumaGorevi) { $script:OkumaGorevi = $script:Islem.StandardOutput.ReadLineAsync() }
        $kalan = [int][Math]::Max(0, ($bitis - (Get-Date)).TotalMilliseconds)
        if (-not $script:OkumaGorevi.Wait($kalan)) { return $true }
        $satir = $script:OkumaGorevi.Result
        $script:OkumaGorevi = $null
        if ($null -eq $satir) { return $false }
        $script:Cikti.Add($satir)
        Write-Host "    | $satir" -ForegroundColor DarkGray
    }
}

function Bekle-Bosaltarak([double]$saniye) {
    $bitis = (Get-Date).AddSeconds($saniye)
    while ((Get-Date) -lt $bitis) { if (-not (Cikti-Bosalt 200)) { return } }
}

function Rcon-Bekle-Baglan {
    $bitis = (Get-Date).AddSeconds($RconBekleme)
    while ((Get-Date) -lt $bitis) {
        if (Rcon-Hazir) { try { return (Rcon-Baglan) } catch { } }
        if (-not (Cikti-Bosalt 1000)) { return $null }
    }
    return $null
}

# Tek bir kurulum komutunu çalıştırır (biçim için $Adimlar açıklamasına bak).
function Komut-Calistir([string]$satir) {
    if ($satir -match '^#bekle ([\d.]+)$') { Bekle-Bosaltarak ([double]$Matches[1] * $BeklemeCarpani); return }
    $istege = $satir.StartsWith('?')
    if ($istege) { $satir = $satir.Substring(1) }
    $secenekler = @($satir -split ' \|\| ')

    if (-not $script:Rcon) {
        # RCON yoksa konsola yazılır; sonuç okunamaz, yanlış seçenekler yalnızca hata satırı basar.
        foreach ($komut in $secenekler) { $script:Islem.StandardInput.WriteLine($komut) }
        $script:Islem.StandardInput.Flush()
        [void](Cikti-Bosalt 100)
        return [pscustomobject]@{ Komut = $satir; Basarili = $true; Istege = $istege; Yanit = '' }
    }
    $yanit = ''
    foreach ($komut in $secenekler) {
        try { $yanit = [string](Rcon-Gonder $script:Rcon $komut) }
        catch { $yanit = "RCON hatası: $($_.Exception.Message)" }
        [void](Cikti-Bosalt 0)
        if (($yanit -notmatch $HataDeseni) -or ($yanit -match $DegisiklikYokDeseni)) {
            return [pscustomobject]@{ Komut = $komut; Basarili = $true; Istege = $istege; Yanit = $yanit }
        }
    }
    return [pscustomobject]@{ Komut = $satir; Basarili = $false; Istege = $istege; Yanit = $yanit }
}

# Sunucuyu açar; açılınca $hazirken'i çalıştırır (içinde Komut-Calistir kullanılır), $bekleme saniye
# bekler ve kapatır. Konsol satırları sonra $script:Cikti'de bulunur.
function Sunucu-Calistir([string]$ram, [scriptblock]$hazirken = $null, [int]$bekleme = 0) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $JavaExe
    $psi.Arguments = "-Xms$ram -Xmx$ram -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8 -jar paper.jar --nogui"
    $psi.WorkingDirectory = $SunucuDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardOutputEncoding = $Utf8BomsuZ
    $script:Cikti = New-Object System.Collections.Generic.List[string]
    $script:OkumaGorevi = $null
    $script:Islem = [System.Diagnostics.Process]::Start($psi)
    try {
        $baslangic = Get-Date
        $hazir = $false
        while (-not $hazir) {
            $okunan = $script:Cikti.Count
            $acik = Cikti-Bosalt 500
            for ($i = $okunan; $i -lt $script:Cikti.Count; $i++) { if ($script:Cikti[$i] -match 'Done \([\d.,]+s\)') { $hazir = $true } }
            if (-not $hazir -and -not $acik) {
                $script:Islem.WaitForExit()
                throw "Sunucu açılırken hata verip kapandı (çıkış kodu $($script:Islem.ExitCode)). Yukarıdaki ERROR satırlarına bak."
            }
            if (-not $hazir -and ((Get-Date) - $baslangic).TotalMinutes -gt 20) { throw 'Sunucu 20 dakika içinde açılamadı.' }
        }

        if ($hazirken) {
            $script:Rcon = Rcon-Bekle-Baglan
            if (-not $script:Rcon) { Uyari 'RCON hazır olmadı; komutlar konsoldan gönderilecek ve sonuçları kontrol edilemeyecek.' }
            try { & $hazirken }
            finally { Rcon-Kapat $script:Rcon; $script:Rcon = $null }
        }
        Bekle-Bosaltarak $bekleme

        if (-not $script:Islem.HasExited) {
            $script:Islem.StandardInput.WriteLine('stop')
            $script:Islem.StandardInput.Flush()
        }
        $kapanis = (Get-Date).AddMinutes(3)
        while (Cikti-Bosalt 500) {
            if ((Get-Date) -gt $kapanis) { $script:Islem.Kill(); break }
        }
        $script:Islem.WaitForExit()
    } catch {
        if (-not $script:Islem.HasExited) { $script:Islem.Kill() }
        throw
    }
}

function Yanit-Kisalt([string]$yanit) {
    $tek = ($yanit -replace '\s+', ' ').Trim()
    if ($tek.Length -gt 120) { $tek = $tek.Substring(0, 120) + '...' }
    if (-not $tek) { return '(cevap yok)' }
    return $tek
}

# Bekleyen tek seferlik ayarları yapar: gerekirse sunucuyu açıp ayar dosyalarını oluşturur,
# dosyaları düzenler, sonra komutlar için sunucuyu bir kez daha açar.
function Adimlari-Uygula($durum, [hashtable]$secenekler) {
    $bekleyen = @($Adimlar | Where-Object {
        (Bekleyen-Adim-Mi $durum $_.Id) -and (-not $_.Kosul -or (& $_.Kosul $secenekler $durum))
    })
    $yamalar = @($bekleyen | Where-Object { $_.Yama })
    $komutAdimlari = @($bekleyen | Where-Object { $_.Komutlar })
    $dunyaYok = $durum.Adimlar -notcontains 'dunya'
    if (-not $dunyaYok -and $bekleyen.Count -eq 0) { return }

    Baslik 'Tek seferlik ayarlar'
    $ram = Ayarlanan-Ram
    if ($dunyaYok -or @($yamalar | Where-Object { -not (& $_.Dosya) }).Count -gt 0) {
        Bilgi 'Sunucu dünyayı ve eklenti ayar dosyalarını oluşturmak için bir kez açılıp kapanacak (birkaç dakika sürebilir).'
        Bilgi 'Windows Güvenlik Duvarı izin isterse "Erişime izin ver" de.'
        Sunucu-Calistir $ram
        Adim-Tamam $durum 'dunya'
        Durum-Yaz $durum
    }

    foreach ($adim in $yamalar) {
        $dosya = & $adim.Dosya
        # Sunucu açılıp kapandığı hâlde dosya yoksa eklentinin bu sürümü onu başka adla tutuyordur; tekrar denemek boşuna.
        if (-not $dosya) { Uyari "$($adim.Ad): ayar dosyası bulunamadı, bu ayar atlandı (elle yapılabilir, OKUBENI.txt)." }
        else { & $adim.Yama $dosya $secenekler $durum }
        Adim-Tamam $durum $adim.Id
    }
    Durum-Yaz $durum

    # Discord ayarlandıysa bağlantının denenmesi için de sunucu açılır.
    if ($komutAdimlari.Count -eq 0 -and -not $secenekler.DiscordToken) { return }
    Bilgi 'Rütbeler, yetkiler, dünyalar, spawn ve NPC''ler için sunucu bir kez daha açılıp kapanacak.'
    $sonraYapilacaklar = New-Object System.Collections.Generic.List[object]
    Sunucu-Calistir $ram {
        foreach ($adim in $komutAdimlari) {
            # Komutlar burada üretilir: önceki adımların sonuçlarını (ör. spawn koordinatı) kullanabilirler.
            $satirlar = @(& $adim.Komutlar $secenekler $durum | Where-Object { $_ })
            if ($satirlar.Count -eq 0) { Bilgi "$($adim.Ad): bu sefer yapılamadı (önceki bir adım eksik), sonra tekrar denenecek."; continue }
            Bilgi "$($adim.Ad)..."
            # İlk kritik hatada dur: yarım kalmış bir zeminin üstüne süsleme yapılmasın, sonraki çalıştırma baştan kurar.
            $sonuclar = New-Object System.Collections.Generic.List[object]
            foreach ($satir in $satirlar) {
                $sonuc = Komut-Calistir $satir
                if (-not $sonuc) { continue }
                $sonuclar.Add($sonuc)
                if (-not $sonuc.Basarili -and -not $sonuc.Istege) { break }
            }
            $sonuclar = $sonuclar.ToArray()
            $kritik = @($sonuclar | Where-Object { -not $_.Basarili -and -not $_.Istege })
            $atlanan = @($sonuclar | Where-Object { -not $_.Basarili -and $_.Istege })
            if ($kritik.Count -gt 0) {
                Uyari "$($adim.Ad) tamamlanamadı: $($kritik[0].Komut) -> $(Yanit-Kisalt $kritik[0].Yanit)"
                Uyari 'KUR.bat bir sonraki çalıştırmada tekrar deneyecek.'
                continue
            }
            Adim-Tamam $durum $adim.Id
            if ($adim.Hemen) { & $adim.Hemen $sonuclar $durum }
            if ($adim.Sonra) { $sonraYapilacaklar.Add(@($adim, $sonuclar)) }
            if ($atlanan.Count -eq 0) { Tamam $adim.Ad }
            else {
                Tamam "$($adim.Ad) ($($atlanan.Count) küçük adım atlandı)"
                foreach ($a in @($atlanan | Select-Object -First 3)) { Bilgi "  atlandı: $($a.Komut) -> $(Yanit-Kisalt $a.Yanit)" }
            }
        }
    } $KomutBekleme

    # server.properties sunucu kapalıyken değiştirilir.
    foreach ($is in $sonraYapilacaklar) { & $is[0].Sonra $is[1] $durum }
    if ($durum.Spawn) { Tamam "Spawn meydanı hazır: $($durum.Spawn) (çevresi $SpawnKorumasi blok korumalı)" }

    if ($secenekler.DiscordToken) {
        $hata = @($script:Cikti | Where-Object { $_ -match 'DiscordSRV' -and $_ -match '(?i)invalid.*token|token.*invalid|disallowed intents|failed to connect' })
        if ($hata.Count -gt 0) {
            Uyari 'DiscordSRV Discord''a bağlanamadı. Token''ı ve botun "Message Content Intent" ayarını kontrol et (OKUBENI.txt).'
            Uyari 'KUR.bat''ı tekrar çalıştırınca Discord ayarı yeniden sorulacak.'
            $durum.Adimlar = @($durum.Adimlar | Where-Object { $_ -ne 'discord-ayar' })
        } else {
            Tamam 'DiscordSRV hata vermedi; Discord kanalında sunucunun açıldı mesajını görmelisin'
        }
    }
    Durum-Yaz $durum
}

# ---------------------------------------------------------------------------
# playit.gg, Görev Zamanlayıcı ve Windows başlangıcı
# ---------------------------------------------------------------------------

function Playit-Kur {
    New-Item -ItemType Directory -Force -Path $PlayitDir | Out-Null
    try {
        $surum = Json-Al $PlayitApi
        $varlik = @($surum.assets | Where-Object { $_.name -eq $PlayitVarlik })[0]
        if (-not $varlik) { throw "$PlayitVarlik bulunamadı" }
        $hash = if ([string]$varlik.digest -match '^sha256:([0-9a-fA-F]{64})$') { $Matches[1] } else { $null }
        Dogrulanmis-Indir $varlik.browser_download_url $PlayitExe 'SHA256' $hash
        Tamam "playit.gg $($surum.tag_name) indirildi"
    } catch {
        Uyari "GitHub API kullanılamadı ($($_.Exception.Message)), doğrudan indiriliyor."
        Dogrulanmis-Indir "https://github.com/playit-cloud/playit-agent/releases/latest/download/$PlayitVarlik" $PlayitExe $null $null
        Tamam 'playit.gg indirildi'
    }
}

function Eski-Gorevler {
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return @() }
    return @(Get-ScheduledTask -TaskName $EskiGorevler -ErrorAction SilentlyContinue)
}

function Duyurular-Yaz {
    $satirlar = @(
        '# Her satır bir duyuru. Sunucu açıkken ve oyuncu varken 15 dakikada bir sırayla sohbete yazılır.',
        '# Satır eklemek, silmek veya değiştirmek serbest; sunucuyu yeniden başlatmaya gerek yok.',
        '# Renkler: &a yeşil  &b mavi  &d pembe  &e sarı  &6 altın  &7 gri  &f beyaz  &l kalın',
        '&7Keşfe çıkmak için &e/tpr &7yaz, seni uzak bir yere ışınlar.',
        '&7Arsanı korumak için &faltın kürekle &7iki köşesine sağ tıkla.',
        '&7Her gün &e/kit gunluk&7, her hafta &e/kit haftalik &7ile ödülünü al!',
        '&7Kazdıkça ve savaştıkça yeteneklerin gelişir: &e/skills',
        '&7Öldüysen eşyaların mezarında: öldüğün yere git ve mezara sağ tıkla.',
        '&7Madencilik için &aKaynak Dünyası&7: spawn''daki demir golem''e tıkla. Her ayın 1''inde sıfırlanır.',
        '&7İnşa denemek için &bYaratıcı Dünya&7: spawn''daki allay''e tıkla.',
        '&7Elindekini sat: &e/sell hand   &7Paran: &e/bal   &7Para gönder: &e/pay isim miktar',
        '&7Sandık marketi kur: satacağın eşyayı eline al, sandığa vur, fiyatı yaz.',
        '&7Eğilip ağaç kesersen bütün ağaç birden düşer (VeinMiner).',
        '&7Skor tablosunu gizlemek veya açmak için: &e/skor',
        '&7Kuralları unutma: &e/rules   &7Yöneticiye yaz: &e/helpop mesaj'
    ) + $EkDuyurular
    [IO.File]::WriteAllText($DuyuruDosyasi, (($satirlar -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $true))
}

function Kisayol-Olustur([string]$kisayolYolu, [string]$hedef) {
    $kabuk = New-Object -ComObject WScript.Shell
    $kisayol = $kabuk.CreateShortcut($kisayolYolu)
    $kisayol.TargetPath = $hedef
    $kisayol.WorkingDirectory = $Kok
    $kisayol.WindowStyle = 7   # simge durumunda başlat
    $kisayol.Save()
}

# ---------------------------------------------------------------------------
# Ana akış
# ---------------------------------------------------------------------------

function Ana {
    Write-Host ''
    Write-Host '  =====================================================' -ForegroundColor Cyan
    Write-Host '    Minecraft Paper Sunucusu - Otomatik Kurulum' -ForegroundColor Cyan
    Write-Host '  =====================================================' -ForegroundColor Cyan
    Bilgi "Klasör: $Kok"

    if (Sunucu-Acik-Mi) {
        Uyari 'Sunucu şu an açık görünüyor. Önce sunucu penceresine stop yazıp kapat, sonra KUR.bat''ı tekrar çalıştır.'
        return
    }
    if ($Kok -match 'OneDrive') {
        Uyari 'Klasör OneDrive içinde. Senkronizasyon dünya dosyalarını bozabilir; C:\MinecraftSunucu gibi bir yere taşıman önerilir.'
    }

    # --- 1. Bilgi toplama (henüz hiçbir şey değişmiyor) -------------------
    Baslik 'Bilgiler toplanıyor (henüz hiçbir şey değiştirilmiyor)'
    $durum = Durum-Oku
    $paperKurulu = Test-Path -LiteralPath (Join-Path $SunucuDir 'paper.jar')
    $kuruluSurum = if ($paperKurulu -and $durum.McSurum) { $durum.McSurum } else { $null }
    $bellek = Bellek-Sec
    Bilgi "Bilgisayarın belleği: $($bellek.ToplamGb) GB -> sunucuya $($bellek.Ram) ayrılacak"

    Bilgi 'Paper sürümleri alınıyor...'
    $paperYaniti = Json-Al "$PaperApi/versions"
    $paperSurumleri = @($paperYaniti.versions |
        Where-Object { (Surum-Anahtari $_.version.id) -and @($_.builds).Count -gt 0 } |
        Sort-Object { Surum-Anahtari $_.version.id } -Descending)
    if ($paperSurumleri.Count -eq 0) { throw 'Paper sürüm listesi boş geldi.' }

    Bilgi "Eklenti sürümleri alınıyor ($($Eklentiler.Count) eklenti)..."
    foreach ($eklenti in $Eklentiler) { $eklenti.Surumler = @(Eklenti-Surumlerini-Al $eklenti) }
    if (@($Eklentiler | Where-Object { $_.Zorunlu -and $_.Surumler.Count -eq 0 }).Count -gt 0) {
        throw 'AuthMe eklentisi bilgisi alınamadı. AuthMe olmadan herkes senin adınla girebilir; güvenlik için kurulum durduruldu. Biraz sonra tekrar dene.'
    }

    $secim = Surum-Sec $paperSurumleri $kuruluSurum
    $kuruluAday = $null
    if ($kuruluSurum) {
        $kuruluKayit = @($paperSurumleri | Where-Object { $_.version.id -eq $kuruluSurum })[0]
        $kuruluAday = Aday-Olustur $kuruluSurum $kuruluKayit
        if (-not $secim) { $secim = $kuruluAday }
    }
    if (-not $secim) { throw 'AuthMe ile uyumlu, kararlı bir Paper sürümü bulunamadı. Biraz sonra tekrar dene.' }
    $enYeni = $paperSurumleri[0].version.id

    # Minecraft sürümü yükselecekse önce sor; dünya yükseltmesi geri alınamaz.
    $mcDegisiyor = [bool]($kuruluSurum -and ($secim.Id -ne $kuruluSurum))
    if ($mcDegisiyor) {
        Baslik 'Yeni Minecraft sürümü'
        Bilgi "Kurulu: $kuruluSurum ($($kuruluAday.Uyumlu.Count) eklenti uyumlu)  ->  Yeni: $($secim.Id) ($($secim.Uyumlu.Count) eklenti uyumlu)"
        Uyari 'Dünyan yeni sürüme yükseltilir ve bu geri alınamaz (öncesinde yedek alınır).'
        if (-not (Sor-EvetHayir 'Sürüm güncellensin mi?' $false)) {
            $secim = $kuruluAday
            $mcDegisiyor = $false
        }
    }
    $paperIndirilecek = [bool]($secim.Build -and (-not $paperKurulu -or $mcDegisiyor -or $durum.PaperBuild -ne [int]$secim.Build.id))

    $javaGerekli = [int]$secim.Kayit.version.java.version.minimum
    if ($javaGerekli -lt 17) { $javaGerekli = [int]$durum.JavaGerekli }
    if ($javaGerekli -lt 17) { $javaGerekli = if ([int]$secim.Id.Split('.')[0] -ge 26) { 25 } else { 21 } }

    $plan = @(Eklenti-Plani $durum $secim $mcDegisiyor)
    $planDiscord = @($plan | Where-Object { $_.Eklenti.Ad -eq 'DiscordSRV' })[0]
    $planChunky = @($plan | Where-Object { $_.Eklenti.Ad -eq 'Chunky' })[0]
    $propertiesVar = Test-Path -LiteralPath $PropertiesDosyasi
    $dunyaVar = $durum.Adimlar -contains 'dunya'

    # --- 2. Plan ve onay -------------------------------------------------
    Baslik 'Yapılacaklar'
    if (-not $kuruluSurum) {
        if ($secim.Id -ne $enYeni) {
            Bilgi "En yeni sürüm $enYeni; $($secim.Id) ile daha çok eklenti uyumlu olduğu için o seçildi."
            Bilgi "ViaVersion sayesinde $enYeni kullanan oyuncular da girebilir."
        }
        Bilgi "* Paper sunucusu kurulacak: Minecraft $($secim.Id) (build $($secim.Build.id))"
    } elseif ($mcDegisiyor) {
        Bilgi "* GÜNCELLEME: Minecraft $kuruluSurum -> $($secim.Id) (önce yedek alınır)"
    } elseif ($paperIndirilecek) {
        Bilgi "* Paper güncellenecek: build $($durum.PaperBuild) -> $($secim.Build.id) (Minecraft sürümü aynı)"
    } else {
        Bilgi "* Paper güncel: Minecraft $($secim.Id)"
    }
    Bilgi "* Java ${javaGerekli}: gerekirse bu klasöre indirilecek (sistemine bir şey kurulmaz)"
    foreach ($p in $plan) {
        $ad = $p.Eklenti.Ad
        switch ($p.Islem) {
            'yeni'       { Bilgi "* Eklenti kurulacak:  $ad $($p.Surum.version_number) - $($p.Eklenti.Aciklama)" }
            'guncelle'   { Bilgi "* Eklenti güncellenecek: $ad -> $($p.Surum.version_number)" }
            'guncel'     { Bilgi "* Eklenti güncel:     $ad" }
            'sorulacak'  { Bilgi "* $ad - $($p.Eklenti.Aciklama): Discord bağlantısı isteyip istemediğin sorulacak" }
            'devre-disi' { Uyari "$ad yeni sürümle uyumlu değil, devre dışı bırakılacak (uyumlu sürüm çıkınca KUR.bat geri kurar)" }
            'uyumsuz'    { Uyari "$ad Minecraft $($secim.Id) ile uyumlu bulunamadı, atlanacak. Elle kurmak için: $($p.Eklenti.Sayfa)" }
        }
    }
    if (-not (Test-Path -LiteralPath $PlayitExe)) { Bilgi '* playit.gg tünel programı indirilecek' }
    if (-not $propertiesVar) {
        Bilgi "* Ayarlar: survival, normal zorluk, whitelist kapalı, TLauncher girişi açık (online-mode=false), bellek $($bellek.Ram)"
    }
    if (-not $propertiesVar -or (Properties-Oku 'enable-rcon') -ne 'true') {
        Bilgi '* RCON açılacak (rastgele şifreli; kurulum, gece restart ve saatlik yedek bununla çalışır, tünelden dışarı açılmaz)'
    }
    if ($durum.Adimlar -notcontains 'spawn-v1') {
        $not = if ($dunyaVar) { 'var olan dünyada ayrıca sorulacak' } else { 'canavar doğmaz, çevresi korumalı' }
        Bilgi "* Spawn meydanı inşa edilecek: 31x31, koyu tema, bahçeler, bilgi tabelası ($not)"
    }
    if ($durum.Adimlar -notcontains 'oyun-kurallari') { Bilgi "* Oyun kuralları: uyku %50, dünya sınırı $DunyaSiniri blok, /tpr ile rastgele ışınlanma" }
    if ($durum.Adimlar -notcontains 'paper-antixray') { Bilgi '* X-ray koruması açılacak (Paper)' }
    $planda = { param($ad) @($plan | Where-Object { $_.Eklenti.Ad -eq $ad -and $_.Islem -in @('yeni', 'guncelle', 'guncel') }).Count -gt 0 }
    if ((& $planda 'Multiverse-Core') -and (& $planda 'Multiverse-Inventories') -and $durum.Adimlar -notcontains 'dunyalar-v1') {
        Bilgi '* Ek dünyalar: Kaynak Dünyası (her ayın 1''inde sıfırlanır) ve Yaratıcı Dünya (düz, creative, ayrı envanter)'
    }
    if ((& $planda 'FancyNpcs') -and $durum.Adimlar -notcontains 'npc-rehber') { Bilgi '* Spawn''a rehber NPC ve dünyalara götüren kapı bekçileri' }
    if ((& $planda 'EssentialsX') -and $durum.Adimlar -notcontains 'odul-kitleri') { Bilgi '* Ödül kitleri: /kit gunluk (24 saatte bir) ve /kit haftalik' }
    if ((& $planda 'TAB') -and $durum.Adimlar -notcontains 'tab-skor') { Bilgi '* Sağda Türkçe skor tablosu (/skor ile gizlenir)' }
    if ((& $planda 'Towny') -and $durum.Adimlar -notcontains 'towny-ayar') { Bilgi '* Kasabalar: kurmak 100 para, günlük bakım ücreti yok (oyuncular girmese de kasaba silinmez)' }
    if (-not (Test-Path -LiteralPath $DuyuruDosyasi)) { Bilgi '* 15 dakikada bir Türkçe ipucu duyuruları (DUYURULAR.txt''den değiştirilebilir)' }
    $eskiGorevler = @(Eski-Gorevler)
    if ($eskiGorevler.Count -gt 0) {
        Bilgi '* Görev Zamanlayıcı''daki eski görevler kaldırılacak: gece restart ve saatlik yedek artık sunucuyla birlikte'
        Bilgi '  açılan gizli yardımcıda çalışır (oyun oynarken pencere açılıp oyunu alta atmaz)'
    }
    Bilgi '* Gerekirse sunucu 1-2 kez açılıp kapanacak (dünya, Türkçe ayarlar, rütbeler, yetkiler, spawn, NPC''ler)'
    Write-Host ''
    if (-not (Sor-EvetHayir 'Devam edilsin mi?')) { Bilgi 'Kurulum iptal edildi, hiçbir şey değiştirilmedi.'; return }

    $eulaDosyasi = Join-Path $SunucuDir 'eula.txt'
    $eulaKabul = (Test-Path -LiteralPath $eulaDosyasi) -and ((Get-Content -LiteralPath $eulaDosyasi -Raw) -match '(?m)^eula=true')
    if (-not $eulaKabul) {
        Baslik 'Minecraft Kullanım Sözleşmesi (EULA)'
        Bilgi 'Sunucu çalıştırmak için Mojang''ın sözleşmesini kabul etmen gerekiyor:'
        Bilgi 'https://aka.ms/MinecraftEULA'
        Bilgi '(BlueMap de haritayı çizmek için bu sözleşme kapsamında Minecraft dosyalarını indirir.)'
        if (-not (Sor-EvetHayir 'Sözleşmeyi okudum ve kabul ediyorum' $false)) {
            Bilgi 'Sözleşme kabul edilmeden sunucu çalışamaz. Kurulum durduruldu.'
            return
        }
    }

    # --- 3. Sorular (sonrası kendi kendine çalışır) ---------------------
    Baslik 'Birkaç soru (sonrası kendi kendine ilerler)'
    $secenekler = @{ OpIsmi = $durum.OpIsmi; DiscordToken = $null; DiscordKanal = $null; ChunkyBaslat = $false; SunucuAdi = $durum.SunucuAdi; SesHost = $null }
    if (-not $propertiesVar) {
        $secenekler.SunucuAdi = Sor-Metin 'Sunucunun adı ne olsun? (Enter: Bizim Sunucu)' 'Bizim Sunucu' '^[^\\\r\n]{1,40}$' 'En fazla 40 karakter yaz, ters bölü (\) kullanma.'
    }
    if (-not $secenekler.SunucuAdi) { $secenekler.SunucuAdi = 'Bizim Sunucu' }
    $durum.SunucuAdi = $secenekler.SunucuAdi
    # Yönetici ismi hem op hem [Yönetici] rütbesi için gerekir; önceki kurulumda kaydedilmediyse tekrar sorulur.
    $rutbeBekliyor = $durum.Adimlar -notcontains 'rutbeler'
    if (-not $secenekler.OpIsmi -and ($durum.Adimlar -notcontains 'op' -or $rutbeBekliyor)) {
        Bilgi 'Yönetici olacak Minecraft ismin nedir? TLauncher''da kullandığın isim.'
        $secenekler.OpIsmi = Sor-Metin 'İsmin (boş bırakırsan atlanır):' '' '^[A-Za-z0-9_]{3,16}$' 'İsim 3-16 karakter olmalı; sadece harf, rakam ve _ kullanılabilir.'
        if (-not $secenekler.OpIsmi) { Adim-Tamam $durum 'op' }
        $durum.OpIsmi = [string]$secenekler.OpIsmi
    }
    if ($dunyaVar -and $durum.Adimlar -notcontains 'spawn-v1') {
        Bilgi 'Dünyanın doğma noktasına koyu temalı spawn meydanı kurulabilir.'
        Uyari 'Doğma noktası çevresindeki 37x37 blokluk alandaki arazi ve yapılar silinip yerine meydan kurulur.'
        if (-not (Sor-EvetHayir 'Spawn meydanı kurulsun mu?' $false)) { Adim-Tamam $durum 'spawn-v1' }
    }
    $discordKurulacak = $false   # yalnızca henüz kurulu değilse ("sorulacak") anlamlı
    if ($planDiscord.Surum -and $durum.Adimlar -notcontains 'discord-ayar') {
        Bilgi 'Discord bağlantısı için bir Discord botu gerekir (adımlar OKUBENI.txt içinde, 5 dakika sürer).'
        if (Sor-EvetHayir 'Discord bağlantısını şimdi ayarlamak ister misin?' $false) {
            $secenekler.DiscordToken = Sor-Metin 'Bot token (yazarken görünmez; boş = atla):' '' '^[\w-]{20,}\.[\w-]{4,}\.[\w-]{20,}$' 'Bu bir bot token gibi görünmüyor. Discord Developer Portal > Bot > Reset Token ile aldığın değeri yapıştır.' -Gizli
            if ($secenekler.DiscordToken) {
                $secenekler.DiscordKanal = Sor-Metin 'Sohbet kanalının ID''si (sadece rakam; boş = atla):' '' '^\d{17,20}$' 'Kanal ID 17-20 haneli bir sayıdır. Discord''da kanala sağ tık > Kanal ID''sini Kopyala.'
            }
            if (-not $secenekler.DiscordKanal) { $secenekler.DiscordToken = $null; Bilgi 'Discord atlandı.' }
            else { $discordKurulacak = $true }
        }
    }
    $chunkyVar = $planChunky.Islem -in @('yeni', 'guncelle', 'guncel') -and $planChunky.Surum
    if ($chunkyVar -and $durum.Adimlar -notcontains 'chunky-baslat') {
        Bilgi "Dünya önceden oluşturulursa keşfederken kasma azalır ($ChunkyYaricap blok yarıçap, arka planda 30-60 dk sürer)."
        if (Sor-EvetHayir 'Dünya önceden oluşturulsun mu?') { $secenekler.ChunkyBaslat = $true } else { Adim-Tamam $durum 'chunky-baslat' }
    }
    $sesliPlanda = & $planda 'SimpleVoiceChat'
    if ($sesliPlanda -and $durum.Adimlar -notcontains 'sesli-sohbet') {
        Bilgi 'Sesli sohbet için playit.gg''de ikinci bir tünel gerekir (tür: "MC: Simple Voice Chat", port 24454; OKUBENI.txt).'
        $secenekler.SesHost = Sor-Metin 'O tünelin adresi varsa yapıştır (ör. abc.gl.at.ply.gg:12345; boş = sonra):' '' '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(:\d{1,5})?$' 'Bu bir adres gibi görünmüyor; playit.gg''deki tünel adresini kopyala (ör. abc.gl.at.ply.gg:12345).'
    }
    # Gece restart ve saatlik yedek yalnızca ilk kez sorulur; KUR.bat tekrar çalıştırılınca cevap korunur.
    if ($durum.Gorevler -eq '') {
        Bilgi "Sunucu açıkken her gece $RestartSaati otomatik restart ve saatlik yedek yapılabilir."
        $durum.Gorevler = if (Sor-EvetHayir 'Gece restart ve saatlik yedek açılsın mı?') { 'evet' } else { 'hayir' }
    }
    $sunucuKisayolu = Join-Path $BaslangicDir 'Minecraft Sunucusu.lnk'
    $tunelKisayolu = Join-Path $BaslangicDir 'Minecraft Tuneli.lnk'
    $kisayolKur = (Test-Path -LiteralPath $sunucuKisayolu) -and (Test-Path -LiteralPath $tunelKisayolu)
    if (-not $kisayolKur -and $durum.Baslangic -eq '') {
        $kisayolKur = Sor-EvetHayir 'Bilgisayar açılınca sunucu ve tünel otomatik başlasın mı?'
    }
    $durum.Baslangic = if ($kisayolKur) { 'evet' } else { 'hayir' }

    New-Item -ItemType Directory -Force -Path $SunucuDir, $EklentiDir | Out-Null
    $luckPermsYeni = -not (Test-Path -LiteralPath (Join-Path $EklentiDir 'LuckPerms'))
    if (-not $luckPermsYeni) { Adim-Tamam $durum 'luckperms-yaml' }   # mevcut yetkiler H2'de kalır

    # --- 4. Java ---------------------------------------------------------
    Baslik 'Java'
    $kuruluJava = Kurulu-Java-Surumu
    if ($kuruluJava -ge $javaGerekli) {
        Tamam "Java $kuruluJava zaten kurulu"
    } else {
        Java-Kur (Java-LTS-Sec $javaGerekli)
        Tamam "Java $(Kurulu-Java-Surumu) kuruldu: $JavaDir"
    }

    # --- 5. Paper ve eklentiler -----------------------------------------
    Baslik 'Paper sunucusu'
    if ($mcDegisiyor) {
        Bilgi 'Güncellemeden önce yedek alınıyor...'
        & (Join-Path $AraclarDir 'yedekle.ps1') -Otomatik
    }
    if ($paperIndirilecek) {
        $indirme = $secim.Build.downloads.'server:default'
        Bilgi "İndiriliyor: $($indirme.name)"
        Dogrulanmis-Indir $indirme.url (Join-Path $SunucuDir 'paper.jar') 'SHA256' $indirme.checksums.sha256
        Tamam "Paper $($secim.Id) build $($secim.Build.id) kuruldu"
        $durum.PaperBuild = [int]$secim.Build.id
    } else {
        Tamam 'Paper zaten güncel'
    }
    $durum.McSurum = $secim.Id
    $durum.JavaGerekli = $javaGerekli
    Durum-Yaz $durum

    Baslik 'Eklentiler'
    foreach ($p in $plan) {
        $ad = $p.Eklenti.Ad
        $islem = $p.Islem
        if ($islem -eq 'sorulacak') { $islem = if ($discordKurulacak) { 'yeni' } else { 'atla' } }
        switch ($islem) {
            { $_ -in @('yeni', 'guncelle') } { $durum.Eklentiler[$ad] = @(Eklenti-Kur $p.Eklenti $p.Surum $p.Eskiler) }
            'guncel'     { Tamam "$ad zaten güncel" }
            'devre-disi' { Eklenti-Devre-Disi $p.Eklenti $p.Eskiler; $durum.Eklentiler.Remove($ad) }
        }
        Durum-Yaz $durum
    }
    $surumMetni = @(
        "Sunucunun Minecraft sürümü: $($secim.Id)",
        '',
        'ViaVersion ve ViaBackwards kurulu oldukça çoğu yeni ve eski sürümle de girebilirsiniz.',
        'Bağlanırken sorun çıkarsa TLauncher''da bu sürümü seçin.'
    )
    [IO.File]::WriteAllText($SurumDosyasi, (($surumMetni -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $true))

    # --- 6. Ayar dosyaları ----------------------------------------------
    Baslik 'Ayarlar'
    if (-not $propertiesVar) {
        ServerProperties-Yaz $secenekler.SunucuAdi
        Tamam 'server.properties oluşturuldu'
    } else {
        Tamam 'server.properties zaten var, oyun ayarlarına dokunulmadı'
    }
    if (Rcon-Ayarla) { Tamam 'RCON açıldı (rastgele şifreyle)' }
    if (-not $eulaKabul) {
        [IO.File]::WriteAllText($eulaDosyasi, "# https://aka.ms/MinecraftEULA kurulum sirasinda kabul edildi`r`neula=true`r`n", [Text.Encoding]::ASCII)
        Tamam 'eula.txt yazıldı'
    }
    if (-not (Test-Path -LiteralPath $AyarDosyasi)) {
        Ayarlar-Yaz $bellek.Ram (JvmAyarlari-Sec $secim.Kayit)
        Tamam "AYARLAR.cmd oluşturuldu (bellek: $($bellek.Ram))"
    } else {
        Tamam 'AYARLAR.cmd zaten var, dokunulmadı'
    }
    if (-not (Test-Path -LiteralPath $DuyuruDosyasi)) {
        Duyurular-Yaz
        Tamam 'DUYURULAR.txt oluşturuldu (15 dakikada bir sohbete yazılan ipuçları)'
    }
    Durum-Yaz $durum

    # --- 7. playit.gg ----------------------------------------------------
    Baslik 'playit.gg tüneli'
    if (Test-Path -LiteralPath $PlayitExe) { Tamam 'playit.gg zaten var' } else { Playit-Kur }

    # --- 8. Tek seferlik ayarlar (dünya, Türkçe, rütbeler, spawn...) ----
    Adimlari-Uygula $durum $secenekler

    # --- 9. Otomatik işler ve Windows başlangıcı ------------------------
    Baslik 'Otomatik işler'
    foreach ($gorev in $eskiGorevler) {
        try {
            Unregister-ScheduledTask -TaskName $gorev.TaskName -Confirm:$false
            Tamam "Eski Görev Zamanlayıcı görevi kaldırıldı: $($gorev.TaskName)"
        } catch {
            Uyari "$($gorev.TaskName) kaldırılamadı ($($_.Exception.Message)). Görev Zamanlayıcı'dan elle silebilirsin."
        }
    }
    $isler = @('15 dakikada bir duyurular (DUYURULAR.txt)')
    if ($durum.Gorevler -eq 'evet') { $isler = @("gece $RestartSaati restart", 'saatlik yedek') + $isler }
    if ($durum.Adimlar -contains 'dunyalar-v1') { $isler += 'her ayın 1''inde kaynak dünyası sıfırlama' }
    Tamam "Sunucu açıkken gizli yardımcı çalışır: $($isler -join ', ')"
    if ($kisayolKur) {
        Kisayol-Olustur $sunucuKisayolu (Join-Path $Kok 'BASLAT.bat')
        Kisayol-Olustur $tunelKisayolu (Join-Path $Kok 'TUNEL.bat')
        Tamam 'Windows açılınca sunucu ve tünel başlayacak (kapatmak için: Win+R -> shell:startup -> kısayolları sil)'
    }
    Durum-Yaz $durum

    # --- 10. Özet -------------------------------------------------------
    Baslik 'Kurulum tamamlandı!'
    Write-Host ''
    Write-Host "    Minecraft sürümü: $($durum.McSurum)   (ViaVersion ile başka sürümler de girebilir)" -ForegroundColor Green
    if ($durum.Spawn) { Write-Host "    Spawn meydanı:    $($durum.Spawn)" -ForegroundColor Green }
    Write-Host ''
    Bilgi 'Sıradaki adımlar:'
    Bilgi '  1. TUNEL.bat ile playit.gg''yi aç. İlk seferde verdiği linki tarayıcıda açıp hesabına bağla,'
    Bilgi '     sonra "Minecraft Java" tüneli ekle (adımlar OKUBENI.txt içinde).'
    Bilgi '  2. BASLAT.bat ile sunucuyu aç.'
    Bilgi '  3. playit.gg''nin verdiği adresi arkadaşlarına gönder.'
    Bilgi '  4. Oyuna ilk girişte hemen: /register şifren şifren   (sonraki girişlerde: /login şifren)'
    $siteler = @()
    if (Eklenti-Kurulu-Mu $durum 'BlueMap') { $siteler += 'harita http://localhost:8100' }
    if (Eklenti-Kurulu-Mu $durum 'Plan') { $siteler += 'istatistik http://localhost:8804' }
    if ($siteler.Count -gt 0) { Bilgi "  5. Sunucu açıkken tarayıcıda: $($siteler -join ', ')" }
    if ((Eklenti-Kurulu-Mu $durum 'SimpleVoiceChat') -and $durum.Adimlar -notcontains 'sesli-sohbet') {
        Bilgi '  6. Sesli sohbet: playit.gg''de "MC: Simple Voice Chat" tüneli ekle, sonra KUR.bat''ı tekrar çalıştırıp adresini gir.'
    }
    Write-Host ''
    if (Sor-EvetHayir 'Tünel ve sunucu şimdi açılsın mı?') {
        Start-Process -FilePath (Join-Path $Kok 'TUNEL.bat') -WorkingDirectory $Kok
        Start-Process -FilePath (Join-Path $Kok 'BASLAT.bat') -WorkingDirectory $Kok
        Tamam 'Açılıyor... (iki yeni pencere)'
    }
}

try {
    Ana
} catch {
    Write-Host ''
    Write-Host "    HATA: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '    Bu pencerenin ekran görüntüsünü Claude''a gönderirsen birlikte çözeriz.' -ForegroundColor Red
    exit 1
}
