# Copyright (c) 2001-2011 John Graham-Cumming
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
# Translation Jan Chochola (jchochola@volny.cz)

# Identify the language and character set used for the interface
LanguageCode                            cz
LanguageCharset                         windows-1250
LanguageDirection                       ltr

# This is used to get the appropriate subdirectory for the manual
ManualLanguage                          en

# Common words that are used on their own all over the interface
Apply                                   Pou��t
On                                      Zapnuto
Off                                     Vypnuto
TurnOn                                  Zapnout
TurnOff                                 Vypnout
Add                                     P�idat
Remove                                  Odstranit
Previous                                P�edchoz�
Next                                    N�sleduj�c�
From                                    Od
Subject                                 P�edm�t
Cc                                      Cc 
Classification                          Klasifikace
Reclassify                              Znova klasifikovat
Probability                             Pravd�podobnost
Scores                                  Sk�re
QuickMagnets                            <I>QuickMagnet</I>y
Undo                                    Vr�tit
Close                                   Zav��t
Find                                    Hledat
Filter                                  Filtr
Yes                                     Ano
No                                      Ne
ChangeToYes                             Zm�nit na Ano
ChangeToNo                              Zm�nit na Ne
Bucket                                  Ko�
Magnet                                  Magnet
Delete                                  Odstranit
Create                                  Vytvo�it
To                                      P��jemce
Total                                   Celkem
Rename                                  P�ejmenovat
Frequency                               Frekvence
Lookup                                  Hled�n�
Word                                    Slovo
Count                                   Po�et
Update                                  Aktualizace
Refresh                                 Obnovit

# The header and footer that appear on every UI page
Header_Title                            Ovl�dac� panel POPFile
Header_Shutdown                         Ukon�it POPFile
Header_History                          Historie
Header_Buckets                          Ko�e
Header_Configuration                    Konfigurace
Header_Advanced                         Roz���en�
Header_Security                         Zabezpe�en�
Header_Magnets                          Magnety

Footer_HomePage                         Domovsk� str�nka POPFile
Footer_Manual                           Manu�l
Footer_Forums                           F�ra
Footer_FeedMe                           Podpo�te v�voj
Footer_RequestFeature                   Po�adavek na funkci
Footer_MailingList                      Mailing List

Configuration_Error1                    Odd�lova� mus� b�t jedin� znak
Configuration_Error2                    Port u�ivatelsk�ho rozhran� mus� b�t ��slo mezi 1 a 65535
Configuration_Error3                    Port protokolu POP3 mus� b�t ��slo mezi 1 a 65535
Configuration_Error4                    Velikost str�nky mus� b�t ��slo mezi 1 a 1000
Configuration_Error5                    Po�et dn� platnosti historie mus� b�t ��slo mezi 1 a 366
Configuration_Error6                    Doba �ek�n� TCP mus� b�t ��slo mezi 10 a 1800
Configuration_Error7                    Port pro XML-RPC mus� b�t ��slo mezi 1 a 65535
Configuration_POP3Port                  Port protokolu POP3
Configuration_POP3Update                Nov� port POP3 je %s; tato zm�na se projev� a� po restartu POPFile
Configuration_XMLRPCUpdate              Nov� port pro XML-RPC je %s; tato zm�na se projev� a� po restartu POPFile
Configuration_XMLRPCPort                Port pro XML-RPC
Configuration_SMTPPort                  Port protokolu SMTP
Configuration_SMTPUpdate                Nov� port pro SMTP je %s; tato zm�na se projev� a� po restartu POPFile
Configuration_NNTPPort                  Port protokolu NNTP
Configuration_NNTPUpdate                Nov� port pro NNTP je %s; tato zm�na se projev� a� po restartu POPFile
Configuration_POP3Separator             Odd�lovac� znak pro POP3 host:port:user
Configuration_NNTPSeparator             Odd�lovac� znak pro NNTP host:port:user
Configuration_POP3SepUpdate             Nov� odd�lova� pro POP3 je %s
Configuration_NNTPSepUpdate             Nov� odd�lova� pro NNTP je %s
Configuration_UI                        Port webov�ho u�ivatelsk�ho rozhran�
Configuration_UIUpdate                  Nov� port webov�ho u�ivatelsk�ho rozhran� je %s; tato zm�na se projev� a� po restartu POPFile
Configuration_History                   Po�et zpr�v na str�nce
Configuration_HistoryUpdate             Nov� po�et zpr�v na str�nce je %s
Configuration_Days                      Po�et dn� platnosti historie
Configuration_DaysUpdate                Nov� po�et dn� platnosti historie je %s
Configuration_UserInterface             U�ivatelsk� rozhran�
Configuration_Skins                     Vzhled
Configuration_SkinsChoose               Zvolit vzhled
Configuration_Language                  Jazyk
Configuration_LanguageChoose            Zvolit jazyk
Configuration_ListenPorts               Porty
Configuration_HistoryView               Zobrazen� historie
Configuration_TCPTimeout                �ek�n� na spojen� 
Configuration_TCPTimeoutSecs            �ek�n� na spojen� v sekund�ch
Configuration_TCPTimeoutUpdate          Nov� �ek�n� na spojen� je %s
Configuration_ClassificationInsertion   Vkl�d�n� textu do zpr�vy
Configuration_SubjectLine               Zm�na p�edm�tu zpr�vy
Configuration_XTCInsertion              P�id�n� hlavi�ky X-Text-Classification
Configuration_XPLInsertion              P�id�n� hlavi�ky X-POPFile-Link
Configuration_Logging                   Protokolov�n�
Configuration_None                      Nen�
Configuration_ToScreen                  Na obrazovku
Configuration_ToFile                    Do souboru
Configuration_ToScreenFile              Na obrazovku i do souboru
Configuration_LoggerOutput              Protokol
Configuration_GeneralSkins              Vzhled
Configuration_SmallSkins                Mal�
Configuration_TinySkins                 Drobn�
Configuration_CurrentLogFile            &lt;aktu�ln� protokol&gt;

