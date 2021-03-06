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

# Identify the language and character set used for the interface
LanguageCode                            fr
LanguageCharset                         ISO-8859-1
LanguageDirection                       ltr

# This is used to get the appropriate subdirectory for the manual
ManualLanguage                          fr

# Common words that are used on their own all over the interface
Apply                                   Appliquer
On                                      Actif
Off                                     Inactif
TurnOn                                  Activer
TurnOff                                 D�sactiver
Add                                     Ajouter
Remove                                  Retirer
Previous                                Pr�c�dent
Next                                    Suivant
From                                    De
Subject                                 Sujet
Cc                                      Cc
Classification                          Classification
Reclassify                              Reclassifier
Probability                             Probabilit�
Scores                                  Scores
QuickMagnets                            Aimants rapides
Undo                                    Annuler
Close                                   Fermer
Find                                    Chercher
Filter                                  Filtrer
Yes                                     Oui
No                                      Non
ChangeToYes                             Passer � Oui
ChangeToNo                              Passer � Non
Bucket                                  Cat�gorie
Magnet                                  Aimant
Delete                                  Supprimer
Create                                  Cr�er
To                                      A
Total                                   Total
Rename                                  Renommer
Frequency                               Fr�quence
Probability                             Probabilit�
Score                                   Score
Lookup                                  Consulter
Word                                    Mot
Count                                   Compteur
Update                                  Mettre � jour
Refresh                                 Actualiser
FAQ                                     FAQ
ID                                      ID
Date                                    Date
Arrived                                 Arriv�
Size                                    Taille

# This is a regular expression pattern that is used to convert
# a number into a friendly looking number (for the US and UK this
# means comma separated at the thousands)

Locale_Thousands                        " "
Locale_Decimal                          ,

# The Locale_Date uses the format strings in Perl's Date::Format
# module to set the date format for the UI.  There are two possible
# ways to specify it.
#
# <format>            Just one simple format used for all dates
# <<format> | <format> The first format is used for dates less than
#                     7 days from now, the second for all other dates

Locale_Date                             %d/%m %R | %d/%m/%Y %R

# The header and footer that appear on every UI page
Header_Title                            Centre de Commande de POPFile
Header_Shutdown                         Arr�ter POPFile
Header_History                          Historique
Header_Buckets                          Cat�gories
Header_Configuration                    Configuration
Header_Advanced                         Avanc�
Header_Security                         S�curit�
Header_Magnets                          Aimants

Footer_HomePage                         Site web de POPFile
Footer_Manual                           Manuel
Footer_Forums                           Forums
Footer_FeedMe                           Encouragez-moi!
Footer_RequestFeature                   Demande d'�volution
Footer_MailingList                      Liste de diffusion
Footer_Wiki                             Documentation additionnelle

