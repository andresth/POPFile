# Copyright (c) 2001-2011 John Graham-Cumming
#
# 2005/08/09 Translated by David Gimeno i Ayuso <info@sima-pc.com>
#
#   This file is part of POPFile
#
#   POPFile is free software; you can redistribute it and/or modify it
#   under the terms of version 2 of the GNU General Public License as
#   published by the Free Software Foundation.
#
#   POPFile is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with POPFile; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

# Identify the language and character set used for the interface
LanguageCode                            ca
LanguageCharset                         ISO-8859-1
LanguageDirection                       ltr

# This is used to get the appropriate subdirectory for the manual
ManualLanguage                          en

# This is where to find the FAQ on the Wiki
FAQLink                                 FAQ

# Common words that are used on their own all over the interface
Apply                                   Aplicar
On                                      Actiu
Off                                     Inactiu
TurnOn                                  Activar
TurnOff                                 Desactivar
Add                                     Afegir
Remove                                  Suprimir
Previous                                Anterior
Next                                    Seg�ent
From                                    Des de
Subject                                 Assumpte
Cc                                      C�pia
Classification                          Cistella
Reclassify                              Reclassificar
Probability                             Probabilitat
Scores                                  Barems
QuickMagnets                            Imants r�pids
Undo                                    Desfer
Close                                   Tancar
Find                                    Cercar
Filter                                  Filtre
Yes                                     S�
No                                      No
ChangeToYes                             Canviar a S�
ChangeToNo                              Canviar a No
Bucket                                  Cistella
Magnet                                  Imant
Delete                                  Esborrar
Create                                  Crear
To                                      A
Total                                   Total
Rename                                  Redenominar
Frequency                               Freq��ncia
Probability                             Probabilitat
Score                                   Barem
Lookup                                  Examinar
Word                                    Mot
Count                                   Comptador
Update                                  Actualitzar
Refresh                                 Recarregar
FAQ                                     PMF
ID                                      ID
Date                                    Data
Arrived                                 Rebut
Size                                    Tamany

# This is a regular expression pattern that is used to convert
# a number into a friendly looking number (for the US and UK this
# means comma separated at the thousands)

Locale_Thousands                       .
Locale_Decimal                         '

# The Locale_Date uses the format strings in Perl's Date::Format
# module to set the date format for the UI.  There are two possible
# ways to specify it.
#
# <format>            Just one simple format used for all dates
# <<format> | <format> The first format is used for dates less than
#                     7 days from now, the second for all other dates

Locale_Date                            %d/%m %R%Z | %e/%L/%Y %R%Z

# The header and footer that appear on every UI page
Header_Title                            Centre de control POPFile
Header_Shutdown                         Aturar POPFile
Header_History                          Hist�ric
Header_Buckets                          Cistelles
Header_Configuration                    Configuraci�
Header_Advanced                         Avan�at
Header_Security                         Seguretat
Header_Magnets                          Imants

Footer_HomePage                         P�gina inicial POPFile
Footer_Manual                           Manual
Footer_Forums                           F�rums
Footer_FeedMe                           Acaptar
Footer_RequestFeature                   Sol�licitar millora
Footer_MailingList                      Llista de correu
Footer_Wiki                             Documentaci�

Configuration_Error1                    El car�cter separador ha de ser-ne un de sol
Configuration_Error2                    El port de l'interf�cie d'usuari ha de ser un n�mero entre 1 i 65535
Configuration_Error3                    El port que rep les connexions POP3 ha de ser un n�mero entre 1 i 65535
Configuration_Error4                    El tamany de p�gina ha de ser un n�mero entre 1 i 1000
Configuration_Error5                    El nombre de dies a l'hist�ric ha de ser un n�mero entre 1 i 366
Configuration_Error6                    El temps d'espera de TCP ha de ser un n�mero entre 10 i 1800
Configuration_Error7                    El port que rep les connexions XML RPC ha de ser un n�mero entre 1 i 65535
Configuration_Error8                    El port intermedi SOCKS V ha de ser un n�mero entre 1 i 65535
Configuration_POP3Port                  Port que rep les connexions POP3
Configuration_POP3Update                S'ha actualitzat el port POP3 a %s; no tindr� efecte fins que reinicieu el POPFile
Configuration_XMLRPCUpdate              S'ha actualitzat el port XML-RPC a %s; no tindr� efecte fins que reinicieu el POPFile
Configuration_XMLRPCPort                Port que rep les connexions XML-RPC
Configuration_SMTPPort                  Port que rep les connexions SMTP
Configuration_SMTPUpdate                S'ha actualitzat el port SMTP a %s; no tindr� efecte fins que reinicieu el POPFile
Configuration_NNTPPort                  Port que rep les connexions NNTP
Configuration_NNTPUpdate                S'ha actualitzat el port NNTP a %s; no tindr� efecte fins que reinicieu el POPFile
Configuration_POPFork                   Permetre connexions concurrents POP3
Configuration_SMTPFork                  Permetre connexions concurrents SMTP
Configuration_NNTPFork                  Permetre connexions concurrents NNTP
Configuration_POP3Separator             Car�cter separador de host:port:user POP3
Configuration_NNTPSeparator             Car�cter separador de host:port:user NNPT
Configuration_POP3SepUpdate             S'ha actualitzat el separador POP3 a %s
Configuration_NNTPSepUpdate             S'ha actualitzat el separador NNTP a %s
Configuration_UI                        Port web d'interf�cie d'usuari
Configuration_UIUpdate                  S'ha actualitzat el port web d'interf�cie d'usuari a %s; no tindr� efecte fins que reinicieu el POPFile
Configuration_History                   Nombre de missatges per p�gina
Configuration_HistoryUpdate             S'ha actualitzat el nombre de missatges per p�gina a %s
Configuration_Days                      Nombre de dies a conservar l'hist�ric
Configuration_DaysUpdate                S'ha actualitzat el nombre de dies d'hist�ric a %s
Configuration_UserInterface             Interf�cie d'usuari
Configuration_Skins                     Aparences
Configuration_SkinsChoose               Trieu aparen�a
Configuration_Language                  Idioma
Configuration_LanguageChoose            Trieu idioma
Configuration_ListenPorts               Opcions de m�duls
Configuration_HistoryView               Veure hist�ric
Configuration_TCPTimeout                Temps d'espera connexi�
Configuration_TCPTimeoutSecs            Temps d'espera connexi� en segons
Configuration_TCPTimeoutUpdate          S'ha actualitzat el temps d'espera connexi� a %s
Configuration_ClassificationInsertion   Inserci� text del missatge
Configuration_SubjectLine               Modificaci�<br>l�nia de l'assumpte
Configuration_XTCInsertion              Cap�alera<br>X-Text-Classification
Configuration_XPLInsertion              Cap�alera<br>X-POPFile-Link
Configuration_Logging                   S'est� registrant
Configuration_None                      Cap
Configuration_ToScreen                  A pantalla
Configuration_ToFile                    A fitxer
Configuration_ToScreenFile              A pantalla i fitxer
Configuration_LoggerOutput              Sortida usuari
Configuration_GeneralSkins              Aparences
Configuration_SmallSkins                Aparences petites
Configuration_TinySkins                 Aparences min�scules
Configuration_CurrentLogFile            &lt;Descarregar fitxer de registre actual&gt;
Configuration_SOCKSServer               Servidor intermedi SOCKS V
Configuration_SOCKSPort                 Port intermedi SOCKS V
Configuration_SOCKSPortUpdate           S'ha actualitzat el port intermedi SOCKS V a %s
Configuration_SOCKSServerUpdate         S'ha actualitzat el servidor intermedi SOCKS V a %s
Configuration_Fields                    Columnes hist�ric

Advanced_Error1                         '%s' ja �s a la llista de mots a ignorar
Advanced_Error2                         Mots a ignorar nom�s pot contenir car�cters alfanum�rics, ., _, - i @
Advanced_Error3                         afegit '%s' a la llista de mots a ignorar
Advanced_Error4                         '%s' no �s a la llista de mots a ignorar
Advanced_Error5                         suprimit '%s' de la llista de mots a ignorar
Advanced_StopWords                      Mots a ignorar
Advanced_Message1                       POPFile ignora els seg�ents mots molt usuals:
Advanced_AddWord                        Afegir mot
Advanced_RemoveWord                     Suprimir mot
Advanced_AllParameters                  Tots els par�metres POPFile
Advanced_Parameter                      Par�metre
Advanced_Value                          Valor
Advanced_Warning                        Aquesta �s la llista completa de par�metres de POPFile. Nom�s usuaris avan�ats: canvieu-los i cliqueu Actualitzar; no se'n comprova la validesa.  Els �tems mostrats en negreta s�n diferents dels predeterminats.
Advanced_ConfigFile                     Fitxer de configuraci�:

