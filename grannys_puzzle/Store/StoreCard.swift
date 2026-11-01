import SwiftUI
import StoreKit
import ArrowwordCore

/// The shop, opened from the stall in grandma's room: the featured items
/// (the welcome bundle, "Remove ads") as large panels on top, the packs of
/// helpers as small tiles in a grid under them (picture, what they give,
/// price), and "Restore purchases" at the foot (App Review requires a way
/// to restore).
///
/// What an item gives is written from `packs`, the same tuning the game
/// delivers with, so the card never promises a number it won't give.
///
/// Owned one-time items stay listed, marked as bought, so the player can
/// see what they have; a thank-you replaces the note after a purchase.
struct StoreCard: View {
    let purchases: Purchases
    /// What each item gives (GameTuning.shop).
    let packs: ShopPacks
    /// Analytics, through Game.
    let onPurchase: (ShopItem, Purchases.PurchaseOutcome) -> Void
    let onRestore: (Purchases.RestoreOutcome) -> Void
    let onClose: () -> Void

    /// What the last action said, at the foot of the card.
    private enum Note: Equatable {
        case thankYou
        case pending
        case purchaseFailed
        case restoreFailed
        case nothingToRestore
    }

    @State private var note: Note?
    /// While Apple's purchase sheet or a restore is in progress, so a second
    /// tap can't start another.
    @State private var isBusy = false
    /// SwiftUI's purchase action: shows Apple's sheet over this window.
    @Environment(\.purchase) private var purchase

