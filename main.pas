(**
 * Application: TUKI BU GAW
 * ===========================================================================================
 * Aapplication de gestion centralisée des services des autoroutes de la société TUKI BU GAW.
 * Cette application fournit les statistiques des fréquentations des autoroutes :
 *      Par tranches horaires,
 *      Par jours de travail,
 *      Par jours fériés,
 *      Par week-ends.
 * De même, elle fournit les statistiques :
 *      Des voitures par catégories,
 *      De l’utilisation des parkings,
 *      Des services de dépannage,
 * __________________________________________________________________________________________
 *
 * Par: Bechir Ba
 * Projet examen ALOG2 LPGI 1
 * Date de creation: Jeudi, 2 Aout 2018, 21h:33min
 * -------------------------------------------------
 * Compilateur: Free Pascal Compiler 3.0.4
 * Editeur de texte: Visual Studio Code
 * Compilé sous: Linux (Ubuntu 18.04), Windows 10
 * ___________________________________________________________________________________________
 * Liens et docs :
 *   - https://www.freepascal.org/docs-html/rtl/sysutils/strtoint.html
 *   - https://www.gladir.com/CODER/TPASCAL7/getdate.htm
 *   - https://www.freepascal.org/docs-html/rtl/sysutils/inttostr.html
 *
 *)

program TUKI_BU_GAW;
uses crt, Dos, SysUtils;

const PRIX_PARKING_PAR_HEURE = 500;
      PRIX_PEAGE_PAR_KM      = 10;
      REDUCTION              = 15;
      DIST_DAKAR_THIES       = 68;
      DIST_THIES_LOUGA       = 124;
      DIST_LOUGA_ST_LOUIS    = 74;

    // Constantes pour les jours et mois
    JOURS : Array[0 .. 6]  of String = ('Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche');
    MOIS  : Array[0 .. 11] of String = ('Janvier', 'Fevrier', 'Mars', 'Avril', 'Mais', 'Juin', 'Juillet', 'Aout', 'Septembre', 'Octobre', 'Novembre', 'Decembre');

    // Consantes pour les fichiers
    NOM_FICHIER_GARES = './data/gares.dta';
    NOM_FICHIER_TICKETS = './data/tickets.dta';
    NOM_FICHIER_ABONNES = './data/abonnes.dta';

    // Le type ServiceFourni permet de savoir le prix a payer pour le service fournit
type tTypeServiceFourni = (Peage, Parking, Depannage);
     tCategorieVoitures = (PoidsLourd, Personnelle, Transport, DeuxRoues);
     tNomVille = (Dakar, StLouis, Louga, Thies);
     TabEntiers = Array of Integer;

    tTime = Record
        h, m, s, c : Word;
        format     : string;
    End;

    tDateTime = Record
        // Date
        jour_semaine, jour_mois, mois, annee : Word;
        // Time
        heures, minutes, secondes, ms : Word;
        // Formatted
        format  : string;
    end;

    tVoiture = Record
        matricule : string;
        categorie : tCategorieVoitures;
    End;

    tClient = Record
        nomComplet  : string;
        voiture     : tVoiture;
        case abonne : boolean of
            true:  (credit : longint);
            false: (liquidite : longint);
    END;

    tTicket = Record
        date    : tDateTime;
        montant : longint;
        ville   : tNomVille;
        vileDest: tNomVille;
        client  : tClient;
        case typeService : tTypeServiceFourni of
            Peage     : (prixParKm, nbKm : integer);
            Parking   : (prixParHeure : integer; nbHeuresGare : shortint);
            Depannage : (nomProbleme : string);
    End;

    tGare = Record
        nom       : tNomVille;
    End;

    FichierGares  = file of tGare;
    FicherTickets  = file of tTicket;
    FichierAbonnes = file of tClient;

var f_gares  : FichierGares;
    f_tickets : FicherTickets;
    f_abonnes : FichierAbonnes;

    client  : tClient;
    ticket  : tTicket;

    terminer, nouveau : boolean;
    str : string;
    n, i, j : integer;

(**
 * FormaterDate
 * Ecrit la date de facon plus lisible dans la variable [format] de la variable de type tDateTime passe en argument.
 *)
procedure formaterDate(var d : tDateTime);
begin
    d.format := IntToStr(d.jour_mois) + '/' + IntToStr(d.mois) + '/' +  IntToStr(d.annee);
end;

(**
 * formaterHeure
 * Meme chose que formaterDate, mais il le fait uniquement pour les heures.
 *)
procedure formaterHeure(var d : tDateTime);
begin
    d.format := IntToStr(d.heures) +'h:' + IntToStr(d.minutes) + 'min';
end;

(**
 * formaterDateEtHeure
 * Combine formaterDate et formaterHeure pour pouvoir enregistrer un joli format de date dans les tickets.
 *)
procedure formaterDateEtHeure(var d : tDateTime);
begin
    d.format := JOURS[d.jour_semaine] + ', ' + IntToStr(d.jour_mois) + ' ' + MOIS[d.mois] + ' ' +  IntToStr(d.annee)
                + ', ' + IntToStr(d.heures) +'h:' + IntToStr(d.minutes) + 'min:' + IntToStr(d.secondes) + 's';
end;

(**
 * Retourne l'heure et la date actuelle du systeme.
 * source: https://www.gladir.com/CODER/TPASCAL7/getdate.htm
 *)
function DateActuelle() : tDateTime;
var d : tDateTime;
begin
    GetDate(d.annee, d.mois, d.jour_mois, d.jour_semaine);
    GetTime(d.heures, d.minutes, d.secondes, d.ms);
    formaterDateEtHeure(d);
    DateActuelle := d;