Advanced_Error1                         '%s' je u� v seznamu ignorovan�ch slov
Advanced_Error2                         Ignorovan� slova mohou obsahovat jen alfanumerick� znaky a znaky '.', '_', '-' nebo '@'
Advanced_Error3                         '%s' p�id�no do seznamu ignorovan�ch slov
Advanced_Error4                         '%s' nen� v seznamu ignorovan�ch slov
Advanced_Error5                         '%s' odstran�no ze seznamu ignorovan�ch slov
Advanced_StopWords                      Ignorovan� slova
Advanced_Message1                       POPFile ignoruje tato �asto u��van� slova:
Advanced_AddWord                        P�idat slovo
Advanced_RemoveWord                     Odebrat slovo

History_Filter                          &nbsp;(zobrazuje se ko� <font color="%s">%s</font>)
History_FilterBy                        Filtr
History_Search                          &nbsp;(vyhled�no podle Odes�latele/P�edm�tu %s)
History_Title                           Posledn� zpr�vy
History_Jump                            P�ej�t ke zpr�v�
History_ShowAll                         Uk�zat v�e
History_ShouldBe                        M� b�t
History_NoFrom                          sch�z� ��dek 'Odes�latel'
History_NoSubject                       sch�z� ��dek 'P�edm�t'
History_ClassifyAs                      Klasifikovat jako
History_MagnetUsed                      Pou�it magnet
History_MagnetBecause                   <b>Pou�it magnet</b><p>Klasifikov�no jako <font color="%s">%s</font>, proto�e byl pou�it magnet %s </p>
History_ChangedTo                       Zm�n�no na <font color="%s">%s
History_Already                         Klasifikace ji� zm�n�na na <font color="%s">%s</font>
History_RemoveAll                       Odstranit v�e
History_RemovePage                      Odstranit str�nku
History_Remove                          Kliknout pro odstran�n� polo�ek v historii
History_SearchMessage                   Hledat Odes�latele/P�edm�t
History_NoMessages                      Zpr�va nenalezena
History_ShowMagnet                      zmagnetov�no
History_ShowNoMagnet                    nezmagnetov�no
History_Magnet                          &nbsp;(jen zpr�vy klasifikovan� magnetem)
History_NoMagnet                        &nbsp;(jen zpr�vy neklasifikovan� magnetem)
History_ResetSearch                     Vynulovat

Password_Title                          Heslo
Password_Enter                          Vlo�it heslo
Password_Go                             Vstoupit
Password_Error1                         Nespr�vn� heslo

