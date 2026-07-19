# AzerothCore Playerbots — Docker et Podman

Environnement Compose validé avec Docker et Podman pour compiler et exécuter
AzerothCore WoW 3.3.5a, la branche Playerbot, 29 modules additionnels et trois
scripts Lua personnalisés.

## Prérequis

- Docker Engine avec Docker Compose v2 (`docker compose`), **ou**
- Podman avec un fournisseur Compose (`podman compose`, testé avec
  `podman-compose` 1.6)
- GNU Make pour les raccourcis `make` (optionnel)

## Installation

```bash
./scripts/init-env.sh
```

Cette commande crée un `.env` en mode `0600` avec trois secrets aléatoires.
Vérifiez ensuite au minimum :

```env
BIND_ADDRESS=127.0.0.1
REALMLIST_IP=127.0.0.1
BUILD_JOBS=4
```

Puis construisez et démarrez la plateforme avec Docker :

```bash
make up
```

Avec Podman :

```bash
podman compose up -d --build
```

Les scripts et le `Makefile` emploient la commande `docker compose`. Sous
Podman, ils fonctionnent directement si le paquet de compatibilité
`podman-docker` est installé. Sans ce paquet, utilisez les commandes
`podman compose` indiquées dans ce document.

Le premier lancement est long : Docker clone 29 modules, compile le core,
importe les bases et télécharge les données client.

```bash
make status
make logs
```

Avec Podman :

```bash
podman compose ps
podman compose logs -f authserver worldserver
```

Les services one-shot affichés comme `Exited (0)` ont terminé normalement. Les
services permanents `database`, `authserver` et `worldserver` doivent être
`healthy` après l'initialisation. La première création des Playerbots peut
prendre plusieurs minutes.

Validez ensuite l'installation complète :

```bash
make health
make diagnose
```

`make health` doit se terminer par `Healthcheck: OK`. Sous Podman, ces scripts
fonctionnent avec le paquet de compatibilité `podman-docker`.

## Architecture

| Service | Rôle | Persistance |
|---|---|---|
| `database` | MySQL 8.4 | volume `database` |
| `database-init` | création des quatre bases et de l'utilisateur applicatif | one-shot |
| `database-preflight` | détection des collisions SQL de Portals/Rare Drops | one-shot |
| `client-data` | téléchargement des DBC/maps/vmaps/mmaps | volume `client-data` |
| `db-import` | migrations du core et des modules | one-shot |
| `database-post-import` | synchronisation idempotente des schémas et données des modules | one-shot |
| `realm-init` | configuration de `realmlist` | one-shot |
| `authserver` | authentification WoW | conteneur permanent |
| `worldserver` | serveur de jeu, Playerbots et modules | conteneur permanent |
| `operations` | comptes, GM, AHBot, santé, métriques et diagnostic | profil outils |

Les bases, données client, configurations et logs sont placés dans des volumes
Compose. Recréer une image ou un conteneur ne supprime donc pas les données.

## Variables principales

`./scripts/init-env.sh` génère les secrets et reprend les valeurs documentées
dans `.env.example`. Les variables les plus importantes sont :

| Variable | Rôle | Valeur conseillée |
|---|---|---|
| `BIND_ADDRESS` | interface exposant les ports jeu | `127.0.0.1` en local, `0.0.0.0` sur le LAN |
| `REALMLIST_IP` | adresse communiquée au client WoW | IP réellement joignable par le client |
| `BUILD_JOBS` | compilations C++ parallèles | `4`, à réduire si la RAM est limitée |
| `DB_BACKUP_RETENTION` | nombre de sauvegardes conservées | `7`, ou `0` pour tout conserver |
| `ALE_LUA_VERSION` | moteur Lua compilé pour ALE | `lua52` |
| `ACORE_REPO` / `ACORE_BRANCH` | source du core Playerbots | valeurs de `.env.example` |

## Modules inclus

Les 29 modules suivants sont clonés et compilés statiquement dans
`worldserver` :