end;

(**
 * Enregistrement d'un ticket
 * Se fait lorsqu'un client utilise un service (peage, parking, depannage) alors un ticket est
 * automatiquement enregistre dans le ficher des tickets.
 *
 * @param f: Le fichier des ticket
 * @param t: le ticket a enregistrer
 *)
procedure EnregistrerTicket(var f : FicherTickets; var t : tTicket);
begin
    Assign(f, NOM_FICHIER_TICKETS);
    reset(f);
    t.date := DateActuelle();
    t.client.abonne := true;
    t.client.nomComplet := client.nomComplet;
    t.client.voiture.matricule := client.voiture.matricule;
    formaterDateEtHeure(t.date);

    seek(f, filesize(f));
    write(f, t);
    close(f);
end;

(**
 * Initialise tous les fichiers utilisés dans le programme
 * Une fois appelé le programme se réinitialise.
 *)
procedure InitialiserFichiers();
begin
    Assign(f_gares, NOM_FICHIER_GARES);
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    Assign(f_abonnes, NOM_FICHIER_ABONNES);

    Writeln('   Creation du fichier "', NOM_FICHIER_GARES, '"  ... ... ...');
    rewrite(f_gares);
    WriteLn('   Termine.');
    Writeln('   Creation du fichier "', NOM_FICHIER_TICKETS, '" ... ... ...');
    rewrite(f_tickets);
    WriteLn('   Termine.');
    Writeln('   Creation du fichier "', NOM_FICHIER_ABONNES, '" ... ... ...');
    rewrite(f_abonnes);
    WriteLn('   Termine.');

    close(f_gares);
    close(f_tickets);
    close(f_abonnes);

    writeln('   Les fichiers ont ete cree avec succes !');
    writeln('   Vous pouvez maintenant commencer la gestion de TUKI BU GAW.');
end;

(**
 * Vérifie qu'un client est abonné a partir de son nom.
 * @param nom : Le nom du client
 * @return boolean
 *)
function estAbonne(const nom : string) : boolean;
var trouvee : boolean;
    c : tClient;
begin
    Assign(f_abonnes, NOM_FICHIER_ABONNES);
    reset(f_abonnes);

    trouvee := false;
    while(not (EOF(f_abonnes) OR trouvee)) do begin
        read(f_abonnes, c);
        if(c.nomComplet = nom) then
            trouvee := true;
    end;
    close(f_abonnes);
    estAbonne := trouvee;
end;

(**
 * Recupere un abonne dans le fichier des abonnes (a partir de son nom)
 * et stocke le resultat dans le second parametre de la procedure.
 * Si nom existe, on renvoie ce client abonne corssepondant.
 * Sinon, c'est le dernier abonne de la lsite qui sera renvoye.
 * Donc cette procedure est a utiliser apres avoir obtenu [estAbonne(nom) = true].
 *)
procedure recupererAbonne(const nom : string; var c : tClient);
var trouvee : boolean;
begin
    Assign(f_abonnes, NOM_FICHIER_ABONNES);
    reset(f_abonnes);

    trouvee := false;
    while(not(trouvee) OR (not EOF(f_abonnes))) do begin
        read(f_abonnes, c);
        if(c.nomComplet = nom) then
            trouvee := true;
    end;

    close(f_abonnes);
end;

(**
 * Affiche la liste des abonnes.
 *)
procedure AfficherAbonnes();
begin
    Assign(f_abonnes, NOM_FICHIER_ABONNES);
    reset(f_abonnes);
    clrscr;
    writeln('   =============================================================');
    writeln('   |                    LISTE DES ABONNEES                     |');
    writeln('   =============================================================');
    writeln;
    i := 0;writeln('   __________________________________________________________');
    while(not EOF(f_abonnes)) do begin
        i := i + 1;
        read(f_abonnes, client);
        WriteLn('   Nom complet       : ', client.nomComplet);
        WriteLn('   Type de voiture   : ', client.voiture.categorie);
        WriteLn('   Matricule voiture : ', client.voiture.matricule);
        WriteLn('   Credit            : ', client.credit, ' Francs CFA');
        writeln('   __________________________________________________________');
    end;
    if(i = 0) then writeln('    Il n''y a aucun abonne a TUKI BU GAW pour le moment.');writeln;
    close(f_abonnes);
end;


(**
 * Permet a l'administrateur d'ajouter des abonnes.
 *)
procedure AjouterAbonne();
begin
    Assign(f_abonnes, NOM_FICHIER_ABONNES);
    reset(f_abonnes);
    writeln;
    writeln('   =============================================================');
    writeln('   |                     AJOUTER UN ABONNE                     |');
    writeln('   =============================================================');

    seek(f_abonnes, filesize(f_abonnes));
    write('Enrez le nom complet de l''abonne > ');
    readln(client.nomComplet);
    write('Entrez la matricule de la voiture > ');
    readln(client.voiture.matricule);
    repeat
        writeln('   Choisissez la categorie de sa voiture:');
        writeln('      1. Poids lourd');
        writeln('      2. Voiture personelle');
        writeln('      3. Voiture de transport');
        writeln('      4. Vehicule 2 roues');
        write('     Votre choix > ');
        readln(n);
    until( (n >= 1) AND (n <= 4));

    with client.voiture do begin
        case n of
            1: categorie := PoidsLourd;
            2: categorie := Personnelle;
            3: categorie := Transport;
            4: categorie := DeuxRoues;
        end;
    end;
    write('Entrez la somme que le client veut deposer > ');
    readln(client.credit);
    client.abonne := true;
    write(f_abonnes, client);
    close(f_abonnes);
    writeln(client.nomComplet, ' a ete ajoute dans la liste des abonnes.');
