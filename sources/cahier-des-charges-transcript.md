Cahier des Charges

Application Mobile "Euromed Studios App"

2\. Architecture Fonctionnelle et Zones Spécifiées

L'application doit fidèlement cartographier la structure physique et organisationnelle des studios, répartie en plusieurs zones fonctionnelles :

- **Studios de Production :** Le Plateau TV, le Studio Podcast, l’Euromed Radio et le Chroma Key Studio
- **Modules de Pédagogie Numérique :** Le Studio Pédagogique et le Speed MOOC.
- **Unités de Postproduction :** Les stations de montage vidéo/audio et les régies techniques centralisées.

3\. Gestion des Profils et Contrôle d'Accès (RBAC)

L'application doit intégrer un système de contrôle d'accès basé sur les rôles (**Role-Based Access Control - RBAC**). Chaque profil dispose de droits et de parcours spécifiques :

- **Étudiants :** Accès limité par défaut, visualiser les espaces et les fonctionnalités des studios. Accès limité à des projets (ex: Studio Podcast, projets académiques). Soumis à une validation hiérarchique systématique.
- **Professeurs / Enseignants-Chercheurs :** Priorité sur les modules de pédagogie numérique (Studio Pédagogique, Speed MOOC). Suivi personnalisé de leurs projets de cours en ligne validés par la hiérarchie.
- **Équipe de Communication :** Gestion simplifiée des projets de communication pour le rayonnement institutionnel (Studio Podcast, Plateau TV).
- **Clubs Étudiants :** Profil de groupe partagé. Permet de réserver pour des activités culturelles validées. La responsabilité légale est adossée à la Direction des Affaires Estudiantines.
- **Clients Externes :** Profil commercial soumis à des autorisations spécifiques et à un suivi de tarification ou de devis.
- **Equipe Technique :** Gestion de la maintenance des équipements, réception du planning .
- **Administrateurs : **Vue d'ensemble sur le planning, gestion de la maintenance des équipements, validation finale des créneaux et supervision globale des projets.

4\. Spécifications Fonctionnelles Détaillées

4.1 Module de Réservation Multi-Créneaux (Gestion des Espaces)

Ce module gère le planning d'occupation en temps réel des infrastructures.

- **Sélection par Usage :** L'utilisateur doit obligatoirement spécifier la nature de l'activité lors de sa demande : Enregistrement, Captation d'image, Montage, ou Mixage audio.

- **Réservation de Matériel Additionnel :** Option permettant de greffer à la réservation de la salle des kits mobiles spécifiques (caméras, microphones, kits d'éclairage).

- **Signature de la Charte de Responsabilité :** Intégration d'une étape obligatoire de signature numérique du règlement intérieur avant la soumission de toute demande.

- **Règles Métiers d'Usage :**

  - Application automatique de quotas d'heures maximums par semaine (ex: 2h/semaine pour un profil Étudiant).
  - Système de pré-verrouillage : Dès la soumission de la demande, le créneau passe au statut **"En attente"** sur le planning général pour éliminer tout risque de collision ou de double réservation.

4.2 Module de Suivi et Gestion de Projets Numériques

Ce module structure la chaîne de valeur audiovisuelle sous la forme d'un flux de travail (**Workflow**) collaboratif :

- **Initialisation du Projet :** Définition de la typologie du projet (Enseignement/MOOC, Recherche, Culture, Communication institutionnelle).

- **Pipeline de Production (Format Jalons / Kanban) :**

  1.  **Pré-production :** Dépôt obligatoire des pièces préparatoires (script, conducteur d'émission ou storyboard).
  2.  **Production :** Liaison automatique du projet avec les créneaux validés dans le module de réservation.
  3.  **Post-production :** Suivi du statut de montage, soumission des demandes de corrections ou de modifications.
  4.  **Validation & Archivage :** Contrôle qualité par l'équipe technique pour l'obtention de la "signature sonore et visuelle professionnelle", puis livraison sécurisée du fichier final via un lien cloud ou autre environnement numérique.

- **Collaboration Intégrée :** Possibilité pour le porteur de projet d'inviter des collaborateurs (ex: un professeur qui ajoute un moniteur étudiant ou un membre de l'équipe technique).

4.3 Workflow d'Approbation Hiérarchique

Toute demande de réservation doit franchir un processus de validation séquentiel strict à deux niveaux :

- **Niveau 1 : Approbation par le Responsable de l'Entité (Validation Métier)**

  - *Étudiants & Clubs :* Validation requise par l’établissement ou le Responsable de la Vie Étudiante (vérification de la pertinence pédagogique/associative).

  - *Professeurs & Chercheurs :* Approbation par le Doyen ou le Directeur de l’établissement de rattachement.

  - *Équipe Communication :* Approbation par le Directeur de la Communication.

  - Clients Externes : Approbation par le La Vice-Présidence Exécutive.

- **Niveau 2 : Validation Finale par le Responsable des Studios (Validation Technique)**

  - Une fois le niveau 1 validé, la demande est poussée vers la Direction chargée de la gestion des Studio pour vérification de la disponibilité de la Régie Technique Centralisée, de la planification des ressources humaines (techniciens, ingénieurs du son) et de l'absence de conflits de maintenance.

- **Gestion des Refus :** Tout refus à l'un des deux niveaux exige la saisie d'un motif obligatoire qui est immédiatement notifié à l'utilisateur.

- **Transparence des statuts :** Suivi en temps réel de l'état de la demande via trois statuts clairs : *En attente entité* → *En attente studio* → *Validée*.

4.4 Fonctionnalités supplémentaires

- **Code QR d'accès temporaire :** Génération automatique d'un code QR sécurisé une fois le niveau 2 validé, actif uniquement durant le créneau.
- **Signalement de l'état du matériel :** Formulaire de sortie de session permettant de signaler instantanément un équipement ou un meuble défectueux, afin de pérenniser le patrimoine.
- **Tableau de bord Régisseur :** Interface optimisée permettant aux techniciens de suivre l'occupation physique des studios en temps réel.

6\. Critères d'Acceptation et Qualité

L'application finale devra se conformer aux exigences de qualité suivantes :

- **Performance :** Temps de réponse des requêtes de planification inférieur à 200ms. Affichage instantané des statuts du calendrier.
- **Disponibilité :** Haute disponibilité requise pour éviter le blocage des accès physiques par Code QR.
- **Ergonomie :** Interface intuitive respectant la charte graphique de l’Euromed Studiod, garantissant une navigation fluide en moins de 3 clics pour soumettre un projet ou une réservation.
