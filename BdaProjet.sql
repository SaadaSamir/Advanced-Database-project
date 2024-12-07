CREATE TABLESPACE SQL3_TBS
  DATAFILE 'sql3_tbs_datafile.dbf' SIZE 100M
  AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITES;

CREATE TEMPORARY TABLESPACE SQL3_TempTBS
  TEMPFILE 'sql3_temptbs_tempfile.dbf' SIZE 50M
  AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED
  EXTEND MANAGEMENT LOCAL UNIFORM SIZE 1M;

CREATE USER SQL3 IDENTIFIED BY PASSWORD
  DEFAULT TABLESPACE SQL3_TBS
  TEMPORARY TABLESPACE SQL3_TempTBS;

GRANT ALL PRIVILEDGES TO SQL3;

CREATE TYPE SuccursaleType;
/

CREATE TYPE AgenceType;
/

CREATE TYPE ClientType;
/

CREATE TYPE CompteType;
/

CREATE TYPE OperationType;
/

CREATE TYPE PretType;
/


create type t_set_ref_Compte as table of ref CompteType;
/
create type t_set_ref_pret as table of ref PretType;
/
create type t_set_ref_Operation as table of ref OperationType;
/
create type t_set_ref_Agence as table of ref AgenceType;
/


CREATE OR REPLACE TYPE SuccursaleType AS OBJECT (
  NumSucc NUMBER,
  nomSucc VARCHAR2(50),
  adresseSucc VARCHAR2(100),
  region VARCHAR2(20),
  Agences t_set_ref_Agence,
  
  MEMBER FUNCTION countMainAgences RETURN NUMBER,
  MEMBER FUNCTION pretANSEJ RETURN NUMBER
);
/
CREATE OR REPLACE TYPE AgenceType AS OBJECT (
  NumAgence NUMBER,
  nomAgence VARCHAR2(50),
  adresseAgence VARCHAR2(100),
  categorie VARCHAR2(20),
  Succursale REF SuccursaleType,
  ComptesAgence t_set_ref_Compte,
  MEMBER FUNCTION countPret RETURN NUMBER,
  MEMBER FUNCTION montantGlobalPret(dateDebut DATE, dateFin DATE) RETURN NUMBER
 
) cascade;

/
CREATE OR REPLACE TYPE ClientType AS OBJECT (
  NumClient NUMBER,
  NomClient VARCHAR2(50),
  TypeClient VARCHAR2(20),
  AdresseClient VARCHAR2(100),
  NumTel VARCHAR2(20),
  Email VARCHAR2(50),
  ComptesClient t_set_ref_Compte
);
/

CREATE OR REPLACE TYPE CompteType AS OBJECT (
  NumCompte NUMBER,
  dateOuverture DATE,
  etatCompte VARCHAR2(20),
  Solde NUMBER,
  Client REF ClientType,
  Agence REF AgenceType,
  prets t_set_ref_pret,
  Operations t_set_ref_Operation
);
/

CREATE OR REPLACE TYPE OperationType AS OBJECT (
  NumOperation NUMBER,
  NatureOp VARCHAR2(20),
  montantOp NUMBER,
  DateOp DATE,
  Observation VARCHAR2(100),
  Compte REF CompteType
);
/

CREATE OR REPLACE TYPE PretType AS OBJECT (
  NumPret NUMBER,
  montantPret NUMBER,
  dateEffet DATE,
  duree NUMBER,
  typePret VARCHAR2(20),
  tauxInteret NUMBER,
  montantEcheance NUMBER,
  Type REF COMPTETYPE
);
/
CREATE OR REPLACE TYPE pretANSEJType AS OBJECT (
  numagence NUMBER,
  numsucc NUMBER
);

CREATE OR REPLACE TYPE pretANSEJTableType AS TABLE OF pretANSEJType;

CREATE OR REPLACE TYPE BODY SuccursaleType AS
  
  MEMBER FUNCTION countMainAgences RETURN NUMBER IS
    nb NUMBER;
  BEGIN
    
      SELECT count(VALUE(b).numagence) into nb
      FROM TABLE(self.agences) b
      WHERE VALUE(b).categorie = 'PRINCIPALE';
   return nb;
  END countMainAgences;
  
  MEMBER FUNCTION pretANSEJ RETURN pretANSEJTableType IS
    v_result pretANSEJTableType := pretANSEJTableType();
  BEGIN
    FOR rec IN (
      SELECT a.numagence, deref(a.succursale).numsucc
      FROM self a, table(a.comptesagence) b, table(value(b).prets) c
      WHERE value(c).typepret = 'ANSEJ' AND a.categorie = 'SECONDAIRE'
    ) LOOP
      v_result.extend;
      v_result(v_result.count) := pretANSEJType(rec.numagence, rec.numsucc);
    END LOOP;

    RETURN v_result;
  END pretANSEJ;
  
END;
/

CREATE OR REPLACE TYPE BODY AgenceType AS
  -- Function to count loans made by the agency
  MEMBER FUNCTION countPret RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT
      COUNT(value(c).numpret) INTO v_total
    FROM
      TABLE(self.comptesAgence) b,
      TABLE(value(b.prets)) c;
    RETURN v_total;
  END countPret;

  -- Function to calculate the total amount of loans made by the agency between specified dates
  MEMBER FUNCTION montantGlobalPret(dateDebut DATE, dateFin DATE) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT
      SUM(value(c).montant) INTO v_total
    FROM
      TABLE(self.comptesAgence) b,
      TABLE(value(b.prets)) c
    WHERE
      c.dateEffet BETWEEN dateDebut AND dateFin;
    RETURN v_total;
  END montantGlobalPret;

END;
/



create TABLE succursale of SuccursaleType(
  constraint pk_succursale primary key(NumSucc),
  constraint ck_region check (UPPER(region) in ('EST', 'OUEST', 'NORD', 'SUD'))
)
nested TABLE Agences store as tab_ref_Agence;

create TABLE agence of AgenceType(
  constraint pk_agence primary key(NumAgence),
  constraint ck_categorie_agence check (UPPER(categorie) in ('PRINCIPALE', 'SECONDAIRE'))
)
nested TABLE ComptesAgence store as tab_comptes;

create TABLE client of ClientType(
  constraint pk_client primary key(NumClient),
  constraint ck_type_client check (UPPER(TypeClient) in ('PARTICULIER', 'ENTREPRISE'))
)
nested TABLE ComptesClient store as tab_comptes_client;

create TABLE compte of CompteType(
  constraint pk_compte primary key(NumCompte),
  constraint ck_etat_compte check (UPPER(etatCompte) in ('ACTIF', 'BLOQUEE'))
)
nested TABLE prets store as tab_prets
nested TABLE Operations store as tab_operations;

create TABLE operation of OperationType(
  constraint pk_operation primary key(NumOperation)
);

create TABLE pret of PretType(
  constraint pk_pret primary key(NumPret),
  constraint ck_pret_type check (UPPER(typePret) in ('ANSEJ', 'VEHICULE', 'IMMOBILIER', 'ANJEM'))
)
;
ALTER TABLE Agence
ADD CONSTRAINT fk_agence_succursale
FOREIGN KEY (NumSucc) REFERENCES succursale(NumSucc);

ALTER TABLE Compte
ADD CONSTRAINT fk_compte_client
FOREIGN KEY (NumClient) REFERENCES Client(NumClient);

ALTER TABLE Compte
ADD CONSTRAINT fk_compte_agence
FOREIGN KEY (NumAgence) REFERENCES Agence(NumAgence);

ALTER TABLE Operation
ADD CONSTRAINT fk_operation_compte
FOREIGN KEY (NumCompte) REFERENCES Compte(NumCompte);

ALTER TABLE Pret
ADD CONSTRAINT fk_pret_compte
FOREIGN KEY (NumCompte) REFERENCES Compte(NumCompte);

insert into succursale values(SuccursaleType(001, 'CitiBank-Alger-est', '28 Rue Didouche', 'EST', t_set_ref_Agence()));

INSERT INTO Succursale 
VALUES (SuccursaleType(002, 'CitiBank-Alger-ouest', '15 Rue Belouizdad', 'OUEST', t_set_ref_Agence()));


INSERT INTO Succursale 
VALUES (SuccursaleType(003, 'CitiBank-Oran-nord', '10 Avenue Mohamed V', 'NORD', t_set_ref_Agence()));

-- Inserting the fourth example
INSERT INTO Succursale 
VALUES (SuccursaleType(004, 'CitiBank-Constantine-est', '5 Rue Larbi Ben Mhidi', 'EST', t_set_ref_Agence()));


INSERT INTO Succursale 
VALUES (SuccursaleType(005, 'CitiBank-Annaba-sud', '30 Avenue de lALN', 'SUD', t_set_ref_Agence()));

-- Inserting the sixth example
INSERT INTO Succursale 
VALUES (SuccursaleType(006, 'CitiBank-Tizi Ouzou-ouest', '3 Rue Colonel Amirouche', 'OUEST', t_set_ref_Agence()));

INSERT INTO agence 
VALUES (AgenceType(101, 'CitiBank-agence-alger-01', '9 Rue Colonel mentouri', 'PRINCIPALE', (select ref(a) from succursale a where a.NumSucc = 001),t_set_ref_Compte()));


INSERT INTO agence 
VALUES (AgenceType(102, 'CitiBank-agence-alger-02', '12 Rue Belouizdad', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 001), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(103, 'CitiBank-agence-alger-03', '20 Avenue Pasteur', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 001), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(104, 'CitiBank-agence-alger-04', '15 Boulevard Amirouche', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 001), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(105, 'CitiBank-agence-alger-05', '8 Rue Larbi Ben Mhidi', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 001), t_set_ref_Compte()));