end;

(**
 * Supprime un abonne dans la liste des abonnes.
 *)
procedure SupprimerAbonne(var c : tClient);
begin
end;

(**
 * Gere l'abonnement d'un client
 * Permet a l'abonne de recharger sa carte de credit, se desabonner, ou afficher sa carte.
 *)
procedure GererAbonnement(var c : tClient);
var terminer : boolean;
    tmp_client : tClient;
begin
    terminer := false;
    clrscr;
    writeln('   =============================================================');
    writeln('   |                  GERER VOTRE ABONNEMENT                   |');
    writeln('   =============================================================');
    while(not terminer) do begin
        repeat
            writeln('   1. Afficher votre credit');
            writeln('   2. Alimenter la carte de credit');
            writeln('   3. Se desabonner');
            writeln('   4. Retour');
            write('    Votre choix > ');
            readln(n);
        until((n >=1 ) AND (n <= 4));

        writeln;
        case n of
            1: writeln('    Il vous reste ', c.credit, ' Francs CFA dans votre compte.');
            2: begin
                write('   Entrez la somme que vous voulez ajouter a votre carte > ');
                readln(n);
                c.credit := c.credit + n;
                Assign(f_abonnes, NOM_FICHIER_ABONNES);
                reset(f_abonnes);
                while(not EOF(f_abonnes)) do begin
                    read(f_abonnes, tmp_client);
                    if(tmp_client.nomComplet = c.nomComplet) then begin
                        seek(f_abonnes, filepos(f_abonnes) - 1);
                        write(f_abonnes, c);
                    end;
                end;
                close(f_abonnes);
                writeln('   Vous avez alimente votre carte, nouvau solde: ', c.credit, ' Francs CFA.');
            end;
            3: begin
                writeln('       Voulez-vous vraiment vous desabonner ? Attention: Vous ne profiterez plus d''une reduction de ', REDUCTION, '% !');
                repeat
                    writeln('   1. Confirmer le desabonnement');
                    writeln('   2. Annuler');
                    write('   Votre choix > '); readln(n);
                until((n = 1) OR (n = 2));
                if(n = 1) then SupprimerAbonne(c) else writeln('    Vous avez fait le bon choix ', c.nomComplet, ' !');
            end;
            4: terminer := true;
        end;
    end;
end;

(**
 * Abonner client
 * Un utilisateur qui est dans la partie client peut s'autoabonner,
 * il fournit les informations et on l'enregistre dans la liste des abonnes.
 *)
procedure AbonnerClient(var c : tClient);
begin
    Assign(f_abonnes, NOM_FICHIER_ABONNES);
    reset(f_abonnes);

    write('Entrez la matricule de votre voiture > ');
    readln(c.voiture.matricule);
    repeat
        writeln('   Choisissez une categorie pour votre voiture:');
        writeln('      1. Poids lourd');
        writeln('      2. Voiture personelle');
        writeln('      3. Voiture de transport');
        writeln('      4. Vehicule 2 roues');
        write('    Votre choix > '); readln(n);
    until( (n >= 1) AND (n <= 4));

    with c.voiture do begin
        case n of
            1: categorie := PoidsLourd;
            2: categorie := Personnelle;
            3: categorie := Transport;
            4: categorie := DeuxRoues;
        end;
    end;
    write('   Entrez la somme que vous voulez deposer > ');
    readln(c.credit);

    c.abonne := true;
    seek(f_abonnes, filesize(f_abonnes));
    write(f_abonnes, c);
    close(f_abonnes);

    writeln;writeln('         Merci ', c.nomComplet, ' ! Vous etes maintenant abonne(e) a notre service.');
end;

(**
 * Affiche la liste des tickets utilises.
 *)
procedure AfficherTickets();
begin
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    reset(f_tickets);

    writeln('   =============================================================');
    writeln('   |                  LISTE DES TICKETS UTILISES               |');
    writeln('   =============================================================');
    writeln; i := 0;
    while(not EOF(f_tickets)) do begin
        i := i + 1;
        read(f_tickets, ticket);
        writeln;writeln('   ------------------  Ticket ~ TUKI BU GAW   ------------------');writeln;
        WriteLn('   Numero            : ', filepos(f_tickets));
        WriteLn('   Date et heure     : ', ticket.date.format);
        writeln('   Ville             : ', ticket.ville);
        writeln('   Type de service   : ', ticket.typeService);
        writeln('   Nom du client     : ', ticket.client.nomComplet);
        writeln('   Matricule voiture : ', ticket.client.voiture.matricule);
        {}write('   Reduction         : '); if(ticket.client.abonne) then writeln(REDUCTION, '%') else writeln('0%');
        WriteLn('   Montant total     : ', ticket.montant, ' Francs CFA');
        writeln('   _____________________________________________________________');writeln;
    end;
    if(i = 0) then writeln('    Pas de tickets pour l''instant.');writeln;
    close(f_tickets);
end;

(**
 * Reinitialise l'application
 *)
procedure InitialiserApp();
begin
    writeln;
    writeln('   =============================================================');
    writeln('   |             INITIALISATION DE TUKI BU GAW                 |');
    writeln('   =============================================================');
    writeln;
    InitialiserFichiers();
end;

(**
 * Facture un client ayant utlise l'un des services de TUKI BU GAW.
 * Dans cette procedure, on affiche la facture, on appelle la procedure EnregistrerTicket qui sauvegarde le ticket (dans la base de donnee).
 *)
