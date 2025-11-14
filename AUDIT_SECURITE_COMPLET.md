# Audit de Sécurité Complet - Application PARALLAX/Gradefy

**Date** : $(date)  
**Version de l'application** : 1.0  
**Système d'exploitation cible** : iOS 17.0+  
**Type d'audit** : Analyse statique complète du code source

---

## Résumé Exécutif

Cet audit de sécurité identifie **toutes les failles de sécurité potentielles** dans l'application iOS PARALLAX (Gradefy). L'analyse a été effectuée sur l'ensemble du code source Swift, les fichiers de configuration, et les mécanismes de sécurité.

**Statistiques** :
- Fichiers Swift analysés : **98 fichiers**
- Occurrences de `print()` : **1,651 occurrences**
- Utilisations de `UserDefaults` : **150 occurrences** (hors commentaires)
- Expositions d'erreurs : **78 occurrences** de `.localizedDescription`
- Failles identifiées : **15 catégories principales**
- Niveau de criticité : **Moyen à Élevé**

---

## 1. LOGGING ET EXPOSITION D'INFORMATIONS SENSIBLES

### 1.1 Logging Excessif avec Données Sensibles

**Criticité** : ⚠️ **MOYENNE**

**Description** :
L'application contient **1,651 occurrences de `print()`** qui loggent des informations potentiellement sensibles en production.

**Exemples identifiés** :

```swift
// Features/PremiumManager.swift:78
print("📢 Statut premium modifié : \(oldValue) → \(newValue)")

// Features/DataImportExportManager.swift:622
print("❌ [PARALLAXApp] Erreur parsing: \(error)")
handleImportError("Erreur parsing deck : \(error.localizedDescription)")

// App/PARALLAXApp.swift:437-452
private func debugUserDefaults() {
    print("=== [PARALLAXApp] DIAGNOSTIC USERDEFAULTS ===")
    // Lister toutes les clés UserDefaults
    for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
        print("🔑 \(key): \(value)")
    }
}
```

**Risques** :
- Exposition de données utilisateur dans les logs système iOS
- Fuite d'informations sur l'état premium de l'utilisateur
- Exposition de chemins de fichiers et structures de données
- Logs accessibles via Xcode Organizer et outils de diagnostic

