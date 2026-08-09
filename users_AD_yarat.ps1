# ============================================================
#  users_AD_yarat.ps1 
#
#  İstifadə:
#    .\users_AD_yarat.ps1 -CSVPath "C:\sagirdler.csv"
#    .\users_AD_yarat.ps1 -CSVPath "C:\sagirdler.csv" -LogPath "C:\Loglar\users_AD_yarat.log"
#
#  CSV sütunları:
#    "First Name","Last Name","Father name","Class","Ixtisas","Password"
#    "Department" sütunu varsa Dep kimi istifadə olunur, yoxdursa "Ixtisas".
#
#  Yeniliklər:
#    1) SamAccountName üçün 48 kombinasiya (Ad/S/A/S2/A2/Dep) cədvəllə idarə olunur
#    2) SAM/UPN yoxlanışı yaddaşda HashSet ilə - AD-yə hər addımda sorğu getmir
#    3) Ensure-OU: yaratma + yoxlama + retry + OU indeksi (dəqiq DN-lər)
#    4) Xəta idarəetməsi: try/finally, fayl loqu, statistika, xəta CSV-si
# ============================================================

param(
    [string]$CSVPath = "C:\users_AD_yarat.csv",
    [string]$LogPath  = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── ActiveDirectory modulu ───────────────────────────────────
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "[XETA] ActiveDirectory modulu tapilmadi (RSAT lazimdir)." -ForegroundColor Red
    exit 1
}
Import-Module ActiveDirectory

# ── Log faylı ────────────────────────────────────────────────
if ([string]::IsNullOrEmpty($LogPath)) {
    $LogPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "users_AD_yarat.log"
}
$script:LogFilePath = $LogPath
$LogDir = Split-Path -Parent $LogPath
if ($LogDir -and -not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

# ── Rəngli + fayllı log funksiyaları ────────────────────────
function Write-Log {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('OK','SKIP','ERROR','INFO')][string]$Level,
        [Parameter(Mandatory=$true)][string]$msg
    )
    switch ($Level) {
        'OK'    { Write-Host "[OK]    $msg" -ForegroundColor Green  }
        'SKIP'  { Write-Host "[SKIP]  $msg" -ForegroundColor Yellow }
        'ERROR' { Write-Host "[XETA]  $msg" -ForegroundColor Red    }
        'INFO'  { Write-Host "[INFO]  $msg" -ForegroundColor Cyan   }
    }
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $msg
    Add-Content -Path $script:LogFilePath -Value $line -Encoding UTF8
}
function Log-OK    ($msg) { Write-Log -Level OK    -msg $msg }
function Log-SKIP  ($msg) { Write-Log -Level SKIP  -msg $msg }
function Log-ERROR ($msg) { Write-Log -Level ERROR -msg $msg }
function Log-INFO  ($msg) { Write-Log -Level INFO  -msg $msg }

# ── CSV sahəsini təhlükəsiz oxu (null → "") ──────────────────
function Get-Field ($row, $name) {
    $val = $row.$name
    if ($null -eq $val) { return "" }
    return ([string]$val).Trim()
}

# ── DN üçün xüsusi simvolları escape et ──────────────────────
function Escape-DN ($s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }
    $s = $s -replace '([,\\#+<>;"=])', '\$1'
    return $s
}

# ── Azərbaycan → Latın transliterasiya ───────────────────────
function Convert-AzToEn ($text) {
    if ([string]::IsNullOrEmpty($text)) { return "" }
    $text = $text.Trim()
    $map = [ordered]@{
        'Ə'='a'; 'Ş'='sh'; 'Ç'='ch'; 'Ğ'='g'
        'Ö'='o'; 'Ü'='u'; 'İ'='i';  'I'='i'
        'ə'='a'; 'ş'='sh'; 'ç'='ch'; 'ğ'='g'
        'ö'='o'; 'ü'='u'; 'ı'='i';  'i'='i'
    }
    foreach ($k in $map.Keys) {
        $text = $text.Replace([string]$k, [string]$map[$k])
    }
    return $text.ToLowerInvariant()
}

# ── 20 simvol limiti ─────────────────────────────────────────
function Trim20 ($s) {
    if ($s.Length -gt 20) { $s.Substring(0,20) } else { $s }
}

