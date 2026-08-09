# ActiveDirectory-User-Automation
Automated Active Directory User &amp; OU Provisioning via PowerShell
# Active Directory User & OU Automation Script (v2.0)

Bu PowerShell skripti CSV faylından mərkəzləşdirilmiş məlumatları oxuyaraq Active Directory mühitində avtomatik OU strukturunun qurulması və unikal istifadəçi hesablarının yaradılması üçün nəzərdə tutulmuşdur.

## 🛠️ Xüsusiyyətlər
- **HashSet təməlli yaddaş yoxlanışı:** AD-yə sorğuları minimuma endirərək yüksək performans təmin edir.
- **48 Varasiyalı SAMAccountName Alqoritmi:** Ad, Soyad, Ata adı və Departament birləşmələrindən istifadə edərək unikallıq yaradır.
- **Dynamic OU & Retry Mechanism:** Replikasiya gecikmələrini idarə edən OU yaratma məntiqi.
- **Azərbaycan Transliterasiyası:** Simvolların UTF-8 / ASCII standartına çevrilməsi.

## 🚀 İstifadə Qaydası
```powershell
.\sagird_AD_yarat.ps1 -CSVPath "C:\path\to\sagirdler.csv"