Security_Error1                         Port mus� b�t ��slo mezi 1 a 65535
Security_Stealth                        Utajen� re�im/re�im serveru
Security_NoStealthMode                  Ne (Utajen� re�im)
Security_ExplainStats                   (Pokud je to zapnuto, POPFile jedenkr�t denn� ode�le skriptu na getpopfile.org n�sleduj�c� �daje: <B>bc</B> [celkov� po�et ko��], <B>mc</B> [celkov� po�et zpr�v, kter� POPFile klasifikoval] a <B>ec</B> [celkov� po�et chyb klasifikace]. Tyto �daje jsou ukl�d�ny a pou�iji je pro statistiku o tom, jak lid� POPFile pou��vaj� a jak je �sp�n�. M�j web server data udr�uje 5 dn� a pak je ru��. Neukl�d� se ��dn� informace o propojen� mezi statistikami a p��slu�n�mi IP adresami.)
Security_ExplainUpdate                  (Pokud je to zapnuto, POPFile jedenkr�t denn� ode�le skriptu na getpopfile.org n�sleduj�c� �daje: <B>ma</B> [hlavn� ��slo verze va�eho POPFile], <B>mi</B> [vedlej�� ��slo verze] a <B>bn</B> (��slo sestaven� POPFile). Pokud je dostupn� nov� verze, POPFile to graficky zobraz� v horn� ��sti str�nky. M�j web server data udr�uje 5 dn� a pak je ru��. Neukl�d� se ��dn� informace o propojen� mezi �daji a p��slu�n�mi IP adresami.)
Security_PasswordTitle                  Heslo u�ivatelsk�ho rozhran�
Security_Password                       Heslo
Security_PasswordUpdate                 Nov� heslo je %s
Security_AUTHTitle                      Vzd�len� servery
Security_SecureServer                   Server POP3 SPA/AUTH
Security_SecureServerUpdate             Nov� bezpe�n� server POP3 SPA/AUTH je %s; tato zm�na se projev� a� po restartu POPFile
Security_SecurePort                     Port pro POP3 SPA/AUTH
Security_SecurePortUpdate               Nov� port pro POP3 SPA/AUTH je %s; tato zm�na se projev� a� po restartu POPFile
Security_SMTPServer                     Z�et�zen� SMTP server
Security_SMTPServerUpdate               Nov� z�et�zen� SMTP server je %s; tato zm�na se projev� a� po restartu POPFile
Security_SMTPPort                       Port pro z�et�zen� SMTP server
Security_SMTPPortUpdate                 Nov� port pro z�et�zen� SMTP server je %s; tato zm�na se projev� a� po restartu POPFile
Security_POP3                           P�ijmout POP3 spojen� od vzd�len�ch po��ta�� (vy�aduje restart POPFile)
Security_SMTP                           P�ijmout SMTP spojen� od vzd�len�ch po��ta�� (vy�aduje restart POPFile)
Security_NNTP                           P�ijmout NNTP spojen� od vzd�len�ch po��ta�� (vy�aduje restart POPFile)
Security_UI                             P�ijmout HTTP (u�ivatelsk� rozhran�) spojen� od vzd�len�ch po��ta�� (vy�aduje restart POPFile)
Security_XMLRPC                         P�ijmout XML-RPC spojen� od vzd�len�ch po��ta�� (vy�aduje restart POPFile)
Security_UpdateTitle                    Automatick� kontrola verze
Security_Update                         Denn� kontrolovat dostupnost aktualizace POPFile
Security_StatsTitle                     Hl�en� statistik
Security_Stats                          Denn� odes�lat statistiky

