# users_AD_yarat

Active Directory-də istifadəçilərin (şagirdlərin) CSV faylından kütləvi yaradılması üçün PowerShell skripti.
OU strukturu avtomatik qurulur, SamAccountName 48 kombinasiya qaydası ilə yaradılır və unikallıq yaddaşda (HashSet) yoxlanılır.

## Xüsusiyyətlər

- **Avtomatik OU strukturu:** `Şagirdlər → İxtisas → Sinif` (mövcud OU-lar atlanır, yeniləri yaradılır və təsdiqlənir)
- **48 SAM kombinasiyası:** `Ad / Soyad (S, S2) / Ata adı (A, A2) / Departament (Dep)` cədvəllə idarə olunur, əlavə etmək asandır
- **Sürətli unikallıq yoxlaması:** AD-yə hər addımda sorğu getmir — bütün mövcud SAM/UPN-lər bir dəfə yaddaşa yüklənir (O(1) yoxlama)
- **Azerbaycan → Latın transliterasiyası:** `ə→a, ş→sh, ç→ch, ğ→g, ö→o, ü→u, ı→i, İ→i`
- **Xəta idarəetməsi:** timestamp-lı fayl loqu, yekun statistika, xəta verən istifadəçilər ayrıca CSV-yə ixrac olunur
- **Təhlükəsizlik:** parollar CSV-də saxlanılır, ilk girişdə dəyişdirilmə məcburidir (`ChangePasswordAtLogon`)

## Tələblər

| Tələb | Qeyd |
|---|---|
| Windows Server / Windows 10+ | PowerShell 5.1+ |
| RSAT-AD PowerShell modulu | `Install-WindowsFeature RSAT-AD-PowerShell` (Server) və ya "Active Directory modulu" (client) |
| Domenə qoşulmuş maşın | `Get-ADDomain` işləməlidir |
| Kifayət qədər AD icazəsi | OU yaratmaq və istifadəçi yaratmaq üçün (Domain Admins və ya delegate olunmuş) |

## İstifadə

```powershell
# Default CSV (C:\users_AD_yarat.csv) ilə:
.\scripts\users_AD_yarat.ps1

# Xüsusi CSV ilə:
.\scripts\users_AD_yarat.ps1 -CSVPath "C:\Users\admin\Desktop\users_AD_yarat.csv"

# Xüsusi log yolu ilə:
.\scripts\users_AD_yarat.ps1 -CSVPath "C:\users_AD_yarat.csv" -LogPath "C:\Loglar\users.log"
```

### CSV formatı

| Sütun | Tələb olunur | Açıqlama |
|---|---|---|
| `First Name` | ✅ | İstifadəçinin adı |
| `Last Name` | ✅ | Soyadı |
| `Father name` | ❌ | Ata adı (boş ola bilər — A/A2 kombinasiyaları avtomatik atlanır) |
| `Class` | ✅ | Sinif adı (OU kimi yaradılır) |
| `Ixtisas` | ✅ | İxtisas adı (OU kimi yaradılır) |
| `Department` | ❌ | Departament — `Dep` kombinasiyalarında istifadə olunur. Boşdursa `Ixtisas` götürülür |
| `Password` | ✅ | İlkin parol (boşdursa istifadəçi atlanır) |

Ayırıcı olaraq `;` və ya `,` avtomatik müəyyən olunur (başlıq sətrinə baxılır).


### Nümunə icra çıxışı

```
[INFO]  Skript başladı | CSV: C:\users_AD_yarat.csv | Log: C:\scripts\users_AD_yarat.log
[INFO]  === Mərhələ 1: OU strukturu yoxlanılır / yaradılır ===
[OK]    OU yaradıldı və təsdiqləndi: OU=Şagirdlər,DC=contoso,DC=com
[OK]    OU yaradıldı və təsdiqləndi: OU=İnformatika,OU=Şagirdlər,DC=contoso,DC=com
[SKIP]  OU artiq var: OU=11A,OU=İnformatika,OU=Şagirdlər,DC=contoso,DC=com
[INFO]  Mövcud istifadəçi/kompüter hesabları yaddaşa yüklənir...
[INFO]  Yükləndi: 1240 SAM, 1240 UPN (1.20 saniyə)
[OK]    Məmmədov Elvin Kamil → SAM: elvinme | Mail: elvinme@contoso.com | OU: OU=11A,OU=İnformatika,...
=== YEKUN HESABAT === Toplam: 150 | Yaradıldı: 148 | Atlandı: 1 | Xəta: 1 | Müddət: 8.43 saniyə
```

## SamAccountName kombinasiyaları


**Kombinasiya qaydası:**
- `Ad` — istifadəçinin tam adı
- `S` — soyadın 1-ci hərfi, `S2` — soyadın ilk 2 hərfi
- `A` — ata adının 1-ci hərfi, `A2` — ata adının ilk 2 hərfi
- `Dep` — departament (Department sütunu, yoxdursa Ixtisas)
- 20 simvol limiti, kiçik hərflər, yalnız `a-z0-9`

Bütün 48 kombinasiya tutulubsa, avtomatik olaraq rəqəm əlavə olunur: `elvinme1`, `elvinme2`, ...

Yeni kombinasiya əlavə etmək üçün `scripts/users_AD_yarat.ps1` faylındakı `$script:SAMPatt` cədvəlinə bir sətir yazmaq kifayətdir:

```powershell
# Məsələn: "S2 + A2 + Ad + Dep" kombinasiyasını birinci yoxlamaq istəsəniz:
$script:SAMPatt = @(
    @('S2','A2','Ad','Dep'),   # ← bu artıq birinci yoxlanılacaq
    # ... digər kombinasiyalar
)
```

## Çıxış faylları

| Fayl | Məzmun |
|---|---|
| `users_AD_yarat.log` | Skriptin yanında — timestamp-lı tam log |
| `users_xetalar.csv` | Xəta verən istifadəçilərin siyahısı (yenidən işlətmək üçün) |

## Təhlükəsizlik qeydləri

- ⚠️ Parollar CSV-də açıq mətndədir — faylı şifrələnmiş saxlamaq və ya istifadədən sonra silmək tövsiyə olunur
- ⚠️ `samples/*.csv` `.gitignore`-a əlavə olunub — real parolları repo-ya push etməyin
- İstifadəçilər ilk girişdə parolu dəyişməyə məcbur edilir
- Yalnız icazəsi olan AD mühitində işlədin

## Lisans

[MIT](LICENSE)