procedure facturerClient(var t : tTicket);
var tmp_client : tClient;
begin
    t.date := DateActuelle();
    formaterDateEtHeure(ticket.date);
    writeln('   _____________________________________________________________');writeln;
    writeln('   ================    FACTURE - TUKI BU GAW    ================');writeln;
    WriteLn('   Date et heure     : ', ticket.date.format);
    writeln('   Type de service   : ', ticket.typeService);
    writeln('   Ville             : ', t.ville);
    case t.typeService of
        Peage : begin
            writeln('   Destination       : ', t.vileDest);
            writeln('   Nombre de km      : ', t.nbKm, 'km');
            writeln('   Prix unitaire     : ', t.prixParKm, ' Francs CFA');
        end;

        Parking: begin
            writeln('   Nombre d''heures   : ', t.nbHeuresGare, 'h');
            writeln('   Prix unitaire     : ', t.prixParHeure, ' Francs CFA');
            t.montant := PRIX_PARKING_PAR_HEURE * t.nbHeuresGare;
        end;
        Depannage: begin
            writeln('   Probleme          : ', t.nomProbleme);
            writeln('   Prix              : ', t.montant, ' Francs CFA');
        end;
    end;

    write('   Client abonne     : ');
    if(client.abonne) then begin
        writeln('OUI, ', REDUCTION, '% de reduction');
        t.montant := t.montant - ((t.montant * REDUCTION) DIV 100);
        Assign(f_abonnes, NOM_FICHIER_ABONNES);
        reset(f_abonnes);
        while(not EOF(f_abonnes)) do begin
            read(f_abonnes, tmp_client);
            if(tmp_client.nomComplet = client.nomComplet) then begin
                client.credit := client.credit - t.montant;
                seek(f_abonnes, filepos(f_abonnes)-1);
                write(f_abonnes, client);
            end;
        end;
        close(f_abonnes);
    end
    else writeln('NON, pas de reduction ');
    writeln('   Prix total        : ', t.montant, ' Francs CFA');
    writeln;writeln('                                               - Bonne route !');
    writeln('   _____________________________________________________________');writeln;
    EnregistrerTicket(f_tickets, t);
end;

(**
 * Service de parking.
 * Pour accelerer les tests, on suppose que 1s => 1h (du temps reel)
 *)
procedure GarerAuParking(var c : tClient; var f : tGare);
var t_debut, t_gare : tTime;
begin
    ticket.typeService := Parking;

    GetTime(t_debut.h, t_debut.m, t_debut.s, t_debut.c);

    writeln;
    writeln('   =============================================================');
    writeln('   |                       SERVICE DE PARKING                  |');
    writeln('   =============================================================');

    writeln;
    writeln('   Nous avons gare votre voiture au parking.');
    writeln('   Le cout du parking est ', PRIX_PARKING_PAR_HEURE, ' F/Heure');
    writeln('   Appuyer sur une touche pour recuperer votre voiture.');
    write('   ');readkey;

    GetTime(t_gare.h, t_gare.m, t_gare.s, t_gare.c);
    if(t_gare.s < t_debut.s) then
        t_gare.s := t_gare.s - t_debut.s + 60
    else t_gare.s := t_gare.s - t_debut.s;
    ticket.nbHeuresGare := t_gare.s;
    ticket.prixParHeure := PRIX_PARKING_PAR_HEURE;

    writeln;
    writeln('   Voila votre voiture ', c.nomComplet, '.');
    facturerClient(ticket);
end;

(**
 * Service de depannage des voitures
 *)
procedure DepannerVoiture(var c : tClient; var g : tGare);
begin
    ticket.typeService := Depannage;
    repeat
        writeln;
        writeln('   =============================================================');
        writeln('   |                      SERVICE DE DEPANNAGE                 |');
        writeln('   =============================================================');
        writeln('   Quelle est la panne de voiture ?');
        writeln('   1. Recharger gazoil                  (6500 F)');
        writeln('   2. Huile epuisee                     (10500 F)');
        writeln('   3. Phare cassee                      (8000 F)');
        writeln('   4. Moteur en panne                   (32000 F)');
        writeln('   5. Vous ignorer d''ou vient la panne  (9000 F)');
        write('   Votre choix > ');
        readln(n);
    until((n >= 1) AND (n <= 5));

    case n of
        1: begin ticket.montant := 6500;  ticket.nomProbleme := 'Recharger gazoil'; end;
        2: begin ticket.montant := 10500; ticket.nomProbleme := 'Huile epuisee';    end;
        3: begin ticket.montant := 8000;  ticket.nomProbleme := 'Phare cassee';     end;
        4: begin ticket.montant := 32000; ticket.nomProbleme := 'Moteur en panne';  end;
        5: begin
            ticket.montant := 9000;       ticket.nomProbleme := 'Entretien';
            writeln('   Vous ne connaissez pas le probleme, le montant est fixe a 9000 F');
        end;
    end;

    writeln('   Depannage ... ... ...');
    facturerClient(ticket);
    writeln('   Votre voiture a ete reparee, vous pouvez mainteant conduire.');
end;

(**
 * Voyager
 * Cette procedure est applle une fois le client veux quitter la ville.
 * C'est donc ici que le service de peage est utilise par le client.
 * La somme totale est deduite du nombre de km qu'il va parcourir au total.
 *)
