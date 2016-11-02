# POPFile Email Classifier für maildrop
Es handelt sich um eine Anpassung von [POPFile](http://getpopfile.org/) für den Einsatz auf Mailserver.
>POPFile automatically sorts your email messages and fights spam.

POPFile verwendet einen [Bayes-Klassifikator](https://de.wikipedia.org/wiki/Bayes-Klassifikator) um Texte in bestimmte Klassen einzuordnen. Die Klassen können vom Benutzer frei festgelegt werden.  
POPFile ist in der Lage zu erlernen welche Dokumentenart welcher Klasse zuzuordnen ist. Dazu muss der Benutzer fehlerhafte Zuordnungen korrigieren. Es dauert ein paar Nachrichten bis die Zuordnung richtig funktioniert.

Ursprünglich wurde POPFile im Mailprogramm am Arbeitsplatzrechner installiert.  
Die Idee hinter diesem Projekt ist es, POPFile direkt am Mailserver zu integrieren. Somit können die E-Mails schon beim Empfang sortiert werden, und die Funktion ist ohne weiteren Aufwand auf jedem beliebigen Endgerät verfügbar.  
Das Training der Klassifikators soll durch ein einfaches Verschieben der E-Mail in den richtigen Ordner erfolgen.

# Installation auf uberspace
## Perl `local::lib` einrichten
Am einfachsten der [Anleitung](https://wiki.uberspace.de/development:perl) aus dem uberspace Wiki folgen.

## SQLite Bibliothek für Perl installieren
```bash
perl -MCPAN -e shell
cpan>install DBD::SQLite
cpan>quit
```

## POPFile installieren
Installiere alle zusätzliche Software in das Verzeichnis `~/opt/`
```bash
mkdir ~/opt
cd ~/opt
git clone https://github.com/andresth/POPFile.git
```
Danach POPFile einmal starten, damit die Datenbank und die Konfigurationsdatei angelegt werden.
```bash
cd ~/opt/POPFile
perl ./pipe.pl
```
Es wird keine sichtbare Ausgabe erscheinen. Man kann das Programm aber einfach per `Strg+C` beenden.

## Dokumentenklasse für den Posteingangsordner anlegen
Für den Ordner `INBOX` muss die Dokumentenklasse per Hand angelegt werden. Dies geschieht wie folgt:
```bash
cd ~/opt/POPFile
perl ./createbucket.pl inbox
```

## Mailfilter einrichten
Dieser Schritt setzt voraus, dass maildrop bereits eingerichtet wurde (siehe [uberspace wiki](https://wiki.uberspace.de/mail:maildrop)).

Folgende Zeilen sind der Datei `~/.mailfilter` hinzuzufügen:

Als erstes muss die Nachricht durch den Klassifikator geleitet werden.
```bash
xfilter "cd $HOME/opt/POPFile && /usr/bin/perl ./pipe.pl 2> $HOME/popfile.err"
```
Anschließend muss der Zielordner bestimmt werden. Dazu wird das Skript `find-maildir.pl` aufgerufen werden.  
Die Variable `$MAILDIR` muss auf das Mailverzeichnis verweisen.
```bash
DestDir = %MAILDIR
/^X-Text-Classification: (.*)$/:h
if ($MATCH1)
{
    DestDir = `/usr/bin/perl $HOME/opt/POPFile/find-maildir.pl "$MAILDIR" "$MATCH1"`
    if ($DestDir eq "")
    {
        DestDir = $MAILDIR
    }
}
```
Zu guter Letzt wird die Mail zugestellt.
```bash
to "$DestDir"
```

## Cronjob zum Erlernen falsch klassifizierter Nachrichten einrichten
Fehlerhaft klassifizierte Nachrichten müssen im Mailprogramm in den richtigen Ordner verschoben werden. Das Skript `teach.pl` sucht diese Nachrichten und lernt sie an. Dazu muss es regelmäßig per `cronjob` aufgerufen werden.
```bash
crontab -e
```
Folgende Zeile muss hinzugefügt werden.
```
0 * * * * cd $HOME/opt/POPFile && /usr/bin/perl ./teach.pl /path/to/maildir
```
Dadurch werden jede Stunde die bereits vorhandenen Nachrichten durchsucht, um den Klassifizierer zu trainieren. `/path/to/maildir` muss durch den Pfad zum E-Mail Verzeichnis ersetzt werden.

# Einschränkungen
* POPFile kann nicht mit Leerzeichen umgehen. Diese werden in einen Unterstrich umgewandelt. Ein Unterstrich im Ordnernamen hat somit die gleiche Bedeutung wie ein Leerzeichen. D.h. `Test_Ordner == Test Ordner`.
* Groß- und Kleinschreibung werden nicht berücksichtigt.
* Es wird nur die oberste Ebene an Ordnern berücksichtigt.
* Ordner die mit einer Zahl beginnen werden ignoriert (um nicht mit den uberspace Spamfiltern in Konflikt zu kommen).
* Die Standard IMAP Ordner (Sent, Spam, Archive, Drafts, Trash) werden ignoriert.
* Wenn ein Ordner umbenannt wird, dann wird die zugehörige Klasse gelöscht und die E-Mails müssen neu gelernt werden.

# Service Skripte
Es gibt eine Reihe von Skripten mit denen sich POPFile warten lässt.
* clearbucket.pl
> Leert den Inhalt einer Dokumentenklasse.
```bash
perl ./clearbucket.pl Klasse
```

* createbucket.pl  
  Erzeugt eine neue leere Dokumentenklasse.
```bash
perl ./createbucket.pl Klasse
```
* deletebucket.pl  
  Löscht die komplette Dokumentenklasse.
```bash
perl ./deletebucket.pl Klasse
```
* getbuckets.pl  
  Gibt eine Liste der verfügbaren Dokumentenklassen aus.
* insert.pl  
  Trainiert eine Dokumentenklasse anhand von Dateien. (z.B. um eine Klasse gezielt anzulernen)
```bash
perl ./insert.pl Klasse Dateien
```
* remove.pl  
  Entfernt Dateien aus einer Dokumentenklasse.
```bash
perl ./remove.pl Klasse Dateien
```
* isbucket.pl  
  Prüft ob eine Dokumentenklasse existiert.
```bash
perl ./isbucket.pl Klasse
```

# TODO
* Unterstützung mehrerer E-Mail Konten
* Lernvorgang ereignisbassiert über einen Daemon lösen
