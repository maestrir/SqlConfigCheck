# PowerShell script completo per analisi e consigli configurazione SQL Server

# Crea log file con timestamp
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "SQL_Config_Report_$TimeStamp.txt"

Write-Output "Analisi configurazione SQL Server in corso..."

# Hardware Info
$CPU = Get-CimInstance Win32_Processor
$RAM_GB = [math]::Round(((Get-CimInstance CIM_PhysicalMemory | Measure-Object Capacity -Sum).Sum) /1GB)
$CoreFisici = ($CPU | Measure-Object -Property NumberOfCores -Sum).Sum
$CoreLogici = ($CPU | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

# Raccolta Config SQL
Import-Module SQLPS -DisableNameChecking
$sqlInstance = "localhost"

# Versione e licensing SQL Server
$versionQuery = "SELECT @@VERSION AS Versione"
$sqlVersion = (Invoke-Sqlcmd -ServerInstance $sqlInstance -Query $versionQuery).Versione

# Determinare se è Express Edition
$isExpress = $sqlVersion -match "Express Edition"

# Dimensioni Database
$dbSizeQuery = @"
SELECT DB_NAME(database_id) AS DatabaseName,  
CAST(SUM(size) * 8 / 1024.0 AS DECIMAL(10,2)) AS SizeMB  
FROM sys.master_files  
GROUP BY database_id
ORDER BY SizeMB DESC
"@
$dbSizes = Invoke-Sqlcmd -ServerInstance $sqlInstance -Query $dbSizeQuery

# Controllo limite DB Express
$DBLimitExceeded = $false
if ($isExpress) {
    foreach ($db in $dbSizes) {
        if ($db.SizeMB -ge 10240) { $DBLimitExceeded = $true }
    }
}

# Query configurazioni SQL
$configQuery = @"
SELECT name, value_in_use FROM sys.configurations
WHERE name IN ('max server memory (MB)', 'max degree of parallelism', 'cost threshold for parallelism')
"@
$configs = Invoke-Sqlcmd -ServerInstance $sqlInstance -Query $configQuery

# Configurazione TempDB
$tempdbQuery = @"
SELECT name AS FileName, physical_name AS PhysicalPath, size/128 AS SizeMB, growth/128 AS GrowthMB
FROM tempdb.sys.database_files
"@
$tempdbConfig = Invoke-Sqlcmd -ServerInstance $sqlInstance -Query $tempdbQuery

# Analisi e consigli
$MaxMemorySuggerita = [math]::Round($RAM_GB * 0.8 * 1024)
$MAXDOP_Consigliato = if ($CoreFisici -le 8) { $CoreFisici } else {8}
$ParallelismThreshold = 50

# Consiglio TempDB
$TempDBFilesConsigliati = [math]::Ceiling($CoreLogici / 4)
if ($TempDBFilesConsigliati -gt 8) { $TempDBFilesConsigliati = 8 }

# Genera log
$Log = @"
===== ANALISI E CONSIGLI CONFIGURAZIONE SQL SERVER =====

>> DATA ANALISI: $(Get-Date)

>> HARDWARE RILEVATO:
- CPU: $($CPU.Name)
- Core Fisici: $CoreFisici
- Core Logici: $CoreLogici
- RAM Totale: $RAM_GB GB

>> VERSIONE SQL SERVER:
$sqlVersion

>> DIMENSIONI DATABASE RILEVATI (MB):
$(($dbSizes | Format-Table -AutoSize | Out-String))

"@

if ($isExpress) {
$Log += @"
>> ATTENZIONE - SQL SERVER EXPRESS EDITION RILEVATA:
  - Limite massimo Database: 10 GB
  - Limite massimo RAM utilizzabile: 1,4 GB
  - Limite massimo CPU: 1 CPU fisica (4 core massimi)
"@

if ($DBLimitExceeded) {
$Log += "`n!!! ATTENZIONE: UNO O PIÙ DATABASE HANNO SUPERATO IL LIMITE DI 10 GB !!!
  >> VALUTARE UPGRADE LICENZA!`n"
}
}

$Log += @"

>> CONFIGURAZIONE ATTUALE SQL SERVER:
$(($configs | Format-Table -AutoSize | Out-String))

>> CONFIGURAZIONE CONSIGLIATA:
- [MAX SERVER MEMORY]: $MaxMemorySuggerita MB (80% della RAM totale)
- [MAX DEGREE OF PARALLELISM]: $MAXDOP_Consigliato (metà o uguale ai core fisici, massimo 8)
- [COST THRESHOLD FOR PARALLELISM]: $ParallelismThreshold

>> SPIEGAZIONE CONSIGLI:
1. MAX SERVER MEMORY limita RAM a SQL Server per lasciare risorse al sistema operativo.
2. MAXDOP limita core per query, evitando sovraccarichi.
3. COST THRESHOLD FOR PARALLELISM evita parallelizzazione inefficace di query semplici.

>> CONFIGURAZIONE TempDB ATTUALE:
$(($tempdbConfig | Format-Table -AutoSize | Out-String))

>> CONSIGLI PER TEMpDB:
- Consigliati almeno $TempDBFilesConsigliati file TempDB (1 file ogni 4 core logici, massimo 8).
- File con dimensioni identiche (es: 1024-2048 MB ciascuno).
- Dischi veloci (SSD/NVMe) migliorano le performance.
- Più file distribuiscono carichi I/O, evitando colli di bottiglia.

>> QUERY PER AGGIUNGERE FILE TempDB:
ALTER DATABASE [tempdb] ADD FILE (NAME='tempdev2', FILENAME='C:\\SQLData\\tempdb2.ndf', SIZE=2048MB, FILEGROWTH=512MB);
-- Ripetere la query modificando nome e percorso per ogni file aggiuntivo.

>> ANALISI EFFICIENZA CONSIGLIATA:
- Verificare regolarmente la frammentazione degli indici.
- Pianificare rebuild degli indici e aggiornamento statistiche almeno settimanalmente.
- Monitorare query lente con SQL Profiler o Extended Events.

===== FINE REPORT =====
"@

$Log | Out-File -FilePath $LogFile -Encoding UTF8
Invoke-Item $LogFile