procedure Voyager(var c : tClient; var g : tGare);
begin
    ticket.typeService := Peage;
    repeat
        writeln('   Ou voulez vous aller ?');
        case g.nom of
            Dakar: begin
                writeln('   1. Louga');
                writeln('   2. Thies');
                writeln('   3. Saint Louis');
            end;
            StLouis: begin
                writeln('   1. Louga');
                writeln('   2. Thies');
                writeln('   3. Dakar');
            end;
            Louga: begin
                writeln('   1. Dakar');
                writeln('   2. Thies');
                writeln('   3. Saint Louis');
            end;
            Thies: begin
                writeln('   1. Louga');
                writeln('   2. Dakar');
                writeln('   3. Saint Louis');
            end;
        end;
        write('   Entrez votre destination > ');
        readln(n);
    until((n >= 1) and (n <= 3));

    ticket.prixParKm := PRIX_PEAGE_PAR_KM;
    case n of
        1: begin
            ticket.vileDest := Louga;
           if((g.nom = Dakar) OR (g.nom = Louga)) then
               ticket.nbKm := DIST_DAKAR_THIES + DIST_THIES_LOUGA
            else if(g.nom = StLouis) then
                ticket.nbKm := DIST_LOUGA_ST_LOUIS
            else if(g.nom = Thies) then
                ticket.nbKm := DIST_THIES_LOUGA;
        end;
        2: begin
            ticket.vileDest := Thies;
           if((g.nom = Dakar) OR (g.nom = Thies)) then
               ticket.nbKm := DIST_DAKAR_THIES
            else if(g.nom = StLouis) then
                ticket.nbKm := DIST_LOUGA_ST_LOUIS + DIST_THIES_LOUGA
            else if(g.nom = Louga) then
                ticket.nbKm := DIST_THIES_LOUGA;
        end;
        3: begin
            ticket.vileDest := StLouis;
           if((g.nom = Dakar) OR (g.nom = StLouis)) then
               ticket.nbKm := DIST_DAKAR_THIES + DIST_THIES_LOUGA + DIST_LOUGA_ST_LOUIS
            else if(g.nom = Louga) then
                ticket.nbKm := DIST_LOUGA_ST_LOUIS
            else if(g.nom = Thies) then
                ticket.nbKm := DIST_THIES_LOUGA + DIST_LOUGA_ST_LOUIS;
        end;
    end;
    ticket.montant := ticket.nbKm * ticket.prixParKm;
    facturerClient(ticket);
end;

(**
 * Partie administration
 * Dans cette partie, les administrateurs de TUKI BU GAW gere l'application:
 * Ils auront la possibilite:
 * - D'abonner ou desabonner un client
 * - De voir la liste des abonnes
 * - D'acceder aux tickets utilises
 * - Reinitialiser l'application
 * - etc.
 *)
procedure ADMIN_TUKI_BU_GAW();
var terminer : boolean;
begin
    clrscr;
    terminer := false;
    while(not terminer) do begin
        repeat
            writeln;
            writeln('   =============================================================');
            writeln('   |                     ADMIN - TUKI BU GAW                   |');
            writeln('   =============================================================');
            writeln('   1. Afficher la liste des abonnes');
            writeln('   2. Afficher les tickets');
            writeln('   3. Ajouter un abonne');
            writeln('   4. Supprimer un abonne');
            writeln('   5. Reinitialiser l''application');
            writeln('   6. Retour au menu pricipal');
            write('   Votre choix > ');
            readln(n);
        until((n >= 1) and (n <= 6));

        case n of
            1: AfficherAbonnes();
            2: AfficherTickets();
            3: AjouterAbonne();
            4: SupprimerAbonne(client);
            5: InitialiserApp();
            6: terminer := true;
        end;
    end;
end;

(**
 * Partie client.
 * Dans cette partie, le client accede au services de TUKI BU GAW: Peage, Parking, Depannage.
 *)
procedure PartieClients();
var g : tGare;
var terminer : boolean;
begin
    clrscr;
    terminer := false;
    while(not terminer) do begin
        writeln;
        writeln('   =============================================================');
        writeln('   |                       PARTIE CLIENTS                      |');
        writeln('   =============================================================');

        if(nouveau) then begin
            write('   Donnez votre nom complet s''il vous plait > ');
            readln(client.nomComplet);
            if(estAbonne(client.nomComplet)) then begin
                recupererAbonne(client.nomComplet, client);
                writeln('   Content de vous revoir, ', client.nomComplet, ', vous ete un abonne.');
            end
            else
                client.abonne := false;
            // Recherche de la gare ou se trouve le client
            repeat
                writeln('   Sur quelle gare etes vous actuellement ?');
                writeln('      1. Dakar');
                writeln('      2. Saint Louis');
                writeln('      3. Louga');
                writeln('      4. Thies');
                write('     Donnez votre position > ');
                readln(n);
            until((n >= 1) AND (n <= 4));
            case n of
                1: begin
                    g.nom := Dakar;
                    ticket.ville := Dakar;
                end;
                2: begin
                    g.nom := StLouis;
                    ticket.ville := StLouis;
                end;
                3: begin
                    g.nom := Louga;
                    ticket.ville := Louga;
                end;
                4: begin
                    g.nom := Thies;
                    ticket.ville := Thies;
                end;
            end;
            nouveau := false;
        end;

        repeat
            writeln('   Que voulez vous faire ', client.nomComplet, ' ?');
            writeln('      1. Depanner votre voiture');
            writeln('      2. Amener votre voiture au parking');
            writeln('      3. Voyager');
            if(client.abonne) then writeln('      4. Gerer votre abonnement')
            else                   writeln('      4. S''abonner');
            writeln('      5. Retour au menu pricipal');

            write('     Votre choix > ');
            readln(n);
        until((n >= 1) and (n <= 5));

        case n of
            1: DepannerVoiture(client, g);
            2: GarerAuParking(client, g);
            3: Voyager(client, g);
            4: begin
                if(client.abonne) then GererAbonnement(client)
                else AbonnerClient(client);
            end;
            5: terminer := true;
        end;
    end;