# ============================================================
#  1) SamAccountName kombinasiya cədvəli (48 variant)
#     Ad  = istifadəçinin adı (tam)
#     S   = soyadın 1-ci hərfi      S2 = soyadın ilk 2 hərfi
#     A   = ata adının 1-ci hərfi   A2 = ata adının ilk 2 hərfi
#     Dep = departament (Department və ya Ixtisas)
#     Yeni kombinasiya əlavə etmək üçün bura bir sətir yazmaq kifayətdir.
# ============================================================
$script:SAMPatt = @(
    # --- Ad+S+A ---
    @('Ad','S','A'),       @('Ad','S','A2'),       @('Ad','S2','A'),       @('Ad','S2','A2'),
    @('Ad','S','A','Dep'), @('Ad','S','A2','Dep'), @('Ad','S2','A','Dep'), @('Ad','S2','A2','Dep'),
    @('Dep','Ad','S','A'), @('Dep','Ad','S','A2'), @('Dep','Ad','S2','A'), @('Dep','Ad','S2','A2'),
    # --- Ad+A+S ---
    @('Ad','A','S'),       @('Ad','A','S2'),       @('Ad','A2','S'),       @('Ad','A2','S2'),
    @('Ad','A','S','Dep'), @('Ad','A','S2','Dep'), @('Ad','A2','S','Dep'), @('Ad','A2','S2','Dep'),
    @('Dep','Ad','A','S'), @('Dep','Ad','A','S2'), @('Dep','Ad','A2','S'), @('Dep','Ad','A2','S2'),
    # --- S+A+Ad ---
    @('S','A','Ad'),       @('S','A2','Ad'),       @('S2','A','Ad'),       @('S2','A2','Ad'),
    @('S','A','Ad','Dep'), @('S','A2','Ad','Dep'), @('S2','A','Ad','Dep'), @('S2','A2','Ad','Dep'),
    @('Dep','S','A','Ad'), @('Dep','S','A2','Ad'), @('Dep','S2','A','Ad'), @('Dep','S2','A2','Ad'),
    # --- A+S+Ad ---
    @('A','S','Ad'),       @('A','S2','Ad'),       @('A2','S','Ad'),       @('A2','S2','Ad'),
    @('A','S','Ad','Dep'), @('A','S2','Ad','Dep'), @('A2','S','Ad','Dep'), @('A2','S2','Ad','Dep'),
    @('Dep','A','S','Ad'), @('Dep','A','S2','Ad'), @('Dep','A2','S','Ad'), @('Dep','A2','S2','Ad')
)

# ── Komponent xəritəsi: hər simvol üçün faktiki dəyər ────────
function Get-SamMap {
    param([string]$Ad, [string]$Soyad, [string]$Ata, [string]$Dep)
    return [ordered]@{
        'Ad'  = $Ad
        'S'   = $(if ($Soyad.Length -gt 0) { $Soyad.Substring(0,1) } else { '' })
        'S2'  = $(if ($Soyad.Length -gt 1) { $Soyad.Substring(0,2) } else { $Soyad })
        'A'   = $(if ($Ata.Length   -gt 0) { $Ata.Substring(0,1)   } else { '' })
        'A2'  = $(if ($Ata.Length   -gt 1) { $Ata.Substring(0,2)   } else { $Ata   })
        'Dep' = $Dep
    }
}

# ── Cədvəldən bütün namizədləri yarat ────────────────────────
function Get-SamCandidates {
    param([System.Collections.IDictionary]$Map)
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($patt in $script:SAMPatt) {
        $sb   = [System.Text.StringBuilder]::new()
        $skip = $false
        foreach ($key in $patt) {
            $val = $Map[$key]
            if ([string]::IsNullOrEmpty($val)) { $skip = $true; break }  # çatışmayan komponent → nümunəni atla
            [void]$sb.Append($val)
        }
        if ($skip -or $sb.Length -eq 0) { continue }
        $cand = Trim20 $sb.ToString()
        if (-not $list.Contains($cand)) { $list.Add($cand) }
    }
    return $list
}