    private var listed: [ShopItem] { ShopItem.all.filter(purchases.isListed) }
    private var featured: [ShopItem] { listed.filter { $0.placement == .featured } }
    private var tiles: [ShopItem] { listed.filter { $0.placement == .tile } }
    /// Two tiles to a row, so each has room for a good-sized picture and a
    /// readable price; a lone tile takes the whole width rather than
    /// leaving half a row empty.
    private var tileColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: tiles.count > 1 ? 2 : 1)
    }

    var body: some View {
        GameCard(title: "Shop", onClose: onClose) {
            VStack(spacing: 16) {
                // Scrolls once there are more items than fit; with one, it's
                // just the row.
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(featured) { item in
                            FeaturedShopItem(
                                item: item,
                                benefits: ShopBenefit.list(for: item, packs: packs),
                                product: purchases.products[item.id],
                                isOwned: !purchases.isAvailable(item),
                                isBusy: isBusy,
                                onBuy: { buy(item, $0) }
                            )
                        }
                        if !tiles.isEmpty {
                            LazyVGrid(columns: tileColumns, spacing: 10) {
                                ForEach(tiles) { item in
                                    ShopItemTile(
                                        item: item,
                                        title: ShopBenefit.tileTitle(for: item, packs: packs),
                                        product: purchases.products[item.id],
                                        isOwned: !purchases.isAvailable(item),
                                        isBusy: isBusy,
                                        onBuy: { buy(item, $0) }
                                    )
                                }
                            }
                        }
                    }
                    // Room for a featured item's ribbon, which hangs above
                    // its panel: the scroll view clips at its top edge.
                    .padding(.top, FeaturedShopItem.ribbonOverhang)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 520)

                if let note {
                    Text(text(for: note))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                restoreLink
            }
        }
        // In case launch was offline and the prices never arrived.
        .task { await purchases.loadProducts() }
    }

    private var restoreLink: some View {
        Button {
            restore()
        } label: {
            Text("Restore purchases")
                .font(.system(size: 15, weight: .medium))
                .underline()
                .foregroundStyle(Theme.secondaryInk)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func text(for note: Note) -> LocalizedStringKey {
        switch note {
        case .thankYou: "Thank you, dear!"
        case .pending: "Waiting for approval. It arrives as soon as it's approved."
        case .purchaseFailed: "The purchase didn't go through. Please try again."
        case .restoreFailed: "Restoring didn't work just now. Please try again in a moment."
        case .nothingToRestore: "No earlier purchase was found for this Apple Account."
        }
    }

    // MARK: - Actions

    private func buy(_ item: ShopItem, _ product: Product) {
        isBusy = true
        note = nil
        Task {
            let outcome: Purchases.PurchaseOutcome
            do {
                let result = try await purchase(product)
                outcome = await purchases.handlePurchase(result)
            } catch {
                // The sheet couldn't open or the App Store refused (offline,
                // purchases turned off in Screen Time).
                outcome = .failed
            }
            onPurchase(item, outcome)
            switch outcome {
            case .purchased: note = .thankYou
            case .cancelled: note = nil
            case .pending: note = .pending
            case .failed: note = .purchaseFailed
            }
            isBusy = false
        }
    }

    private func restore() {
        isBusy = true
        note = nil
        Task {
            let outcome = await purchases.restore()
            onRestore(outcome)
            switch outcome {
            case .restored: note = .thankYou
            case .nothingToRestore: note = .nothingToRestore
            case .failed: note = .restoreFailed
            }
            isBusy = false
        }
    }
}

/// The shop's main offer: its picture and name, what it gives, and either
/// its Buy button with Apple's price or, once a one-time item is owned,
/// "Bought".
private struct FeaturedShopItem: View {
    let item: ShopItem
    let benefits: [ShopBenefit]
    /// Nil until the price has loaded (or while offline).
    let product: Product?
    let isOwned: Bool
    let isBusy: Bool
    let onBuy: (Product) -> Void

    private let buttonHeight: CGFloat = 50
    /// How far the ribbon sticks out above the panel.
    static let ribbonOverhang: CGFloat = 10

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(benefits) { benefit in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: benefit.systemName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .accessibilityHidden(true)
                        benefit.text
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
        // The ribbon pointing at the better deal, on the panel's corner.
        .overlay(alignment: .topTrailing) {
            if let badge = item.badge, !isOwned {
                Text(badge)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.alertDot))
                    .offset(x: -10, y: -Self.ribbonOverhang)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var action: some View {
        if isOwned {
            BoughtLabel(height: buttonHeight)
        } else if let product {
            PrimaryButton(title: "Buy for \(product.displayPrice)", height: buttonHeight) {
                onBuy(product)
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.6 : 1)
        } else {
            // No price yet, or offline: no button to tap, and a word on why.
            Text("The shop can't be reached just now. Please check your connection.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: buttonHeight)
        }
    }
}

/// A small item in the shop's grid: picture, short title and the price as
/// its button (no separate Buy: tapping the price buys, as in most shops).
private struct ShopItemTile: View {
    let item: ShopItem
    let title: Text
    let product: Product?
    let isOwned: Bool
    let isBusy: Bool
    let onBuy: (Product) -> Void

    private let buttonHeight: CGFloat = 38

    var body: some View {
        VStack(spacing: 6) {
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 72)
                .accessibilityHidden(true)
            title
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            price
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var price: some View {
        if isOwned {
            BoughtLabel(height: buttonHeight)
        } else if let product {
            Button {
                onBuy(product)
            } label: {
                Text(product.displayPrice)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.onPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonHeight)
                    .background(Capsule().fill(Theme.primary))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .opacity(isBusy ? 0.6 : 1)
            .accessibilityLabel(Text("Buy for \(product.displayPrice)"))
        } else {
            // No price yet, or offline; the card's other items say why.
            ProgressView()
                .frame(height: buttonHeight)
        }
    }
}

/// In place of the Buy button once a one-time item is owned.
private struct BoughtLabel: View {
    let height: CGFloat

    var body: some View {
        Label("Bought", systemImage: "checkmark.seal.fill")
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: height)
    }
}

/// One line of what a featured item gives, with its icon, written from the
/// item and the current tuning; and a tile's few words.
private struct ShopBenefit: Identifiable {
    let id: Int
    let systemName: String
    let text: Text

    static func list(for item: ShopItem, packs: ShopPacks) -> [ShopBenefit] {
        var lines: [(String, Text)] = []
        if item.removesAds {
            lines.append(("checkmark.circle.fill", Text("No ads between levels or under the board")))
        }
        if let contents = item.contents {
            let reward = packs[keyPath: contents]
            if reward.hints > 0 { lines.append(("pawprint.fill", Text("\(reward.hints) cat hints"))) }
            if reward.grandmas > 0 { lines.append(("heart.fill", Text("\(reward.grandmas) grandma helpers"))) }
        }
        if item.removesAds {
            // Said plainly, so nobody buys expecting every ad gone: the
            // videos are the player's choice, for helpers and treats.
            lines.append(("play.circle", Text("Videos for helpers stay, whenever you want one")))
        }
        return lines.enumerated().map { ShopBenefit(id: $0.offset, systemName: $0.element.0, text: $0.element.1) }
    }

    /// What a tile gives, which is its name: "15 cat hints".
    static func tileTitle(for item: ShopItem, packs: ShopPacks) -> Text {
        guard let contents = item.contents else { return Text(item.title) }
        let reward = packs[keyPath: contents]
        switch (reward.hints, reward.grandmas) {
        case (let hints, 0): return Text("\(hints) cat hints")
        case (0, let grandmas): return Text("\(grandmas) grandma helpers")
        case (let hints, let grandmas): return Text("\(hints) cat hints and \(grandmas) grandma helpers")
        }
    }
}