end;

procedure attendreUtilisateur();
begin
    writeln;writeln;
    writeln('   Appuyez sur une touche pour revenir en arriere.');
    write('   ');readkey;
end;

(**
 * Statistiques des voitures par tranches horaires.
 * L'utilisateur entre une fourchette et la procedure affiche le nombre de voitures qui ont utilises cette autoroutes
 * dans cet intervalle de temps.
 *)
procedure StatistiquesParTranchesHoraires();
var d1, d2 : tDateTime; terminer : boolean;
    tmp : string;
begin
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    reset(f_tickets);

    terminer := false;
    while(not terminer) do begin
        clrscr;
        writeln('   ==============================================================');
        writeln('   |     FREQUENTATIONS DES AUTOROUTES PAR TRANCHES HORAIRES    |');
        writeln('   ==============================================================');

        writeln('   Entrez less date entre lesquelles vous voulez voir les statistiques.');
        writeln('   La premiere date doit etre inferieur a la deuxieme.');
        writeln('   Le format est de type jour/mois/annee (Exemple: 01/05/1999).');writeln;
        write('   Entrez la premiere date (format: jj/mm/aaaa) > ');
            readln(str);
            tmp := Copy(str, 1, 2);
            d1.jour_mois := StrToInt(tmp);
            tmp := Copy(str, 4, 2);
            d1.mois := StrToInt(tmp);
            tmp := Copy(str, 7, 4);
            d1.annee := StrToInt(tmp);
            formaterDate(d1);
        write('   Entrez la deuxieme date (format: jj/mm/aaaa) > ');
            readln(str);
            tmp := Copy(str, 1, 2);
            d2.jour_mois := StrToInt(tmp);
            tmp := Copy(str, 4, 2);
            d2.mois := StrToInt(tmp);
            tmp := Copy(str, 7, 4);
            d2.annee := StrToInt(tmp);
            formaterDate(d2);

        repeat
            writeln('   Voulez-vous preciser les heures et minutes ?');
            writeln('   1. NON              2. OUI');
            write('   Choix > ');
            readln(n);
        until ((n = 1) OR (n = 2));

        if(n = 2) then begin
            writeln('   Les les deux temps. Le format est hh:mm (Exemple 13:43 pour 14h 43min).');
            write('   Entrez la premiere heure (hh:mm) > ');
            readln(str);
            tmp := Copy(str, 1, 2);
            d1.heures := StrToInt(tmp);
            tmp := Copy(str, 4, 2);
            d1.minutes := StrToInt(tmp);
            formaterHeure(d1);
            write('   Entrez la deuxieme heure (hh:mm) > ');
            readln(str);
            tmp := Copy(str, 1, 2);
            d2.heures := StrToInt(tmp);
            tmp := Copy(str, 4, 2);
            d2.minutes := StrToInt(tmp);
            formaterHeure(d2);
        end;
        i := 0;
        while(not EOF(f_tickets)) do begin
            read(f_tickets, ticket);
            with ticket do begin
                if(ticket.typeService = Peage) then
                    if((d1.annee <= date.annee) AND (d2.annee >= date.annee)) then begin
                        if(n = 2) then begin
                            if(((d1.heures <= date.heures) AND (d2.heures >= date.heures)) AND ((d1.minutes <= date.minutes) AND (d2.minutes >= date.minutes))) then begin
                                i := i + 1;
                            end;
                        end
                        else i := i + 1;
                    end;
            end;
        end;
        writeln;
        if(i = 1) then
            writeln('   Il n''y a qu''une seule voiture qui est passe par cette autoroute entre ', d1.format, ' et ', d2.format, '.')
        else if(i > 1) then
            writeln('    Il y a ', i, ' voitures qui sont passes par cette autoroute entre ', d1.format, ' et ', d2.format, '.')
        else writeln('    Il n''y a aucune voiture qui est passe par cette autoroute entre ', d1.format, ' et ', d2.format, '.');

        write('   ');readkey;
        repeat
            writeln;writeln('   Saisir d''autres dates ?');
            writeln('   1. OUI              2. NON');
            write('    Entrez votre reponse > '); readln(n);
        until ((n = 1) OR (n = 2));
        if(n = 2) then terminer := true;
    end;

    close(f_tickets);
    attendreUtilisateur();
end;

(**
 * Affiche l'utilisation moyenne des services de parkings ou de depannages.
 * @param jours : jour de week-end | jour ouvrable
 *)
procedure AfficherMoyenne(const jours : string);
var d : tDateTime;
begin
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    reset(f_tickets);
    i := 0; j := 1; n := 0; d.mois := 0;
    while(not EOF(f_tickets)) do begin
        read(f_tickets, ticket);
        if(ticket.typeService = Peage) then begin
            case jours of
                'travail': begin
                    if(ticket.date.jour_semaine in [1 .. 5]) then begin
                        if((ticket.date.mois <> d.mois) AND ( n <> 0)) then
                            j := j + 1;
                        i := i + 1; n := 1;
                        d.mois := ticket.date.mois;
                    end;
                end;
                'week-ends': begin
                    if(ticket.date.jour_semaine in [6 .. 7]) then begin
                        if((ticket.date.mois <> d.mois) AND ( n <> 0)) then
                            j := j + 1;
                        i := i + 1; n := 1;
                        d.mois := ticket.date.mois;
                    end;
                end;
            end;
        end;
    end;
    writeln;
    if(j > 1) then
        i := i DIV j;
    if(i = 1) then
        if(jours = 'travail') then
            writeln('   Il n''y a en moyenne qu''une seule voiture qui passe par cette autoroute les jours de travail.')
        else writeln('   Il n''y a en moyenne qu''une seule voiture qui passe par cette autoroute les week-ends.')
    else if(i > 1) then
        if (jours = 'travail') then
            writeln('    Il y a en moyenne ', i, ' voitures qui passent par cette autoroute les jours de travail.')
        else  writeln('    Il y a en moyenne ', i, ' voitures qui passent par cette autoroute les week-ends.')
    else begin
        if (jours = 'travail') then
            writeln('    Il n''y a en moyenne 0 voiture qui passe par cette autoroute les jours de travail.')
        else writeln('    Il n''y a en moyenne 0 voiture qui passe par cette autoroute les week-ends.');
    end;
    close(f_tickets);
    attendreUtilisateur();
