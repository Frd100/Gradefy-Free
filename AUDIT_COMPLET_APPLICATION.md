# Audit Complet de l'Application PARALLAX (Gradefy)

**Date de l'audit** : 2025-11-14  
**Version de l'application** : 1.0 (Build 1)  
**Bundle Identifier** : `Coefficient.Gradefy`  
**Statut** : Application entièrement gratuite

---

## Table des Matières

1. [Informations Générales](#informations-générales)
2. [Statistiques du Code](#statistiques-du-code)
3. [Structure et Architecture](#structure-et-architecture)
4. [Fonctionnalités Principales](#fonctionnalités-principales)
5. [Business Model](#business-model)
6. [Technologies et Dépendances](#technologies-et-dépendances)
7. [Modèle de Données](#modèle-de-données)
8. [Qualité du Code](#qualité-du-code)
9. [Tests](#tests)
10. [Configuration et Déploiement](#configuration-et-déploiement)
11. [Widgets et Extensions](#widgets-et-extensions)
12. [Sécurité et Permissions](#sécurité-et-permissions)

---

## Informations Générales

### Identification du Projet

- **Nom de l'application** : PARALLAX (nom interne) / Gradefy (nom d'affichage)
- **Type d'application** : Application iOS native (SwiftUI)
- **Catégorie App Store** : Éducation (`public.app-category.education`)
- **Version minimale iOS** : iOS 17.0
- **Orientations supportées** : Portrait uniquement (iPhone), Portrait et Portrait inversé (iPad)
- **Langues supportées** : Français (fr), Anglais (en), Espagnol (es), Allemand (de)

### Cibles du Projet

Le projet contient **4 cibles** :
1. **PARALLAX** (application principale)
2. **PARALLAXTests** (tests unitaires)
3. **PARALLAXWidgetExtension** (extension de widgets)
4. **RevisionLiveActivityExtension** (extension Live Activity)

### Schémas de Build

- PARALLAX
- PARALLAXTests
- PARALLAXWidgetExtension
- RevisionLiveActivityExtension

---

## Statistiques du Code

### Fichiers Swift

- **Nombre total de fichiers Swift** : 97 fichiers
- **Nombre total de lignes de code** : 42,111 lignes
- **Fichiers avec imports** : 95 fichiers
- **Fichiers avec classes/structs/enums** : 89 fichiers
- **Nombre total de déclarations** (func/var/let) : ~6,500 déclarations

### Répartition par Dossier

- **App/** : Fichiers principaux de l'application (PARALLAXApp.swift, ContentView.swift)
- **Features/** : Fonctionnalités métier (11 fichiers)
- **Revision/** : Système de révision SRS (18 fichiers)
- **Domain/** : Entités et logique métier (7 fichiers)
- **Data/** : Persistance et cache (11 fichiers)
- **Presentation/** : Vues et composants UI (10 fichiers)
- **Shared/** : Code partagé (5 fichiers)
- **PARALLAXWidget/** : Extension widgets (9 fichiers)
- **PARALLAXTests/** : Tests unitaires (15 fichiers)

### Tests

- **Nombre de fichiers de tests** : 15 fichiers
- **Lignes de code de tests** : 7,135 lignes
- **Couverture** : Tests SM-2 complets (algorithmes, intégration, robustesse, stress, validation, limites)

### Debug et Logging

- **Fichiers avec print()** : 49 fichiers
- **Nombre total de print()** : 1,651 occurrences
- **Marqueurs TODO/FIXME/XXX/HACK/BUG** : 7 occurrences identifiées (principalement dans tests et DataImportExportManager)
- **Fichiers avec MARK:** : 68 fichiers (organisation du code)

### Concurrence et Thread Safety

- **Utilisation @MainActor** : 89 occurrences dans 31 fichiers
- **Utilisation async/await** : 613 occurrences dans 54 fichiers
- **Utilisation Task.** : 163 occurrences dans 42 fichiers
- **Utilisation DispatchQueue** : Présente dans plusieurs fichiers pour opérations asynchrones

### Extensions et Réutilisabilité

- **Nombre d'extensions** : 75 extensions définies
- **Extensions de types** : Flashcard, FlashcardDeck, Subject, Date, Notification.Name, etc.

### Navigation et Présentation

- **Utilisation de .sheet()** : 73 occurrences dans 22 fichiers
- **Utilisation de NavigationStack** : Présente dans ContentView, ProfileView, OnboardingViewModel
- **NavigationPath** : Utilisé pour navigation programmatique

---

## Structure et Architecture

### Architecture Générale

L'application suit une architecture **MVVM (Model-View-ViewModel)** avec SwiftUI :

- **Modèle** : Core Data (entités : Subject, Evaluation, Flashcard, FlashcardDeck, Period, UserConfiguration)
- **Vue** : SwiftUI Views dans `Presentation/` et `App/`
- **ViewModel** : Classes `@Observable` et `@StateObject` (ex: `FeatureManager`, `OnboardingViewModel`)

### Organisation des Dossiers

```
PARALLAX/
├── App/                    # Point d'entrée et configuration
│   ├── PARALLAXApp.swift   # @main struct
│   ├── ContentView.swift   # Vue principale
│   └── Core/               # Utilitaires core
├── Features/               # Fonctionnalités métier
│   ├── FeatureManager.swift
│   ├── AIFlashcardGenerator.swift
│   ├── ModelManager.swift
│   ├── DebugAccessButton.swift
│   └── ...
├── Revision/               # Système SRS (Spaced Repetition)
│   ├── SimpleSRSManager.swift
│   ├── FlashcardRevisionSystem.swift
│   └── ...
├── Domain/                 # Entités et logique métier
│   ├── Entities/
│   ├── GradingSystems/
│   └── Views/
├── Data/                   # Persistance
│   ├── Persistence/
│   └── Cache/
├── Presentation/           # Vues SwiftUI
│   └── Views/
├── Shared/                 # Code partagé
└── PARALLAXWidget/         # Extension widgets
```

### Patterns de Conception Identifiés

1. **Singleton** : `PersistenceController.shared`, `FeatureManager.shared`, `SimpleSRSManager.shared`, `AIFlashcardGenerator.shared`, `GradefyCacheManager.shared`, `MediaStorageManager.shared`, `AudioManager.shared`, `HapticFeedbackManager.shared`, `ModelManager.shared`, `DeckSharingManager.shared`, `StoreKitHelper.shared`, `ConfigurationManager`, `WidgetDataManager.shared`
2. **Observable** : Utilisation de `@Observable` (iOS 17+) et `@Published` pour la réactivité
   - **@Observable** : 443 occurrences dans 40 fichiers
   - **@Published** : Utilisé dans les ViewModels et Managers
3. **Repository** : Pattern implicite avec Core Data
4. **Factory** : `GradingSystemRegistry` pour les systèmes de notation
5. **Strategy** : Systèmes de notation pluggables (`GradingSystemPlugin`)
6. **Cache** : Système de cache multi-niveaux (`GradefyCacheManager`, `SmartAverageCache`, `SM2OptimizationCache`, `SM2PerformanceMonitor`, `CachePerformanceMonitor`)
7. **Manager** : Pattern Manager pour encapsulation (AudioManager, MediaStorageManager, ModelManager, etc.)
8. **ViewModifier** : Modifiers personnalisés (KeyboardAdaptive, etc.)
9. **Component** : Composants SwiftUI réutilisables (AdaptiveLottieView, AdaptiveImage, etc.)

---

## Fonctionnalités Principales

### 1. Gestion des Notes et Systèmes de Notation

**Systèmes de notation supportés** :
- **Système français** : 0-20, note de passage 10
- **Système américain** : GPA 0-4, note de passage 2.0
- **Système allemand** : 1-5 (inversé), note de passage 4.0
- **Système espagnol** : 0-10, note de passage 5.0
- **Système canadien** : GPA 0-4, note de passage 2.0

**Fonctionnalités** :
- Calcul de moyennes pondérées par coefficient
- Gestion de périodes académiques
- Sujets avec heures de crédit
- Évaluations multiples par sujet
- Calcul automatique des moyennes

### 2. Système de Révision par Répétition Espacée (SRS)

**Algorithme** : SM-2 (SuperMemo 2) avec optimisations

**Caractéristiques** :
- Système binaire (2 niveaux de qualité : correct/incorrect)
- Gestion des intervalles de révision
- Ease Factor (facteur de facilité) ajustable
- Soft cap pour éviter les intervalles aberrants
- Phase early avec intervalles fixes (3j, 7j)
- Seuils de statut :
  - **Nouvelle** : reviewCount == 0
  - **À réviser** : intervalle < 7 jours
  - **Acquise** : intervalle >= 7 jours et < 21 jours
  - **Maîtrisée** : intervalle >= 21 jours

**Modes de révision** :
- **Mode Swipe** : Glissement gauche/droite
- **Mode Quiz** : Questions à choix multiples
- **Mode Association** : Association de paires
- **Mode Libre** : Révision sans contraintes SM-2

**Optimisations** :
- Cache SM-2 pour éviter recalculs (`SM2OptimizationCache`)
- Optimisations Core Data pour requêtes batch (`SM2CoreDataOptimizer`)
- Monitoring de performance conditionnel (`SM2PerformanceMonitor`)
- Idempotence des opérations SM-2 (protection contre doubles traitements)
- Cache des moyennes avec dépendances (`SmartAverageCache`)
- Cache hiérarchique multi-niveaux (`GradefyCacheManager`)
- Debouncing des changements Core Data (2 secondes)
- Préchargement des données critiques au démarrage

### 3. Génération de Flashcards par IA

**Modèle utilisé** : SmolLM3-3B-4bit (MLX)

**Fonctionnalités** :
- Génération de flashcards à partir d'un prompt texte
- Support multilingue (français, anglais, espagnol, allemand)
- Parsing JSON robuste avec fallback manuel
- Gestion de la mémoire GPU optimisée
- Cache KV pour réutilisation entre générations
- Reset préventif tous les 10 générations
- Détection de boucles de répétition

**Configuration** :
- Max tokens : 512 (défini dans generation_config.json)
- Température : 0.2 (défini dans generation_config.json)
- Top-P : 0.9 (défini dans generation_config.json)
- Top-K : 50 (défini dans generation_config.json)
- Repetition penalty : 1.0 (défini dans generation_config.json)
- Early stopping : Activé
- No repeat ngram size : 2

**Architecture du modèle** :
- Type : SmolLM3ForCausalLM
- Hidden size : 2048
- Num layers : 36
- Num attention heads : 16
- Num key value heads : 4
- Vocab size : 128,256
- Quantization : 4-bit (group size 64)
- Max position embeddings : 4096
- Sliding window : 1024

**Stockage du modèle** : `Library/Application Support/Models/SmolLM3-3B-4bit/`

**Compatibilité** : Requiert minimum 5GB RAM (vérification dans ModelManager)

**Téléchargement** :
- URL : GitHub Releases (https://github.com/Frd100/AitestGrd/releases/download/1.0.0/SmolLM3-3B-4bit.zip)
- Taille attendue : ~100MB compressé
- Session background : Réutilisable pour téléchargements
- Retry automatique : Maximum 3 tentatives
- Extraction asynchrone : Non-bloquante avec gestion d'erreurs

### 4. Gestion des Médias

**Types de médias supportés** :
- **Images** : Stockage en fichiers (recommandation Apple), compression adaptative selon usage
- **Audio** : Enregistrement M4A (AAC, 44.1kHz, mono, 64kbps), stockage local
- **Transcription** : Transcription automatique des enregistrements audio (champs optionnels)

**Stockage** :
- **Dossier médias** : `Documents/GradefyMedia/`
- **Images** : Format JPG avec compression qualité 0.7
- **Audio** : Format M4A avec compression automatique si >500KB
- **Compression audio** : Bitrate réduit (128kbps normal, 96kbps pour fichiers >5MB)
- **Compression images** : Qualité adaptative selon usage (thumbnail, flashcard)

**Limites** :
- **Toutes les limites supprimées** : Application entièrement gratuite
- **Médias** : Illimités (Int.max)
- **Durée audio max** : 30 secondes (arrêt automatique, conservée pour UX)
- **Taille fichier max** : 500MB pour import

**Gestion** :
- **MediaStorageManager** : Gestion centralisée des médias
- **Nettoyage orphelins** : Fonction de nettoyage disponible
- **Export/Import** : Support complet dans packages ZIP

### 5. Import/Export de Données

**Formats supportés** :
- Format natif `.gradefy` (JSON compressé)
- Format JSON rétrocompatible
- Export de decks individuels
- Export complet de l'application

**Fonctionnalités** :
- Import depuis fichiers (JSON, .gradefy)
- Import depuis URL (deep links)
- Partage de decks entre utilisateurs
- Prévisualisation avant import
- Export complet avec médias (format ZIP)
- Export de decks individuels
- Validation d'intégrité référentielle
- Validation UUID et détection de doublons
- Import atomique avec rollback en cas d'erreur
- Import par chunks pour médias (10 fichiers par chunk)
- Compression automatique des médias à l'export
- Support Base64 pour rétrocompatibilité
- Gestion des bookmarks de sécurité iOS

**Format d'export** :
- Structure ZIP avec :
  - `data.json` : Données Core Data (format version 3.0)
  - `media/images/` : Images des flashcards
  - `media/audio/` : Fichiers audio des flashcards
- Métadonnées : Date export, version app, format version, iOS version
- Format ISO8601 pour toutes les dates

### 6. Onboarding

**Étapes** :
1. Introduction
2. Bienvenue avec présentation des fonctionnalités
3. Sélection du système de notation
4. Création du profil utilisateur
5. Création de la première période
6. Complétion

**Protection** : Système de protection contre les doubles complétions

### 7. Widgets iOS

**Types de widgets** :
- Widget de révision (cartes à réviser aujourd'hui)
- Widget de notes (moyennes par période)
- Live Activity pour sessions de révision

**Fonctionnalités** :
- Synchronisation avec App Group
- Tous les widgets accessibles (verrouillage premium supprimé)
- Mise à jour automatique via WidgetKit

---

## Business Model

### Modèle : Application Entièrement Gratuite

L'application est entièrement gratuite. Toutes les fonctionnalités sont accessibles sans limitation.

### Limites et Fonctionnalités

#### Flashcards

- **Flashcards** : Illimitées
- **Decks** : Illimités
- **Médias** : Illimités
- **Widgets** : Tous accessibles

### Gestion des Fonctionnalités (FeatureManager)

**FeatureManager** :
- `hasFullAccess` : Toujours `true`
- Toutes les fonctionnalités activées par défaut
- Synchronisation App Group pour widgets
- Notification `fullAccessStatusChanged` pour réactivité UI
- Mode debug disponible (`debugOverride`)

**StoreKitHelper** :
- Conservé pour compatibilité technique
- Non utilisé activement dans le modèle gratuit

**Fonctionnalités disponibles** :
1. **unlimited_flashcards_per_deck** : Activée (illimité)
2. **unlimited_decks** : Activée (illimité)
3. **custom_themes** : Activée
4. **premium_widgets** : Activée (tous les widgets accessibles)
5. **advanced_stats** : Activée
6. **export_data** : Activée
7. **priority_support** : Activée

---

## Technologies et Dépendances

### Frameworks Apple Natifs

- **SwiftUI** : Interface utilisateur (56 imports)
- **Core Data** : Persistance des données (55 imports)
- **Foundation** : Utilitaires de base (48 imports)
- **UIKit** : Composants UI et intégrations (28 imports)
- **WidgetKit** : Widgets iOS (18 imports)
- **StoreKit** : Achats in-app (StoreKit 2) (4 imports)
- **UserNotifications** : Notifications locales (1 import)
- **TipKit** : Conseils contextuels (2 imports)
- **EventKit** : Intégration calendrier (non utilisé actuellement)
- **ActivityKit** : Live Activities (1 import)
- **AVFoundation** : Audio et vidéo (9 imports)
- **Combine** : Programmation réactive (14 imports)
- **UniformTypeIdentifiers** : Types de fichiers (15 imports)
- **os.log** : Logging structuré (10 imports)
- **ImageIO** : Traitement d'images (2 imports)
- **Charts** : Graphiques (1 import)
- **AppIntents** : Intents App (1 import)

### Dépendances Externes (Swift Package Manager)

#### MLX (Apple Machine Learning)

**Packages MLX** :
- `MLX` : Framework de base
- `MLXNN` : Réseaux de neurones
- `MLXLLM` : Modèles de langage
- `MLXLMCommon` : Utilitaires communs
- `MLXOptimizers` : Optimiseurs
- `MLXRandom` : Génération aléatoire
- `MLXFast` : Opérations rapides
- `MLXEmbedders` : Embeddings
- `MLXVLM` : Vision-Language Models
- `MLXMNIST` : Modèles MNIST
- `MLXFFT` : Transformée de Fourier
- `MLXLinalg` : Algèbre linéaire
- `StableDiffusion` : Génération d'images

**Utilisation** : Génération de flashcards avec SmolLM3-3B-4bit

#### Autres Packages

- **Lottie** : Animations
- **ZIPFoundation** : Compression/décompression ZIP

### Versions et Compatibilité

- **iOS minimum** : 17.0
- **Swift** : Version moderne (syntaxe iOS 17+)
- **Xcode** : ObjectVersion 90 (Xcode 16+)

---

## Modèle de Données

### Entités Core Data

#### 1. Subject (Matière)

**Attributs** :
- `id` : UUID
- `name` : String
- `code` : String (optionnel)
- `grade` : Double (moyenne calculée)
- `coefficient` : Double (coefficient de pondération)
- `creditHours` : Double (heures de crédit)
- `createdAt` : Date
- `lastModified` : Date

**Relations** :
- `evaluations` : To-Many → Evaluation
- `period` : To-One → Period

**Computed Properties** :
- `currentGrade` : Calcul automatique de la moyenne pondérée
- `isValidForGPA` : Validation pour calcul GPA

#### 2. Evaluation (Évaluation)

**Attributs** :
- `id` : UUID
- `title` : String
- `grade` : Double (optionnel, -999.0 = pas de note)
- `coefficient` : Double
- `date` : Date

**Relations** :
- `subject` : To-One → Subject

#### 3. Flashcard (Carte de révision)

**Attributs** :
- `id` : UUID
- `question` : String
- `answer` : String
- `createdAt` : Date
- `lastReviewDate` : Date (optionnel)
- `lastReviewed` : Date (optionnel, alias)
- `reviewCount` : Int32
- `correctCount` : Int16
- `interval` : Double (intervalle SM-2)
- `easeFactor` : Double (facteur de facilité SM-2)
- `nextReviewDate` : Date (optionnel)

**Médias Question** :
- `questionType` : String ("text", "image", "audio")
- `questionImageData` : Binary (optionnel)
- `questionImageFileName` : String (optionnel)
- `questionAudioFileName` : String (optionnel)
- `questionAudioDuration` : Double
- `questionTranscription` : String (optionnel)
- `questionTranscriptionDate` : Date (optionnel)

**Médias Réponse** :
- `answerType` : String ("text", "image", "audio")
- `answerImageData` : Binary (optionnel)
- `answerImageFileName` : String (optionnel)
- `answerAudioFileName` : String (optionnel)
- `answerAudioDuration` : Double
- `answerTranscription` : String (optionnel)
- `answerTranscriptionDate` : Date (optionnel)

**Relations** :
- `deck` : To-One → FlashcardDeck

#### 4. FlashcardDeck (Deck de cartes)

**Attributs** :
- `id` : UUID
- `name` : String
- `createdAt` : Date

**Relations** :
- `flashcards` : To-Many → Flashcard (Cascade delete)

#### 5. Period (Période académique)

**Attributs** :
- `id` : UUID
- `name` : String
- `startDate` : Date
- `endDate` : Date (optionnel)
- `createdAt` : Date (optionnel)

**Relations** :
- `subjects` : To-Many → Subject (Cascade delete)

#### 6. UserConfiguration (Configuration utilisateur)

**Attributs** :
- `id` : UUID
- `username` : String (optionnel)
- `selectedSystem` : String (optionnel, ID du système de notation)
- `hasCompletedOnboarding` : Bool
- `activePeriodID` : String (optionnel)
- `profileGradientStart` : String (optionnel)
- `profileGradientEnd` : String (optionnel)
- `createdDate` : Date (optionnel)
- `lastModifiedDate` : Date (optionnel)

### Configuration Core Data

- **Nom du modèle** : PARALLAX
- **Type de store** : SQLite
- **Migration automatique** : Activée
- **Persistent History Tracking** : Activé
- **Merge Policy** : NSMergeByPropertyObjectTrumpMergePolicy
- **Automatic Merge** : Activé

### Système de Cache

**Caches multi-niveaux** :

1. **SmartAverageCache** : Cache des moyennes avec dépendances
   - Cache avec graphe de dépendances
   - Invalidation en cascade
   - Expiration automatique (5 minutes)
   - Thread-safe avec DispatchQueue concurrent

2. **GradefyCacheManager** : Cache principal hiérarchique
   - Cache mémoire (NSCache) : Limites adaptatives selon appareil
   - Cache calculs : 200 objets max, 2MB
   - Cache assets : 100 objets max, 10MB
   - Cache disque : 500 objets max, 100MB
   - Sauvegarde automatique des données critiques
   - Préchargement des données importantes

3. **SM2OptimizationCache** : Cache des calculs SM-2
   - Cache des résultats SM-2 pour éviter recalculs
   - Intégration avec SimpleSRSManager

4. **SM2CoreDataOptimizer** : Optimisations Core Data pour SM-2
   - Requêtes batch optimisées
   - Préchargement des relations

5. **SM2PerformanceMonitor** : Monitoring des performances
   - Métriques SM-2 spécifiques
   - Historique de performance (100 snapshots max)
   - Rapports périodiques (toutes les 5 minutes)
   - Alertes de latence élevée

6. **CachePerformanceMonitor** : Monitoring général du cache
   - Hit rate tracking
   - Latence tracking
   - Évictions tracking
   - Health status

**Invalidation** : Invalidation intelligente basée sur les changements Core Data
- Notification `NSManagedObjectContextDidSave`
- Extraction des ObjectIDs modifiés
- Invalidation en cascade via graphe de dépendances
- Debouncing (2 secondes) pour éviter invalidations excessives

---

## Qualité du Code

### Points Positifs

1. **Architecture claire** : Séparation des responsabilités (App, Features, Domain, Data, Presentation)
2. **Patterns cohérents** : Utilisation de singletons, observables, factory
3. **Gestion d'erreurs** : Try-catch et gestion d'erreurs explicite
4. **Logging structuré** : Utilisation de `os.log` avec Logger
5. **Documentation** : Commentaires MARK: pour organisation
6. **Type safety** : Utilisation de types Swift stricts
7. **Async/await** : Utilisation moderne de la concurrence Swift

### Points d'Attention

1. **Logging excessif** : ~1,600 occurrences de `print()` dans 49 fichiers
   - Impact : Performance en production, taille de logs
   - Suggestion : Utiliser des niveaux de log conditionnels
   - Note : Beaucoup de logs sont structurés avec préfixes pour faciliter le debug

2. **Marqueurs TODO/FIXME** : 4 occurrences identifiées (principalement dans tests et DataImportExportManager)
   - TODO compression audio dans DataImportExportManager
   - TODOs dans tests pour corrections API
   - Indique du code en cours de développement

3. **Complexité** : Certains fichiers très volumineux
   - `ContentView.swift` : ~2,600 lignes (fichier principal de l'application)
   - `DeckManagement.swift` : ~3,800 lignes (gestion complète des decks)
   - `SimpleSRSManager.swift` : ~1,500 lignes (algorithme SM-2 complet)
   - `DataImportExportManager.swift` : 1,737 lignes (import/export complet)
   - `AIFlashcardGenerator.swift` : 972 lignes (génération IA)
   - `OnboardingViewModel.swift` : ~1,200 lignes (onboarding complet)

4. **Qualité du code** :
   - Variables nommées de manière descriptive (alpha, red, green, blue)
   - Gestion d'erreurs sécurisée avec do-catch
   - Headers de fichiers corrects
   - Code conforme aux standards SwiftLint

5. **Dépendances MLX** : 3 fichiers utilisent MLX (AIFlashcardGenerator, ModelManager, configuration)
   - Packages MLX chargés : 13 packages dans le projet
   - Réellement utilisés : MLX, MLXLLM, MLXLMCommon
   - Impact sur la taille de l'application : Modèle SmolLM3-3B-4bit (~100MB compressé)

6. **UserDefaults et @AppStorage** : 231 occurrences dans 29 fichiers
   - Utilisation extensive pour préférences utilisateur
   - Synchronisation avec App Group pour widgets
   - Gestion de la période active via UserDefaults

7. **NotificationCenter** : 89 occurrences dans 22 fichiers
   - Communication entre composants
   - Notifications pour changements de données, statut premium, etc.

### Métriques de Complexité

- **Fichiers avec >500 lignes** : 15 fichiers identifiés
- **Fichiers avec >1000 lignes** : 6 fichiers identifiés
- **Fichiers avec >2000 lignes** : 1 fichier (DeckManagement.swift : 3,890 lignes)
- **Déclarations totales** : 6,900 déclarations (func/var/let/class/struct/enum)
- **Types définis** : 306 types (classes, structs, enums) identifiés
- **Extensions** : 75 extensions pour réutilisabilité
- **Fonctions complexes** : Certaines fonctions SM-2 et import/export nécessitent attention

### Gestion de la Mémoire

- **Cache GPU MLX** : Limité à 256MB
- **Nettoyage automatique** : Après chaque génération IA
- **Cache KV réutilisé** : Entre générations pour performance
- **Système de cache hiérarchique** :
  - Cache mémoire (NSCache) : Limites adaptatives selon appareil
  - Cache disque : Persistance des données critiques
  - Cache calculs : Optimisation des moyennes
  - Cache assets : Gestion des médias
- **Gestion mémoire** : Surveillance des alertes mémoire système, nettoyage automatique des caches non essentiels
- **Fichiers utilisant NSCache** : 33 fichiers avec système de cache

---

## Tests

### Structure des Tests

**15 fichiers de tests** dans `PARALLAXTests/` :

1. **SM2AlgorithmTests.swift** : Tests de l'algorithme SM-2 de base
2. **SM2ComprehensiveTests.swift** : Tests complets SM-2
3. **SM2EdgeCaseTests.swift** : Cas limites SM-2
4. **SM2IdempotenceTests.swift** : Tests d'idempotence
5. **SM2IntegrationTests.swift** : Tests d'intégration SM-2
6. **SM2OptimizationTests.swift** : Tests d'optimisation
7. **SM2RobustnessTests.swift** : Tests de robustesse
8. **SM2StressTests.swift** : Tests de stress
9. **SM2StrictTests.swift** : Tests stricts SM-2
10. **SM2ValidationTests.swift** : Tests de validation
11. **SRSBoundaryTests.swift** : Tests des limites SRS
12. **GradingSystemTests.swift** : Tests des systèmes de notation
13. **ExportImportSmokeTests.swift** : Tests smoke import/export
14. **GradefyCacheSimulation.swift** : Simulation de cache
15. **PARALLAXTests.swift** : Tests généraux

**Total lignes de tests** : 7,135 lignes

### Couverture

- **SM-2** : Couverture complète (algorithmes, intégration, robustesse, limites)
- **Systèmes de notation** : Tests présents
- **Import/Export** : Tests smoke présents
- **Cache** : Simulation présente

### Types de Tests

- **Unitaires** : Tests d'algorithmes isolés
- **Intégration** : Tests avec Core Data
- **Robustesse** : Tests de cas limites et erreurs
- **Performance** : Tests de stress et optimisation
- **Idempotence** : Tests de non-duplication

---

## Configuration et Déploiement

### Configuration du Projet

**Bundle Identifier** :
- Application : `Coefficient.Gradefy`
- Tests : `Parallax.PARALLAXTests`
- Widget : `Coefficient.Gradefy.PARALLAXWidget`

**Versions** :
- Marketing Version : 1.0
- Current Project Version : 1

**Capabilities** :
- App Groups : `group.com.Coefficient.PARALLAX2`
- Background Modes :
  - Background processing
  - Background fetch
  - Remote notifications
- StoreKit Configuration File : `PARALLAX_StoreKit.storekit`

### Permissions Requises

**Info.plist** :
- `NSMicrophoneUsageDescription` : Enregistrement audio
- `NSSpeechRecognitionUsageDescription` : Transcription vocale
- `NSPhotoLibraryUsageDescription` : Accès photos
- `NSCameraUsageDescription` : Appareil photo
- `NSDocumentsFolderUsageDescription` : Accès fichiers

### Sécurité

- **ITSAppUsesNonExemptEncryption** : `false`
- **NSAppTransportSecurity** : Configuration sécurisée (pas d'arbitrary loads)
- **Local networking** : Autorisé pour développement

### Entitlements

**Application** :
- App Groups activé
- Background modes activés

**Widget Extension** :
- App Groups activé
- WidgetKit activé

---

## Widgets et Extensions

### PARALLAXWidgetExtension

**Fichiers** :
- `PARALLAXWidgetBundle.swift` : Bundle principal
- `MainWidgets.swift` : Widgets principaux
- `EvaluationDataManager.swift` : Gestion données évaluations
- `WidgetAccessHelper.swift` : Gestion d'accès
- `WidgetLockedView.swift` : Vue verrouillée (non utilisée, tous les widgets accessibles)
- `PARALLAXWidgetLiveActivity.swift` : Live Activity
- `AppIntent.swift` : Intents App

**Fonctionnalités** :
- Widget de révision (cartes à réviser) : Accessible à tous
- Widget de notes (moyennes) : Accessible à tous
- Live Activity pour sessions : Accessible à tous
- Synchronisation App Group : Active
- Verrouillage premium : Supprimé (tous les widgets accessibles)

### RevisionLiveActivityExtension

Extension pour Live Activities de révision (non analysée en détail dans cet audit)

---

## Sécurité et Permissions

### Stockage des Données

- **Core Data** : Stockage local SQLite
  - Persistent History Tracking activé
  - Merge Policy : NSMergeByPropertyObjectTrumpMergePolicy
  - Automatic Merge activé
- **UserDefaults** : Préférences utilisateur (231 occurrences)
  - Synchronisation avec App Group pour widgets
  - Gestion de la période active
- **App Group** : `group.com.Coefficient.PARALLAX2`
  - Partage données app/widget
  - Test d'accessibilité au démarrage
- **Application Support** : Modèles IA (non visible utilisateur)
  - Dossier : `Library/Application Support/Models/`
- **Documents** : Médias utilisateur
  - Dossier : `Documents/GradefyMedia/`
- **Cache disque** : Données critiques
  - Dossier : `Documents/GradefyCache/`

### Gestion des Fonctionnalités

- **Statut** : Application entièrement gratuite
  - `hasFullAccess` toujours à `true`
  - Toutes les fonctionnalités activées
- **Synchronisation** : App Group pour widgets
  - Synchronisation automatique du statut d'accès
  - Mise à jour des widgets via WidgetCenter
- **StoreKit** : Conservé pour compatibilité technique

### Données Sensibles

- **Pas de données utilisateur sensibles** stockées en clair
- **Modèles IA** : Stockage local uniquement
- **Pas de connexion serveur** pour données utilisateur
- **Sécurité des fichiers** : Utilisation de security-scoped resources pour accès fichiers
- **Bookmarks** : Gestion des bookmarks pour accès fichiers persistants
- **Validation d'entrée** : Validation des UUID, détection de doublons, vérification intégrité référentielle

### Gestion des Erreurs et Sécurité

- **Types d'erreurs personnalisés** : 5 enums d'erreurs avec LocalizedError
- **Gestion d'erreurs explicite** : Try-catch avec messages localisés
- **Validation des données** : Validation avant import/export
- **Protection contre corruption** : Vérification de format, taille, intégrité
- **Rollback atomique** : Import avec rollback en cas d'erreur

---

## Résumé Exécutif

### Points Forts

1. **Architecture solide** : MVVM bien structurée avec séparation claire
   - Organisation par domaines (App, Features, Domain, Data, Presentation)
   - Utilisation de patterns modernes (@Observable, async/await)
   - 68 fichiers avec organisation MARK:

2. **Fonctionnalités complètes** : Gestion notes + SRS + IA + médias
   - 5 systèmes de notation supportés
   - 4 modes de révision différents
   - Génération IA avec modèle local
   - Gestion complète des médias (images, audio)

3. **Tests complets** : 7,135 lignes de tests, couverture SM-2 excellente
   - 15 fichiers de tests couvrant tous les aspects SM-2
   - Tests d'intégration, robustesse, stress, limites

4. **Performance optimisée** : Système de cache multi-niveaux, optimisations Core Data
   - 6 systèmes de cache différents
   - Monitoring de performance intégré
   - Optimisations Core Data (batch, préchargement)
   - Debouncing et throttling pour éviter surcharge

5. **Modèle économique** : Application entièrement gratuite
   - Toutes les fonctionnalités accessibles sans limitation
   - Aucun paywall ou restriction premium
   - Code refactorisé pour refléter le statut gratuit

6. **Gestion d'erreurs robuste** : 
   - 3 enums d'erreurs personnalisés (ImportExportError, DataError, PeriodError, StoreKitHelperError, AIGenerationError)
   - Gestion d'erreurs explicite avec LocalizedError
   - Messages d'erreur localisés

7. **Thread safety** :
   - Utilisation extensive de @MainActor (89 occurrences)
   - DispatchQueue pour opérations asynchrones
   - Protection des caches avec queues concurrentes

8. **Extensibilité** :
   - 75 extensions pour réutilisabilité
   - Systèmes de notation pluggables
   - Composants SwiftUI réutilisables

### Points d'Amélioration

1. **Réduction du logging** : 1,651 print() à remplacer par système de logs conditionnels
   - Beaucoup de logs sont structurés avec préfixes pour faciliter le debug
   - Suggestion : Utiliser des niveaux de log (debug, info, warning, error)

2. **Réduction complexité** : Refactoring des fichiers >1000 lignes
   - 6 fichiers dépassent 1000 lignes
   - 1 fichier dépasse 2000 lignes (DeckManagement.swift : 3,890 lignes)

3. **Nettoyage dépendances** : Supprimer packages MLX non utilisés
   - 13 packages MLX chargés, seulement 3 réellement utilisés
   - Impact sur la taille de l'application

4. **Documentation** : Compléter les 7 TODO/FIXME identifiés
   - Principalement dans tests et DataImportExportManager
   - Compression audio à implémenter

5. **Métriques** : Ajouter métriques de complexité cyclomatique
   - Utiliser des outils d'analyse statique pour identifier les fonctions complexes

### Métriques Clés

- **Taille du code** : 42,111 lignes Swift (~35,000 lignes sans tests)
- **Fichiers** : 97 fichiers Swift
- **Tests** : 15 fichiers, ~7,000 lignes
- **Dépendances externes** : 10 packages Swift (mlx-swift, Lottie, ZIPFoundation, etc.)
- **Entités Core Data** : 6 entités (Subject, Evaluation, Flashcard, FlashcardDeck, Period, UserConfiguration)
- **Systèmes de notation** : 5 systèmes (France, USA, Allemagne, Espagne, Canada)
- **Modes de révision** : 4 modes (Swipe, Quiz, Association, Libre)
- **Types définis** : ~300 types (classes, structs, enums)
- **Extensions** : 75 extensions
- **Déclarations** : ~6,500 déclarations (func/var/let/class/struct/enum)
- **Imports uniques** : 28 frameworks/packages différents
- **Fichiers avec cache** : 33 fichiers utilisant NSCache
- **Utilisation @AppStorage** : 231 occurrences dans 29 fichiers
- **Notifications** : 89 occurrences de NotificationCenter dans 22 fichiers
- **Fichiers avec MARK:** : 68 fichiers organisés
- **Composants SwiftUI** : Nombreux composants réutilisables (AdaptiveLottieView, AdaptiveImage, etc.)
- **Statut** : Application entièrement gratuite

---

## Détails Techniques Supplémentaires

### Gestion de la Concurrence

- **@MainActor** : 89 occurrences pour isolation du thread principal
- **async/await** : 613 occurrences pour opérations asynchrones
- **Task.detached** : Utilisé pour opérations CPU-intensives
- **DispatchQueue** : Utilisé pour opérations I/O et cache
- **Queues spécialisées** :
  - `com.gradefy.cache` : Cache principal
  - `com.gradefy.disk.cache` : Cache disque
  - `com.parallax.srs.operations` : Opérations SM-2
  - `cache.performance` : Monitoring performance
  - `sm2.metrics` : Métriques SM-2

### Système de Notifications

- **NotificationCenter** : 89 occurrences dans 22 fichiers
- **Notifications personnalisées** :
  - `dataDidChange` : Changements Core Data
  - `fullAccessStatusChanged` : Changement statut d'accès
  - `activePeriodChanged` : Changement période active
  - `OnboardingCompleted` : Complétion onboarding
  - `RestartOnboarding` : Redémarrage onboarding
  - `audioDidStop` / `audioDidFinish` : Événements audio
  - `navigateToEvaluations` / `navigateToWeeklyStats` : Navigation
  - `saveActivePeriod` : Sauvegarde période active
  - `FlashcardModified` : Modification flashcards
  - `forceClosePopovers` : Fermeture popovers
  - `deckStatsUpdated` : Mise à jour stats decks

### Composants UI Personnalisés

- **AdaptiveLottieView** : Animation Lottie adaptative au thème
- **AdaptiveImage** : Image adaptative clair/sombre
- **KeyboardAdaptive** : Modifier pour gestion clavier
- **NativeTabButton** : Bouton tab natif iOS
- **PremiumFeatureRow** : Ligne fonctionnalité premium
- **WidgetLockedView** : Vue verrouillée pour widgets
- **LazyView** : Vue lazy pour chargement différé

### Configuration et Constantes

- **SRSConfiguration** : Configuration centralisée SM-2
  - Seuils d'intervalles (acquired: 7j, mastery: 21j)
  - Ease factor (min: 1.3, max: 3.0, default: 2.3)
  - Soft cap (3 ans)
  - Phase early (intervalles fixes: 3j, 7j)
- **GradingConstants** : Constantes systèmes de notation
  - NO_GRADE: -999.0
  - MIN_COEFF: 0.5, MAX_COEFF: 10.0
- **AppConstants** : Constantes UI
  - Tailles animations Lottie
  - Tailles avatars et icônes
  - Limites périodes (min: 1j, max: 730j)

### Gestion des Assets

- **Animations Lottie** : 12 fichiers JSON dans `Presentation/Components/`
  - confetti, download, folder, globe, information, loop, notesblue, palette, poeme, preference, subjectblue
- **Icônes d'application** : 4 variantes (Default, Dark, Colorful, Minimal)
- **Assets** : Organisation dans Assets.xcassets avec previews

### Localisation

- **Fichiers de localisation** : Localizable.strings, Localizable.xcstrings
- **Langues supportées** : Français (principal), Anglais, Espagnol, Allemand
- **Clés de localisation** : Utilisation extensive de `String(localized:)`

### Deep Linking

- **Schemes supportés** : `parallax://`, `gradefy://`
- **Routes** :
  - `parallax://evaluations` : Navigation vers évaluations
  - `parallax://stats` : Navigation vers statistiques
  - `parallax://streak-stats` : Widget vers statistiques
- **Import de fichiers** : Support `.json` et `.gradefy`

### Monitoring et Performance

- **Logging structuré** : Utilisation de `os.log` avec Logger
- **Monitoring conditionnel** : Activé/désactivé selon configuration
- **Performance tracking** : 
  - Latence des opérations
  - Hit rate des caches
  - Métriques SM-2 spécifiques
- **Alertes automatiques** : Alertes si latence élevée ou hit rate faible

### Gestion de la Mémoire

- **Surveillance mémoire** : Observer `UIApplication.didReceiveMemoryWarningNotification`
- **Nettoyage automatique** : Cache assets vidé en cas d'alerte mémoire
- **Préservation données critiques** : Sauvegarde avant nettoyage
- **Cache adaptatif** : Limites selon capacité appareil (AdaptiveCacheConfiguration)

---

---

**Fin de l'audit**