Configuration_Error1                    Le caract�re s�parateur doit �tre un unique caract�re
Configuration_Error2                    Le port de l'interface utilisateur doit �tre un nombre compris entre 1 et 65535
Configuration_Error3                    Le port d'�coute POP3 doit �tre un nombre compris entre 1 et 65535
Configuration_Error4                    La taille de page doit �tre un nombre compris entre 1 et 1000
Configuration_Error5                    Le nombre de jours d'historique doit �tre un nombre compris entre 1 et 366
Configuration_Error6                    Le d�lai d'expiration TCP doit �tre un nombre compris entre 10 et 1800
Configuration_Error7                    Le port d'�coute XML-RPC doit �tre un nombre compris entre 1 et 65535
Configuration_Error8                    Le port du proxy SOCKS V doit �tre un nombre compris entre 1 et 65535
Configuration_POP3Port                  Port d'�coute POP3
Configuration_POP3Update                Port pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Configuration_XMLRPCUpdate              Le port XML-RPC est pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Configuration_XMLRPCPort                Port d'�coute XML-RPC
Configuration_SMTPPort                  Port d'�coute SMTP
Configuration_SMTPUpdate                Le port SMTP est pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Configuration_NNTPPort                  Port d'�coute NNTP
Configuration_NNTPUpdate                Le port NNTP est pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Configuration_POPFork                   Autorise plusieurs connexions POP3 simultan�es
Configuration_SMTPFork                  Autorise plusieurs connexions SMTP simultan�es
Configuration_NNTPFork                  Autorise plusieurs connexions NNTP simultan�es
Configuration_POP3Separator             Caract�re de s�paration pour h�te:port:utilisateur POP3
Configuration_NNTPSeparator             Caract�re de s�paration pour h�te:port:utilisateur NNTP
Configuration_POP3SepUpdate             Le s�parateur POP3 est pass� � %s
Configuration_NNTPSepUpdate             Le s�parateur NNTP est pass� � %s
Configuration_UI                        Port web d'interface utilisateur
Configuration_UIUpdate                  Port web d'interface utilisateur pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Configuration_History                   Nombre de messages par page
Configuration_HistoryUpdate             Nombre de messages par page pass� � %s
Configuration_Days                      Nombre de jours d'historique � conserver
Configuration_DaysUpdate                Nombre de jours d'historique pass� � %s
Configuration_UserInterface             Interface Utilisateur
Configuration_Skins                     Apparences
Configuration_SkinsChoose               Choisir une apparence
Configuration_Language                  Langue
Configuration_LanguageChoose            Choisir une langue
Configuration_ListenPorts               Ports d'Ecoute
Configuration_HistoryView               Pages d'Historique
Configuration_TCPTimeout                D�lai d'Expiration de Connexion TCP
Configuration_TCPTimeoutSecs            D�lai d'expiration de connexion TCP en secondes
Configuration_TCPTimeoutUpdate          D�lai d'expiration de connexion TCP pass� � %s
Configuration_ClassificationInsertion   Informations de Classification
Configuration_SubjectLine               Modification de la ligne Sujet
Configuration_XTCInsertion              Insertion de X-Text-Classification
Configuration_XPLInsertion              Insertion de X-POPFile-Link
Configuration_Logging                   Journalisation
Configuration_None                      aucune
Configuration_ToScreen                  � l'�cran
Configuration_ToFile                    dans un fichier
Configuration_ToScreenFile              �cran et fichier
Configuration_LoggerOutput              Sortie
Configuration_GeneralSkins              Habillages
Configuration_SmallSkins                Habillages compacts
Configuration_TinySkins                 Habillages ultra-compacts
Configuration_CurrentLogFile            &lt;T�l�charger le fichier journal en cours&gt;
Configuration_SOCKSServer               H�te du proxy SOCKS V
Configuration_SOCKSPort                 Port du proxy SOCKS V
Configuration_SOCKSPortUpdate           Le port du proxy SOCKS V est pass� � %s
Configuration_SOCKSServerUpdate         L'h�te du proxy SOCKS V est pass� � %s
Configuration_Fields                    Colonnes de l'historique

Advanced_Error1                         '%s' est d�j� dans la liste des mots ignor�s
Advanced_Error2                         Les mots ignor�s ne peuvent contenir que des caract�res alphanum�riques ou ., _, -, @
Advanced_Error3                         '%s' ajout� � la liste des mots ignor�s
Advanced_Error4                         '%s' n'est pas dans la liste des mots ignor�s
Advanced_Error5                         '%s' retir� de la liste des mots ignor�s
Advanced_StopWords                      Mots ignor�s
Advanced_Message1                       Les mots suivants sont ignor�s dans toutes les classifications car ils apparaissent tr�s souvent.
Advanced_AddWord                        Ajouter un mot
Advanced_RemoveWord                     Retirer un mot
Advanced_AllParameters                  Tous les param�tres de POPFile
Advanced_Parameter                      Param�tre
Advanced_Value                          Valeur
Advanced_Warning                        Ceci est la liste compl�te des param�tres de POPFile. Utilisateurs avertis seulement: vous pouvez modifier ceux que vous d�sirez et cliquer Actualiser. Aucune v�rification de validit� n'est effectu�e. Les �l�ments diff�rents des valeurs par d�faut sont �crits en caract�res gras.
Advanced_ConfigFile                     Fichier de configuration :