end;

(**
 * Statistiques des voitures par jours de travail.
 *)
procedure StatistiquesParJourTravail();
begin
    clrscr;
    writeln('   =============================================================');
    writeln('   |     FREQUENTATIONS DES AUTOROUTES PAR JOURS DE TRAVAIL    |');
    writeln('   =============================================================');
    AfficherMoyenne('travail');
end;

(**
 * Statistiques des voitures par week-ends.
 *)
procedure StatistiquesParWeekends();
begin
    clrscr;
    writeln('   =============================================================');
    writeln('   |        FREQUENTATIONS DES AUTOROUTES PAR WEEK-ENDS        |');
    writeln('   =============================================================');
    AfficherMoyenne('week-ends');
end;

(**
 * Statistiques des voitures  par jours feriers.
 *
 *)
procedure StatistiquesParJourFeriers();
// Par exemple 3 jours de feriers.
var jours_ferier : array[1 .. 3] of tDateTime;
    i_s          : array[1 .. 3] of integer;
begin
    clrscr;
    writeln('   =============================================================');
    writeln('   |       FREQUENTATIONS DES AUTOROUTES PAR JOURS FERIES      |');
    writeln('   =============================================================');
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    reset(f_tickets);

    // Fete le 4 avril, independance du Senegal
    jours_ferier[1].jour_mois := 4;
    jours_ferier[1].mois := 4;
    // Ferier le 15 Aout
    jours_ferier[2].jour_mois := 5;
    jours_ferier[2].mois := 8;
    // Ferier le 31 Decembre
    jours_ferier[3].jour_mois := 31;
    jours_ferier[3].mois := 12;

    for i := 1 to 3 do begin
        i_s[i] := 0;
    end;
    while(not EOF(f_tickets)) do begin
        read(f_tickets, ticket);
        if(ticket.typeService = Peage) then begin
            for i := 1 to 3 do begin
                if((ticket.date.mois = jours_ferier[i].mois) AND (ticket.date.jour_mois = jours_ferier[i].jour_mois)) then
                    i_s[i] := i_s[i] + 1;
            end;
        end;
    end;

    writeln('   -------------------------------------------');
    writeln('   |  Jours feriers  |   Nombre de voitures  |');
    writeln('   |-----------------|-----------------------|');
    {}write('   |  Le 4 Avril     |         ');writeln(i_s[1] : 4, '|':11);
    {}write('   |  Le 15 Aout     |         ');writeln(i_s[1] : 4, '|':11);
    {}write('   |  Le 31 Decembre |         ');writeln(i_s[1] : 4, '|':11);
    writeln('   -------------------------------------------');
    close(f_tickets);
    attendreUtilisateur();
end;

(**
 * Statistiques des voitures par categories.
 * Un tableau est dessine avec les entetes: Categorie, Nombres de voitures, Moyenne par jour).
 * Pour les categories on a : Poids Lourd, Personnelle, Transport, Deux Roues.
 *)
procedure StatistiquesVoituresParCategories();
var i_s   : array[1 .. 4] of integer;
    j_s : array[1 .. 4] of integer;
    dates                  : array[1 .. 4] of tDateTime;
    ns                     : array[1 .. 4] of integer;