# ── Mövcud SAM/UPN-ləri bir dəfə yaddaşa yüklə ───────────────
function Initialize-SamStore {
    param([string]$DomainDNS)
    $store = [ordered]@{
        SAM = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        UPN = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    Log-INFO "Mövcud istifadəçi/kompüter hesabları yaddaşa yüklənir..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Get-ADUser -Filter * -Properties UserPrincipalName -ResultPageSize 500 | ForEach-Object {
            if ($_.SamAccountName)    { [void]$store.SAM.Add($_.SamAccountName) }
            if ($_.UserPrincipalName) { [void]$store.UPN.Add($_.UserPrincipalName) }
        }
        Get-ADComputer -Filter * -ResultPageSize 500 -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.SamAccountName) { [void]$store.SAM.Add($_.SamAccountName) }
        }
        $sw.Stop()
        Log-INFO ("Yükləndi: {0} SAM, {1} UPN ({2} saniyə)" -f $store.SAM.Count, $store.UPN.Count, [Math]::Round($sw.Elapsed.TotalSeconds, 2))
    } catch {
        Log-ERROR ("Yaddaş yüklənməsi alınmadı: {0} — yalnız cari işləmə daxilində unikallıq yoxlanılacaq." -f $_.Exception.Message)
    }
    return $store
}

# ── Unikal SAM seçimi (yaddaş əsaslı) ────────────────────────
function Get-UniqueSam {
    param(
        [System.Collections.IDictionary]$Map,
        [System.Collections.Generic.HashSet[string]]$UsedSAM,
        [System.Collections.Generic.HashSet[string]]$UsedUPN,
        [string]$DomainDNS
    )
    foreach ($cand in (Get-SamCandidates $Map)) {
        $upn = "$cand@$DomainDNS"
        if ($UsedSAM.Contains($cand) -or $UsedUPN.Contains($upn)) { continue }
        [void]$UsedSAM.Add($cand)   # dərhal rezerv et - cari işləmədə təkrarlanmasın
        [void]$UsedUPN.Add($upn)
        return $cand
    }
    # 48 kombinasiya da tutulubsa → rəqəm əlavə et
    $base = Trim20 (($Map['Ad']) + ($Map['S']) + ($Map['A']))
    if ([string]::IsNullOrEmpty($base)) { $base = 'istifadeci' }
    $i = 1
    do {
        $suffix = [string]$i
        $maxCut = [Math]::Max(1, 20 - $suffix.Length)
        $cut    = $base.Substring(0, [Math]::Min($base.Length, $maxCut))
        $cand   = $cut + $suffix
        $upn    = "$cand@$DomainDNS"
        $i++
    } while ($UsedSAM.Contains($cand) -or $UsedUPN.Contains($upn))
    [void]$UsedSAM.Add($cand)
    [void]$UsedUPN.Add($upn)
    return $cand
}

# ── OU yarat + yoxla + retry (təkmilləşdirilmiş) ─────────────
function Ensure-OU {
    param(
        [string]$Name,
        [string]$Path,
        [int]$MaxAttempts = 3
    )
    $escName = Escape-DN $Name
    $dn = "OU=$escName,$Path"

    # 1) Mövcudluq yoxlanışı - Identity ilə (filter xətasına davamlı)
    try {
        $null = Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop
        Log-SKIP "OU artiq var: $dn"
        return $dn
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # mövcud deyil → yaratmağa keç
    } catch {
        Log-ERROR ("OU yoxlanışı xətası: {0} → {1}" -f $dn, $_.Exception.Message)
        return $null
    }

    # 2) Yarat → yoxla (replikasiya gecikməsi üçün təkrar cəhdlər)
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
            $check = Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop
            if ($check) {
                Log-OK ("OU yaradıldı və təsdiqləndi: {0}" -f $dn)
                return $dn
            }
        } catch {
            # Cəhd xəta versə də OU yarana bilər (replikasiya gecikməsi)
            $exists = Get-ADOrganizationalUnit -Identity $dn -ErrorAction SilentlyContinue
            if ($exists) {
                Log-OK ("OU yaradıldı (replikasiyadan sonra təsdiq olundu): {0}" -f $dn)
                return $dn
            }
            Log-ERROR ("OU yaratma cəhdi {0}/{1} uğursuz: {2} → {3}" -f $attempt, $MaxAttempts, $dn, $_.Exception.Message)
        }
        if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds 2 }
    }
    Log-ERROR ("OU yaradıla bilmədi: {0}" -f $dn)
    return $null
}

