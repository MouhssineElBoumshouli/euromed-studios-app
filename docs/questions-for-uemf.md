# Questions pour UEMF

À l'attention de **M. Brahim Seddouki, Directeur de la Communication**.

> Note interne (Mouhssine et Claude) : ce document est **l'ordre du jour de la future réunion**. Il ne sera pas envoyé avant. En attendant, chaque « Proposition » est utilisée comme réglage par défaut, modifiable dans l'application (voir `docs/decisions/0001-build-with-adjustable-defaults.md`).

Ces questions viennent du Cahier des Charges. Nous ne voulons pas inventer de règles à la place de l'université. Pour chaque question, nous proposons une réponse par défaut. Un simple « OK » suffit si elle vous convient.

Les questions marquées 🔴 bloquent le design. Les autres peuvent attendre quelques semaines.

| Statut | Signification |
| --- | --- |
| ⏳ | En attente de réponse |
| ✅ | Répondu (la réponse est notée sous la question) |

---

## Document et périmètre

**Q0 ⏳ — Cahier des Charges complet**
Notre version commence à la section 2 et saute la section 5. Pourriez-vous nous envoyer les sections 1 et 5, ou la version complète ?

**Q1 🔴 ⏳ — Studios qui partagent une même salle**
D'après le plan, Plateau TV, Web TV et Euromed Radio sont dans la même salle (Area 2). Chroma Key et Photo sont aussi ensemble (Area 3), tout comme Studio Pédagogique et SpeedMOOC (Area 4).
*Proposition :* réserver un studio bloque automatiquement les autres studios de la même salle sur le même créneau.

**Q2 🔴 ⏳ — Espaces réservables**
Quels espaces peut-on réserver dans l'application ? Le Salon VIP ? Les régies ? Les postes de montage ?
*Proposition :* tous les studios des Areas 1 à 4 et les postes de montage sont réservables. Les régies sont réservées automatiquement avec le studio qu'elles contrôlent. Le Salon VIP ne se réserve pas.

## Réservations

**Q3 🔴 ⏳ — Horaires et durée des créneaux**
Quels sont les horaires d'ouverture et la durée d'un créneau ? Combien de temps à l'avance peut-on réserver ?
*Proposition :* lundi à vendredi de 9h à 18h, créneaux d'1 heure, réservation jusqu'à 30 jours à l'avance.

**Q4 ⏳ — Quotas d'heures par semaine**
Le Cahier des Charges donne l'exemple « 2h/semaine pour un étudiant ». Quels sont les vrais quotas pour chaque profil ?
*Proposition :* chaque quota se règle dans l'application par l'administrateur. On commence avec 2h pour les étudiants et sans limite pour les autres profils, en attendant votre décision.

**Q5 🔴 ⏳ — Qui donne la validation finale (niveau 2) ?**
Le « Responsable des Studios » et l'« Administrateur » sont-ils la même personne ? Qui sont ces personnes aujourd'hui ?
*Proposition :* deux rôles distincts. Le niveau 2 est validé par le Responsable des Studios. L'Administrateur gère l'application.

**Q6 ⏳ — Clubs : profil partagé**
Le Cahier des Charges parle d'un « profil de groupe partagé » pour les clubs.
*Proposition :* chaque club existe dans l'application, mais chaque membre utilise son propre compte. Les représentants du club sont désignés par la Direction des Affaires Estudiantines. Ainsi, on sait toujours qui a fait quoi.

**Q7 🔴 ⏳ — Les validateurs de niveau 1**
Les Doyens, les Directeurs, la Vice-Présidence et le Responsable de la Vie Étudiante utiliseront-ils l'application mobile pour valider ? Ou préfèrent-ils recevoir un e-mail avec un bouton « Valider / Refuser » ?
*Proposition :* les deux. La validation se fait dans l'application, et un e-mail avec un lien est envoyé en parallèle.

**Q8 ⏳ — Priorité des professeurs**
Les professeurs ont la priorité sur le Studio Pédagogique et le SpeedMOOC. Un professeur peut-il prendre un créneau déjà demandé, mais pas encore validé, par un étudiant ?
*Proposition :* non. La priorité veut dire que certains créneaux sont réservés aux professeurs, ou qu'ils sont traités en premier. Elle n'annule pas une demande existante.

**Q9 ⏳ — Clients externes**
Qui fixe les tarifs ? Le paiement se fait-il dans l'application, ou seulement le suivi du devis ? Comment un client externe crée-t-il son compte ?
*Proposition :* l'application gère seulement la demande et le suivi du devis. Le paiement se fait hors application. Les comptes externes sont créés par l'administrateur.

## Accès et sécurité

**Q10 ⏳ — Le code QR à la porte**
Qui scanne le code QR ? Un lecteur à la porte, ou un agent à l'accueil ? Que se passe-t-il si Internet est coupé ?
*Proposition :* le régisseur ou l'accueil scanne avec l'application. Le contrôle fonctionne même sans Internet pendant le créneau.

**Q11 ⏳ — La signature de la charte**
Pourriez-vous nous envoyer le texte du règlement intérieur ? Une case « J'ai lu et j'accepte », avec la date et le nom enregistrés, suffit-elle ?
*Proposition :* oui. Une case à cocher, enregistrée avec la date, l'heure et l'identité de la personne.

**Q12 ⏳ — Livraison des fichiers finaux**
Quel espace cloud utiliser pour livrer les fichiers finaux (OneDrive UEMF, Google Drive, serveur interne) ? Combien de temps faut-il les garder ?
*Proposition :* OneDrive de l'université, avec un lien réservé au porteur du projet.

**Q13 🔴 ⏳ — « Moins de 3 clics »**
Une réservation demande un studio, une date, une activité, la charte et parfois du matériel. Cela ne tient pas en 3 clics exacts.
*Proposition :* 3 écrans au maximum. L'application retient aussi les derniers choix de l'utilisateur.

**Q14 ⏳ — Connexion avec le compte UEMF**
Les étudiants et le personnel ont des adresses @ueuromed.org. Le service informatique peut-il nous permettre de nous connecter avec ces comptes (Microsoft 365) ? Qui contacter au service informatique ?
*Proposition :* connexion avec le compte UEMF. Les clients externes reçoivent un compte séparé.

**Q15 ⏳ — Hébergement et données personnelles**
Où l'application doit-elle être hébergée : serveurs de l'université ou cloud ? L'université a-t-elle déjà une déclaration CNDP (loi 09-08) qui peut couvrir cette application ?
*Proposition :* nous en discutons avec le service informatique avant de commencer le développement.

## Identité visuelle

**Q16 🔴 ⏳ — Charte graphique Euromed Studios**
Pourriez-vous nous envoyer la charte graphique officielle : logo en haute qualité, couleurs exactes, polices ?
*Proposition :* en attendant, nous partons de la brochure (bleu nuit et doré).

**Q17 ⏳ — Langues**
L'application doit-elle être en français seulement, ou aussi en arabe et en anglais ?
*Proposition :* le français d'abord, l'anglais ensuite. L'arabe si vous le demandez.

## Ajoutées pendant le développement

**Q18 ⏳ — Demande d’un validateur pour lui-même**
Un directeur ou une directrice d’établissement est aussi enseignant·e. Sa propre demande ne peut pas être validée par lui-même ou elle-même. Qui la valide au niveau 1 ?
*Proposition :* l’administrateur des Studios, ou un supérieur hiérarchique désigné. Réglable dans l’application.