History_Filter                          &nbsp;(ne montrant que la cat�gorie <font color="%s">%s</font>)
History_FilterBy                        Filtrer selon
History_Search                          &nbsp;(recherche du sujet %s)
History_Title                           Messages r�cents
History_Jump                            Aller au message
History_ShowAll                         Tout afficher
History_ShouldBe                        Devrait �tre
History_NoFrom                          pas de ligne De
History_NoSubject                       pas de ligne Sujet
History_ClassifyAs                      Classifi� comme
History_MagnetUsed                      Aimant utilis�
History_MagnetBecause                   <b>Aimant utilis�</b><p>Classifi� comme <font color="%s">%s</font> par l'aimant %s </p>
History_ChangedTo                       Chang� en <font color="%s">%s
History_Already                         D�j� reclassifi� comme <font color="%s">%s</font>
History_RemoveAll                       Supprimer tout
History_RemovePage                      Supprimer page
History_RemoveChecked                   Supprimer les messages coch�s
History_Remove                          Pour supprimer des entr�es dans l'historique cliquez
History_SearchMessage                   Chercher De/Sujet
History_NoMessages                      Pas de messages
History_ShowMagnet                      Aimant�
History_Negate_Search                   Inverser la recherche ou le filtre
History_Magnet                          &nbsp;(ne montrant que les messages classifi�s par aimant)
History_NoMagnet                        &nbsp;(ne montrant que les messages non classifi�s par aimant)
History_ResetSearch                     Initialiser
History_ChangedClass                    Devrait maintenant �tre classifi� comme
History_Purge                           Supprimer maintenant
History_Increase                        Croissant
History_Decrease                        D�croissant
History_Column_Characters               Changer la largeur des colonnes De, A, Cc et Sujet
History_Automatic                       Automatique
History_Reclassified                    Reclassifi�
History_Size_Bytes                      %d&nbsp;octets
History_Size_KiloBytes                  %.1f&nbsp;Ko
History_Size_MegaBytes                  %.1f&nbsp;Mo

Password_Title                          Mot de Passe
Password_Enter                          Entrez le mot de passe
Password_Go                             Continuer
Password_Error1                         Mot de passe incorrect