begin
    clrscr;
    writeln('   =============================================================');
    writeln('   |          STATISTIQUES DES VOITURES PAR CATEGORIES         |');
    writeln('   =============================================================');
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    reset(f_tickets);writeln;writeln;

    for i := 1 to 4 do begin
        i_s[i] := 0;
        j_s[i] := 0;
        dates[i].jour_mois := 0;
        ns[i] := 0;
    end;
    while(not EOF(f_tickets)) do begin
        read(f_tickets, ticket);
        if(ticket.typeService = Peage) then begin
            case ticket.client.voiture.categorie of
                PoidsLourd: begin
                    i_s[1] := i_s[1] + 1;
                    if((ticket.date.jour_mois <> dates[1].jour_mois) AND ( ns[1] <> 0)) then
                        j_s[1] := j_s[1] + 1;
                    dates[1].jour_mois := ticket.date.jour_mois;
                end;
                Personnelle: begin
                    i_s[2] := i_s[2] + 1;
                    if((ticket.date.jour_mois <> dates[2].jour_mois) AND ( ns[2] <> 0)) then
                        j_s[2] := j_s[2] + 1;
                    dates[2].jour_mois := ticket.date.jour_mois;
                end;
                Transport: begin
                    i_s[3] := i_s[3] + 1;
                    if((ticket.date.jour_mois <> dates[3].jour_mois) AND ( ns[3] <> 0)) then
                        j_s[3] := j_s[3] + 1;
                    dates[3].jour_mois := ticket.date.jour_mois;
                end;
                DeuxRoues: begin
                    i_s[4] := i_s[4] + 1;
                    if((ticket.date.jour_mois <> dates[4].jour_mois) AND ( ns[4] <> 0)) then
                        j_s[4] := j_s[4] + 1;
                    dates[4].jour_mois := ticket.date.jour_mois;
                end;
            end;
        end;
    end;
    for i := 1 to 4 do
        if(j_s[i] > 0) then
            i_s[i] := i_s[i] DIV j_s[i];

    writeln('   -----------------------------------------------------------------------------');
    writeln('   |  Categorie    |   Nombre de voitures  |   Moyenne des voitures par jour   |');
    writeln('   |---------------|-----------------------------------------------------------|');
    {}write('   |  Pois lourd   |        ');
    write(i_s[1] : 4, '|':12);
    if(j_s[1] > 0) then i_s[1] := i_s[1] div j_s[1];
    writeln('              ', i_s[1] : 4, '|':18);
    writeln('   |---------------------------------------------------------------------------|');
    {}write('   |  Personnelle  |        ');
    write(i_s[2] : 4, '|':12);
    if(j_s[2] > 0) then i_s[2] := i_s[2] div j_s[2];
    writeln('              ', i_s[2] : 4, '|':18);
    writeln('   |---------------------------------------------------------------------------|');
    {}write('   |  Transport    |        ');
    write(i_s[3] : 4, '|':12);
    if(j_s[3] > 0) then i_s[3] := i_s[3] div j_s[3];
    writeln('              ', i_s[3] : 4, '|':18);
    writeln('   |---------------------------------------------------------------------------|');
    {}write('   |  Deux roues   |        ');
    write(i_s[4] : 4, '|':12);
    if(j_s[4] > 0) then i_s[4] := i_s[4] div j_s[4];
    writeln('              ', i_s[4] : 4, '|':18);
    writeln('   -----------------------------------------------------------------------------');writeln;

    close(f_tickets);
    attendreUtilisateur();
end;

function MoyenneUtilisationParJour(const s : tTypeServiceFourni) : integer;
var d : tDateTime;
begin
    Assign(f_tickets, NOM_FICHIER_TICKETS);
    reset(f_tickets);clrscr;

    i := 0; j := 1; n := 0; d.jour_semaine := 0;
    while(not EOF(f_tickets)) do begin
        read(f_tickets, ticket);
        if(ticket.typeService = s) then begin
            if((ticket.date.jour_semaine <> d.jour_semaine) AND ( n <> 0)) then
                j := j + 1;
            i := i + 1; n := 1;
            d.jour_semaine := ticket.date.jour_semaine;
        end;
    end;
    if(j > 1) then i := i DIV j;
    close(f_tickets);
    MoyenneUtilisationParJour := i;
end;

procedure StatistiquesUtilisationParkings();
begin
    writeln('   ===============================================================');
    writeln('   |   STATISTIQUES DE L''UTILISATION DES SERVICES DE PARKINGS   |');
    writeln('   ===============================================================');
    writeln('En moyenne ', MoyenneUtilisationParJour(Parking), ' voiture(s) utilise(nt) les services de parkings par jour.');
    attendreUtilisateur();
end;

procedure StatistiquesUtilisationDepanages();
begin
    writeln('   =================================================================');
    writeln('   |    STATISTIQUES DE L''UTILISATION DES SERVICES DE DEPANAGES   |');
    writeln('   =================================================================');
    writeln('En moyenne ', MoyenneUtilisationParJour(Depannage), ' voiture(s) utilise(nt) les services de depanages par jour.');
    attendreUtilisateur();
end;

procedure MenuStatistiques();
var terminer : boolean;
begin
    terminer := false;
    while(not terminer) do begin
        repeat
            clrscr;
            writeln('   =============================================================');
            writeln('   |                        STATISTIQUES                       |');
            writeln('   =============================================================');
            writeln('   Afficher les frequentations des autoroutes par :');
            writeln('       1. Tranches horaires.');
            writeln('       2. Jours de travail.');
            writeln('       3. Jours feriers.');
            writeln('       4. Week-ends.');
            writeln('   5. Statistiques de voitures par categories.');
            writeln('   6. Utilisation des parkings.');
            writeln('   7. Utilisation des services de depanages.');
            writeln('   8. Retour');
            write('   Votre choix > ');
            readln(n);
        until((n >= 1) and (n <= 8));

        case n of
            1: StatistiquesParTranchesHoraires();
            2: StatistiquesParJourTravail();
            3: StatistiquesParJourFeriers();
            4: StatistiquesParWeekends();
            5: StatistiquesVoituresParCategories();
            6: StatistiquesUtilisationParkings();
            7: StatistiquesUtilisationDepanages();
            8: terminer := true;
        end;
    end;
end;

procedure MenuPrincipal();
begin
    terminer := false;
    while(not terminer) do begin
        repeat
            clrscr;
            writeln;
            writeln('   =============================================================');
            writeln('   |                          TUKI BU GAW                      |');
            writeln('   =============================================================');
            writeln('   1. Administration de TUKI BU GAW');
            writeln('   2. Partie clients');
            writeln('   3. Statistiques');
            writeln('   4. Quitter');

            write('   Votre choix > ');
            readln(n);
        until((n >= 1) and (n <= 4));

        nouveau := true;
        case n of
            1: ADMIN_TUKI_BU_GAW();
            2: PartieClients();
            3: MenuStatistiques();
            4: terminer := true;
        end;
    end;
end;

Begin
    clrscr;
    MenuPrincipal();
    writeln;writeln;writeln;

    writeln('   MERCI !');
    write('   ');readln;
End.