-- Succursale 002
INSERT INTO agence 
VALUES (AgenceType(201, 'CitiBank-agence-oran-01', '25 Avenue Mohamed V', 'PRINCIPALE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 002), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(202, 'CitiBank-agence-oran-02', '30 Rue Belarbi Habib', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 002), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(203, 'CitiBank-agence-oran-03', '40 Boulevard Zabana', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 002), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(204, 'CitiBank-agence-oran-04', '12 Avenue de France', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 002), t_set_ref_Compte()));


-- Succursale 003
INSERT INTO agence 
VALUES (AgenceType(301, 'CitiBank-agence-constantine-01', '5 Rue Ali Boumendjel', 'PRINCIPALE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 003), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(302, 'CitiBank-agence-constantine-02', '18 Avenue Larbi Tebessi', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 003), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(303, 'CitiBank-agence-constantine-03', '30 Rue Abane Ramdane', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 003), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(304, 'CitiBank-agence-constantine-04', '10 Boulevard Maata Mohamed', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 003), t_set_ref_Compte()));

-- Succursale 004
INSERT INTO agence 
VALUES (AgenceType(401, 'CitiBank-agence-annaba-01', '3 Rue Didouche Mourad', 'PRINCIPALE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 004), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(402, 'CitiBank-agence-annaba-02', '20 Avenue Mohamed V', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 004), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(403, 'CitiBank-agence-annaba-03', '15 Rue Larbi Ben Mhidi', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 004), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(404, 'CitiBank-agence-annaba-04', '8 Boulevard Zabana', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 004), t_set_ref_Compte()));

-- Succursale 005
INSERT INTO agence 
VALUES (AgenceType(501, 'CitiBank-agence-tizi-01', '12 Rue Colonel Amirouche', 'PRINCIPALE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 005), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(502, 'CitiBank-agence-tizi-02', '25 Avenue Pasteur', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 005), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(503, 'CitiBank-agence-tizi-03', '30 Rue Belarbi Habib', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 005), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(504, 'CitiBank-agence-tizi-04', '40 Boulevard Zighoud Youcef', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 005), t_set_ref_Compte()));

-- Succursale 006
INSERT INTO agence 
VALUES (AgenceType(601, 'CitiBank-agence-bejaia-01', '5 Avenue de lIndépendance', 'PRINCIPALE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 006), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(602, 'CitiBank-agence-bejaia-02', '10 Rue de la Liberté', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 006), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(603, 'CitiBank-agence-bejaia-03', '15 Boulevard Maata Mohamed', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 006), t_set_ref_Compte()));

INSERT INTO agence 
VALUES (AgenceType(604, 'CitiBank-agence-bejaia-04', '20 Rue Ali Boumendjel', 'SECONDAIRE', (SELECT REF(a) FROM succursale a WHERE a.NumSucc = 006), t_set_ref_Compte()));

UPDATE Succursale 
SET Agences = t_set_ref_Agence(SELECT REF(v) 
FROM agence v WHERE TO_CHAR(v.NumAgence) LIKE '1%')
WHERE NumSucc = 001;

insert into table (select l.Agences from succursale l where numsucc= 3)
(select ref(c) from agence c where TO_CHAR(v.NumAgence) LIKE '3%');

INSERT INTO client 
VALUES (ClientType(50045, 'hamza taourirt', 'PARTICULIER', '299 RUE DES BANANES TROP MUR', '0565500022', 'hamzatrt@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1010050045, TO_DATE('30-04-2022', 'DD-MM-YYYY'), 'ACTIF', 350000, (SELECT REF(a) FROM client a WHERE a.NumClient = 50045),(SELECT REF(b) FROM agence b WHERE b.NumAgence = 101), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 1
INSERT INTO client 
VALUES (ClientType(50046, 'Fatima Zohra', 'PARTICULIER', '123 Avenue des Roses', '0655500111', 'fatimazohra@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1010050046, TO_DATE('15-03-2002', 'DD-MM-YYYY'), 'ACTIF', 250000, (SELECT REF(a) FROM client a WHERE a.NumClient = 50046), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 101), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 2
INSERT INTO client 
VALUES (ClientType(50047, 'Kamel Benali', 'ENTREPRISE', '456 Rue de Commerce', '0775500222', 'kamelbenali@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1010050047, TO_DATE('20-05-2012', 'DD-MM-YYYY'), 'ACTIF', 500000, (SELECT REF(a) FROM client a WHERE a.NumClient = 50047), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 101), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 3
INSERT INTO client 
VALUES (ClientType(50048, 'Leila Cherif', 'PARTICULIER', '789 Boulevard des Oliviers', '0555500333', 'leilacherif@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1010050048, TO_DATE('10-06-2022', 'DD-MM-YYYY'), 'ACTIF', 100000, (SELECT REF(a) FROM client a WHERE a.NumClient = 50048), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 101), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 4 for Agence 102
INSERT INTO client 
VALUES (ClientType(51001, 'Karim Djebbar', 'PARTICULIER', '567 Avenue du Soleil', '0666600444', 'karimdjebbar@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1020051001, TO_DATE('25-04-2005', 'DD-MM-YYYY'), 'ACTIF', 150000, (SELECT REF(a) FROM client a WHERE a.NumClient = 51001), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 102), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 5 for Agence 102
INSERT INTO client 
VALUES (ClientType(51002, 'Amina Touati', 'PARTICULIER', '890 Rue des Violettes', '0788800555', 'aminatouati@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1020051002, TO_DATE('30-06-2022', 'DD-MM-YYYY'), 'ACTIF', 200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 51002), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 102), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 6 for Agence 102
INSERT INTO client 
VALUES (ClientType(51003, 'Rachid Amiri', 'ENTREPRISE', '123 Rue de la Mer', '0999900666', 'rachidamiri@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1020051003, TO_DATE('12-08-2022', 'DD-MM-YYYY'), 'ACTIF', 300000, (SELECT REF(a) FROM client a WHERE a.NumClient = 51003), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 102), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 7 for Agence 102
INSERT INTO client 
VALUES (ClientType(51004, 'Salima Kadi', 'PARTICULIER', '456 Avenue de la Plage', '0555500777', 'salimakadi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1020051004, TO_DATE('20-09-2022', 'DD-MM-YYYY'), 'ACTIF', 400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 51004), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 102), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 8 for Agence 103
INSERT INTO client 
VALUES (ClientType(52001, 'Ahmed Benmoussa', 'PARTICULIER', '789 Avenue des Fleurs', '0666600888', 'ahmedbenmoussa@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1030052001, TO_DATE('05-07-2008', 'DD-MM-YYYY'), 'ACTIF', 350000, (SELECT REF(a) FROM client a WHERE a.NumClient = 52001), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 103), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 9 for Agence 103
INSERT INTO client 
VALUES (ClientType(52002, 'Samiha Larbi', 'ENTREPRISE', '147 Rue du Commerce', '0777711000', 'samilharbi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1030052002, TO_DATE('10-08-2002', 'DD-MM-YYYY'), 'ACTIF', 450000, (SELECT REF(a) FROM client a WHERE a.NumClient = 52002), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 103), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 10 for Agence 103
INSERT INTO client 
VALUES (ClientType(52003, 'Nadia Boudjema', 'PARTICULIER', '258 Avenue des Roses', '0888822111', 'nadiaboudjema@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1030052003, TO_DATE('15-09-2015', 'DD-MM-YYYY'), 'ACTIF', 550000, (SELECT REF(a) FROM client a WHERE a.NumClient = 52003), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 103), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 11 for Agence 103
INSERT INTO client 
VALUES (ClientType(52004, 'Hichem Ferhati', 'PARTICULIER', '369 Boulevard des Oliviers', '0999933444', 'hichemferhati@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1030052004, TO_DATE('20-10-2009', 'DD-MM-YYYY'), 'ACTIF', 650000, (SELECT REF(a) FROM client a WHERE a.NumClient = 52004), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 103), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 12 for Agence 104
INSERT INTO client 
VALUES (ClientType(53001, 'Linda Mokrani', 'PARTICULIER', '456 Avenue des Pivoines', '0666600999', 'lindamokrani@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1040053001, TO_DATE('25-11-2011', 'DD-MM-YYYY'), 'ACTIF', 750000, (SELECT REF(a) FROM client a WHERE a.NumClient = 53001), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 104), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 13 for Agence 104
INSERT INTO client 
VALUES (ClientType(53002, 'Mohamed El Kebir', 'ENTREPRISE', '789 Rue du Château', '0777722000', 'mohamedelkebir@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1040053002, TO_DATE('30-12-2010', 'DD-MM-YYYY'), 'ACTIF', 850000, (SELECT REF(a) FROM client a WHERE a.NumClient = 53002), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 104), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 14 for Agence 104
INSERT INTO client 
VALUES (ClientType(53003, 'Amel Kaddour', 'PARTICULIER', '147 Avenue de la Fontaine', '0888833111', 'amelkaddour@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1040053003, TO_DATE('05-01-2023', 'DD-MM-YYYY'), 'ACTIF', 950000, (SELECT REF(a) FROM client a WHERE a.NumClient = 53003), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 104), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 15 for Agence 104
INSERT INTO client 
VALUES (ClientType(53004, 'Hassan Bouzidi', 'PARTICULIER', '258 Rue de la Paix', '0999944555', 'hassanbouzidi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1040053004, TO_DATE('10-02-2020', 'DD-MM-YYYY'), 'ACTIF', 1050000, (SELECT REF(a) FROM client a WHERE a.NumClient = 53004), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 104), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 16 for Agence 105
INSERT INTO client 
VALUES (ClientType(54001, 'Yasmine Benamar', 'PARTICULIER', '123 Avenue des Roses', '0666600111', 'yasminebenamar@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1050054001, TO_DATE('15-03-2016', 'DD-MM-YYYY'), 'ACTIF', 1500000, (SELECT REF(a) FROM client a WHERE a.NumClient = 54001), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 105), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 17 for Agence 105
INSERT INTO client 
VALUES (ClientType(54002, 'Samir Toumi', 'ENTREPRISE', '456 Rue de Commerce', '0777722333', 'samirtoumi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1050054002, TO_DATE('20-05-2017', 'DD-MM-YYYY'), 'ACTIF', 1650000, (SELECT REF(a) FROM client a WHERE a.NumClient = 54002), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 105), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 18 for Agence 105
INSERT INTO client 
VALUES (ClientType(54003, 'Malika Belkacem', 'PARTICULIER', '789 Boulevard des Oliviers', '0888844666', 'malikabelkacem@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1050054003, TO_DATE('25-06-2018', 'DD-MM-YYYY'), 'ACTIF', 1800000, (SELECT REF(a) FROM client a WHERE a.NumClient = 54003), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 105), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 19 for Agence 105
INSERT INTO client 
VALUES (ClientType(54004, 'Omar Meziani', 'PARTICULIER', '258 Rue de la Mer', '0999955777', 'omarmeziani@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(1050054004, TO_DATE('30-07-2019', 'DD-MM-YYYY'), 'ACTIF', 1950000, (SELECT REF(a) FROM client a WHERE a.NumClient = 54004), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 105), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 20 for Agence 201
INSERT INTO client 
VALUES (ClientType(10101, 'Nadia Benmoussa', 'PARTICULIER', '123 Rue des Fleurs', '0666611111', 'nadiabenmoussa@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2010010101, TO_DATE('15-08-2020', 'DD-MM-YYYY'), 'ACTIF', 2000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10101), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 201), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 21 for Agence 201
INSERT INTO client 
VALUES (ClientType(10102, 'Khaled Djebbar', 'ENTREPRISE', '456 Avenue de la République', '0777733333', 'khaleddjebbar@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2010010102, TO_DATE('20-09-2021', 'DD-MM-YYYY'), 'ACTIF', 2200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10102), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 201), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 22 for Agence 201
INSERT INTO client 
VALUES (ClientType(10103, 'Karima Touati', 'PARTICULIER', '789 Avenue des Acacias', '0888855555', 'karimatouati@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2010010103, TO_DATE('25-10-2022', 'DD-MM-YYYY'), 'ACTIF', 2400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10103), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 201), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 23 for Agence 201
INSERT INTO client 
VALUES (ClientType(10104, 'Ahmed Kaddour', 'PARTICULIER', '147 Rue de la Paix', '0999966666', 'ahmedkaddour@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2010010104, TO_DATE('30-11-2023', 'DD-MM-YYYY'), 'ACTIF', 2600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10104), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 201), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 24 for Agence 202
INSERT INTO client 
VALUES (ClientType(10201, 'Sofiane Boudjema', 'PARTICULIER', '123 Rue des Roses', '0666622222', 'sofianeboudjema@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2020010201, TO_DATE('15-12-2023', 'DD-MM-YYYY'), 'ACTIF', 3000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10201), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 202), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 25 for Agence 202
INSERT INTO client 
VALUES (ClientType(10202, 'Lamia Belkacem', 'ENTREPRISE', '456 Avenue de la Liberté', '0777744444', 'lamiabelkacem@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2020010202, TO_DATE('20-01-2024', 'DD-MM-YYYY'), 'ACTIF', 3200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10202), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 202), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 26 for Agence 202
INSERT INTO client 
VALUES (ClientType(10203, 'Salim Meziani', 'PARTICULIER', '789 Boulevard de la Mer', '0888866666', 'salimmeziani@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2020010203, TO_DATE('25-02-2023', 'DD-MM-YYYY'), 'ACTIF', 3400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10203), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 202), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 27 for Agence 202
INSERT INTO client 
VALUES (ClientType(10204, 'Fatima Zohraoui Toumi', 'PARTICULIER', '147 Rue de la Liberté', '0999977777', 'fatimazohratoumi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2020010204, TO_DATE('30-03-2022', 'DD-MM-YYYY'), 'ACTIF', 3600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10204), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 202), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 28 for Agence 203
INSERT INTO client 
VALUES (ClientType(10301, 'Ahmed Benmoussa', 'PARTICULIER', '123 Rue des Fleurs', '0666633333', 'ahmedbenmoussa@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2030010301, TO_DATE('15-04-2021', 'DD-MM-YYYY'), 'ACTIF', 4000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10301), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 203), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 29 for Agence 203
INSERT INTO client 
VALUES (ClientType(10302, 'Karima Touatina', 'ENTREPRISE', '456 Avenue de la République', '0777755555', 'karimatouati@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2030010302, TO_DATE('20-05-2020', 'DD-MM-YYYY'), 'ACTIF', 4200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10302), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 203), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 30 for Agence 203
INSERT INTO client 
VALUES (ClientType(10303, 'Yasmine Benamar', 'PARTICULIER', '789 Avenue des Acacias', '0888877777', 'yasminebenamar@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2030010303, TO_DATE('25-06-2020', 'DD-MM-YYYY'), 'ACTIF', 4400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10303), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 203), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 31 for Agence 203
INSERT INTO client 
VALUES (ClientType(10304, 'Lamia Belkacem', 'PARTICULIER', '147 Rue de la Paix', '0999988888', 'lamiabelkacem@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2030010304, TO_DATE('30-07-2019', 'DD-MM-YYYY'), 'ACTIF', 4600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10304), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 203), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 32 for Agence 204
INSERT INTO client 
VALUES (ClientType(10401, 'Fatima Zohra Meziani', 'PARTICULIER', '123 Rue des Roses', '0666644444', 'fatimazohrameziani@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2040010401, TO_DATE('15-08-2018', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10401), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 204), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 33 for Agence 204
INSERT INTO client 
VALUES (ClientType(10402, 'Omar Toumi', 'ENTREPRISE', '456 Avenue de la Liberté', '0777766666', 'omartoumi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2040010402, TO_DATE('20-09-2017', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10402), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 204), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 34 for Agence 204
INSERT INTO client 
VALUES (ClientType(10403, 'Sofiane Benmoussa', 'PARTICULIER', '789 Avenue des Acacias', '0888888888', 'sofianebenmoussa@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2040010403, TO_DATE('25-10-2016', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10403), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 204), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 35 for Agence 204
INSERT INTO client 
VALUES (ClientType(10404, 'Lila Kaddour', 'PARTICULIER', '147 Rue de la Paix', '0999999999', 'lilakaddour@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(2040010404, TO_DATE('30-11-2015', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10404), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 204), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 36 for Agence 301
INSERT INTO client 
VALUES (ClientType(10501, 'Ahmed Benmoussa', 'PARTICULIER', '123 Rue des Roses', '0666633333', 'ahmedbenmoussa@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3010010501, TO_DATE('15-04-2015', 'DD-MM-YYYY'), 'ACTIF', 4000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10501), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 301), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 37 for Agence 301
INSERT INTO client 
VALUES (ClientType(10502, 'Karima Touatia', 'ENTREPRISE', '456 Avenue de la République', '0777755555', 'karimatouati@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3010010502, TO_DATE('20-05-2014', 'DD-MM-YYYY'), 'ACTIF', 4200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10502), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 301), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 38 for Agence 301
INSERT INTO client 
VALUES (ClientType(10503, 'Yasmine Benamar', 'PARTICULIER', '789 Avenue des Acacias', '0888877777', 'yasminebenamar@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3010010503, TO_DATE('25-06-2014', 'DD-MM-YYYY'), 'ACTIF', 4400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10503), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 301), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 39 for Agence 301
INSERT INTO client 
VALUES (ClientType(10504, 'Lamia Belkacem', 'PARTICULIER', '147 Rue de la Paix', '0999988888', 'lamiabelkacem@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3010010504, TO_DATE('30-07-2014', 'DD-MM-YYYY'), 'ACTIF', 4600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10504), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 301), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 40 for Agence 302
INSERT INTO client 
VALUES (ClientType(10601, 'Fatima Zohra Meziane', 'PARTICULIER', '123 Rue des Roses', '0666644444', 'fatimazohrameziani@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3020010601, TO_DATE('15-08-2013', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10601), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 302), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 41 for Agence 302
INSERT INTO client 
VALUES (ClientType(10602, 'Omar Toumi', 'ENTREPRISE', '456 Avenue de la Liberté', '0777766666', 'omartoumi@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3020010602, TO_DATE('20-09-2013', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10602), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 302), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 42 for Agence 302
INSERT INTO client 
VALUES (ClientType(10603, 'Sofiane Benmoussa', 'PARTICULIER', '789 Avenue des Acacias', '0888888888', 'sofianebenmoussa@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3020010603, TO_DATE('25-10-2012', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10603), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 302), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 43 for Agence 302
INSERT INTO client 
VALUES (ClientType(10604, 'Lila Kaddour', 'PARTICULIER', '147 Rue de la Paix', '0999999999', 'lilakaddour@gmail.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3020010604, TO_DATE('30-11-2012', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10604), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 302), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 44 for Agence 303
INSERT INTO client 
VALUES (ClientType(10701, 'John Smith', 'PARTICULIER', '123 Main Street', '1234567890', 'john.smith@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3030010701, TO_DATE('30-11-2002', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10701), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 303), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 45 for Agence 303
INSERT INTO client 
VALUES (ClientType(10702, 'Emily Johnson', 'ENTREPRISE', '456 Oak Avenue', '0987654321', 'emily.johnson@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3030010702, TO_DATE('30-10-2012', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10702), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 303), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 46 for Agence 303
INSERT INTO client 
VALUES (ClientType(10703, 'William Brown', 'PARTICULIER', '789 Pine Street', '1122334455', 'william.brown@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3030010703, TO_DATE('30-11-2010', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10703), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 303), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 47 for Agence 303
INSERT INTO client 
VALUES (ClientType(10704, 'Olivia Davis', 'PARTICULIER', '147 Elm Street', '5544332211', 'olivia.davis@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3030010704, TO_DATE('11-11-2020', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10704), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 303), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 48 for Agence 304
INSERT INTO client 
VALUES (ClientType(10801, 'Michael Johnson', 'PARTICULIER', '123 Oak Street', '1234567890', 'michael.johnson@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3040010801, TO_DATE('30-11-2018', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10801), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 304), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 49 for Agence 304
INSERT INTO client 
VALUES (ClientType(10802, 'Jennifer Williams', 'ENTREPRISE', '456 Maple Avenue', '0987654321', 'jennifer.williams@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3040010802, TO_DATE('30-07-2022', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10802), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 304), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 50 for Agence 304
INSERT INTO client 
VALUES (ClientType(10803, 'James Brown', 'PARTICULIER', '789 Pine Street', '1122334455', 'james.brown@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3040010803, TO_DATE('30-11-2012', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10803), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 304), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 51 for Agence 304
INSERT INTO client 
VALUES (ClientType(10804, 'Jessica Davis', 'PARTICULIER', '147 Elm Street', '5544332211', 'jessica.davis@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(3040010804, TO_DATE('30-11-2012', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10804), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 304), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 52 for Agence 401
INSERT INTO client 
VALUES (ClientType(10901, 'Robert Smith', 'PARTICULIER', '123 Oak Street', '1234567890', 'robert.smith@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4010010901, TO_DATE('2024-08-15', 'YYYY-MM-DD'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10901), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 401), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 53 for Agence 401
INSERT INTO client 
VALUES (ClientType(10902, 'Susan Johnson', 'ENTREPRISE', '456 Maple Avenue', '0987654321', 'susan.johnson@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4010010902, TO_DATE('30-01-2012', 'DD-MM-YYYY'), 'BLOQUEE', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10902), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 401), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 54 for Agence 401
INSERT INTO client 
VALUES (ClientType(10903, 'Daniel Brown', 'PARTICULIER', '789 Pine Street', '1122334455', 'daniel.brown@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4010010903, TO_DATE('30-11-2018', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10903), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 401), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 55 for Agence 401
INSERT INTO client 
VALUES (ClientType(10904, 'Rebecca Davis', 'PARTICULIER', '147 Elm Street', '5544332211', 'rebecca.davis@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4010010904, TO_DATE('30-11-2002', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 10904), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 401), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 56 for Agence 402
INSERT INTO client 
VALUES (ClientType(11001, 'Michael Johnson', 'PARTICULIER', '123 Oak Street', '1234567890', 'michael.johnson@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4020011001, TO_DATE('10-12-2012', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11001), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 402), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 57 for Agence 402
INSERT INTO client 
VALUES (ClientType(11002, 'Jennifer Williams', 'ENTREPRISE', '456 Maple Avenue', '0987654321', 'jennifer.williams@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4020011002, TO_DATE('30-11-2022', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11002), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 402), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 58 for Agence 402
INSERT INTO client 
VALUES (ClientType(11003, 'James Brown', 'PARTICULIER', '789 Pine Street', '1122334455', 'james.brown@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4020011003, TO_DATE('03-11-2012', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11003), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 402), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 59 for Agence 402
INSERT INTO client 
VALUES (ClientType(11004, 'Jessica Davis', 'PARTICULIER', '147 Elm Street', '5544332211', 'jessica.davis@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4020011004, TO_DATE('30-01-2002', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11004), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 402), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 60 for Agence 403
INSERT INTO client 
VALUES (ClientType(11101, 'William Smith', 'PARTICULIER', '123 Oak Street', '1234567890', 'william.smith@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4030011101, TO_DATE('30-11-2007', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11101), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 403), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 61 for Agence 403
INSERT INTO client 
VALUES (ClientType(11102, 'Sophia Johnson', 'ENTREPRISE', '456 Maple Avenue', '0987654321', 'sophia.johnson@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4030011102, TO_DATE('30-11-2005', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11102), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 403), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 62 for Agence 403
INSERT INTO client 
VALUES (ClientType(11103, 'Alexander Brown', 'PARTICULIER', '789 Pine Street', '1122334455', 'alexander.brown@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4030011103, TO_DATE('30-11-2000', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11103), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 403), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 63 for Agence 403
INSERT INTO client 
VALUES (ClientType(11104, 'Isabella Davis', 'PARTICULIER', '147 Elm Street', '5544332211', 'isabella.davis@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4030011104, TO_DATE('30-11-2011', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11104), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 403), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 64 for Agence 404
INSERT INTO client 
VALUES (ClientType(11201, 'Olivia Smith', 'PARTICULIER', '123 Oak Street', '1234567890', 'olivia.smith@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4040011201, TO_DATE('30-11-2012', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11201), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 404), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 65 for Agence 404
INSERT INTO client 
VALUES (ClientType(11202, 'Mia Johnson', 'ENTREPRISE', '456 Maple Avenue', '0987654321', 'mia.johnson@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4040011202, TO_DATE('30-11-2013', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11202), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 404), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 66 for Agence 404
INSERT INTO client 
VALUES (ClientType(11203, 'Ethan Brown', 'PARTICULIER', '789 Pine Street', '1122334455', 'ethan.brown@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4040011203, TO_DATE('30-11-2014', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11203), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 404), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 67 for Agence 404
INSERT INTO client 
VALUES (ClientType(11204, 'Ava Davis', 'PARTICULIER', '147 Elm Street', '5544332211', 'ava.davis@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(4040011204, TO_DATE('30-01-2012', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11204), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 404), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 68 for Agence 501
INSERT INTO client 
VALUES (ClientType(11301, 'Haruto Suzuki', 'PARTICULIER', '1-1 Ginza, Chuo-ku', '0901234567', 'haruto.suzuki@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5010011301, TO_DATE('30-02-2012', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11301), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 501), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 69 for Agence 501
INSERT INTO client 
VALUES (ClientType(11302, 'Yuna Tanaka', 'ENTREPRISE', '2-2 Shibuya, Shibuya-ku', '0809876543', 'yuna.tanaka@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5010011302, TO_DATE('30-03-2012', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11302), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 501), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 70 for Agence 501
INSERT INTO client 
VALUES (ClientType(11303, 'Ryota Nakamura', 'PARTICULIER', '3-3 Shinjuku, Shinjuku-ku', '0701122334', 'ryota.nakamura@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5010011303, TO_DATE('30-04-2012', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11303), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 501), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 71 for Agence 501
INSERT INTO client 
VALUES (ClientType(11304, 'Sakura Sato', 'PARTICULIER', '4-4 Asakusa, Taito-ku', '0805544332', 'sakura.sato@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5010011304, TO_DATE('30-05-2012', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11304), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 501), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 72 for Agence 502
INSERT INTO client 
VALUES (ClientType(11401, 'Hiroshi Yamamoto', 'PARTICULIER', '5-5 Roppongi, Minato-ku', '0901111222', 'hiroshi.yamamoto@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011401, TO_DATE('30-06-2012', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11401), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 73 for Agence 502
INSERT INTO client 
VALUES (ClientType(11402, 'Mika Ito', 'ENTREPRISE', '6-6 Marunouchi, Chiyoda-ku', '0803333444', 'mika.ito@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011402, TO_DATE('30-07-2012', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11402), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 74 for Agence 502
INSERT INTO client 
VALUES (ClientType(11403, 'Yuki Tanaka', 'PARTICULIER', '7-7 Ueno, Taito-ku', '0706666777', 'yuki.tanaka@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011403, TO_DATE('30-08-2012', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11403), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 75 for Agence 502
INSERT INTO client 
VALUES (ClientType(11404, 'Aoi Watanabe', 'PARTICULIER', '8-8 Shibuya, Shibuya-ku', '0808888999', 'aoi.watanabe@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011404, TO_DATE('30-09-2012', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11404), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 72 for Agence 502
INSERT INTO client 
VALUES (ClientType(11401, 'Hiroshi Yamamoto', 'PARTICULIER', '5-5 Roppongi, Minato-ku', '0901111222', 'hiroshi.yamamoto@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011401, TO_DATE('30-10-2012', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11401), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 73 for Agence 502
INSERT INTO client 
VALUES (ClientType(11402, 'Mika Ito', 'ENTREPRISE', '6-6 Marunouchi, Chiyoda-ku', '0803333444', 'mika.ito@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011402, TO_DATE('30-11-2012', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11402), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 74 for Agence 502
INSERT INTO client 
VALUES (ClientType(11403, 'Yuki Tanaka', 'PARTICULIER', '7-7 Ueno, Taito-ku', '0706666777', 'yuki.tanaka@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011403, TO_DATE('30-12-2012', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11403), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 75 for Agence 502
INSERT INTO client 
VALUES (ClientType(11404, 'Aoi Watanabe', 'PARTICULIER', '8-8 Shibuya, Shibuya-ku', '0808888999', 'aoi.watanabe@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5020011404, TO_DATE('30-01-2015', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11404), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 502), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 76 for Agence 503
INSERT INTO client 
VALUES (ClientType(11501, 'Lin Chen', 'PARTICULIER', '9-9 Nanjing Road, Huangpu District', '13911112222', 'lin.chen@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5030011501, TO_DATE('30-01-2016', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11501), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 503), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 77 for Agence 503
INSERT INTO client 
VALUES (ClientType(11502, 'Wei Zhang', 'ENTREPRISE', '10-10 Hanzhong Road, Jingan District', '13833334444', 'wei.zhang@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5030011502, TO_DATE('30-01-2017', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11502), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 503), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 78 for Agence 503
INSERT INTO client 
VALUES (ClientType(11503, 'Xin Liu', 'PARTICULIER', '11-11 Huaihai Road, Xuhui District', '13766667777', 'xin.liu@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5030011503, TO_DATE('30-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11503), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 503), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 79 for Agence 503
INSERT INTO client 
VALUES (ClientType(11504, 'Hui Wang', 'PARTICULIER', '12-12 Changle Road, Xuhui District', '13888889999', 'hui.wang@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5030011504, TO_DATE('30-01-2019', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11504), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 503), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 80 for Agence 504
INSERT INTO client 
VALUES (ClientType(11601, 'Jung Soo Kim', 'PARTICULIER', '13-13 Gangnam-daero, Gangnam-gu', '01011112222', 'jungsoo.kim@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5040011601, TO_DATE('30-01-2020', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11601), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 504), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 81 for Agence 504
INSERT INTO client 
VALUES (ClientType(11602, 'Min Joo Lee', 'ENTREPRISE', '14-14 Yeouido-dong, Yeongdeungpo-gu', '01033334444', 'minjoo.lee@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5040011602, TO_DATE('30-01-2021', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11602), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 504), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 82 for Agence 504
INSERT INTO client 
VALUES (ClientType(11603, 'Hyun Woo Park', 'PARTICULIER', '15-15 Jongno-gu, Sajik-ro', '01066667777', 'hyunwoo.park@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5040011603, TO_DATE('30-01-2021', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11603), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 504), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 83 for Agence 504
INSERT INTO client 
VALUES (ClientType(11604, 'Sung Mi Choi', 'PARTICULIER', '16-16 Jung-gu, Euljiro', '01088889999', 'sungmi.choi@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(5040011604, TO_DATE('30-01-2022', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11604), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 504), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 84 for Agence 601
INSERT INTO client 
VALUES (ClientType(11701, 'Takahiro Yamaguchi', 'PARTICULIER', '17-17 Shinjuku, Shinjuku-ku', '08011112222', 'takahiro.yamaguchi@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6010011701, TO_DATE('30-01-2023', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11701), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 601), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 85 for Agence 601
INSERT INTO client 
VALUES (ClientType(11702, 'Yui Tanaka', 'ENTREPRISE', '18-18 Shibuya, Shibuya-ku', '08033334444', 'yui.tanaka@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6010011702, TO_DATE('01-01-2012', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11702), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 601), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 86 for Agence 601
INSERT INTO client 
VALUES (ClientType(11703, 'Riku Nakamura', 'PARTICULIER', '19-19 Ueno, Taito-ku', '07066667777', 'riku.nakamura@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6010011703, TO_DATE('02-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11703), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 601), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 87 for Agence 601
INSERT INTO client 
VALUES (ClientType(11704, 'Rin Watanabe', 'PARTICULIER', '20-20 Asakusa, Taito-ku', '08088889999', 'rin.watanabe@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6010011704, TO_DATE('03-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11704), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 601), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 88 for Agence 602
INSERT INTO client 
VALUES (ClientType(11801, 'Wei Li', 'PARTICULIER', '21-21 Jing'an Temple, Jing'an District', '13911112222', 'wei.li@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6020011801, TO_DATE('04-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11801), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 602), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 89 for Agence 602
INSERT INTO client 
VALUES (ClientType(11802, 'Xiao Chen', 'ENTREPRISE', '22-22 Peoples Square, Huangpu District', '13833334444', 'xiao.chen@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6020011802, TO_DATE('05-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11802), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 602), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 90 for Agence 602
INSERT INTO client 
VALUES (ClientType(11803, 'Hua Wang', 'PARTICULIER', '23-23 Lujiazui, Pudong District', '13766667777', 'hua.wang@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6020011803, TO_DATE('06-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11803), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 602), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 91 for Agence 602
INSERT INTO client 
VALUES (ClientType(11804, 'Lei Zhang', 'PARTICULIER', '24-24 Xintiandi, Huangpu District', '13888889999', 'lei.zhang@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6020011804, TO_DATE('07-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11804), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 602), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 92 for Agence 603
INSERT INTO client 
VALUES (ClientType(11901, 'Satoshi Yamamoto', 'PARTICULIER', '25-25 Nihonbashi, Chuo City', '08011112222', 'satoshi.yamamoto@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6030011901, TO_DATE('08-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11901), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 603), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 93 for Agence 603
INSERT INTO client 
VALUES (ClientType(11902, 'Aoi Tanaka', 'ENTREPRISE', '26-26 Shinagawa, Minato City', '08033334444', 'aoi.tanaka@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6030011902, TO_DATE('09-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11902), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 603), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 94 for Agence 603
INSERT INTO client 
VALUES (ClientType(11903, 'Haruto Suzuki', 'PARTICULIER', '27-27 Roppongi, Minato City', '07066667777', 'haruto.suzuki@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6030011903, TO_DATE('10-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11903), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 603), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 95 for Agence 603
INSERT INTO client 
VALUES (ClientType(11904, 'Yuki Nakamura', 'PARTICULIER', '28-28 Ikebukuro, Toshima City', '08088889999', 'yuki.nakamura@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6030011904, TO_DATE('12-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 11904), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 603), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 96 for Agence 604
INSERT INTO client 
VALUES (ClientType(12001, 'Aarav Patel', 'PARTICULIER', '29-29 Bandra, Mumbai', '9123456789', 'aarav.patel@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6040012001, TO_DATE('13-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5000000, (SELECT REF(a) FROM client a WHERE a.NumClient = 12001), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 604), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 97 for Agence 604
INSERT INTO client 
VALUES (ClientType(12002, 'Aaradhya Sharma', 'ENTREPRISE', '30-30 Connaught Place, New Delhi', '9234567890', 'aaradhya.sharma@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6040012002, TO_DATE('14-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5200000, (SELECT REF(a) FROM client a WHERE a.NumClient = 12002), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 604), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 98 for Agence 604
INSERT INTO client 
VALUES (ClientType(12003, 'Advik Gupta', 'PARTICULIER', '31-31 Indiranagar, Bangalore', '9345678901', 'advik.gupta@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6040012003, TO_DATE('15-01-2018', 'DD-MM-YYYY'), 'ACTIF', 5400000, (SELECT REF(a) FROM client a WHERE a.NumClient = 12003), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 604), t_set_ref_pret(), t_set_ref_Operation()));

-- Client 99 for Agence 604
INSERT INTO client 
VALUES (ClientType(12004, 'Aarush Khanna', 'PARTICULIER', '32-32 Koregaon Park, Pune', '9456789012', 'aarush.khanna@example.com', t_set_ref_Compte()));

INSERT INTO compte 
VALUES (CompteType(6040012004, TO_DATE('02-01-2020', 'DD-MM-YYYY'), 'ACTIF', 5600000, (SELECT REF(a) FROM client a WHERE a.NumClient = 12004), (SELECT REF(b) FROM agence b WHERE b.NumAgence = 604), t_set_ref_pret(), t_set_ref_Operation()));


-- For Agence 102
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 102)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '102%');

-- For Agence 103
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 103)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '103%');


-- For Agence 104
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 104)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '104%');

-- For Agence 105
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 105)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '105%');

-- For Agence 201
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 201)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '201%');

-- For Agence 202
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 202)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '202%');

-- For Agence 203
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 203)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '203%');

-- For Agence 204
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 204)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '204%');

-- Repeat the process for other agencies similarly
-- For Agence 301
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 301)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '301%');

-- For Agence 302
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 302)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '302%');

-- For Agence 303
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 303)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '303%');

-- For Agence 304
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 304)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '304%');

-- For Agence 401
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 401)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '401%');

-- For Agence 402
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 402)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '402%');

-- For Agence 403
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 403)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '403%');

-- For Agence 404
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 404)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '404%');

-- For Agence 501
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 501)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '501%');

-- For Agence 502
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 502)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '502%');

-- For Agence 503
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 503)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '503%');

-- For Agence 504
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 504)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '504%');

-- For Agence 601
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 601)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '601%');

-- For Agence 602
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 602)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '602%');

-- For Agence 603
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 603)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '603%');

-- For Agence 604
INSERT INTO TABLE (SELECT l.ComptesAgence FROM agence l WHERE NumAgence = 604)
(SELECT REF(c) FROM compte c WHERE TO_CHAR(c.NumCompte) LIKE '604%');





-- Inserting a withdrawal operation
INSERT INTO operation 
VALUES (OperationType(1, 'Retrait', 50000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', (SELECT REF(c) FROM compte c WHERE c.NumCompte = 1010050046)));

-- Inserting a deposit operation
INSERT INTO operation 
VALUES (OperationType(2, 'Dépôt', 100000, TO_DATE('10-05-24', 'DD-MM-YY'), 'Dépôt argent', (SELECT REF(c) FROM compte c WHERE c.NumCompte = 1010050046)));


INSERT INTO operation 
VALUES (OperationType(1, 'Retrait', 50000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', (SELECT REF(c) FROM compte c WHERE c.NumCompte = 1010050046)));


BEGIN
  ajoutCmptProcedure(1, 1010050046);
END;
/

BEGIN
    update_solde_after_insert(1010050046, 1);
END;
/


CREATE OR REPLACE PROCEDURE update_solde_after_insert(
    p_NumCompte IN NUMBER,
    p_NumOperation IN NUMBER
) AS
    v_amount NUMBER;
BEGIN
    -- Determine the amount to be added or subtracted based on the nature of the operation
    SELECT CASE 
               WHEN UPPER(NatureOp) = 'RETRAIT' THEN -1 * montantOp -- Subtract the amount for a retrait
               WHEN UPPER(NatureOp) = 'DEPOT' THEN montantOp -- Add the amount for a depot
               ELSE 0
           END INTO v_amount
    FROM operation
    WHERE NumOperation = p_NumOperation;

    -- Print the value of v_amount for debugging
    DBMS_OUTPUT.PUT_LINE('v_amount: ' || v_amount);

    -- Update the Solde column in the corresponding Compte row
    UPDATE compte
    SET Solde = Solde + v_amount
    WHERE NumCompte = p_NumCompte;

    -- Print a message indicating successful update
    DBMS_OUTPUT.PUT_LINE('Solde updated successfully');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Print a message for no data found
        DBMS_OUTPUT.PUT_LINE('No data found for NumOperation: ' || p_NumOperation);
    WHEN OTHERS THEN
        -- Print the error message
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END;
/
PROCEDURE ajoutCmptProcedure(arg1 IN NUMBER, arg2 IN NUMBER) AS
BEGIN
    
    INSERT INTO TABLE (SELECT p.operations FROM compte p WHERE p.numCompte = arg

    (SELECT REF(c) FROM operation c WHERE c.numoperation = arg1);

    DBMS_OUTPUT.PUT_LINE('Processing operation ' || arg1);
    DBMS_OUTPUT.PUT_LINE('Argument 1: ' || arg1);
    DBMS_OUTPUT.PUT_LINE('Argument 2: ' || arg2);
END ajoutCmptProcedure;


-- NumCompte 2030010303
INSERT INTO operation 
VALUES (
    OperationType(4, 'Depot', 60000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010303))
);

BEGIN
    ajoutCmptProcedure(4, 2030010303);
END;
/

BEGIN
    update_solde_after_insert(2030010303, 4);
END;
/

-- NumCompte 2030010304
INSERT INTO operation 
VALUES (
    OperationType(5, 'Retrait', 30000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(5, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 5);
END;
/
-- NumCompte 2030010304
INSERT INTO operation 
VALUES (
    OperationType(100, 'Depot', 30000, TO_DATE('01-05-23', 'DD-MM-YY'), 'Depot argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(100, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 100);
END;
/
INSERT INTO operation 
VALUES (
    OperationType(101, 'Depot', 40000, TO_DATE('01-08-23', 'DD-MM-YY'), 'Depot argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(101, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 101);
END;
/
INSERT INTO operation 
VALUES (
    OperationType(102, 'Depot', 35000, TO_DATE('07-05-23', 'DD-MM-YY'), 'Depot argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(102, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 102);
END;
/
INSERT INTO operation 
VALUES (
    OperationType(103, 'Retrait', 10000, TO_DATE('17-05-23', 'DD-MM-YY'), 'Depot argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(103, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 103);
END;
/
INSERT INTO operation 
VALUES (
    OperationType(104, 'Retrait', 15000, TO_DATE('17-10-23', 'DD-MM-YY'), 'Depot argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(104, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 104);
END;
/

-- NumCompte 2040010401
INSERT INTO operation 
VALUES (
    OperationType(6, 'Depot', 40000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010401))
);

BEGIN
    ajoutCmptProcedure(6, 2040010401);
END;
/

BEGIN
    update_solde_after_insert(2040010401, 6);
END;
/

-- NumCompte 2040010402
INSERT INTO operation 
VALUES (
    OperationType(7, 'Retrait', 20000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010402))
);

BEGIN
    ajoutCmptProcedure(7, 2040010402);
END;
/

BEGIN
    update_solde_after_insert(2040010402, 7);
END;
/

-- NumCompte 2040010403
INSERT INTO operation 
VALUES (
    OperationType(8, 'Depot', 45000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010403))
);

BEGIN
    ajoutCmptProcedure(8, 2040010403);
END;
/

BEGIN
    update_solde_after_insert(2040010403, 8);
END;
/

-- NumCompte 2040010404
INSERT INTO operation 
VALUES (
    OperationType(9, 'Retrait', 35000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010404))
);

BEGIN
    ajoutCmptProcedure(9, 2040010404);
END;
/

BEGIN
    update_solde_after_insert(2040010404, 9);
END;
/

-- NumCompte 3010010501
INSERT INTO operation 
VALUES (
    OperationType(10, 'Depot', 50000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010501))
);

BEGIN
    ajoutCmptProcedure(10, 3010010501);
END;
/

BEGIN
    update_solde_after_insert(3010010501, 10);
END;
/

-- NumCompte 3010010502
INSERT INTO operation 
VALUES (
    OperationType(11, 'Retrait', 25000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010502))
);

BEGIN
    ajoutCmptProcedure(11, 3010010502);
END;
/

BEGIN
    update_solde_after_insert(3010010502, 11);
END;
/

-- NumCompte 3010010503
INSERT INTO operation 
VALUES (
    OperationType(12, 'Depot', 60000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010503))
);

BEGIN
    ajoutCmptProcedure(12, 3010010503);
END;
/

BEGIN
    update_solde_after_insert(3010010503, 12);
END;
/

-- NumCompte 3010010504
INSERT INTO operation 
VALUES (
    OperationType(13, 'Retrait', 20000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010504))
);

BEGIN
    ajoutCmptProcedure(13, 3010010504);
END;
/

BEGIN
    update_solde_after_insert(3010010504, 13);
END;
/
-- NumCompte 2030010304
INSERT INTO operation 
VALUES (
    OperationType(14, 'Retrait', 45000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2030010304))
);

BEGIN
    ajoutCmptProcedure(14, 2030010304);
END;
/

BEGIN
    update_solde_after_insert(2030010304, 14);
END;
/

-- NumCompte 2040010401
INSERT INTO operation 
VALUES (
    OperationType(15, 'Depot', 50000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010401))
);

BEGIN
    ajoutCmptProcedure(15, 2040010401);
END;
/

BEGIN
    update_solde_after_insert(2040010401, 15);
END;
/

-- NumCompte 2040010402
INSERT INTO operation 
VALUES (
    OperationType(16, 'Retrait', 20000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010402))
);

BEGIN
    ajoutCmptProcedure(16, 2040010402);
END;
/

BEGIN
    update_solde_after_insert(2040010402, 16);
END;
/

-- NumCompte 2040010403
INSERT INTO operation 
VALUES (
    OperationType(17, 'Depot', 60000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010403))
);

BEGIN
    ajoutCmptProcedure(17, 2040010403);
END;
/

BEGIN
    update_solde_after_insert(2040010403, 17);
END;
/

-- NumCompte 2040010404
INSERT INTO operation 
VALUES (
    OperationType(18, 'Retrait', 35000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010404))
);

BEGIN
    ajoutCmptProcedure(18, 2040010404);
END;
/

BEGIN
    update_solde_after_insert(2040010404, 18);
END;
/

-- NumCompte 3010010501
INSERT INTO operation 
VALUES (
    OperationType(19, 'Depot', 75000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010501))
);

BEGIN
    ajoutCmptProcedure(19, 3010010501);
END;
/

BEGIN
    update_solde_after_insert(3010010501, 19);
END;
/

-- NumCompte 3010010502
INSERT INTO operation 
VALUES (
    OperationType(20, 'Retrait', 25000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010502))
);

BEGIN
    ajoutCmptProcedure(20, 3010010502);
END;
/

BEGIN
    update_solde_after_insert(3010010502, 20);
END;
/

-- NumCompte 3010010503
INSERT INTO operation 
VALUES (
    OperationType(21, 'Depot', 55000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010503))
);

BEGIN
    ajoutCmptProcedure(21, 3010010503);
END;
/

BEGIN
    update_solde_after_insert(3010010503, 21);
END;
/

-- NumCompte 3010010504
INSERT INTO operation 
VALUES (
    OperationType(22, 'Retrait', 15000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010504))
);

BEGIN
    ajoutCmptProcedure(22, 3010010504);
END;
/

BEGIN
    update_solde_after_insert(3010010504, 22);
END;
/

-- NumCompte 3020010601
INSERT INTO operation 
VALUES (
    OperationType(23, 'Depot', 40000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010601))
);

BEGIN
    ajoutCmptProcedure(23, 3020010601);
END;
/

BEGIN
    update_solde_after_insert(3020010601, 23);
END;
/

-- NumCompte 3020010602
INSERT INTO operation 
VALUES (
    OperationType(24, 'Retrait', 30000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010602))
);

BEGIN
    ajoutCmptProcedure(24, 3020010602);
END;
/

BEGIN
    update_solde_after_insert(3020010602, 24);
END;
/

-- NumCompte 3020010603
INSERT INTO operation 
VALUES (
    OperationType(25, 'Depot', 80000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010603))
);

BEGIN
    ajoutCmptProcedure(25, 3020010603);
END;
/

BEGIN
    update_solde_after_insert(3020010603, 25);
END;
/

-- NumCompte 3020010604
INSERT INTO operation 
VALUES (
    OperationType(26, 'Retrait', 20000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010604))
);

BEGIN
    ajoutCmptProcedure(26, 3020010604);
END;
/

BEGIN
    update_solde_after_insert(3020010604, 26);
END;
/

-- NumCompte 3030010701
INSERT INTO operation 
VALUES (
    OperationType(27, 'Depot', 70000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010701))
);

BEGIN
    ajoutCmptProcedure(27, 3030010701);
END;
/

BEGIN
    update_solde_after_insert(3030010701, 27);
END;
/

-- NumCompte 3030010702
INSERT INTO operation 
VALUES (
    OperationType(28, 'Retrait', 10000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010702))
);

BEGIN
    ajoutCmptProcedure(28, 3030010702);
END;
/

BEGIN
    update_solde_after_insert(3030010702, 28);
END;
/

-- NumCompte 3030010703
INSERT INTO operation 
VALUES (
    OperationType(29, 'Depot', 95000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010703))
);

BEGIN
    ajoutCmptProcedure(29, 3030010703);
END;
/

BEGIN
    update_solde_after_insert(3030010703, 29);
END;
/

-- NumCompte 3030010704
INSERT INTO operation 
VALUES (
    OperationType(30, 'Retrait', 5000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010704))
);

BEGIN
    ajoutCmptProcedure(30, 3030010704);
END;
/

BEGIN
    update_solde_after_insert(3030010704, 30);
END;
/

-- NumCompte 3040010801
INSERT INTO operation 
VALUES (
    OperationType(31, 'Depot', 80000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3040010801))
);

BEGIN
    ajoutCmptProcedure(31, 3040010801);
END;
/

BEGIN
    update_solde_after_insert(3040010801, 31);
END;
/

-- NumCompte 3040010802
INSERT INTO operation 
VALUES (
    OperationType(32, 'Retrait', 15000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3040010802))
);

BEGIN
    ajoutCmptProcedure(32, 3040010802);
END;
/

BEGIN
    update_solde_after_insert(3040010802, 32);
END;
/

-- NumCompte 3040010803
INSERT INTO operation 
VALUES (
    OperationType(33, 'Depot', 30000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3040010803))
);

BEGIN
    ajoutCmptProcedure(33, 3040010803);
END;
/

BEGIN
    update_solde_after_insert(3040010803, 33);
END;
/

-- NumCompte 3040010804
INSERT INTO operation 
VALUES (
    OperationType(34, 'Retrait', 20000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3040010804))
);

BEGIN
    ajoutCmptProcedure(34, 3040010804);
END;
/

BEGIN
    update_solde_after_insert(3040010804, 34);
END;
/

-- NumCompte 4010010901
INSERT INTO operation 
VALUES (
    OperationType(35, 'Depot', 90000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4010010901))
);

BEGIN
    ajoutCmptProcedure(35, 4010010901);
END;
/

BEGIN
    update_solde_after_insert(4010010901, 35);
END;
/

-- NumCompte 4010010902
INSERT INTO operation 
VALUES (
    OperationType(36, 'Retrait', 45000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4010010902))
);

BEGIN
    ajoutCmptProcedure(36, 4010010902);
END;
/

BEGIN
    update_solde_after_insert(4010010902, 36);
END;
/

-- NumCompte 4010010903
INSERT INTO operation 
VALUES (
    OperationType(37, 'Depot', 60000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4010010903))
);

BEGIN
    ajoutCmptProcedure(37, 4010010903);
END;
/

BEGIN
    update_solde_after_insert(4010010903, 37);
END;
/

-- NumCompte 4010010904
INSERT INTO operation 
VALUES (
    OperationType(38, 'Retrait', 25000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4010010904))
);

BEGIN
    ajoutCmptProcedure(38, 4010010904);
END;
/

BEGIN
    update_solde_after_insert(4010010904, 38);
END;
/

-- NumCompte 4020011001
INSERT INTO operation 
VALUES (
    OperationType(39, 'Depot', 70000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011001))
);

BEGIN
    ajoutCmptProcedure(39, 4020011001);
END;
/

BEGIN
    update_solde_after_insert(4020011001, 39);
END;
/

-- NumCompte 4020011002
INSERT INTO operation 
VALUES (
    OperationType(40, 'Retrait', 30000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011002))
);

BEGIN
    ajoutCmptProcedure(40, 4020011002);
END;
/

BEGIN
    update_solde_after_insert(4020011002, 40);
END;
/

-- NumCompte 4020011003
INSERT INTO operation 
VALUES (
    OperationType(41, 'Depot', 90000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011003))
);

BEGIN
    ajoutCmptProcedure(41, 4020011003);
END;
/

BEGIN
    update_solde_after_insert(4020011003, 41);
END;
/

-- NumCompte 4020011004
INSERT INTO operation 
VALUES (
    OperationType(42, 'Retrait', 15000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011004))
);

BEGIN
    ajoutCmptProcedure(42, 4020011004);
END;
/

BEGIN
    update_solde_after_insert(4020011004, 42);
END;
/

-- NumCompte 4030011101
INSERT INTO operation 
VALUES (
    OperationType(43, 'Depot', 80000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4030011101))
);

BEGIN
    ajoutCmptProcedure(43, 4030011101);
END;
/

BEGIN
    update_solde_after_insert(4030011101, 43);
END;
/

-- NumCompte 4030011102
INSERT INTO operation 
VALUES (
    OperationType(44, 'Retrait', 50000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4030011102))
);

BEGIN
    ajoutCmptProcedure(44, 4030011102);
END;
/

BEGIN
    update_solde_after_insert(4030011102, 44);
END;
/

-- NumCompte 4030011103
INSERT INTO operation 
VALUES (
    OperationType(45, 'Depot', 95000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4030011103))
);

BEGIN
    ajoutCmptProcedure(45, 4030011103);
END;
/

BEGIN
    update_solde_after_insert(4030011103, 45);
END;
/

-- NumCompte 4030011104
INSERT INTO operation 
VALUES (
    OperationType(46, 'Retrait', 20000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4030011104))
);

BEGIN
    ajoutCmptProcedure(46, 4030011104);
END;
/

BEGIN
    update_solde_after_insert(4030011104, 46);
END;
/

-- NumCompte 4040011201
INSERT INTO operation 
VALUES (
    OperationType(47, 'Depot', 70000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
    (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4040011201))
);
                  

BEGIN
    ajoutCmptProcedure(47, 4040011201);
END;
/

BEGIN
    update_solde_after_insert(4040011201, 47);
END;
/
-- NumCompte 5030011503
INSERT INTO operation 
VALUES (
    OperationType(52, 'Depot', 75000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5030011503))
);

BEGIN
    ajoutCmptProcedure(52, 5030011503);
END;
/

BEGIN
    update_solde_after_insert(5030011503, 52);
END;
/

-- NumCompte 5030011504
INSERT INTO operation 
VALUES (
    OperationType(53, 'Retrait', 45000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5030011504))
);

BEGIN
    ajoutCmptProcedure(53, 5030011504);
END;
/

BEGIN
    update_solde_after_insert(5030011504, 53);
END;
/

-- NumCompte 5040011601
INSERT INTO operation 
VALUES (
    OperationType(54, 'Depot', 55000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011601))
);

BEGIN
    ajoutCmptProcedure(54, 5040011601);
END;
/

BEGIN
    update_solde_after_insert(5040011601, 54);
END;
/

-- NumCompte 5040011602
INSERT INTO operation 
VALUES (
    OperationType(55, 'Retrait', 65000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011602))
);

BEGIN
    ajoutCmptProcedure(55, 5040011602);
END;
/

BEGIN
    update_solde_after_insert(5040011602, 55);
END;
/

-- NumCompte 5040011603
INSERT INTO operation 
VALUES (
    OperationType(56, 'Depot', 35000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011603))
);

BEGIN
    ajoutCmptProcedure(56, 5040011603);
END;
/

BEGIN
    update_solde_after_insert(5040011603, 56);
END;
/

-- NumCompte 5040011604
INSERT INTO operation 
VALUES (
    OperationType(57, 'Retrait', 85000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011604))
);

BEGIN
    ajoutCmptProcedure(57, 5040011604);
END;
/

BEGIN
    update_solde_after_insert(5040011604, 57);
END;
/

-- NumCompte 6010011701
INSERT INTO operation 
VALUES (
    OperationType(58, 'Depot', 95000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011701))
);

BEGIN
    ajoutCmptProcedure(58, 6010011701);
END;
/

BEGIN
    update_solde_after_insert(6010011701, 58);
END;
/

-- NumCompte 6010011702
INSERT INTO operation 
VALUES (
    OperationType(59, 'Retrait', 75000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011702))
);

BEGIN
    ajoutCmptProcedure(59, 6010011702);
END;
/

BEGIN
    update_solde_after_insert(6010011702, 59);
END;
/

-- NumCompte 6010011703
INSERT INTO operation 
VALUES (
    OperationType(60, 'Depot', 25000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011703))
);

BEGIN
    ajoutCmptProcedure(60, 6010011703);
END;
/

BEGIN
    update_solde_after_insert(6010011703, 60);
END;
/

-- NumCompte 6010011704
INSERT INTO operation 
VALUES (
    OperationType(61, 'Retrait', 35000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011704))
);

BEGIN
    ajoutCmptProcedure(61, 6010011704);
END;
/

BEGIN
    update_solde_after_insert(6010011704, 61);
END;
/

-- NumCompte 6020011801
INSERT INTO operation 
VALUES (
    OperationType(62, 'Depot', 45000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011801))
);

BEGIN
    ajoutCmptProcedure(62, 6020011801);
END;
/

BEGIN
    update_solde_after_insert(6020011801, 62);
END;
/

-- NumCompte 6020011802
INSERT INTO operation 
VALUES (
    OperationType(63, 'Retrait', 55000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011802))
);

BEGIN
    ajoutCmptProcedure(63, 6020011802);
END;
/

BEGIN
    update_solde_after_insert(6020011802, 63);
END;
/

-- NumCompte 6020011803
INSERT INTO operation 
VALUES (
    OperationType(64, 'Depot', 65000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011803))
);

BEGIN
    ajoutCmptProcedure(64, 6020011803);
END;
/

BEGIN
    update_solde_after_insert(6020011803, 64);
END;
/

-- NumCompte 6020011804
INSERT INTO operation 
VALUES (
    OperationType(65, 'Retrait', 75000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011804))
);

BEGIN
    ajoutCmptProcedure(65, 6020011804);
END;
/

BEGIN
    update_solde_after_insert(6020011804, 65);
END;
/

-- NumCompte 6030011901
INSERT INTO operation 
VALUES (
    OperationType(66, 'Depot', 85000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011901))
);

BEGIN
    ajoutCmptProcedure(66, 6030011901);
END;
/

BEGIN
    update_solde_after_insert(6030011901, 66);
END;
/

-- NumCompte 6030011902
INSERT INTO operation 
VALUES (
    OperationType(67, 'Retrait', 95000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011902))
);

BEGIN
    ajoutCmptProcedure(67, 6030011902);
END;
/

BEGIN
    update_solde_after_insert(6030011902, 67);
END;
/

-- NumCompte 6030011903
INSERT INTO operation 
VALUES (
    OperationType(68, 'Depot', 15000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011903))
);

BEGIN
    ajoutCmptProcedure(68, 6030011903);
END;
/

BEGIN
    update_solde_after_insert(6030011903, 68);
END;
/

-- NumCompte 6030011904
INSERT INTO operation 
VALUES (
    OperationType(69, 'Retrait', 25000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011904))
);

BEGIN
    ajoutCmptProcedure(69, 6030011904);
END;
/

BEGIN
    update_solde_after_insert(6030011904, 69);
END;
/

-- NumCompte 6040012001
INSERT INTO operation 
VALUES (
    OperationType(70, 'Depot', 35000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Dépôt argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6040012001))
);

BEGIN
    ajoutCmptProcedure(70, 6040012001);
END;
/

BEGIN
    update_solde_after_insert(6040012001, 70);
END;
/

-- NumCompte 6040012002
INSERT INTO operation 
VALUES (
    OperationType(71, 'Retrait', 45000, TO_DATE('01-05-24', 'DD-MM-YY'), 'Retrait argent', 
                   (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6040012002))
);

BEGIN
    ajoutCmptProcedure(71, 6040012002);
END;
/
BEGIN
    update_solde_after_insert(71, 6040012002);
END;
/


CREATE OR REPLACE PROCEDURE update_solde_after_borrow(
    p_NumCompte IN NUMBER,
    p_NumPret IN NUMBER
) AS
    v_amount NUMBER;
BEGIN
    -- Determine the borrowed amount based on the specified Pret
    SELECT MONTANTPRET INTO v_amount
    FROM pret
    WHERE NUMPRET = p_NumPret;

    -- Print the borrowed amount for debugging
    DBMS_OUTPUT.PUT_LINE('Borrowed amount: ' || v_amount);

    -- Update the Solde column in the corresponding Compte row
    UPDATE compte
    SET Solde = Solde + v_amount
    WHERE NumCompte = p_NumCompte;

    -- Print a message indicating successful update
    DBMS_OUTPUT.PUT_LINE('Solde updated successfully');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Print a message for no data found
        DBMS_OUTPUT.PUT_LINE('No data found for NumPret: ' || p_NumPret);
    WHEN OTHERS THEN
        -- Print the error message
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END;
/

CREATE OR REPLACE PROCEDURE ajoutCmptPretProcedure(arg1 IN NUMBER, arg2 IN NUMBER) AS

BEGIN
    -- Your logic to process the operation goes here
    -- You can also use the arguments passed to the procedure
    INSERT INTO TABLE (SELECT p.prets FROM compte p WHERE p.numCompte = arg2)

    (SELECT REF(c) FROM pret c WHERE c.numpret = arg1);

    -- Optionally, you can include DBMS_OUTPUT statements for debugging purposes

    DBMS_OUTPUT.PUT_LINE('Processing pret ' || arg1);
    DBMS_OUTPUT.PUT_LINE('Argument 1: ' || arg1);
    DBMS_OUTPUT.PUT_LINE('Argument 2: ' || arg2);

    -- Your processing logic here
END ajoutCmptPretProcedure;
/



-- Generating pret data
INSERT INTO pret 
VALUES (
    pretType(
        1, 
        5000, 
        TO_DATE('2024-05-01', 'YYYY-MM-DD'), 
        12, 
        'ANSEJ',
        5.5, 
        500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 1010050046) -- TYPE
    )
);

-- Procedure calls
BEGIN
    ajoutCmptPretProcedure(1, 1010050046);
END;
/

BEGIN
    update_solde_after_borrow(1010050046, 1);
END;
/

-- Repeat the process for each additional pret
-- For example:

INSERT INTO pret 
VALUES (
    pretType(
        2, 
        6000, 
        TO_DATE('2002-11-30', 'YYYY-MM-DD'), 
        24, 
        'ANJEM',
        6.0, 
        0.00,  -- This signifies that it was repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4010010904) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(2, 4010010904);
END;
/

BEGIN
    update_solde_after_borrow(4010010904, 2);
END;
/

-- Repeat the process for each additional pret
-- Adjust values as needed
-- Pret data and procedure calls for numcompte: 4020011001
INSERT INTO pret 
VALUES (
    pretType(
        3, 
        8000, 
        TO_DATE('2012-12-10', 'YYYY-MM-DD'), 
        36, 
        'VEHICULE',
        7.5, 
        750.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011001) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(3, 4020011001);
END;
/

BEGIN
    update_solde_after_borrow(4020011001, 3);
END;
/

-- Pret data and procedure calls for numcompte: 4020011002
INSERT INTO pret 
VALUES (
    pretType(
        4, 
        10000, 
        TO_DATE('2022-11-30', 'YYYY-MM-DD'), 
        48, 
        'IMMOBILIER',
        6.25, 
        900.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011002) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(4, 4020011002);
END;
/

BEGIN
    update_solde_after_borrow(4020011002, 4);
END;
/
INSERT INTO pret 
VALUES (
    pretType(
        4, 
        10000, 
        TO_DATE('2020-11-30', 'YYYY-MM-DD'), 
        48, 
        'IMMOBILIER',
        6.25, 
        900.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011002) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(4, 4020011002);
END;
/

BEGIN
    update_solde_after_borrow(4020011002, 4);
END;
/

-- Pret data and procedure calls for numcompte: 4020011003
INSERT INTO pret 
VALUES (
    pretType(
        5, 
        12000, 
        TO_DATE('2012-11-03', 'YYYY-MM-DD'), 
        60, 
        'ANSEJ',
        8.0, 
        1100.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011003) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(5, 4020011003);
END;
/

BEGIN
    update_solde_after_borrow(4020011003, 5);
END;
/

-- Pret data and procedure calls for numcompte: 4020011004
INSERT INTO pret 
VALUES (
    pretType(
        6, 
        15000, 
        TO_DATE('2002-01-30', 'YYYY-MM-DD'), 
        72, 
        'VEHICULE',
        7.0, 
        0.00,  -- Repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 4020011004) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(6, 4020011004);
END;
/

BEGIN
    update_solde_after_borrow(4020011004, 6);
END;
/

-- Pret data and procedure calls for numcompte: 5030011503
INSERT INTO pret 
VALUES (
    pretType(
        11, 
        40000, 
        TO_DATE('2018-01-30', 'YYYY-MM-DD'), 
        60, 
        'ANSEJ',
        7.0, 
        2200.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5030011503) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(11, 5030011503);
END;
/

BEGIN
    update_solde_after_borrow(5030011503, 11);
END;
/

-- Pret data and procedure calls for numcompte: 5030011504
INSERT INTO pret 
VALUES (
    pretType(
        12, 
        45000, 
        TO_DATE('2019-01-30', 'YYYY-MM-DD'), 
        72, 
        'ANJEM',
        7.5, 
        2500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5030011504) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(12, 5030011504);
END;
/

BEGIN
    update_solde_after_borrow(5030011504, 12);
END;
/

-- Pret data and procedure calls for numcompte: 5040011601
INSERT INTO pret 
VALUES (
    pretType(
        13, 
        50000, 
        TO_DATE('2020-01-30', 'YYYY-MM-DD'), 
        84, 
        'VEHICULE',
        8.0, 
        0.00,  -- Repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011601) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(13, 5040011601);
END;
/

BEGIN
    update_solde_after_borrow(5040011601, 13);
END;
/

-- Pret data and procedure calls for numcompte: 5040011602
INSERT INTO pret 
VALUES (
    pretType(
        14, 
        55000, 
        TO_DATE('2021-01-30', 'YYYY-MM-DD'), 
        96, 
        'IMMOBILIER',
        8.5, 
        2800.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011602) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(14, 5040011602);
END;
/

BEGIN
    update_solde_after_borrow(5040011602, 14);
END;
/
-- Pret data and procedure calls for numcompte: 5040011603
INSERT INTO pret 
VALUES (
    pretType(
        15, 
        60000, 
        TO_DATE('2021-01-30', 'YYYY-MM-DD'), 
        108, 
        'ANSEJ',
        9.0, 
        3200.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011603) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(15, 5040011603);
END;
/

BEGIN
    update_solde_after_borrow(5040011603, 15);
END;
/

-- Pret data and procedure calls for numcompte: 5040011604
INSERT INTO pret 
VALUES (
    pretType(
        16, 
        65000, 
        TO_DATE('2022-01-30', 'YYYY-MM-DD'), 
        120, 
        'ANJEM',
        9.5, 
        3500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 5040011604) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(16, 5040011604);
END;
/

BEGIN
    update_solde_after_borrow(5040011604, 16);
END;
/

-- Pret data and procedure calls for numcompte: 6010011701
INSERT INTO pret 
VALUES (
    pretType(
        17, 
        70000, 
        TO_DATE('2023-01-30', 'YYYY-MM-DD'), 
        132, 
        'VEHICULE',
        10.0, 
        0.00,  -- Repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011701) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(17, 6010011701);
END;
/

BEGIN
    update_solde_after_borrow(6010011701, 17);
END;
/

-- Pret data and procedure calls for numcompte: 6010011702
INSERT INTO pret 
VALUES (
    pretType(
        18, 
        75000, 
        TO_DATE('2012-01-01', 'YYYY-MM-DD'), 
        144, 
        'IMMOBILIER',
        10.5, 
        3800.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011702) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(18, 6010011702);
END;
/

BEGIN
    update_solde_after_borrow(6010011702, 18);
END;
/

-- Pret data and procedure calls for numcompte: 6010011703
INSERT INTO pret 
VALUES (
    pretType(
        19, 
        80000, 
        TO_DATE('2018-01-02', 'YYYY-MM-DD'), 
        156, 
        'ANSEJ',
        11.0, 
        4000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011703) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(19, 6010011703);
END;
/

BEGIN
    update_solde_after_borrow(6010011703, 19);
END;
/

-- Pret data and procedure calls for numcompte: 6010011704
INSERT INTO pret 
VALUES (
    pretType(
        20, 
        85000, 
        TO_DATE('2018-01-03', 'YYYY-MM-DD'), 
        168, 
        'ANJEM',
        11.5, 
        4500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6010011704) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(20, 6010011704);
END;
/

BEGIN
    update_solde_after_borrow(6010011704, 20);
END;
/

-- Pret data and procedure calls for numcompte: 6020011801
INSERT INTO pret 
VALUES (
    pretType(
        21, 
        90000, 
        TO_DATE('2018-01-04', 'YYYY-MM-DD'), 
        180, 
        'VEHICULE',
        12.0, 
        0.00,  -- Repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011801) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(21, 6020011801);
END;
/

BEGIN
    update_solde_after_borrow(6020011801, 21);
END;
/

-- Pret data and procedure calls for numcompte: 6020011802
INSERT INTO pret 
VALUES (
    pretType(
        22, 
        95000, 
        TO_DATE('2018-01-05', 'YYYY-MM-DD'), 
        192, 
        'IMMOBILIER',
        12.5, 
        4800.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011802) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(22, 6020011802);
END;
/

BEGIN
    update_solde_after_borrow(6020011802, 22);
END;
/
-- Pret data and procedure calls for numcompte: 6020011803
INSERT INTO pret 
VALUES (
    pretType(
        23, 
        100000, 
        TO_DATE('2018-01-06', 'YYYY-MM-DD'), 
        204, 
        'ANSEJ',
        13.0, 
        5000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011803) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(23, 6020011803);
END;
/

BEGIN
    update_solde_after_borrow(6020011803, 23);
END;
/

-- Pret data and procedure calls for numcompte: 6020011804
INSERT INTO pret 
VALUES (
    pretType(
        24, 
        105000, 
        TO_DATE('2018-01-07', 'YYYY-MM-DD'), 
        216, 
        'ANJEM',
        13.5, 
        5500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6020011804) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(24, 6020011804);
END;
/

BEGIN
    update_solde_after_borrow(6020011804, 24);
END;
/

-- Pret data and procedure calls for numcompte: 6030011901
INSERT INTO pret 
VALUES (
    pretType(
        25, 
        110000, 
        TO_DATE('2018-01-08', 'YYYY-MM-DD'), 
        228, 
        'VEHICULE',
        14.0, 
        0.00,  -- Repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011901) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(25, 6030011901);
END;
/

BEGIN
    update_solde_after_borrow(6030011901, 25);
END;
/

-- Pret data and procedure calls for numcompte: 6030011902
INSERT INTO pret 
VALUES (
    pretType(
        26, 
        115000, 
        TO_DATE('2018-01-09', 'YYYY-MM-DD'), 
        240, 
        'IMMOBILIER',
        14.5, 
        6000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011902) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(26, 6030011902);
END;
/

BEGIN
    update_solde_after_borrow(6030011902, 26);
END;
/

-- Pret data and procedure calls for numcompte: 6030011903
INSERT INTO pret 
VALUES (
    pretType(
        27, 
        120000, 
        TO_DATE('2018-01-10', 'YYYY-MM-DD'), 
        252, 
        'ANJEM',
        15.0, 
        6500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011903) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(27, 6030011903);
END;
/

BEGIN
    update_solde_after_borrow(6030011903, 27);
END;
/

-- Pret data and procedure calls for numcompte: 6030011904
INSERT INTO pret 
VALUES (
    pretType(
        28, 
        125000, 
        TO_DATE('2018-01-12', 'YYYY-MM-DD'), 
        264, 
        'VEHICULE',
        15.5, 
        7000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6030011904) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(28, 6030011904);
END;
/

BEGIN
    update_solde_after_borrow(6030011904, 28);
END;
/

-- Pret data and procedure calls for numcompte: 6040012001
INSERT INTO pret 
VALUES (
    pretType(
        29, 
        130000, 
        TO_DATE('2018-01-13', 'YYYY-MM-DD'), 
        276, 
        'ANSEJ',
        16.0, 
        7500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6040012001) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(29, 6040012001);
END;
/

BEGIN
    update_solde_after_borrow(6040012001, 29);
END;
/

-- Pret data and procedure calls for numcompte: 6040012002
INSERT INTO pret 
VALUES (
    pretType(
        30, 
        135000, 
        TO_DATE('2018-01-14', 'YYYY-MM-DD'), 
        288, 
        'IMMOBILIER',
        16.5, 
        8000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6040012002) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(30, 6040012002);
END;
/

BEGIN
    update_solde_after_borrow(6040012002, 30);
END;
/

-- Pret data and procedure calls for numcompte: 6040012003
INSERT INTO pret 
VALUES (
    pretType(
        31, 
        140000, 
        TO_DATE('2018-01-15', 'YYYY-MM-DD'), 
        300, 
        'VEHICULE',
        17.0, 
        0.00,  -- Repaid
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6040012003) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(31, 6040012003);
END;
/

BEGIN
    update_solde_after_borrow(6040012003, 31);
END;
/

-- Pret data and procedure calls for numcompte: 6040012004
INSERT INTO pret 
VALUES (
    pretType(
        32, 
        145000, 
        TO_DATE('2020-01-02', 'YYYY-MM-DD'), 
        312, 
        'ANJEM',
        17.5, 
        8500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 6040012004) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(32, 6040012004);
END;
/

BEGIN
    update_solde_after_borrow(6040012004, 32);
END;
/
-- Pret data and procedure calls for numcompte: 2040010401
INSERT INTO pret 
VALUES (
    pretType(
        33, 
        150000, 
        TO_DATE('2019-01-01', 'YYYY-MM-DD'), -- Adjusted date
        324, 
        'VEHICULE',
        18.0, 
        9000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010401) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(33, 2040010401);
END;
/

BEGIN
    update_solde_after_borrow(2040010401, 33);
END;
/

-- Pret data and procedure calls for numcompte: 2040010402
INSERT INTO pret 
VALUES (
    pretType(
        34, 
        155000, 
        TO_DATE('2018-01-01', 'YYYY-MM-DD'), -- Adjusted date
        336, 
        'IMMOBILIER',
        18.5, 
        9500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010402) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(34, 2040010402);
END;
/

BEGIN
    update_solde_after_borrow(2040010402, 34);
END;
/

-- Pret data and procedure calls for numcompte: 2040010403
INSERT INTO pret 
VALUES (
    pretType(
        35, 
        160000, 
        TO_DATE('2017-01-01', 'YYYY-MM-DD'), -- Adjusted date
        348, 
        'ANSEJ',
        19.0, 
        10000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010403) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(35, 2040010403);
END;
/

BEGIN
    update_solde_after_borrow(2040010403, 35);
END;
/

-- Pret data and procedure calls for numcompte: 2040010404
INSERT INTO pret 
VALUES (
    pretType(
        36, 
        165000, 
        TO_DATE('2016-01-01', 'YYYY-MM-DD'), -- Adjusted date
        360, 
        'ANJEM',
        19.5, 
        10500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 2040010404) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(36, 2040010404);
END;
/

BEGIN
    update_solde_after_borrow(2040010404, 36);
END;
/

-- Pret data and procedure calls for numcompte: 3010010501
INSERT INTO pret 
VALUES (
    pretType(
        37, 
        170000, 
        TO_DATE('2016-01-01', 'YYYY-MM-DD'), -- Adjusted date
        372, 
        'VEHICULE',
        20.0, 
        11000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010501) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(37, 3010010501);
END;
/

BEGIN
    update_solde_after_borrow(3010010501, 37);
END;
/
-- Pret data and procedure calls for numcompte: 3010010502
INSERT INTO pret 
VALUES (
    pretType(
        38, 
        175000, 
        TO_DATE('2015-01-01', 'YYYY-MM-DD'), -- Adjusted date
        384, 
        'ANSEJ',
        20.5, 
        11500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010502) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(38, 3010010502);
END;
/

BEGIN
    update_solde_after_borrow(3010010502, 38);
END;
/

-- Pret data and procedure calls for numcompte: 3010010503
INSERT INTO pret 
VALUES (
    pretType(
        39, 
        180000, 
        TO_DATE('2014-01-01', 'YYYY-MM-DD'), -- Adjusted date
        396, 
        'ANJEM',
        21.0, 
        12000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010503) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(39, 3010010503);
END;
/

BEGIN
    update_solde_after_borrow(3010010503, 39);
END;
/

-- Pret data and procedure calls for numcompte: 3010010504
INSERT INTO pret 
VALUES (
    pretType(
        40, 
        185000, 
        TO_DATE('2013-01-01', 'YYYY-MM-DD'), -- Adjusted date
        408, 
        'IMMOBILIER',
        21.5, 
        12500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3010010504) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(40, 3010010504);
END;
/

BEGIN
    update_solde_after_borrow(3010010504, 40);
END;
/

-- Pret data and procedure calls for numcompte: 3020010601
INSERT INTO pret 
VALUES (
    pretType(
        41, 
        190000, 
        TO_DATE('2012-01-01', 'YYYY-MM-DD'), -- Adjusted date
        420, 
        'ANSEJ',
        22.0, 
        13000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010601) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(41, 3020010601);
END;
/

BEGIN
    update_solde_after_borrow(3020010601, 41);
END;
/
-- Pret data and procedure calls for numcompte: 3020010602
INSERT INTO pret 
VALUES (
    pretType(
        42, 
        195000, 
        TO_DATE('2011-01-01', 'YYYY-MM-DD'), -- Adjusted date
        432, 
        'ANJEM',
        22.5, 
        13500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010602) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(42, 3020010602);
END;
/

BEGIN
    update_solde_after_borrow(3020010602, 42);
END;
/

-- Pret data and procedure calls for numcompte: 3020010603
INSERT INTO pret 
VALUES (
    pretType(
        43, 
        200000, 
        TO_DATE('2010-01-01', 'YYYY-MM-DD'), -- Adjusted date
        444, 
        'VEHICULE',
        23.0, 
        14000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010603) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(43, 3020010603);
END;
/

BEGIN
    update_solde_after_borrow(3020010603, 43);
END;
/

-- Pret data and procedure calls for numcompte: 3020010604
INSERT INTO pret 
VALUES (
    pretType(
        44, 
        205000, 
        TO_DATE('2009-01-01', 'YYYY-MM-DD'), -- Adjusted date
        456, 
        'IMMOBILIER',
        23.5, 
        14500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3020010604) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(44, 3020010604);
END;
/

BEGIN
    update_solde_after_borrow(3020010604, 44);
END;
/

-- Pret data and procedure calls for numcompte: 3030010701
INSERT INTO pret 
VALUES (
    pretType(
        45, 
        210000, 
        TO_DATE('2008-01-01', 'YYYY-MM-DD'), -- Adjusted date
        468, 
        'ANSEJ',
        24.0, 
        15000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010701) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(45, 3030010701);
END;
/

BEGIN
    update_solde_after_borrow(3030010701, 45);
END;
/
-- Pret data and procedure calls for numcompte: 3030010702
INSERT INTO pret 
VALUES (
    pretType(
        46, 
        215000, 
        TO_DATE('2007-01-01', 'YYYY-MM-DD'), -- Adjusted date
        480, 
        'ANJEM',
        24.5, 
        15500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010702) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(46, 3030010702);
END;
/

BEGIN
    update_solde_after_borrow(3030010702, 46);
END;
/

-- Pret data and procedure calls for numcompte: 3030010703
INSERT INTO pret 
VALUES (
    pretType(
        47, 
        220000, 
        TO_DATE('2006-01-01', 'YYYY-MM-DD'), -- Adjusted date
        492, 
        'VEHICULE',
        25.0, 
        16000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010703) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(47, 3030010703);
END;
/

BEGIN
    update_solde_after_borrow(3030010703, 47);
END;
/

-- Pret data and procedure calls for numcompte: 3030010704
INSERT INTO pret 
VALUES (
    pretType(
        48, 
        225000, 
        TO_DATE('2005-01-01', 'YYYY-MM-DD'), -- Adjusted date
        504, 
        'IMMOBILIER',
        25.5, 
        16500.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3030010704) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(48, 3030010704);
END;
/

BEGIN
    update_solde_after_borrow(3030010704, 48);
END;
/

-- Pret data and procedure calls for numcompte: 3040010801
INSERT INTO pret 
VALUES (
    pretType(
        49, 
        230000, 
        TO_DATE('2004-01-01', 'YYYY-MM-DD'), -- Adjusted date
        516, 
        'ANSEJ',
        26.0, 
        17000.00, 
        (SELECT REF(c) FROM compte c WHERE c.NumCompte = 3040010801) -- TYPE
    )
);

BEGIN
    ajoutCmptPretProcedure(49, 3040010801);
END;
/

BEGIN
    update_solde_after_borrow(3040010801, 49);
END;
/

-- figure 38
select count(deref(value(a).client).typeclient) 
from agence b, table(b.comptesagence) a 
where numagence = 101 and upper(deref(value(a).client).typeclient) = 'ENTREPRISE';

-- figure 40
select value(a).nomagence as nnom_agence, value(b).numcompte, value(c).numpret as num_pret, value(c).montantPret as montant
from succursale d, table(d.agences) a, table(value(a).comptesagence) b, table(value(b).prets) c
where numsucc = 002;


--  figure 42
select numcompte
from compte
where numcompte not in(
  select a.numcompte
  from compte a, table(a.operations) b
  where value(b).natureop = 'Depot'
  and value(b).dateop BETWEEN TO_DATE('01-01-2000', 'DD-MM-YYYY') AND TO_DATE('12-31-2022', 'DD-MM-YYYY')
  );

-- figure 44
select sum(value(b).montantpret) as somme_totale_prets
  from compte a, table(a.prets) b
  where numcompte = 4020011002;

--  figure 46
select a.numcompte, deref(a.client).nomclient, deref(a.agence).numagence, value(b).numpret, value(b).montantpret
  from compte a, table(a.prets) b
  where value(b).montantecheance != 0.0;

-- figure 48
SELECT NumCompte
FROM (
    SELECT c.NumCompte, COUNT(*) AS operation_count
    FROM Compte c
    JOIN TABLE(value(c).Operations) o ON 1=1
    WHERE o.NatureOp IN ('retrait', 'depot')
    GROUP BY c.NumCompte
    ORDER BY COUNT(*) DESC
)
WHERE ROWNUM = 1;

-- 14
select numCompte, nbOperations from(
Select a.NumCompte, count(value(b).natureOp) as nbOperations
from compte a, table(a.operations) b
where value(b).natureOp IN ('Retrait', 'Depot')
group by a.NumCompte
order by COUNT(*) DESC
)
WHERE ROWNUM = 1;




select a.numagence, deref(a.succursale).numsucc
  from agence a, table(a.comptesagence) b, table(value(b).prets) c
  where value(c).typepret in 'ANSEJ'and a.categorie in 'SECONDAIRE';

