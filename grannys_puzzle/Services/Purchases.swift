import StoreKit
import os

/// What the player has bought from the App Store, through Apple's StoreKit 2,
/// for every item in `ShopItem.all`: whether ads are removed, and delivering
/// helpers bought in packs or in the welcome bundle.
///
/// Apple's records are the truth, not our save file: `Transaction` gives
/// signed transactions that StoreKit checks and keeps on the phone, so this
/// works offline, can't be unlocked by editing a file, and comes back after
/// a reinstall or on a new phone with the same Apple Account. The only thing
/// kept here is a cache of the last answer (see `cacheKey`).
///
/// Kept apart from AdKit on purpose: AdKit shows ads and knows nothing about
/// purchases; the app decides where ads go and asks this whether to skip
/// them (Game, LevelScreen). And apart from the player's progress: helpers
/// are handed to the game through `DeliverHelpers`, which saves them.
///
/// Delivery is idempotent by design. The App Store can hand a purchase over
/// more than once (after a crash, at every restore), so each one carries a
/// key, and the game adds a key's helpers only once
/// (`PlayerProgress.grantPurchase`). That lets this simply deliver whatever
/// arrives, without its own bookkeeping.
@MainActor
@Observable
final class Purchases {
    enum PurchaseOutcome {
        case purchased
        case cancelled
        /// Waiting for someone else: a parent approving ("Ask to Buy"), or
        /// a payment that needs action. It arrives later through
        /// `Transaction.updates` if it goes through.
        case pending
        case failed
    }

    enum RestoreOutcome {
        case restored
        /// Apple has no purchase to give back for this Apple Account.
        case nothingToRestore
        case failed
    }

    /// Adds an item's helpers to the player's progress and saves it, once per
    /// key; true when they're in (or were already). Set by `start`.
    typealias DeliverHelpers = (_ item: ShopItem, _ key: String) -> Bool

    /// The non-consumable items the player owns, by product ID.
    private(set) var owned: Set<String>
    /// The products with their prices in the player's currency, once loaded
    /// from the App Store; missing before that or while it can't be reached.
    private(set) var products: [String: Product] = [:]

    /// Either item that removes ads is owned ("Remove ads" or the bundle).
    var ownsRemoveAds: Bool {
        ShopItem.all.contains { $0.removesAds && owned.contains($0.id) }
    }

    /// Whether the shop still has something to sell. With packs of helpers
    /// that's always, but the rule stays in one place for the stall.
    var hasSomethingToSell: Bool {
        ShopItem.all.contains { isAvailable($0) }
    }

    /// Can be bought now: a pack always; a one-time item if not owned, and
    /// not if it removes ads and ads are already removed (buying the bundle
    /// after "Remove ads" would charge twice for the same thing).
    func isAvailable(_ item: ShopItem) -> Bool {
        switch item.kind {
        case .consumable: true
        case .nonConsumable: !owned.contains(item.id) && !(item.removesAds && ownsRemoveAds)
        }
    }

    /// Shown in the shop: what can be bought, plus one-time items the
    /// player owns, marked as bought. The other ad-removing item is left
    /// out once ads are removed, rather than shown as something they can't
    /// buy (or as "Bought", which they didn't).
    func isListed(_ item: ShopItem) -> Bool {
        isAvailable(item) || owned.contains(item.id)
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var deliverHelpers: DeliverHelpers?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "purchases")