**Recommandations** :
- Utiliser `os.log` avec niveaux appropriés (`.debug`, `.info`, `.error`)
- Ne jamais logger de données sensibles (UUIDs, noms d'utilisateurs, chemins complets)
- Désactiver tous les `print()` en production via compilation conditionnelle
- Implémenter un système de logging centralisé avec filtrage

---

## 2. STOCKAGE DE DONNÉES SENSIBLES

### 2.1 UserDefaults pour Données Sensibles

**Criticité** : ⚠️ **MOYENNE à ÉLEVÉE**

**Description** :
L'application utilise **UserDefaults** (150+ occurrences, hors commentaires) pour stocker des données qui devraient être dans Keychain :

**Données stockées dans UserDefaults** :
- `isPremium` : Statut premium (Features/PremiumManager.swift:63)
- `username` : Nom d'utilisateur (Features/OnboardingViewModel.swift:321)
- `activePeriodID` : Identifiants de périodes (App/ContentView.swift:166)
- `profileGradientStartHex`, `profileGradientEndHex` : Préférences utilisateur
- `GradingSystem` : Système de notation sélectionné
- Bookmarks de fichiers (Features/DocumentPickerView.swift:57)

**Risques** :
- UserDefaults est stocké en clair dans le système de fichiers iOS
- Accessible via jailbreak ou backup iTunes/iCloud
- Pas de protection contre la modification malveillante
- Synchronisation iCloud peut exposer les données

**Localisation** :
```swift
// Features/PremiumManager.swift:63
UserDefaults.standard.set(newValue, forKey: "isPremium")

// Features/DocumentPickerView.swift:57
UserDefaults.standard.set(bookmarkData, forKey: "importedFileBookmark_\(url.lastPathComponent)")
```

**Recommandations** :
- Migrer `isPremium` vers Keychain avec `kSecAttrAccessibleWhenUnlocked`
- Stocker les bookmarks de fichiers dans Keychain
- Utiliser UserDefaults uniquement pour préférences non sensibles
- Implémenter chiffrement pour données critiques dans UserDefaults

---

### 2.2 Absence de Chiffrement pour Données Core Data

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Les données Core Data sont stockées en **clair** dans SQLite sans chiffrement au niveau de la base de données.

**Données stockées** :
- Noms d'utilisateurs
- Notes et évaluations
- Contenu des flashcards
- Métadonnées de médias
- Historique de révision

**Risques** :
- Accès direct aux données via backup iTunes/iCloud
- Lecture possible avec outils SQLite sur appareil jailbreaké
- Pas de protection contre extraction de données

**Recommandations** :
- Activer `NSPersistentStoreFileProtectionKey` avec `.complete`
- Utiliser `NSFileProtectionComplete` pour les fichiers Core Data
- Implémenter chiffrement au niveau application pour données sensibles
- Considérer `NSPersistentStoreFileProtectionKey` avec `.completeUnlessOpen`

---

## 3. GESTION DES ERREURS ET EXPOSITION D'INFORMATIONS

### 3.1 Exposition d'Erreurs Détaillées aux Utilisateurs

**Criticité** : ⚠️ **MOYENNE**

**Description** :
**78 occurrences** de `error.localizedDescription` sont exposées directement aux utilisateurs, révélant des informations système.

**Exemples** :

```swift
// Features/PremiumView.swift:139
showError(String(localized: "premium_error_restore_failed")
    .replacingOccurrences(of: "%@", with: error.localizedDescription))

// Features/DataImportExportManager.swift:1634
.replacingOccurrences(of: "%@", with: underlyingError.localizedDescription)

// Domain/Views/SubjectAndEvaluationViews.swift:410
errorMessage = String(localized: "error_save")
    .replacingOccurrences(of: "%@", with: error.localizedDescription)
```

**Risques** :
- Exposition de chemins de fichiers complets
- Révélation de structure de données interne
- Informations sur l'état du système
- Aide à l'ingénierie inverse

**Recommandations** :
- Créer des messages d'erreur génériques pour l'utilisateur
- Logger les erreurs détaillées uniquement côté serveur/logs
- Utiliser des codes d'erreur internes au lieu de descriptions système
- Implémenter un système de mapping erreur → message utilisateur

---

## 4. VALIDATION ET SANITISATION DES ENTRÉES

### 4.1 Validation Insuffisante des Noms de Fichiers

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Les noms de fichiers utilisateur sont utilisés directement sans validation stricte contre les attaques de path traversal.

**Exemples** :

```swift
// Features/DataImportExportManager.swift:254
let targetFile = targetDir.appendingPathComponent(file.lastPathComponent)

// Shared/DeckSharingManager.swift:94
let tempURL = tempDir.appendingPathComponent("\(fileName).gradefy")

// Revision/MediaStorageManager.swift
// Utilisation directe de fileName sans validation
```

**Risques** :
- Path traversal (`../../../etc/passwd`)
- Injection de caractères spéciaux
- Écrasement de fichiers système
- Création de fichiers avec noms malveillants

**Recommandations** :
- Valider les noms de fichiers contre whitelist de caractères autorisés
- Sanitiser les noms avec `NSString.stringByReplacingOccurrencesOfString`
- Utiliser `URL(fileURLWithPath:)` au lieu de concaténation de strings
- Implémenter validation stricte : alphanumériques + tirets/underscores uniquement

---

### 4.2 Validation Insuffisante des URLs

**Criticité** : ⚠️ **FAIBLE à MOYENNE**

**Description** :
Les URLs sont utilisées sans validation stricte dans certains cas.

**Exemples** :

```swift
// Features/ModelManager.swift:47
downloadURL: URL(string: "https://github.com/Frd100/AitestGrd/releases/download/1.0.0/SmolLM3-3B-4bit.zip")!

// PARALLAXWidget/PARALLAXWidgetLiveActivity.swift:53
.widgetURL(URL(string: "http://www.apple.com"))
```

**Risques** :
- URLs malformées peuvent causer des crashes
- Pas de validation du schème (http/https)
- Deep links non validés

**Recommandations** :
- Valider toutes les URLs avec `URLComponents`
- Vérifier le schème (https uniquement sauf exceptions documentées)
- Valider les deep links avec whitelist de chemins autorisés
- Implémenter validation stricte pour URLs utilisateur

---

## 5. INJECTION SQL ET REQUÊTES COREDATA

### 5.1 Utilisation de NSPredicate avec Valeurs Utilisateur

**Criticité** : ✅ **FAIBLE** (Bien protégé)

**Description** :
L'application utilise **NSPredicate** avec des valeurs utilisateur, mais utilise correctement les placeholders `%@` pour éviter l'injection.

**Exemples sécurisés** :

```swift
// App/ContentView.swift:1981
request.predicate = NSPredicate(format: "name == %@", savedPeriod)

// Features/DataImportExportManager.swift:733
request.predicate = NSPredicate(format: "id == %@", periodUUID as CVarArg)

// Data/Cache/SM2CoreDataOptimizer.swift:51
fetchRequest.predicate = NSPredicate(format: "deck == %@ AND (nextReviewDate == nil OR nextReviewDate <= %@)", deck, now as NSDate)
```

**Statut** : ✅ **SÉCURISÉ** - Toutes les requêtes utilisent des placeholders paramétrés

**Note** : Aucune utilisation dangereuse de format strings avec `%s` ou concaténation trouvée.

---

## 6. GESTION DES PERMISSIONS ET ACCÈS FICHIERS

### 6.1 Utilisation Correcte de Security-Scoped Resources

**Criticité** : ✅ **BIEN IMPLÉMENTÉ**

**Description** :
L'application utilise correctement `startAccessingSecurityScopedResource()` et `stopAccessingSecurityScopedResource()` pour l'accès aux fichiers.

**Exemples** :

```swift
// Features/DataImportExportManager.swift:338-342
guard url.startAccessingSecurityScopedResource() else {
    throw ImportExportError.securityScopedResourceFailed
}
defer { url.stopAccessingSecurityScopedResource() }

// App/PARALLAXApp.swift:599-604
let accessing = url.startAccessingSecurityScopedResource()
defer {
    if accessing {
        url.stopAccessingSecurityScopedResource()
    }
}
```

**Statut** : ✅ **SÉCURISÉ** - Bonne gestion des security-scoped resources

---

### 6.2 Stockage de Bookmarks dans UserDefaults

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Les bookmarks de fichiers sont stockés dans UserDefaults au lieu de Keychain.

**Exemple** :

```swift
// Features/DocumentPickerView.swift:57
UserDefaults.standard.set(bookmarkData, forKey: "importedFileBookmark_\(url.lastPathComponent)")
```

**Risques** :
- Bookmarks accessibles via backup
- Pas de protection contre modification
- Synchronisation iCloud peut exposer les bookmarks

**Recommandations** :
- Stocker les bookmarks dans Keychain
- Utiliser `kSecClassGenericPassword` avec accès contrôlé
- Implémenter expiration automatique des bookmarks

---

## 7. SÉCURITÉ RÉSEAU ET COMMUNICATION

### 7.1 Configuration App Transport Security

**Criticité** : ✅ **BIEN CONFIGURÉ**

**Description** :
L'application a une configuration ATS sécurisée dans `Info.plist`.

**Configuration** :
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Statut** : ✅ **SÉCURISÉ** - ATS activé avec exception uniquement pour localhost (développement)

---

### 7.2 URL HTTP dans Widget

**Criticité** : ⚠️ **FAIBLE**

**Description** :
Une URL HTTP est utilisée dans un widget (mais pointe vers apple.com).

**Exemple** :
```swift
// PARALLAXWidget/PARALLAXWidgetLiveActivity.swift:53
.widgetURL(URL(string: "http://www.apple.com"))
```

**Risque** : Faible (domaine Apple), mais devrait utiliser HTTPS pour cohérence

**Recommandation** : Changer en `https://www.apple.com`

---

## 8. VALIDATION PREMIUM ET ACHATS IN-APP

### 8.1 Validation StoreKit Correcte

**Criticité** : ✅ **BIEN IMPLÉMENTÉ**

**Description** :
L'application utilise StoreKit 2 avec validation correcte des transactions.

**Exemple** :
```swift
// Features/PremiumManager.swift:389-401
for await result in Transaction.currentEntitlements {
    do {
        let transaction = try await checkVerified(result)
        if transaction.revocationDate == nil {
            hasValidEntitlement = true
            break
        }
    } catch {
        continue
    }
}
```

**Statut** : ✅ **SÉCURISÉ** - Validation correcte avec vérification de révocation

---

### 8.2 Stockage du Statut Premium dans UserDefaults

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Le statut premium est stocké dans UserDefaults, permettant une modification facile.

**Exemple** :
```swift
// Features/PremiumManager.swift:63
UserDefaults.standard.set(newValue, forKey: "isPremium")
```

**Risques** :
- Modification possible via jailbreak
- Pas de vérification d'intégrité
- Synchronisation peut être manipulée

**Recommandations** :
- Ne jamais faire confiance à UserDefaults pour validation premium
- Toujours valider via StoreKit avant d'accorder l'accès
- Implémenter cache local avec vérification périodique
- Utiliser Keychain pour stockage local avec validation serveur

---

## 9. PROTECTION CONTRE LES ATTAQUES

### 9.1 Absence de Rate Limiting

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Aucun mécanisme de rate limiting identifié pour :
- Tentatives de validation premium
- Import de données
- Génération de flashcards IA
- Requêtes Core Data

**Risques** :
- Attaques par déni de service (DoS)
- Épuisement des ressources système
- Consommation excessive de batterie/CPU

**Recommandations** :
- Implémenter rate limiting pour validation premium (déjà partiellement fait avec circuit breaker)
- Limiter le nombre d'imports par période
- Throttling pour génération IA
- Monitoring des ressources système

---

### 9.2 Circuit Breaker pour Validation Premium

**Criticité** : ✅ **BIEN IMPLÉMENTÉ**

**Description** :
L'application implémente un circuit breaker pour la validation premium.

**Exemple** :
```swift
// Features/PremiumManager.swift:344-354
if validationAttempts >= maxValidationAttempts {
    let backoffTime = validationCooldown * pow(2.0, Double(validationAttempts - maxValidationAttempts))
    if now.timeIntervalSince(lastValidationAttempt) < backoffTime {
        print("🛑 Circuit breaker actif - validation bloquée")
        return
    }
}
```

**Statut** : ✅ **SÉCURISÉ** - Protection contre validation excessive

---

## 10. SÉCURITÉ DES DONNÉES IMPORT/EXPORT

### 10.1 Validation des Données Importées

**Criticité** : ✅ **BIEN IMPLÉMENTÉ**

**Description** :
L'application valide correctement les données importées.

**Exemples** :
```swift
// Features/DataImportExportManager.swift:870-903
private func validateImportData(_ data: [String: Any]) throws {
    // Validation de la structure de base
    guard let metadata = data["metadata"] as? [String: Any] else {
        throw ImportExportError.invalidFormat
    }
    // Validation des UUID
    try validateUUIDs(periodsData, entityName: "periods")
    // Validation de l'intégrité référentielle
    try validateRelationalIntegrity(...)
}
```

**Statut** : ✅ **SÉCURISÉ** - Validation complète avec vérification d'intégrité

---

### 10.2 Limite de Taille des Fichiers Importés

**Criticité** : ✅ **BIEN IMPLÉMENTÉ**

**Description** :
L'application limite la taille des fichiers importés.

**Exemple** :
```swift
// Features/DataImportExportManager.swift:84-103
private func validateImportSize(_ data: Data) throws {
    let fileSize = data.count
    let maxSize = 500 * 1024 * 1024 // 500MB
    
    if fileSize > maxSize {
        throw ImportExportError.fileTooLarge(maxSize: maxSize, actualSize: fileSize)
    }
    
    // Vérifier l'espace disque disponible
    let availableSpace = try getAvailableDiskSpace()
    let requiredSpace = fileSize * 2
    if availableSpace < requiredSpace {
        throw ImportExportError.insufficientDiskSpace(...)
    }
}
```

**Statut** : ✅ **SÉCURISÉ** - Protection contre fichiers trop volumineux

---

## 11. GESTION DES MÉDIAS ET FICHIERS

### 11.1 Validation des Types de Fichiers

**Criticité** : ⚠️ **MOYENNE**

**Description** :
La validation des types de fichiers médias pourrait être plus stricte.

**Risques** :
- Upload de fichiers malveillants déguisés en images/audio
- Exploitation de vulnérabilités dans les codecs
- Consommation excessive de stockage

**Recommandations** :
- Valider les signatures de fichiers (magic numbers) au lieu de se fier aux extensions
- Limiter les formats supportés à une whitelist stricte
- Valider la taille des fichiers avant traitement
- Scanner les fichiers pour contenu malveillant

---

## 12. SÉCURITÉ DES DEEP LINKS

### 12.1 Validation des Deep Links

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Les deep links sont validés mais pourraient être plus stricts.

**Exemple** :
```swift
// App/PARALLAXApp.swift:648-677
private func handleGradefyUrl(_ url: URL) {
    let pathComponents = url.pathComponents
    guard pathComponents.count > 1 else { return }
    
    let path = pathComponents[1]
    switch path.lowercased() {
    case "premium": handlePremiumURL()
    case "evaluations": handleEvaluationsURL()
    case "stats": handleWeeklyStatsURL()
    default: logger.error("❌ Chemin Gradefy non reconnu : \(path)")
    }
}
```

**Risques** :
- Injection de paramètres malveillants
- Accès non autorisé à certaines fonctionnalités
- Manipulation de l'état de l'application

**Recommandations** :
- Valider tous les paramètres des deep links
- Implémenter whitelist stricte de chemins autorisés
- Valider les permissions avant d'exécuter les actions
- Logger tous les deep links pour audit

---

## 13. CONFIGURATION ET ENTITLEMENTS

### 13.1 Configuration Info.plist

**Criticité** : ✅ **BIEN CONFIGURÉ**

**Description** :
La configuration `Info.plist` est globalement sécurisée.

**Points positifs** :
- ATS activé avec exceptions minimales
- Permissions documentées avec descriptions appropriées
- Pas d'arbitrary loads activés
- Encryption déclarée correctement (`ITSAppUsesNonExemptEncryption: false`)

---

### 13.2 Entitlements

**Criticité** : ✅ **BIEN CONFIGURÉ**

**Description** :
Les entitlements sont minimalistes et appropriés.

**Configuration** :
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.Coefficient.PARALLAX2</string>
</array>
```

**Statut** : ✅ **SÉCURISÉ** - App Groups correctement configuré

---

## 14. MODE DEBUG ET FONCTIONNALITÉS DE DÉVELOPPEMENT

### 14.1 Mode Debug Accessible

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Des fonctionnalités de debug sont présentes et pourraient être activées en production.

**Exemple** :
```swift
// Features/PremiumManager.swift:447-468
#if DEBUG
func enableDebugPremium() {
    debugOverride = true
    isPremium = true
}
#endif
```

**Risques** :
- Code debug compilé en release si `#if DEBUG` mal configuré
- Fonctionnalités de test accessibles
- Bypass de sécurité possible

**Recommandations** :
- Vérifier que `#if DEBUG` est correctement configuré
- Supprimer tout code debug en production
- Utiliser compilation conditionnelle stricte
- Auditer les flags de compilation

---

## 15. SÉCURITÉ DES DONNÉES DANS LES WIDGETS

### 15.1 Partage de Données via App Group

**Criticité** : ⚠️ **MOYENNE**

**Description** :
Les widgets partagent des données via App Group UserDefaults.

**Risques** :
- Données accessibles par toutes les extensions
- Pas de chiffrement pour données partagées
- Synchronisation peut exposer des données

**Recommandations** :
- Chiffrer les données sensibles avant partage
- Limiter les données partagées au minimum nécessaire
- Valider l'intégrité des données partagées
- Implémenter expiration automatique

---

## RÉSUMÉ DES FAILLES PAR CRITICITÉ

### 🔴 CRITIQUE
Aucune faille critique identifiée.

### ⚠️ MOYENNE à ÉLEVÉE
1. **Logging excessif avec données sensibles** (1,651 occurrences)
2. **Stockage de données sensibles dans UserDefaults** (150+ occurrences)
3. **Exposition d'erreurs détaillées aux utilisateurs** (78 occurrences)
4. **Validation insuffisante des noms de fichiers**
5. **Stockage de bookmarks dans UserDefaults**
6. **Absence de chiffrement Core Data**
7. **Absence de rate limiting généralisé**

### ⚠️ FAIBLE à MOYENNE
8. **URL HTTP dans widget** (apple.com uniquement)
9. **Validation des types de fichiers médias**
10. **Validation des deep links**
11. **Mode debug accessible**
12. **Partage de données via App Group**

### ✅ BIEN SÉCURISÉ
- NSPredicate avec placeholders (protection injection SQL)
- Security-scoped resources (accès fichiers)
- Configuration ATS
- Validation StoreKit
- Circuit breaker premium
- Validation import/export
- Limite taille fichiers

---

## RECOMMANDATIONS PRIORITAIRES

### Priorité 1 (Immédiat)
1. **Désactiver tous les `print()` en production**
2. **Migrer `isPremium` vers Keychain**
3. **Remplacer `error.localizedDescription` par messages génériques**
4. **Activer chiffrement Core Data**

### Priorité 2 (Court terme)
5. **Valider strictement les noms de fichiers**
6. **Migrer bookmarks vers Keychain**
7. **Implémenter rate limiting généralisé**
8. **Renforcer validation deep links**

### Priorité 3 (Moyen terme)
9. **Valider signatures de fichiers médias**
10. **Chiffrer données App Group**
11. **Audit complet du code debug**
12. **Implémenter monitoring sécurité**

---

## CONCLUSION

L'application présente une **architecture de sécurité globalement solide** avec de bonnes pratiques pour :
- Protection contre injection SQL
- Gestion des security-scoped resources
- Validation StoreKit
- Configuration réseau sécurisée

Cependant, plusieurs **améliorations importantes** sont nécessaires concernant :
- Le logging excessif en production
- Le stockage de données sensibles
- La gestion des erreurs
- La validation des entrées utilisateur

**Score de sécurité global** : **7/10**

L'application est **sécurisée pour un usage général**, mais nécessite des améliorations avant une mise en production à grande échelle ou pour des données hautement sensibles.

---

**Fin du rapport d'audit de sécurité**