Magnet_Error1                           Magnet '%s' u� je v ko�i '%s'
Magnet_Error2                           Nov� magnet '%s' koliduje s magnetem '%s' v ko�i '%s' a mohl by zp�sobit nejednozna�n� v�sledky. Nov� magnet nebyl p�id�n.
Magnet_Error3                           Vytvo�it nov� magnet '%s' v ko�i '%s'
Magnet_CurrentMagnets                   Platn� magnety
Magnet_Message1                         N�sleduj�c� magnety zp�sob�, �e zpr�vy budou v�dy za�azeny do ur�en�ho ko�e.
Magnet_CreateNew                        Zalo�it nov� magnet
Magnet_Explanation                      Jsou dostupn� tyto typy magnet�: <ul><li><b>From: Adresa nebo jm�no odes�latele:</b> Nap��klad: john@company.com pro konkr�tn� adresu, <br />company.com pro v�echny odes�latele z company.com, <br />John Doe pro konkr�tn� osobu, John pro v�echny Johny</li><li><b>To/Cc: Adresa nebo jm�no p��jemce/p��jemc�:</b> Obdobn� jako magnet From: pro adresy p��jemc� (hlavi�ky To: a Cc:).</li> <li><b>Subject: slova v p�edm�tu</b>Nap��klad: hello pro v�echny zpr�vy se slovem hello v p�edm�tu</li></ul>
Magnet_MagnetType                       Typ magnetu
Magnet_Value                            Hodnota
Magnet_Always                           Za�adit v�dy do ko�e
Magnet_Jump                             P�echod na str�nku magnet�

Bucket_Error1                           Jm�na ko�� mohou obsahovat jen mal� p�smena 'a' a� 'z', ��slice '0' a� '9', a znaky '-' a '_'
Bucket_Error2                           Ko� %s ji� existuje
Bucket_Error3                           Ko� %s byl zalo�en
Bucket_Error4                           Vlo�te nepr�zdn� slovo
Bucket_Error5                           Ko� %s byl p�ejmenov�n na %s
Bucket_Error6                           Ko� %s byl odstran�n
Bucket_Title                            Shrnut�
Bucket_BucketName                       Jm�no ko�e
Bucket_WordCount                        Po�et slov
Bucket_WordCounts                       Po�ty slov
Bucket_UniqueWords                      Unik�tn� slova
Bucket_SubjectModification              Modifikace p�edm�tu
Bucket_ChangeColor                      Zm�na barvy
Bucket_NotEnoughData                    P��li� m�lo dat
Bucket_ClassificationAccuracy           P�esnost klasifikace
Bucket_EmailsClassified                 Po�et klasifikovan�ch zpr�v
Bucket_EmailsClassifiedUpper            Po�et klasifikovan�ch zpr�v
Bucket_ClassificationErrors             Chyby klasifikace
Bucket_Accuracy                         P�esnost
Bucket_ClassificationCount              Po�et klasifikac�
Bucket_ClassificationFP                 Po�et chyb "False Positive"
Bucket_ClassificationFN                 Po�et chyb "False Negative"
Bucket_ResetStatistics                  Vynulovat statistiky
Bucket_LastReset                        Posledn� nulov�n�
Bucket_CurrentColor                     %s m� barvu %s
Bucket_SetColorTo                       Nastavit barvu %s na %s
Bucket_Maintenance                      �dr�ba
Bucket_CreateBucket                     Zalo�it ko� s n�zvem
Bucket_DeleteBucket                     Odstranit ko� s n�zvem
Bucket_RenameBucket                     P�ejmenovat ko� s n�zvem
Bucket_Lookup                           Vyhled�n�
Bucket_LookupMessage                    Vyhledat slovo v ko��ch
Bucket_LookupMessage2                   V�sledky hled�n�
Bucket_LookupMostLikely                 <b>%s</b> se nej�ast�ji objevuje v ko�i <font color="%s">%s</font>
Bucket_DoesNotAppear                    <p><b>%s</b> se nena�lo v ��dn�m ko�i
Bucket_DisabledGlobally                 Glob�ln� vypnuto
Bucket_To                               na
Bucket_Quarantine                       Karant�na

SingleBucket_Title                      Detail %s
SingleBucket_WordCount                  Po�et slov v ko�i
SingleBucket_TotalWordCount             Celkov� po�et slov
SingleBucket_Percentage                 Procento
SingleBucket_WordTable                  Tabulka slov pro %s
SingleBucket_Message1                   Pro zobrazen� slov za��naj�c�ch ur�it�m p�smenem je mo�no kliknout na toto p�smeno v indexu. Kliknut�m na slovo se zobraz� jeho pravd�podobnosti pro v�echny ko�e.
SingleBucket_Unique                     %s unik�tn�ch
SingleBucket_ClearBucket                Odstranit v�echna slova

Session_Title                           Relace POPFile vypr�ela
Session_Error                           Va�e relace POPFile vypr�ela. To m��e b�t zp�sobeno zastaven�m a nov�m spu�t�n�m POPFile, zat�mco prohl�e� z�stal otev�en�. Pro pokra�ov�n� pr�ce s POPFile je nutno kliknout na n�kter� z odkaz� naho�e.