    /// The last answer from StoreKit, read at launch. Asking StoreKit takes
    /// a moment; without the cache a buyer would see a banner flash in, or
    /// get an ad break, before the answer arrived. It is replaced by
    /// StoreKit's answer at every launch, so a refund still takes effect.
    private static let cacheKey = "purchases.owned"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        owned = Set(defaults.stringArray(forKey: Self.cacheKey) ?? [])
    }

    /// Listens for transactions and checks what's owned. Call once, at
    /// launch, as soon as the game can take helpers: purchases can arrive at
    /// any time, not only from our Buy button (a parent's approval, a
    /// purchase on another device, a pack bought just before a crash, a
    /// refund).
    func start(deliver: @escaping DeliverHelpers) {
        guard updatesTask == nil else { return }
        deliverHelpers = deliver
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await refreshOwnership()
            await loadProducts()
        }
    }

    /// Loads the products (their prices) not loaded yet; the shop card
    /// calls this when it opens, in case launch was offline.
    func loadProducts() async {
        let missing = ShopItem.all.map(\.id).filter { products[$0] == nil }
        guard !missing.isEmpty else { return }
        do {
            for product in try await Product.products(for: missing) {
                products[product.id] = product
            }
            for id in missing where products[id] == nil {
                // Not set up (in App Store Connect, or the scheme's StoreKit
                // file isn't selected): a setup problem, not the player's.
                logger.error("No product for \(id, privacy: .public)")
            }
        } catch {
            logger.error("Loading products failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reads what Apple's purchase sheet returned. The sheet itself is
    /// opened by the view, with SwiftUI's `purchase` action, which ties it
    /// to the right window.
    func handlePurchase(_ result: Product.PurchaseResult) async -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            // An unverified transaction failed Apple's signature check:
            // treated as not bought.
            guard case .verified(let transaction) = verification else { return .failed }
            return await deliver(transaction) ? .purchased : .failed
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed
        }
    }

    /// "Restore purchases": asks the App Store for this Apple Account's
    /// purchases again. Usually not needed (StoreKit 2 syncs by itself), but
    /// App Review requires the button, and it helps after a sign-in change.
    /// It may ask the player to sign in. Only non-consumables come back:
    /// a used-up pack can't be restored, by Apple's rules.
    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("Restoring failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
        await refreshOwnership()
        return owned.isEmpty ? .nothingToRestore : .restored
    }

    // MARK: - Private

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        _ = await deliver(transaction)
    }

    /// Gives the player what a verified transaction bought, then finishes it
    /// (finishing tells Apple it was delivered; until then it keeps arriving
    /// at every launch). True if delivered.
    private func deliver(_ transaction: Transaction) async -> Bool {
        guard let item = ShopItem.all.first(where: { $0.id == transaction.productID }) else {
            // Not ours to deliver (an item removed from the shop): finished
            // so it stops coming back.
            await transaction.finish()
            return false
        }
        switch item.kind {
        case .nonConsumable:
            await transaction.finish()
            // A refund arrives here too (revoked): re-reading ownership
            // handles both directions, and gives a bundle's helpers.
            await refreshOwnership()
            return owned.contains(item.id)
        case .consumable:
            // Saved into progress first, finished after: if the app dies in
            // between, Apple hands the purchase over again at the next
            // launch, and its key stops it counting twice.
            guard let deliverHelpers, deliverHelpers(item, "pack-\(transaction.id)") else {
                logger.error("Delivering \(item.id, privacy: .public) failed; Apple will offer it again")
                return false
            }
            await transaction.finish()
            return true
        }
    }

    /// Owned while Apple has a verified, unrevoked transaction for it. A
    /// refund revokes it, and the ads come back.
    ///
    /// Also where a one-time item's helpers (the bundle's) are given: every
    /// owned purchase is delivered again here, and its key, the purchase's
    /// original ID (the same for a restore), makes repeats add nothing. On a
    /// new phone or after a reinstall progress starts empty, so the helpers
    /// come again, which is fair: so did the player's other helpers. A
    /// refund doesn't take given helpers back; they may be spent already.
    private func refreshOwnership() async {
        var found: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let item = ShopItem.all.first(where: { $0.id == transaction.productID }),
                  item.kind == .nonConsumable
            else { continue }
            found.insert(item.id)
            if item.contents != nil {
                _ = deliverHelpers?(item, "bundle-\(transaction.originalID)")
            }
        }
        owned = found
        defaults.set(Array(found), forKey: Self.cacheKey)
    }
}
