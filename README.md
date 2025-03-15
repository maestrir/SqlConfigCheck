# SqlConfigCheck
SQL Server Configuration Analyzer &amp; Tuning  Script PowerShell per analizzare automaticamente configurazioni SQL Server (RAM, CPU, Database, TempDB) e file di tuning specifico per superare le limitazioni della SQL Server Express Edition. Ideale per ottimizzare rapidamente ambienti SQL Server e valutare necessità di upgrade.
# SQL Server Configuration Analyzer e Tuning per SQL Express Edition

📌 **Strumenti inclusi:**

- **SqlConfigCheck.ps1**  
  Script PowerShell che analizza automaticamente il tuo server SQL, rilevando configurazioni hardware, configurazioni SQL Server correnti e dimensioni dei database, consigliando impostazioni ottimali personalizzate.

- **SqlExpressTuning.txt**  
  Schema semplice e immediato che riassume limitazioni SQL Express Edition e fornisce best practice pratiche per ottimizzare prestazioni e configurazioni.

---

## 🚀 **Come usare SqlConfigCheck.ps1**

1. Scarica il file `SqlConfigCheck.ps1` sul tuo server.
2. Eseguilo come amministratore in PowerShell:

```powershell
.\SqlConfigCheck.ps1