# ── Əsas domen məlumatı ─────────────────────────────────────
$DomainDN  = (Get-ADDomain).DistinguishedName
$DomainDNS = (Get-ADDomain).DNSRoot

# ── Statistika və köməkçi obyektlər ─────────────────────────
$Stats     = [ordered]@{ Toplam = 0; Yaradildi = 0; Atlandi = 0; Xeta = 0 }
$XetaList  = [System.Collections.Generic.List[object]]::new()
$OUIndex   = @{}
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Log-INFO ("Skript başladı | CSV: {0} | Log: {1}" -f $CSVPath, $script:LogFilePath)

try {
    if (-not (Test-Path $CSVPath)) { throw "CSV tapılmadı: $CSVPath" }

    # ============================================================
    #  MƏRHƏLƏ 1 – OU strukturunu qur və yoxla
    # ============================================================
    Log-INFO "=== Mərhələ 1: OU strukturu yoxlanılır / yaradılır ==="

    $FirstLine = Get-Content -Path $CSVPath -TotalCount 1
    $Delim     = if ($FirstLine -match ";") { ";" } else { "," }
    $Siyahi    = Import-Csv -Path $CSVPath -Delimiter $Delim -Encoding UTF8

    $KokOU = Ensure-OU -Name "Şagirdlər" -Path $DomainDN
    if (-not $KokOU) { throw "Kök OU ('Şagirdlər') yaradıla bilmədi — əməliyyat dayandırıldı." }

    $Ixtisaslar = $Siyahi |
        ForEach-Object { Get-Field $_ 'Ixtisas' } |
        Where-Object { $_ -ne "" } |
        Select-Object -Unique

    foreach ($Ixtisas in $Ixtisaslar) {
        $IxtisasOU = Ensure-OU -Name $Ixtisas -Path $KokOU
        if (-not $IxtisasOU) {
            Log-ERROR "İxtisas OU yaradılmadı, siniflər keçilir: $Ixtisas"
            continue
        }
        $Sinifler = $Siyahi |
            Where-Object { (Get-Field $_ 'Ixtisas') -eq $Ixtisas -and (Get-Field $_ 'Class') -ne "" } |
            ForEach-Object { Get-Field $_ 'Class' } |
            Select-Object -Unique
        foreach ($Sinif in $Sinifler) {
            $SinifOU = Ensure-OU -Name $Sinif -Path $IxtisasOU
            if ($SinifOU) { $OUIndex["$Ixtisas|$Sinif"] = $SinifOU }
        }
    }
    Log-INFO "OU strukturu hazırdır. İndekslənən sinif OU-ləri: $($OUIndex.Count)"

    # ============================================================
    #  MƏRHƏLƏ 2 – SAM yaddaşını yüklə, istifadəçiləri yarat
    # ============================================================
    Log-INFO ""
    Log-INFO "=== Mərhələ 2: İstifadəçilər yaradılır ==="

    $Store = Initialize-SamStore -DomainDNS $DomainDNS

    foreach ($Sagird in $Siyahi) {
        $Stats.Toplam++

        $Ad    = Get-Field $Sagird 'First Name'
        $Soyad = Get-Field $Sagird 'Last Name'
        if ([string]::IsNullOrEmpty($Ad) -and [string]::IsNullOrEmpty($Soyad)) {
            $Stats.Atlandi++
            Log-SKIP "Sətir atlandı (Ad və Soyad boşdur)"
            continue
        }

        $Ata      = Get-Field $Sagird 'Father name'
        $Sinif    = Get-Field $Sagird 'Class'
        $Ixtisas  = Get-Field $Sagird 'Ixtisas'
        $Dep      = Get-Field $Sagird 'Department'
        if ([string]::IsNullOrEmpty($Dep)) { $Dep = $Ixtisas }
        $Password = Get-Field $Sagird 'Password'
        $FullName = ("$Soyad $Ad $Ata").Trim()

        if ([string]::IsNullOrEmpty($Password)) {
            $Stats.Atlandi++
            Log-ERROR "$FullName üçün parol boşdur — keçilir."
            continue
        }
        if ([string]::IsNullOrEmpty($Sinif) -or [string]::IsNullOrEmpty($Ixtisas)) {
            $Stats.Atlandi++
            Log-ERROR "$FullName üçün Sinif/Ixtisas boşdur — keçilir."
            continue
        }

        # Transliterasiya + təmizləmə
        $cAd    = Convert-AzToEn $Ad
        $cSoyad = Convert-AzToEn $Soyad
        $cAta   = Convert-AzToEn $Ata
        $cDep   = Convert-AzToEn $Dep

        $cAd    = ($cAd    -replace '[^a-z0-9]', '')
        $cSoyad = ($cSoyad -replace '[^a-z0-9]', '')
        $cAta   = ($cAta   -replace '[^a-z0-9]', '')
        $cDep   = ($cDep   -replace '[^a-z0-9]', '')

        # Komponent xəritəsi + unikal SAM seçimi (yaddaş əsaslı)
        $Map = Get-SamMap -Ad $cAd -Soyad $cSoyad -Ata $cAta -Dep $cDep
        $SAM = Get-UniqueSam -Map $Map -UsedSAM $Store.SAM -UsedUPN $Store.UPN -DomainDNS $DomainDNS

        # OU indeksindən dəqiq hədəf DN (yenidən sorğu yoxdur)
        $TargetOU = $OUIndex["$Ixtisas|$Sinif"]
        if (-not $TargetOU) {
            $Stats.Xeta++
            Log-ERROR "$FullName üçün OU tapılmadı: $Ixtisas | $Sinif — keçilir."
            continue
        }

        $UPN    = "$SAM@$DomainDNS"
        $SecPwd = ConvertTo-SecureString $Password -AsPlainText -Force

        try {
            New-ADUser `
                -Name                  $FullName `
                -DisplayName           $FullName `
                -GivenName             $Ad `
                -Surname               $Soyad `
                -SamAccountName        $SAM `
                -UserPrincipalName     $UPN `
                -EmailAddress          $UPN `
                -Path                  $TargetOU `
                -AccountPassword       $SecPwd `
                -ChangePasswordAtLogon $true `
                -Enabled               $true `
                -ErrorAction Stop

            $Stats.Yaradildi++
            Log-OK "$FullName → SAM: $SAM | Mail: $UPN | OU: $TargetOU"
        }
        catch {
            $Stats.Xeta++
            Log-ERROR "$FullName yaradıla bilmədi! $($_.Exception.Message)"
            $XetaList.Add([pscustomobject]@{
                FullName       = $FullName
                Ad             = $Ad
                Soyad          = $Soyad
                Sinif          = $Sinif
                Ixtisas        = $Ixtisas
                SamAccountName = $SAM
                UPN            = $UPN
                Xeta           = $_.Exception.Message
            })
        }
    }
}
catch {
    Log-ERROR "Kritik xəta: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) { Add-Content -Path $script:LogFilePath -Value $_.ScriptStackTrace -Encoding UTF8 }
}
finally {
    $Stopwatch.Stop()
    Log-INFO ""
    $msg = "=== YEKUN HESABAT === Toplam: {0} | Yaradıldı: {1} | Atlandı: {2} | Xəta: {3} | Müddət: {4} saniyə" -f `
        $Stats.Toplam, $Stats.Yaradildi, $Stats.Atlandi, $Stats.Xeta, [Math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)
    Log-INFO $msg

    if ($XetaList.Count -gt 0) {
        $xetaCsv = Join-Path (Split-Path -Parent $script:LogFilePath) "users_xetalar.csv"
        try {
            $XetaList | Export-Csv -Path $xetaCsv -NoTypeInformation -Encoding UTF8
            Log-INFO "Xəta siyahısı fayla yazıldı: $xetaCsv"
        } catch {
            Log-ERROR "Xəta CSV yazıla bilmədi: $($_.Exception.Message)"
        }
    }
    Log-INFO "Log faylı: $script:LogFilePath"
}
