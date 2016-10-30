# POPFile Email Classifier
Fork of [POPFile](http://getpopfile.org/) to interface directly with qmail.

# Installation auf auf uberspace
## Perl `local::lib` einrichten
Am einfachsten der [Anleitung](https://wiki.uberspace.de/development:perl) aus dem uberspace Wiki folgen.

## SQLite Bibliothek für Perl installieren
```bash
perl -MCPAN -e shell
cpan>install DBD::SQLite
cpan>quit
```

## POPFile installieren
Ich installiere alle zusätzliche Software in das Verzeichnis `~/opt/`
```bash
mkdir ~/opt
cd ~/opt
git clone https://github.com/andresth/POPFile.git
```
Danach POPFile einmal starten, damit die Datenbank und die Konfigurationsdatei angelegt werden.
```bash
cd POPFile
perl ./pipe.pl
```
Es wird keine sichtbare Ausgabe erscheinen, man kann das Programm aber einfach per `Strg+C` beenden.

## Mailfilter einrichten
Als erstes muss die Nachricht durch den Klassifizierer geleitet werden.
```bash
xfilter "cd $HOME/opt/POPFile && /usr/bin/perl ./pipe.pl 2> $HOME/popfile.err"
```
Anschließend muss der Zielordner bestimmt werden. Dazu muss das Skript `find-maildir.pl` aufgerufen werden.  
Die Variable `$MAILDIR` muss auf das Mailverzeichnis weisen.
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
Zu guter letzt wird die Mail zugestellt.
```bash
to "$DestDir"
```

## Cronjob zum erlernen falsch klassifizierter Nachrichten einrichten
Fehlerhaft klassifizierte Nachrichten müssen im Mailprogramm in den richtigen Ordner verschoben werden. Das Skript `teach.pl` sucht diese Nachrichten und lernt sie an. Dazu muss es regelmäßig per `cronjob` aufgerufen weden.
```bash
crontab -e
```
Folgende Zeile muss hinzugefügt werden.
```
0 * * * * cd $HOME/opt/POPFile && /usr/bin/perl ./teach.pl /path/to/maildir
```
Jetzt wird jede Stunde nach Nachrichten zum erlernen gesucht. `/path/to/maildir` muss durch den richtigen Pfad ersetzt erden.