Security_Error1                         Le port s�curis� doit �tre un nombre compris entre 1 et 65535
Security_Stealth                        Mode Furtif/Fonctionnement du Serveur
Security_NoStealthMode                  Non (Mode Furtif)
Security_StealthMode                    (Mode Furtif)
Security_ExplainStats                   (Quand ceci est activ� POPFile envoie une fois par jour les trois valeurs suivantes � un script � getpopfile.org: bc (le nombre total de vos cat�gories), mc (le nombre total de messages classifi�s par POPFile) et ec (le nombre total d'erreurs de classification).  Elles sont alors stock�es dans un fichier que j'utiliserai pour publier quelques statistiques sur comment les gens utilisent POPFile et si �a marche bien.  Mon serveur web conserve ses fichiers log pendant environ 5 jours puis les efface; je ne recueille aucun lien entre les statisques et les adresses IP individuelles.)
Security_ExplainUpdate                  (Quand ceci est activ� POPFile envoie une fois par jour les trois valeurs suivantes � un script � getpopfile.org: ma (le num�ro de version principal de votre POPFile), mi (le num�ro de version secondaire de votre POPFile) et bn (le num�ro de compilation de votre POPFile).  POPFile re�oit une r�ponse sous la forme d'un graphique qui appara�t en haut de la page si une version plus r�cente est disponible.  Mon serveur web conserve ses fichiers log pendant environ 5 jours puis les efface; je ne recueille aucun lien entre les contr�les de mise � jour et les adresses IP individuelles.)
Security_PasswordTitle                  Mot de passe de l'interface utilisateur
Security_Password                       Mot de passe
Security_PasswordUpdate                 Mot de passe chang� en %s
Security_AUTHTitle                      Authentification par mot de passe s�curis�/AUTH
Security_SecureServer                   Serveur s�curis�
Security_SecureServerUpdate             Serveur s�curis� pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Security_SecurePort                     Port s�curis�
Security_SecurePortUpdate               Port s�curis� pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Security_SMTPServer                     Serveur de chaine SMTP
Security_SMTPServerUpdate               Serveur de chaine SMTP pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Security_SMTPPort                       Port de la chaine SMTP
Security_SMTPPortUpdate                 Port de la chaine SMTP pass� � %s; ce changement ne prendra effet qu'au prochain red�marrage de POPFile
Security_POP3                           Accepter les connexions POP3 de machines distantes
Security_SMTP                           Accepter les connexions SMTP de machines distantes (n�cessite le red�marrage de POPFile)
Security_NNTP                           Accepter les connexions NNTP de machines distantes (n�cessite le red�marrage de POPFile)
Security_UI                             Accepter les connexions HTTP (Interface Utilisateur) de machines distantes
Security_XMLRPC                         Accepter les connexions XML-RPC de machines distantes (n�cessite le red�marrage de POPFile)
Security_UpdateTitle                    Contr�le automatique de mise � jour
Security_Update                         V�rifier quotidiennement les mises � jour de POPFile
Security_StatsTitle                     Compte-rendu de statistiques
Security_Stats                          Envoyer quotidiennement des statistiques � John

Magnet_Error1                           L'aimant '%s' existe d�j� pour la cat�gorie '%s'
Magnet_Error2                           Le nouvel aimant '%s' interf�re avec l'aimant '%s' de la cat�gorie '%s' et pourrait causer des r�sultats ambig�s.  Le nouvel aimant n'est pas ajout�.
Magnet_Error3                           Nouvel aimant '%s' cr�� pour la cat�gorie '%s'
Magnet_CurrentMagnets                   Aimants actuels
Magnet_Message1                         Les aimants suivants entra�nent la classification syst�matique d'un message dans la cat�gorie sp�cifi�e.
Magnet_CreateNew                        Cr�er un nouvel aimant
Magnet_Explanation                      Trois types d'aimants sont disponibles: <ul><li><b>Adresse ou nom de l'exp�diteur:</b> Par exemple: john@company.com pour capter une adresse sp�cifique, <br />company.com pour capter les messages de tous les exp�diteurs de company.com, <br />John Doe pour capter une personne en particulier, John pour capter tous les John</li><li><b>Adresse ou nom du destinataire:</b> Comme un aimant De: mais pour l'adresse du destinataire du message</li><li><b>Mots du sujet:</b> Par exemple: bonjour pour capter tous les messages avec bonjour dans le sujet</li></ul>
Magnet_MagnetType                       Type d'aimant
Magnet_Value                            Valeur
Magnet_Always                           Toujours envoyer dans la cat�gorie
Magnet_Jump                             Aller � la page des aimants

Bucket_Error1                           Les noms de cat�gories ne peuvent contenir que les minuscules de a � z ainsi que - et _
Bucket_Error2                           La cat�gorie nomm�e %s existe d�j�
Bucket_Error3                           Cat�gorie nomm�e %s cr��e
Bucket_Error4                           Veuillez entrer un mot non vide
Bucket_Error5                           Cat�gorie %s renomm�e en %s
Bucket_Error6                           Cat�gorie %s effac�e
Bucket_Title                            R�sum�
Bucket_BucketName                       Nom de cat�gorie
Bucket_WordCount                        Nombre de mots
Bucket_WordCounts                       Nombres de Mots
Bucket_UniqueWords                      Mots distincts
Bucket_SubjectModification              Modification du sujet
Bucket_ChangeColor                      Changer la couleur
Bucket_NotEnoughData                    Pas assez de donn�es
Bucket_ClassificationAccuracy           Performance de Classification
Bucket_EmailsClassified                 Messages classifi�s
Bucket_EmailsClassifiedUpper            Messages Classifi�s
Bucket_ClassificationErrors             Erreurs de classification
Bucket_Accuracy                         Performance
Bucket_ClassificationCount              Nombre de classifications
Bucket_ClassificationFP                 Faux Positifs
Bucket_ClassificationFN                 Faux N�gatifs
Bucket_ResetStatistics                  Initialiser les statisques
Bucket_LastReset                        Derni�re initialisation
Bucket_CurrentColor                     La couleur actuelle de %s est %s
Bucket_SetColorTo                       Changer la couleur de %s en %s
Bucket_Maintenance                      Maintenance
Bucket_CreateBucket                     Cr�er une cat�gorie nomm�e
Bucket_DeleteBucket                     Effacer la cat�gorie nomm�e
Bucket_RenameBucket                     Renommer la cat�gorie nomm�e
Bucket_Lookup                           Examiner
Bucket_LookupMessage                    Examiner le mot dans les cat�gories
Bucket_LookupMessage2                   Examiner le r�sultat pour
Bucket_LookupMostLikely                 <b>%s</b> a le plus de chance d'appara�tre dans <font color="%s">%s</font>
Bucket_DoesNotAppear                    <p><b>%s</b> n'appara�t dans aucune cat�gorie
Bucket_DisabledGlobally                 D�sactiv� globalement
Bucket_To                               en
Bucket_Quarantine                       Mise en quarantaine

SingleBucket_Title                      D�tail pour %s
SingleBucket_WordCount                  Nombre de mots de la cat�gorie
SingleBucket_TotalWordCount             Nombre total de mots
SingleBucket_Percentage                 Pourcentage du total
SingleBucket_WordTable                  Table des mots pour %s
SingleBucket_Message1                   Les mots signal�s (*) ont �t� utilis�s pour la classification dans cette session POPFile.  Cliquez sur un mot pour examiner sa probabilit� dans toutes les cat�gories.
SingleBucket_Unique                     %s seul
SingleBucket_ClearBucket                Supprimer tous les mots

Session_Title                           Session POPFile expir�e
Session_Error                           Votre session POPFile a expir�.  Cela peut �tre d� � un arr�t/relance de POPFile alors que le navigateur est rest� ouvert.  Veuillez cliquer sur l'un des liens ci-dessus pour continuer � utiliser POPFile.

View_Title                              Vue d'un message
View_ShowFrequencies                    Voir les fr�quences des mots
View_ShowProbabilities                  Voir les probabilit�s des mots
View_ShowScores                         Voir les scores des mots et la table de d�cision
View_WordMatrix                         Matrice des mots
View_WordProbabilities                  Probablit� des mots
View_WordFrequencies                    Fr�quence des mots
View_WordScores                         Score des mots
View_Chart                              Table de d�cision

Windows_TrayIcon                        Montrer l'ic�ne de POPFile dans la zone de notification de Windows ?
Windows_Console                         Lancer POPFile dans une fen�tre console ?
Windows_NextTime                        <p><font color="red">Cette modification sera prise en compte apr�s le prochain d�marrage de POPFile</font>

Header_MenuSummary                      Cette page est le menu de navigation qui donne acc�s aux diff�rentes pages du centre de contr�le.
History_MainTableSummary                Cette table montre l'exp�diteur et le sujet des messages re�us r�cemment, et permet de les visionner et de les reclassifier. Cliquez sur la ligne du sujet pour voir l'int�gralit� du message ainsi que des informations sur la classification qui a �t� effectu�e. La colonne 'devrait �tre' vous permet de sp�cifier � quelle cat�gorie le message appartient, ou d'annuler cette modification. La colonne 'Supprimer' vous permet de supprimer de l'historique les messages dont vous n'avez plus besoin.
History_OpenMessageSummary              Cette table contient le texte complet d'un message �lectronique, chaque mot utilis� lors de la classification �tant color� en fonction de la cat�gorie � laquelle il se rapporte le plus.
Bucket_MainTableSummary                 Cette table fournit un aper�u des cat�gories. Sur chaque ligne, le nom de la cat�gorie, le total des compteurs des mots de la cat�gorie, le nombre de mots uniques, le r�glage de la modification du sujet si un message est classifi� dans cette cat�gorie, le r�glage de la mise en quarantaine des messages classifi�s dans cette cat�gorie, et une table permettant de choisir la couleur associ�e � cette cat�gorie, utilis�e pour afficher tout ce qui est relatif � cette derni�re dans le centre de contr�le.
Bucket_StatisticsTableSummary           Cette table fournit trois valeurs statistiques sur les performance g�n�rales de POPFile. La premi�re donne le taux de r�ussite de la classification, la seconde combien de messages ont �t� classifi�s et dans quelles cat�gories, et la troisi�me combien de mots sont pr�sents dans chaque cat�gorie, avec leurs pourcentages relatifs.
Bucket_MaintenanceTableSummary          Cette table contient des formulaires qui vous permettent de cr�er, supprimer ou renommer les cat�gories, et rechercher un mot dans toutes les cat�gories pour v�rifier ses probabilit�s relatives.
Bucket_AccuracyChartSummary             Cette table repr�sente graphiquement le taux de r�ussite de la classification des messages.
Bucket_BarChartSummary                  Cette table repr�sente graphiquement la taille relative de chaque cat�gorie. Elle est utilis�e aussi bien pour le nombre de messages classifi�s que pour le total des compteurs de mots.
Bucket_LookupResultsSummary             Cette table montre les probabilit�s associ�es � chaque mot donn� du corpus. Pour chaque cat�gorie, elle montre la fr�quence � laquelle le mot est rencontr�, la probabilit� qu'il a d'appartenir � cette cat�gorie, et l'effet global sur le score de cette cat�gorie si le mot est rencontr� dans un message.
Bucket_WordListTableSummary             Cette table fournit une liste de tous les mots d'une cat�gorie donn�e, class�s en fonction de leur premi�re lettre.
Magnet_MainTableSummary                 Cette table montre la liste des aimants utilis�s pour classifier automatiquement des messages en fonction de r�gles fixes. Chaque ligne montre comment l'aimant est d�fini, � quelle cat�gorie il est assign�, ainsi qu'un bouton permettant de supprimer l'aimant.
Configuration_MainTableSummary          Cette table contient un certain nombre de formulaires vous permettant de contr�ler la configuration de POPFile.
Configuration_InsertionTableSummary     Cette table contient des boutons qui d�terminent si certaines modifications doivent �tre apport�es aux en-t�tes ou � la ligne de sujet du message avant qu'il soit transmis au client de messagerie.
Security_MainTableSummary               Cette table permet de contr�ler les param�tres de s�curit� de la configuration g�n�rale de POPFile, de d�cider s'il doit v�rifier automatiquement les mises � jour du programme, et si les statistiques de performance de POPFile doivent �tre transmises au serveur de donn�es central de l'auteur du programme � des fins d'information g�n�rale.
Advanced_MainTableSummary               Cette table fournit une liste de mots que POPFile ignore lors de la classification des messages, �tant donn� leur trop grande possibilit� de pr�sence dans les messages de tout type. Ils sont class�s en fonction de leur premi�re lettre.

Imap_Bucket2Folder                      Les messages de la cat�gorie <b>%s</b> vont dans le dossier
Imap_MapError                           Vous ne pouvez pas assigner plus d'une cat�gorie � un m�me dossier !
Imap_Server                             Nom du serveur IMAP :
Imap_ServerNameError                    Veuillez entrer le nom du serveur !
Imap_Port                               Port du serveur IMAP
Imap_PortError                          Veuillez entrer un num�ro de port valide !
Imap_Login                              Nom de compte IMAP :
Imap_LoginError                         Veuillez entrer un nom de compte !
Imap_Password                           Mot de passe du compte IMAP :
Imap_PasswordError                      Veuillez entrer un mot de passe pour le serveur !
Imap_Expunge                            Effacer les messages supprim�s des dossiers surveill�s
Imap_Interval                           P�riode de rafra�chissement en secondes :
Imap_IntervalError                      Veuillez entrer un d�lai compris entre 10 et 3600 secondes.
Imap_Bytelimit                          Par message, nombre d'octets pris en compte pour la classification. Entrez 0 (z�ro) pour le message complet :
Imap_BytelimitError                     Veuillez entrer un nombre.
Imap_RefreshFolders                     Actualiser la liste des dossiers
Imap_Now                                maintenant !
Imap_UpdateError1                       Impossible de s'identifier. Veuillez v�rifier votre nom de compte et votre mot de passe.
Imap_UpdateError2                       Impossible de se connecter au serveur. Veuillez v�rifier le nom du serveur et le port, et vous assurer que vous �tre en ligne.
Imap_UpdateError3                       Veuillez configurer pr�alablement les d�tails de la connexion.
Imap_NoConnectionMessage                Veuillez configurer pr�alablement les d�tails de la connexion. Une fois cela fait, d'avantage d'options seront disponibles sur cette page.
Imap_WatchMore                          un dossier � la liste des dossiers surveill�s
Imap_WatchedFolder                      Dossier surveill� n�

Shutdown_Message                        POPFile s'est arr�t�

Help_Training                           Lorsque vous utilisez POPFile pour la premi�re fois, il ne connait rien et a besoin d'un apprentissage. POPFile a besoin d'�tre entra�n� avec des messages appartenant � chaque cat�gorie, cet apprentissage ayant lieu quand vous reclassifiez un message que POPFile a mal class�. Vous devez �galement configurer votre client de messagerie pour filtrer les messages en fonction de la classification effectu�e par POPFile. Pour plus de renseignements sur la mise en place du filtrage dans les clients de messagerie, consultez : <a href="http://getpopfile.org/docs/FAQ:EmailSorting">POPFile Documentation Project</a> (en Anglais).
Help_Bucket_Setup                       POPFile a besoin d'au moins deux cat�gories en plus de la pseudo-cat�gorie 'unclassified'. Ce qui rend POPFile unique est qu'il peut classifier les messages dans autant de cat�gorie que vous le d�sirez. Une configuration simple pourrait �tre une cat�gorie "spam", une autre "personnel" et une autre "professionnel"
Help_No_More                            Ne plus montrer ceci