| # | Module | Fonction | Dépôt |
|---:|---|---|---|
| 1 | `mod-playerbots` | Ajoute les joueurs contrôlés par IA et leur base dédiée. | [mod-playerbots/mod-playerbots](https://github.com/mod-playerbots/mod-playerbots) |
| 2 | `mod-ah-bot-plus` | Vend et achète aux hôtels des ventes avec prix, stocks, catégories et plusieurs personnages vendeurs configurables. | [NathanHandley/mod-ah-bot-plus](https://github.com/NathanHandley/mod-ah-bot-plus) |
| 3 | `mod-autobalance` | Adapte les donjons et raids aux groupes réduits ou au jeu solo. | [azerothcore/mod-autobalance](https://github.com/azerothcore/mod-autobalance) |
| 4 | `mod-aoe-loot` | Permet de ramasser en une fois le butin des créatures proches. | [azerothcore/mod-aoe-loot](https://github.com/azerothcore/mod-aoe-loot) |
| 5 | `mod-learn-spells` | Apprend automatiquement les sorts de classe pendant la progression. | [azerothcore/mod-learn-spells](https://github.com/azerothcore/mod-learn-spells) |
| 6 | `mod-solo-lfg` | Rend la recherche de groupe exploitable seul ou sur un petit serveur. | [azerothcore/mod-solo-lfg](https://github.com/azerothcore/mod-solo-lfg) |
| 7 | `mod-challenge-modes` | Propose par personnage des défis de progression : Hardcore, Semi-Hardcore, Self Crafted, qualité limitée, XP réduite/quête uniquement et Iron Man, avec récompenses de paliers. | [ZhengPeiRu21/mod-challenge-modes](https://github.com/ZhengPeiRu21/mod-challenge-modes) |
| 8 | `mod-player-bot-level-brackets` | Contrôle la distribution des niveaux des Playerbots par tranches. | [DustinHendrickson/mod-player-bot-level-brackets](https://github.com/DustinHendrickson/mod-player-bot-level-brackets) |
| 9 | `mod-junk-to-gold` | Vend automatiquement les objets gris au moment où le joueur les ramasse. | [kadeshar/mod-junk-to-gold](https://github.com/kadeshar/mod-junk-to-gold) |
| 10 | `mod-rare-drops` | Ajoute par SQL du butin vert ou bleu thématique aux 450 créatures rares classiques de Kalimdor et des Royaumes de l'Est. | [StraysFromPath/mod-rare-drops](https://github.com/StraysFromPath/mod-rare-drops) |
| 11 | `mod-transmog` | Ajoute la transmogrification et ses PNJ/outils associés. | [azerothcore/mod-transmog](https://github.com/azerothcore/mod-transmog) |
| 12 | `mod-reagent-bank-account` | Ajoute un PNJ de banque de composants par personnage, sans limite, avec dépôt global et classement par catégories. | [Brian-Aldridge/mod-reagent-bank-account](https://github.com/Brian-Aldridge/mod-reagent-bank-account) |
| 13 | `mod-daily-reset` | Ajoute directement la commande `.daily reset`, sans option de configuration, pour réinitialiser les quêtes journalières et instances du joueur. | [binboupan/mod-daily-reset](https://github.com/binboupan/mod-daily-reset) |
| 14 | `mod-mount-scaling` | Fait évoluer progressivement la vitesse des montures avec le niveau. | [claudevandort/mod-mount-scaling](https://github.com/claudevandort/mod-mount-scaling) |
| 15 | `mod-ale` | Fournit le moteur Lua AzerothCore utilisé par les scripts serveur. | [azerothcore/mod-ale](https://github.com/azerothcore/mod-ale) |
| 16 | `mod-quest-loot-party` | Partage les objets de quête admissibles entre membres du groupe. | [pangolp/mod-quest-loot-party](https://github.com/pangolp/mod-quest-loot-party) |
| 17 | `mod-TimeIsTime` | Permet de régler la vitesse du cycle jour/nuit. | [dunjeon/mod-TimeIsTime](https://github.com/dunjeon/mod-TimeIsTime) |
| 18 | `mod-boss-announcer` | Annonce les victoires sur les boss ; les annonces de wipe sont désactivées dans le profil fourni. | [azerothcore/mod-boss-announcer](https://github.com/azerothcore/mod-boss-announcer) |
| 19 | `mod-auto-revive` | Ressuscite automatiquement les comptes GM avant la mort, partout ou uniquement dans une zone configurée. | [azerothcore/mod-auto-revive](https://github.com/azerothcore/mod-auto-revive) |
| 20 | `mod-duel-reset` | Réinitialise vie, ressources et cooldowns admissibles autour des duels. | [azerothcore/mod-duel-reset](https://github.com/azerothcore/mod-duel-reset) |
| 21 | `NoProfessionLimit` | Autorise jusqu'aux 11 professions principales de WotLK ; la limite native du core est également fixée à 11. | [AlsoNotMehh/NoProfessionLimit](https://github.com/AlsoNotMehh/NoProfessionLimit) |
| 22 | `mod-no-hearthstone-cooldown` | Supprime immédiatement le cooldown de la pierre de foyer. | [BytesGalore/mod-no-hearthstone-cooldown](https://github.com/BytesGalore/mod-no-hearthstone-cooldown) |
| 23 | `mod-autofish` | Automatise la capture, le butin et la relance de la pêche. | [Flerp/mod-autofish](https://github.com/Flerp/mod-autofish) |
| 24 | `lua-battlepass` | Ajoute un battle pass Lua, ses quêtes, récompenses et commandes. | [Shonik/lua-battlepass](https://github.com/Shonik/lua-battlepass) |
| 25 | `mod-skip-dk-starting-area` | Permet, selon sa configuration, de passer automatiquement ou facultativement la zone de départ des chevaliers de la mort. | [d23monkey/mod-skip-dk-starting-area](https://github.com/d23monkey/mod-skip-dk-starting-area) |
| 26 | `mod-gunship-skip` | Ajoute sur Muradin/Saurfang une option solo qui termine la Canonnière ICC, distribue son butin par courrier et téléporte après le combat. | [BlaMacfly/mod-gunship-skip](https://github.com/BlaMacfly/mod-gunship-skip) |
| 27 | `portals-in-all-capitals` | Ajoute automatiquement par SQL 24 portails près du maître de vol des capitales. | [azerothcore/portals-in-all-capitals](https://github.com/azerothcore/portals-in-all-capitals) |
| 28 | `mod-gain-honor-guard` | Accorde de l'honneur pour les gardes et/ou élites non gris, hors arène et joueur vivant, avec taux, annonces et partage de groupe configurables. | [azerothcore/mod-gain-honor-guard](https://github.com/azerothcore/mod-gain-honor-guard) |
| 29 | `mod-dungeon-master` | Ajoute des donjons procéduraux jouables seul ou en groupe, avec difficulté, thèmes, mise à l'échelle, récompenses et mode roguelike à affixes. | [InstanceForge/mod-dungeon-master](https://github.com/InstanceForge/mod-dungeon-master) |

Certains dépôts utilisent encore des API AzerothCore anciennes. Les adaptations
de compatibilité nécessaires sont appliquées automatiquement et de façon
reproductible par `docker/build-source.sh` et le `Dockerfile`.

## Scripts Lua inclus

| Script | Activation | Fonction |
|---|---|---|
| [`starter_boost.lua`](https://github.com/Kyroth88/ale-scripts/blob/main/starter_boost.lua) | `.starterboost` | Offre aux personnages de niveau 10 maximum un équipement de départ, quatre sacs et 250 pièces d'or. |
| [`SitMeansRest.lua`](https://github.com/Brytenwally/SitMeansRest) | `/sit` hors combat | Applique une régénération de 20 secondes, annulée dès que le personnage se déplace. |
| [`LootArbiter.lua`](https://github.com/Brytenwally/Loot-Arbiter) | Automatique après un jet de groupe ; diagnostic avec `.lootspec` | Attribue le butin au membre pour lequel il représente la meilleure amélioration. Le hook général d'obtention d'objet est désactivé afin de ne pas redistribuer les achats, courriers et récompenses hors jet de groupe. |

Les trois scripts sont intégrés à l'image `worldserver`. Leur chargement peut
être contrôlé dans les journaux avec :

```bash
docker compose logs worldserver | grep '\[ALE\]'
```

Sous Podman, remplacez `docker compose` par `podman compose`.

### Gain Honor Guard

`mod-gain-honor-guard` est activé pour le jeu solo/privé. Les gardes et les
créatures élites de niveau approprié donnent de l'honneur, partagé entre les
membres connectés du groupe. Les annonces à chaque victime sont désactivées et
le multiplicateur d'honneur reste celui du core (`1.0`). Les valeurs sont dans
`docker/acore.env` sous le préfixe `AC_GAIN_HONOR_GUARD_`.

Un garde doit avoir le drapeau `CREATURE_FLAG_EXTRA_GUARD` (`32768`) dans
`creature_template.flags_extra` pour être reconnu par le module.

## Better Professions — densité des ressources

Le projet porte uniquement la partie minerais/plantes du pack MIT
[Better Professions](https://github.com/Upload-Academy/azerothcore-daisy/tree/master/packs/mcrilly/better-professions).
Les quêtes et le script Lua du pack original ne sont pas installés.

Au premier passage post-import, les valeurs AzerothCore d'origine des pools
concernés sont sauvegardées dans
`custom_better_professions_pool_baseline`. La densité est ensuite toujours
recalculée depuis cette référence : les redémarrages ne cumulent donc jamais le
multiplicateur. Les réglages se trouvent dans `.env` :

```env
BETTER_PROFESSIONS_HERBALISM_MULTIPLIER=6
BETTER_PROFESSIONS_MINING_MULTIPLIER=6
```

Le profil couvre les plantes et minerais de Classic, Outreterre et Norfendre.
La plage acceptée est `1–10`. La valeur `1` restaure la densité importée du
core. La modification s'applique au prochain `podman compose up -d` ou en
recréant explicitement `database-post-import`.

## Ports

| Port | Service | Exposition par défaut |
|---|---|---|
| `3724` | authserver | `127.0.0.1` |
| `8085` | worldserver | `127.0.0.1` |
| `7878` | SOAP | toujours `127.0.0.1` |
| `3306` | MySQL | non exposé |

Pour permettre un accès depuis le réseau local, définissez par exemple :

```env
BIND_ADDRESS=0.0.0.0
REALMLIST_IP=192.168.1.50
```

Assurez-vous alors que le pare-feu n'autorise que les sources nécessaires.

## Connexion du client WoW 3.3.5a

Le client doit être une version **3.3.5a (build 12340)**. Dans son fichier
`Data/<locale>/realmlist.wtf`, utilisez la même adresse que `REALMLIST_IP` :

```text
set realmlist 127.0.0.1
```

Pour un client situé sur une autre machine, remplacez `127.0.0.1` par l'adresse
LAN du serveur. Vérifiez que les ports TCP `3724` et `8085` sont accessibles et
que `BIND_ADDRESS=0.0.0.0`. Il n'est pas nécessaire d'exposer MySQL ni SOAP.

## Créer le compte administrateur

Le projet ne crée volontairement plus de compte `admin/admin`. La méthode
recommandée, compatible avec les schémas SHA1 et SRP6, est :

```bash
./scripts/create-account.sh admin 'MOT_DE_PASSE'
./scripts/set-gm.sh admin 3 -1
```

Sans la compatibilité `podman-docker`, utilisez directement :

```bash
podman compose --profile tools run --rm operations \
  python3 /azerothcore/tools/admin.py create-account admin 'MOT_DE_PASSE'
podman compose --profile tools run --rm operations \
  python3 /azerothcore/tools/admin.py set-gm admin 3 -1
```

Équivalent avec Make :

```bash
make account ACCOUNT=admin PASS='MOT_DE_PASSE'
make gm ACCOUNT=admin LEVEL=3 REALM=-1
```

La console interactive reste disponible :

```bash
make console
```

Dans la console worldserver :

```text
account create admin MOT_DE_PASSE MOT_DE_PASSE
account set gmlevel admin 3 -1
```

Pour détacher la console sans arrêter le serveur, utilisez `Ctrl-p`, puis
`Ctrl-q`. N'utilisez pas `Ctrl-c`.

## Commandes courantes

```bash
make up          # construire et démarrer
make down        # arrêter les conteneurs
make restart     # redémarrer authserver/worldserver
make status      # état des services
make logs        # journaux applicatifs
make console     # console worldserver interactive
make backup      # sauvegarde SQL compressée dans backups/
make health      # santé MySQL/auth/world/SOAP
make metrics     # snapshot JSON strict
make diagnose    # services, ressources, DB, modules et logs
make watch       # healthcheck périodique, INTERVAL=30 par défaut
make bots-help   # aide des commandes Playerbots
make clean-logs  # supprimer les fichiers de logs applicatifs
make update      # reconstruction complète depuis les sources distantes
```

Compose laisse jusqu'à deux minutes à `worldserver` pour sauvegarder son état et
fermer proprement ses connexions avant de forcer son arrêt.

Commandes Docker Compose directes :

```bash
docker compose logs -f worldserver
docker compose restart worldserver
docker compose exec database mysql -uroot -p
```

Sous Podman, remplacez simplement `docker compose` par `podman compose` :

```bash
podman compose logs -f worldserver
podman compose restart worldserver
podman compose exec database mysql -uroot -p
```

## Configuration AzerothCore et modules

Les réglages versionnés se trouvent dans `docker/acore.env`. Ce profil contient
maintenant l'intégralité des réglages statiques de l'ancienne installation
Vagrant (249 variables Compose, plus les secrets injectés par Compose). Le point devient
un underscore, les transitions minuscule/majuscule reçoivent un underscore et
la clé est préfixée par `AC_` :

```text
Rate.XP.Kill                  -> AC_RATE_XP_KILL
AiPlayerbot.MinRandomBots     -> AC_AI_PLAYERBOT_MIN_RANDOM_BOTS
AutoBalance.MinPlayers        -> AC_AUTO_BALANCE_MIN_PLAYERS
```

Après une modification :

```bash
docker compose up -d --force-recreate authserver worldserver
```

Les configurations générées sont conservées dans le volume `config`.

## AHBot

AHBot n'utilise plus automatiquement un personnage joueur comme solution de
secours. Créez d'abord le compte dédié :

```bash
./scripts/bootstrap-ahbot.sh ahbot 'MOT_DE_PASSE'
```

Créez son personnage avec le client WoW, récupérez son GUID, puis :

```bash
./scripts/setup-ahbot.sh 123
# Plusieurs personnages : ./scripts/setup-ahbot.sh 123,456
```

Le script vérifie les GUID, active le vendeur dans la configuration persistante,
puis exécute `.ahbot reload` et trois mises à jour via SOAP. Le compte technique
SOAP défini dans `.env` est créé automatiquement avec les droits requis pendant
l'initialisation des bases.

## Sauvegarde et restauration

```bash
make backup
```

`DB_BACKUP_RETENTION` dans `.env` conserve les N derniers snapshots. Chaque
sauvegarde est écrite dans un répertoire temporaire, vérifiée avec `gzip -t`,
puis publiée atomiquement. `0` conserve tous les snapshots.

Restauration d'une base :

```bash
gunzip -c backups/DATE/acore_characters.sql.gz | \
  docker compose exec -T database \
  sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_characters'
```

Arrêtez `worldserver` avant de restaurer `acore_characters`.

## Mise à jour

`make update` reconstruit intégralement les images. Effectuez toujours une
sauvegarde avant :

```bash
make backup
make update
```

Avec Podman :

```bash
./scripts/backup-db.sh
podman compose build --pull --no-cache
podman compose down
podman compose up -d
```

La recréation des conteneurs après la reconstruction garantit l'utilisation
des nouvelles images. Les volumes de base de données et de données client sont
conservés par `podman compose down`.

Les dépendances externes sont encore suivies par branches. Pour une plateforme
de production, épinglez le core et chaque module sur un commit vérifié.

## Dépannage

Commencez par le diagnostic intégré :

```bash
make status
make health
make diagnose
```

Sous Podman sans `podman-docker` :

```bash
podman compose ps
podman compose logs --tail=200 authserver worldserver
podman compose --profile tools run --rm operations python3 /azerothcore/tools/diagnose.py
```

### Échec de compilation

Conservez toute la sortie avant de rechercher la première erreur réelle :

```bash
podman compose build worldserver 2>&1 | tee build.log
grep -n -m1 -B20 -A30 -E 'error:|fatal error:|Killed|undefined reference' build.log
```

Une ligne finale `gmake: Error 2` n'est généralement qu'une conséquence. En cas
de processus `Killed`, réduisez `BUILD_JOBS` dans `.env`, puis reconstruisez.

### Sélection interactive de l'image MySQL avec Podman

Si Podman demande quel registre utiliser pour `mysql:8.4`, choisissez
`docker.io/library/mysql:8.4`. Le fichier Compose utilise volontairement cette
référence pleinement qualifiée afin d'éviter la question lors des prochains
lancements.

### Services one-shot

`database-init`, `database-preflight`, `db-import`, `database-post-import`,
`realm-init` et `client-data` doivent terminer en `Exited (0)`. Tout autre code
signale un échec ; consultez par exemple :

```bash
podman compose logs database-preflight database-post-import db-import
```

## Suppression complète

La commande suivante détruit également toutes les bases et données client :

```bash
docker compose down --volumes
```

Équivalent Podman :

```bash
podman compose down --volumes
```

Elle est irréversible sans sauvegarde.

## Références

- [Documentation Docker officielle AzerothCore](https://www.azerothcore.org/wiki/install-with-docker)
- [Installation Docker de mod-playerbots](https://github.com/mod-playerbots/mod-playerbots)
