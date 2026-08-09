# SamAccountName Kombinasiyaları (48 variant)

## Komponentlər

| Simvol | Məna | Nümunə (`Elvin Məmmədov Kamil`) |
|---|---|---|
| `Ad` | İstifadəçinin tam adı | `elvin` |
| `S` | Soyadın 1-ci hərfi | `m` |
| `S2` | Soyadın ilk 2 hərfi | `me` |
| `A` | Ata adının 1-ci hərfi | `k` |
| `A2` | Ata adının ilk 2 hərfi | `ka` |
| `Dep` | Departament (Department sütunu, boşdursa Ixtisas) | `it` |

> Qayda: `2` işarəsi "ilk iki hərf" deməkdir; rəqəm olmadıqda (1 hərfli adlarda) tək hərf istifadə olunur.
> Bütün dəyərlər kiçik hərfə çevrilir, qeyri-əlifba simvolları silinir, uzunluq 20 simvolla məhdudlanır.

## Kombinasiya cədvəli

### Blok 1 — `Ad+S+A` (12 variant)

| # | Kombinasiya | Nümunə nəticə |
|---|---|---|
| 1 | `Ad+S+A` | `elvinmk` |
| 2 | `Ad+S+A2` | `elvinmka` |
| 3 | `Ad+S2+A` | `elvinmek` |
| 4 | `Ad+S2+A2` | `elvinmeka` |
| 5 | `Ad+S+A+Dep` | `elvinmkit` |
| 6 | `Ad+S+A2+Dep` | `elvinmka it` → `elvinmkait` |
| 7 | `Ad+S2+A+Dep` | `elvinmekit` |
| 8 | `Ad+S2+A2+Dep` | `elvinmekait` |
| 9 | `Dep+Ad+S+A` | `itelvinmk` |
| 10 | `Dep+Ad+S+A2` | `itelvinmka` |
| 11 | `Dep+Ad+S2+A` | `itelvinmek` |
| 12 | `Dep+Ad+S2+A2` | `itelvinmeka` |

### Blok 2 — `Ad+A+S` (12 variant)

| # | Kombinasiya | Nümunə nəticə |
|---|---|---|
| 13 | `Ad+A+S` | `elvinkm` |
| 14 | `Ad+A+S2` | `elvinkme` |
| 15 | `Ad+A2+S` | `elvinkam` |
| 16 | `Ad+A2+S2` | `elvinkame` |
| 17 | `Ad+A+S+Dep` | `elvinkmit` |
| 18 | `Ad+A+S2+Dep` | `elvinkmeit` |
| 19 | `Ad+A2+S+Dep` | `elvinkamit` |
| 20 | `Ad+A2+S2+Dep` | `elvinkameit` |
| 21 | `Dep+Ad+A+S` | `itelvinkm` |
| 22 | `Dep+Ad+A+S2` | `itelvinkme` |
| 23 | `Dep+Ad+A2+S` | `itelvinkam` |
| 24 | `Dep+Ad+A2+S2` | `itelvinkame` |

### Blok 3 — `S+A+Ad` (12 variant)

| # | Kombinasiya | Nümunə nəticə |
|---|---|---|
| 25 | `S+A+Ad` | `mkelvin` |
| 26 | `S+A2+Ad` | `mkaelvin` |
| 27 | `S2+A+Ad` | `mekelvin` |
| 28 | `S2+A2+Ad` | `mekaelvin` |
| 29 | `S+A+Ad+Dep` | `mkelvinit` |
| 30 | `S+A2+Ad+Dep` | `mkaelvinit` |
| 31 | `S2+A+Ad+Dep` | `mekelvinit` |
| 32 | `S2+A2+Ad+Dep` | `mekaelvinit` |
| 33 | `Dep+S+A+Ad` | `itmkelvin` |
| 34 | `Dep+S+A2+Ad` | `itmkaelvin` |
| 35 | `Dep+S2+A+Ad` | `itmekelvin` |
| 36 | `Dep+S2+A2+Ad` | `itmekaelvin` |

### Blok 4 — `A+S+Ad` (12 variant)

| # | Kombinasiya | Nümunə nəticə |
|---|---|---|
| 37 | `A+S+Ad` | `kmelvin` |
| 38 | `A+S2+Ad` | `kmelvin` (S2+Ad ilə üst-üstə düşür → unikal deyilsə atlanır) |
| 39 | `A2+S+Ad` | `kamelvin` |
| 40 | `A2+S2+Ad` | `kamelvin` (A2+S2+Ad ilə üst-üstə düşür → atlanır) |
| 41 | `A+S+Ad+Dep` | `kmelvinit` |
| 42 | `A+S2+Ad+Dep` | `kamelvinit` |
| 43 | `A2+S+Ad+Dep` | `kamelvinit` (üst-üstə düşür → atlanır) |
| 44 | `A2+S2+Ad+Dep` | `kamelvinit` (üst-üstə düşür → atlanır) |
| 45 | `Dep+A+S+Ad` | `itkmelvin` |
| 46 | `Dep+A+S2+Ad` | `itkmelvin` (üst-üstə düşür → atlanır) |
| 47 | `Dep+A2+S+Ad` | `itkamelvin` |
| 48 | `Dep+A2+S2+Ad` | `itkamelvin` (üst-üstə düşür → atlanır) |

> Bəzi kombinasiyalar eyni nəticə verir (məs. `A2+S` və `A2+S2` — çünki 1 hərfli `A` dəyəri `A2` ilə birləşdikdə təkrarlanır).
> Skript `Select-Object -Unique` kimi təkrarları silir və hər unikal namizədi yalnız bir dəfə yoxlayır.

## Seçim alqoritmi

1. Cədvəldəki ardıcıllıqla (1→48) hər kombinasiyadan namizəd yaradılır
2. Boş komponent varsa həmin kombinasiya atlanır (məs. ata adı yoxdursa `A`/`A2` olanlar)
3. Namizəd `SAM` və `UPN` HashSet-lərində yoxlanılır
4. Boş olan ilk namizəd seçilir və dərhal rezerv edilir
5. Hamısı tutulubsa → `Ad+S+A` əsasına rəqəm əlavə olunur: `elvinmk1`, `elvinmk2`, ...

## Yeni kombinasiya əlavə etmək

`scripts/users_AD_yarat.ps1` faylındakı `$script:SAMPatt` cədvəlinə sətir əlavə edin:

```powershell
# S2 + A2 + Dep + Ad sırası ilə yaratmaq istəsəniz:
@('S2','A2','Dep','Ad'),
```

Cədvəldə yuxarıda olan kombinasiya daha əvvəl yoxlanılır — prioritet sırasını da belə idarə edirsiniz.