History_Filter                          &nbsp;(s'est� mostrant nom�s la cistella <font color="%s">%s</font>)
History_FilterBy                        Filtrat per
History_Search                          &nbsp;(cercat per Des de/Assumte %s)
History_Title                           Missatges recents
History_Jump                            Anar a la p�gina
History_ShowAll                         Mostrar-ho tot
History_ShouldBe                        Hauria de ser
History_NoFrom                          cap l�nia Des de
History_NoSubject                       cap l�nia Assumpte
History_ClassifyAs                      Classificar com a
History_MagnetUsed                      Imant usat
History_MagnetBecause                   <b>Imant usat</b><p>Classificat com a <font color="%s">%s</font> degut a l'imant %s </p>
History_ChangedTo                       S'ha canviat a <font color="%s">%s</font>
History_Already                         Reclassificat com a <font color="%s">%s</font>
History_RemoveAll                       Suprimir-ho tot
History_RemovePage                      Suprimir p�gina
History_RemoveChecked                   Suprimir marcats
History_Remove                          Per suprimir entrades a l'hist�ric, cliqueu
History_SearchMessage                   Cercar Des de/Assumpte
History_NoMessages                      Cap missatge
History_ShowMagnet                      imantat
History_Negate_Search                   Invertir cerca/filtre
History_Magnet                          &nbsp;(s'est� mostrant nom�s missatges classificats per imant)
History_NoMagnet                        &nbsp;(s'est� mostrant nom�s missatges no classificats per imant)
History_ResetSearch                     Reiniciar
History_ChangedClass                    Ara s'hauria de classificar com a
History_Purge                           Esborrar ara
History_Increase                        Augmentar
History_Decrease                        Reduir
History_Column_Characters               Canviar l'ample de les columnes Des de, A, C�pia i Assumpte
History_Automatic                       Autom�tic
History_Reclassified                    Reclassificat
History_Size_Bytes                      %d&nbsp;B
History_Size_KiloBytes                  %.1f&nbsp;KB
History_Size_MegaBytes                  %.1f&nbsp;MB

Password_Title                          Contrasenya
Password_Enter                          Introdu�u-hi la contrasenya
Password_Go                             Anar-hi!
Password_Error1                         Contrasenya incorrecta

Security_Error1                         El port ha de ser un n�mero entre 1 i 65535
Security_Stealth                        Mode furtiu/Operaci� del servidor
Security_NoStealthMode                  No (mode furtiu)
Security_StealthMode                    (Mode furtiu)
Security_ExplainStats                   (Si s'activa, POPFile envia un cop al dia els tres seg�ents valors a un programa a getpopfile.org: bc, el nombre total de cistelles que teniu; mc, el nombre total de missatges classificats per POPFile, i ec, el nombre total d'errors de classificaci�. Aix� s'emmagatzema en un fitxer i ser� usat per confeccionar estad�stiques d'�s de POPFile i com funciona de b�. El meu servidor web conserva els seus fitxers de registre uns 5 dies i aleshores s'esborren; no emmagatzemo cap connexi� entre estad�stiques i adreces IP individuals).
Security_ExplainUpdate                  (Si s'activa, POPFile envia un cop per dia els tres seg�ents valors a un programa a getpopfile.org: ma, el nombre major de versi� de la vostra instal�laci� POPFile; mi, el nombre menor de versi� de la vostra instal�laci� POPFile, i bn, el nombre de muntatge de la vostra instal�laci� POPFile. POPFile rep una resposta en forma de gr�fic que surt dalt de la p�gina, si hi ha una versi� nova disponible. El meu servidor web conserva els seus fitxers de registre uns 5 dies i aleshores s'esborren; no emmagatzemo cap connexi� entre les verificacions d'actualitzaci� i les adreces IP individuals).
Security_PasswordTitle                  Contrasenya d'interf�cie d'usuari
Security_Password                       Contrasenya
Security_PasswordUpdate                 S'ha actualitzat la contrasenya
Security_AUTHTitle                      Servidors remots
Security_SecureServer                   Servidor POP3 remot (SPA/AUTH o servidor intermedi transparent)
Security_SecureServerUpdate             S'ha actualitzat el servidor POP3 remot a %s
Security_SecurePort                     Port POP3 remot (SPA/AUTH o servidor intermedi transparent)
Security_SecurePortUpdate               S'ha actualitzat el port del servidor POP3 remot a %s
Security_SMTPServer                     Servidor de cadena SMTP
Security_SMTPServerUpdate               S'ha actualitzat el servidor de cadena SMTP a %s; no tindr� efecte fins que reinicieu el POPFile
Security_SMTPPort                       Port de cadena SMTP
Security_SMTPPortUpdate                 S'ha actualitzat el port de cadena SMTP a %s; no tindr� efecte fins que reinicieu el POPFile
Security_POP3                           Acceptar connexions POP3 de m�quines remotes (cal reiniciar POPFile)
Security_SMTP                           Acceptar connexions SMTP de m�quines remotes (cal reiniciar POPFile)
Security_NNTP                           Acceptar connexions NNTP de m�quines remotes (cal reiniciar POPFile)
Security_UI                             Acceptar connexions HTTP (interf�cie d'usuari) de m�quines remotes (cal reiniciar POPFile)
Security_XMLRPC                         Acceptar connexions XML-RPC de m�quines remotes (cal reiniciar POPFile)
Security_UpdateTitle                    Comprovaci� autom�tica d'actualitzacions
Security_Update                         Comprovar actualitzacions de POPFile di�riament
Security_StatsTitle                     S'estan informant les estad�stiques
Security_Stats                          Enviar les estad�stiques di�riament

Magnet_Error1                           Ja existeix l'imant '%s' a la cistella '%s'
Magnet_Error2                           El nou imant '%s' interfereix amb el '%s' de la cistella '%s' i podria donar resultats ambigus.  No s'ha afegit el nou.
Magnet_Error3                           S'ha creat el nou imant '%s' a la cistella '%s'
Magnet_CurrentMagnets                   Imants actuals
Magnet_Message1                         Els imants seg�ents impliquen que un missatge sigui sempre encasellat a la cistella indicada
Magnet_CreateNew                        Crear imant nou
Magnet_Explanation                      Disposeu de tres tipus d'imants: <ul><li><b>Adre�a Des de o nom:</b> Per exemple: john@company.com per evitar una adre�a espec�fica, <br />company.com per evitar tothom de company.com, <br />John Doe per evitar una persona concreta, John per evitar-los tots</li><li><b>Adre�a A/C�pia o nom:</b> Com un imant Des de: per� per a l'adressa A:/C�pia: a un missatge</li> <li><b>Mots Assumpte:</b> Per exemple: hello per evitar tots els missatges amb hello a l'assumpte</li></ul>
Magnet_MagnetType                       Tipus d'imant
Magnet_Value                            Valors
Magnet_Always                           Va sempre a la cistella
Magnet_Jump                             Anar a la p�gina d'imants

Bucket_Error1                           Els noms de cistella nom�s poden contenir lletres a a z en min�scules, n�meros 0 a 9, m�s - i _
Bucket_Error2                           Ja existeix la cistella anomenada %s
Bucket_Error3                           S'ha creat la cistella anomenada %s
Bucket_Error4                           Introdu�u-hi algun mot
Bucket_Error5                           Redenominada la cistella %s a %s
Bucket_Error6                           Esborrada la cistella %s
Bucket_Title                            Configuraci� de cistella
Bucket_BucketName                       Nom de<br>cistella
Bucket_WordCount                        Comptador de mots
Bucket_WordCounts                       Comptadors de mots
Bucket_UniqueWords                      Mots<br>distints
Bucket_SubjectModification              Modificaci�<br>cap�alera assumpte
Bucket_ChangeColor                      Color<br>cistella
Bucket_NotEnoughData                    No hi ha prous dades
Bucket_ClassificationAccuracy           Precisi� de la classificaci�
Bucket_EmailsClassified                 Missatges classificats
Bucket_EmailsClassifiedUpper            Missatges Classificats
Bucket_ClassificationErrors             Errors de classificaci�
Bucket_Accuracy                         Precisi�
Bucket_ClassificationCount              Comptador de classificaci�
Bucket_ClassificationFP                 Falsos positius
Bucket_ClassificationFN                 Falsos negatius
Bucket_ResetStatistics                  Reiniciar estad�stiques
Bucket_LastReset                        �ltima reinicialitzaci�
Bucket_CurrentColor                     El color actual de %s �s %s
Bucket_SetColorTo                       S'ha canviat el color de %s a %s
Bucket_Maintenance                      Manteniment
Bucket_CreateBucket                     Crear una cistella de nom
Bucket_DeleteBucket                     Esborrar la cistella anomenada
Bucket_RenameBucket                     Redenominar la cistella anomenada
Bucket_Lookup                           Examinar
Bucket_LookupMessage                    Examinar la paraula a les cistelles
Bucket_LookupMessage2                   Examinar el resultat per
Bucket_LookupMostLikely                 <b>%s</b> �s m�s probable que aparegui a <font color="%s">%s</font>
Bucket_DoesNotAppear                    <p><b>%s</b> no apareix a cap de les cistelles
Bucket_DisabledGlobally                 Globalment inhabilitat
Bucket_To                               a
Bucket_Quarantine                       Missatge de<br>quarantena

SingleBucket_Title                      Detall de %s
SingleBucket_WordCount                  Comptador de mots de la cistella
SingleBucket_TotalWordCount             Comptador total de mots
SingleBucket_Percentage                 Percentatge del total
SingleBucket_WordTable                  Taula de mots de %s
SingleBucket_Message1                   Cliqueu una lletra a l'�ndex per veure la llista de mots que hi comencen. Cliqueu qualsevol mot per examinar llur probabilitat per a totes les cistelles.
SingleBucket_Unique                     %s distint
SingleBucket_ClearBucket                Suprimir tots els mots

Session_Title                           La sessi� POPFile ha ven�ut
Session_Error                           La vostra sessi� POPFile ha ven�ut. Aix� pot ser degut a haver aturat i iniciat POPFile deixant el vostre navegador web obert. Cliqueu un dels enlla�os de m�s amunt per continuar usant POPFile.

View_Title                              Visualitzaci� missatge individual
View_ShowFrequencies                    Mostrar freq��ncies de mot
View_ShowProbabilities                  Mostrar probabilitats de mot
View_ShowScores                         Mostrar barems de mot i diagrama de decisi�
View_WordMatrix                         Matriu de mots
View_WordProbabilities                  s'estan mostrant les probabilitats de mot
View_WordFrequencies                    s'estan mostrant les freq��ncies de mot
View_WordScores                         s'estan mostrant els barems de mot
View_Chart                              Diagrama de decisi�

Windows_TrayIcon                        Mostrar la icona POPFile a la safata de sistema del Windows?
Windows_Console                         Executar POPFile a una finestra de consola?
Windows_NextTime                        <p><font color="red">No tindr� efecte fins que reinicieu el POPFile</font>

Header_MenuSummary                      Aquesta taula �s el men� de navegaci� que permet d'accedir a cadascuna de les diferents p�gines del centre de control.
History_MainTableSummary                Aquesta taula mostra el remitent i l'assumpte dels missatges rebuts ad�s i permet de revisar-los i reclassificar-los. En clicar la l�nia de l'assumpte es mostrar� el missatge sencer, juntament amb la informaci� del per qu� de llur classificaci�. La columna 'Hauria de ser' us permet d'especificar a quina cistella pertany o de desfer aquest canvi. La columna 'Esborrar' us permet d'esborrar de l'hist�ric missatges espec�fics, si ja no els necessiteu.
History_OpenMessageSummary              Aquesta taula cont� el text complet d'un missatge, amb els mots usats a la classificaci� ressaltats segons la cistella m�s rellevant de cadascun.
Bucket_MainTableSummary                 Aquesta taula proporciona una ullada de les cistelles de classificaci�. Cada fila mostra per a cada cistella el nom, el comptador total de mots, el nombre total de mots individuals, si es modificar� la l�nia d'assumpte en classificar-lo, si es deixaran en quarantena els que es rebin i una taula per seleccionar el color a usar en presentar al centre de control res de relacionat amb ella.
Bucket_StatisticsTableSummary           Aquesta taula proporciona tres jocs d'estad�stiques sobre el rendiment general de POPFile. El primer �s com d'acurada �s la classificaci�, el segon quants missatges i a quines cistelles s'han classificat i el tercer quants mots hi ha a cada cistella i quins percentatges representen.
Bucket_MaintenanceTableSummary          Aquesta taula cont� formularis que us permeten de crear, esborrar o redenominar cistelles o examinar un mot a totes les cistelles per veure quines probabilitats presenta.
Bucket_AccuracyChartSummary             Aquesta taula representa gr�ficament la precisi� de la classificaci� de missatges.
Bucket_BarChartSummary                  Aquesta taula representa gr�ficament l'assignaci� de percentatges a cadascuna de les diferents cistelles. S'usa tant per al nombre de missatges classificats com per als comptadors totals de mots.
Bucket_LookupResultsSummary             Aquesta taula mostra les probabilitats associades a un mot del corpus donat. De cada cistella mostra la freq��ncia en que esdev� el mot, la probabilitat de que hi aparegui i l'efecte general que t� sobre el barem de la cistella si n'hi ha cap en un missatge.
Bucket_WordListTableSummary             Aquesta taula proporciona una llista de tots els mots d'una cistella particular, ordenats per la primera lletra com� a cada fila.
Magnet_MainTableSummary                 Aquesta taula mostra la llista d'imants que s'usen per classificar missatges autom�ticament segons unes regles fixes. Cada fila mostra com es defineix l'imant, per a quina cistella s'ha fet i un bot� per esborrar-lo.
Configuration_MainTableSummary          Aquesta taula cont� un nombre de formularis que us permeten de controlar la configuraci� de POPFile.
Configuration_InsertionTableSummary     Aquesta taula cont� els botons que determinen si es fan certes modificacions a les cap�aleres o l�nia d'assumpte del missatge abans no sigui passat al client de correu, o no.
Security_MainTableSummary               Aquesta taula proporciona jocs de controls que afecten la seguretat de la configuraci� general de POPFile, si s'ha de comprovar autom�ticament si hi ha actualitzacions del programa i si s'han enviar les estad�stiques sobre rendiment del POPFile al magatzem central de l'autor del programa per a informaci� general.
Advanced_MainTableSummary               Aquesta taula proporciona una llista de mots que POPFile ignora en classificar els missatges atesa llur freq��ncia relativa als missatges de tota mena. S'ordenen per fila segons llur primera lletra.

Imap_Bucket2Folder                      Els correus de la cistella <b>%s</b> van a la carpeta
Imap_MapError                           No podeu assignar m�s d'una cistella a una sola carpeta!
Imap_Server                             Nom del servidor IMAP:
Imap_ServerNameError                    Introdu�u-hi el nom del servidor!
Imap_Port                               Port del servidor IMAP:
Imap_PortError                          Introdu�u-hi un n�mero de port v�lid!
Imap_Login                              Nom del compte IMAP:
Imap_LoginError                         Introdu�u-hi un nom d'usuari!
Imap_Password                           Contrasenya del compte IMAP:
Imap_PasswordError                      Introdu�u-hi una contrasenya pel servidor!
Imap_Expunge                            Destruir de les carpetes mirades els missatges esborrats.
Imap_Interval                           Interval d'actualitzaci�, en segons:
Imap_IntervalError                      Introdu�u-hi un interval entre 10 i 3600 segons.
Imap_Bytelimit                          Nombre de bytes per missatge a usar per a la classificaci�. Introdu�u-hi 0 (zero) pel missatge complet:
Imap_BytelimitError                     Introdu�u-hi un nombre.
Imap_RefreshFolders                     Recarregar la llista de carpetes
Imap_Now                                ara!
Imap_UpdateError1                       No s'ha pogut entrar. Verifiqueu el nom del compte i la contrasenya.
Imap_UpdateError2                       No s'ha pogut connectar amb el servidor. Comproveu el nom i el port del servidor i assegureu-vos que sou en l�nia.
Imap_UpdateError3                       Configureu abans els detalls de la connexi�.
Imap_NoConnectionMessage                Configureu abans els detalls de la connexi�. Despr�s que hi hagueu fet, hi haur� m�s opcions disponibles.
Imap_WatchMore                          una carpeta a la llista de les carpetes mirades
Imap_WatchedFolder                      Carpeta mirada n�m.

Shutdown_Message                        S'ha aturat el POPFile

Help_Training                           Quan useu per primer cop POPFile, no sap res i caldr� una mica d'entrenament. Cal entrenar POPFile per a cada cistella. L'anireu educant cada cop que reclassifiqueu un missatge que POPFile hagi classificat a una cistella incorrecta. Tamb� haureu de configurar el vostre client de correu perqu� filtri els missatges segons la classificaci� de POPFile. Podeu trobar informaci� sobre com configurar el filtratge del vostre client de correu a <a href="http://getpopfile.org/docs/FAQ:EmailSorting">Projecte de Documentaci� POPFile</a> (en angl�s).
Help_Bucket_Setup                       POPFile necessita al menys dues cistelles a m�s de la pseudo-cistella 'unclassified'. El que fa �nic POPFile �s que pot classificar els correus en tantes cistelles com volgueu. Una configuraci� senzilla pot ser una cistella "spam", una "personal" i una altra "feina".
Help_No_More                            No mostrar-m'ho m�s
