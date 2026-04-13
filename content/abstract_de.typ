Cloud-basierte integrierte Entwicklungsumgebungen reduzieren technische Barrieren in
der Informatikausbildung, indem sie einen unmittelbaren Zugriff auf
Programmierumgebungen ohne komplexe lokale Installationen ermöglichen.

Der Online-Dienst Theia Cloud nutzt eine dynamische Provisionierung innerhalb von
Kubernetes, leidet jedoch unter Cold-Start-Verzögerungen, die das synchrone Lernen
stören. Diese Arbeit implementiert eine Eager-Session-Startup-Pipeline für Theia
Cloud, um diese Latenzen zu minimieren. Die Lösung nutzt vorgewärmte Instanzen in
Kombination mit einer Data-Bridge für eine sichere Late-Binding-Personalisierung zur
Laufzeit, die die Injektion von Anmeldedaten ohne Container-Neustarts erlaubt. Durch
die Migration auf die Kubernetes Gateway API reduziert die Architektur die Startzeit
weiter, indem sie Verzögerungen bei der Routing-Propagation verringert.

Benchmarks belegen eine Reduzierung der sequentiellen Startup-Latenz im Median um 75
% auf 1,37s sowie eine Verringerung um 89 % bei Burst-Lasten im Median auf 1,99s.
Diese Architektur bietet eine robuste, latenzarme Grundlage für umfangreiche
Bildungsaktivitäten bei gleichzeitiger Wahrung einer strikten Multi-Tenant-Isolation.