View_Title                              Pohled na jednu zpr�vu

Header_MenuSummary                      Tato tabulka tvo�� naviga�n� menu umo��uj�c� p��stup k jednotliv�m str�nk�m Ovl�dac�ho panelu.

History_MainTableSummary                Tato tabulka zobrazuje odes�latele a p�edm�t doru�en�ch zpr�v a umo��uje jejich prohl�dnut� a zm�nu klasifikace. Po kliknut� na p�edm�t se zobraz� cel� text zpr�vy sou�asn� s informac�, pro� byla klasifikov�na tak, jak byla. Sloupec 'M� b�t' umo��uje ur�it ko�, do kter�ho zpr�va pat��, nebo odvolat tuto zm�nu. Sloupec 'Odstranit' umo��uje zru�it zpr�vy, kter� ji� nejsou zapot�eb�.

History_OpenMessageSummary              Tato tabulka obsahuje cel� text zpr�vy. Slova pou�it� p�i klasifikaci jsou ozna�ena barvou ko�e, pro kter� jsou nejv�ce relevantn�.

Bucket_MainTableSummary                 Tato tabulka poskytuje p�ehled klasifika�n�ch ko��. Ka�d� ��dek obsahuje jm�no ko�e, celkov� po�et slov pro dan� ko�, aktu�ln� po�et slov, zda je p�i klasifikaci modifikov�n p�edm�t zpr�vy, zda jsou zpr�vy umis�ov�ny do karant�ny, a tabulka pro v�b�r barvy ko�e.

Bucket_StatisticsTableSummary           Tato tabulka poskytuje t�i sady statistick�ch �daj� o �innosti POPFile. Prvn� z nich zobrazuje p�esnost klasifikace, druh� po�et klasifikovan�ch zpr�v pro jednotliv� ko�e a t�et� po�ty slov v jednotliv�ch ko��ch a jejich relativn� zastoupen�.

Bucket_MaintenanceTableSummary          Tato tabulka obsahuje formul��e pro zakl�d�n�, ru�en� a p�ejmenov�v�n� ko�� a pro vyhled�n� slova v ko��ch a zji�t�n� jeho relativn� pravd�podobnosti.

Bucket_AccuracyChartSummary             Tato tabulka graficky zn�zor�uje p�esnost klasifikace zpr�v.

Bucket_BarChartSummary                  Tato tabulka graficky zn�zor�uje relativn� zastoupen� klasifikovan�ch zpr�v a celkov�ho po�tu slov pro jednotliv� ko�e. 

Bucket_LookupResultsSummary             Tato tabulka poskytuje pravd�podobnosti pro ka�d� slovo z korpusu. Pro ka�d� ko� je zobrazena frekvence v�skytu slova, pravd�podobnost, �e se v ko�i objev�, a celkov� vliv na sk�re pro dan� ko�, pokud se ve zpr�v� vyskytuje.

Bucket_WordListTableSummary             Tato tabulka nab�z� seznam v�ech slov pro dan� ko�.

Magnet_MainTableSummary                 Tato tabulka zobrazuje seznam v�ech magnet�, kter� jsou pou�ity pro automatickou klasifikaci zpr�v podle pevn�ch pravidel. Ka�d� ��dek obsahuje informace o tom, jak je magnet definov�n a pro kter� ko� je ur�en, a tla��tko pro jeho zru�en�.

Configuration_MainTableSummary          Tato tabulka obsahuje �adu formul��� ur�en�ch k nastavov�n� konfigurace POPFile.

Configuration_InsertionTableSummary     Tato tabulka osahuje tla��tka ur�uj�c�, zda se budou prov�d�t ur�it� modifikace hlavi�ky zpr�vy p�ed jej�m p�ed�n�m po�tovn�mu klientu.

Security_MainTableSummary               Tato tabulka umo��uje nastavit zabezpe�en� konfigurace POPFile, automatickou kontrolu nov�ch verz� programu a zas�l�n� statistick�ch �daj� do centr�ln�ho �lo�i�t� autora.

Advanced_MainTableSummary               Tato tabulka obsahuje seznam slov, kter� POPFile p�i klasifikaci pro jejich vysokou �etnost ve zpr�v�ch ignoruje.

