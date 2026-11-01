import SwiftUI
import ArrowwordCore

/// One thing the shop sells: its App Store product, how it's shown and what
/// it does. The shop card draws items from this alone (a large panel for a
/// featured one, a small tile for the rest), so adding one is a new entry in
/// `all` plus its product in App Store Connect and Store.storekit, not a new
/// screen.
///
/// Neither the price nor the number of helpers is here: the price is
/// Apple's, per country (`Product.displayPrice`), and the helpers come from
/// tuning (`contents`, read from `ShopPacks`), so both can change after
/// launch without an app update.
struct ShopItem: Identifiable {
    /// How Apple treats the purchase, which decides how it's delivered.
    enum Kind {
        /// Bought once, kept forever, restorable ("Remove ads", the bundle).
        /// Owned while Apple has an unrevoked transaction for it.
        case nonConsumable
        /// Used up and bought again (packs of helpers). Delivered into the
        /// player's progress *before* Apple is told it was delivered, so a
        /// crash in between can't lose what they paid for (see
        /// `Purchases.deliver`).
        case consumable
    }

    /// How big it shows in the shop.
    enum Placement {
        /// A large panel on top: picture, name, what it gives, Buy.
        case featured
        /// A small tile in the grid under it: picture, what it gives in a
        /// few words, the price as the button.
        case tile
    }

    /// The App Store product ID. Permanent: an ID can never be changed or
    /// reused in App Store Connect, even after deleting the product. So
    /// IDs name the product ("cat hints, small"), never an amount.
    let id: String
    let kind: Kind
    let placement: Placement
    /// Short, for analytics (`store_purchase`'s `product`).
    let analyticsName: String
    let imageName: String
    /// A featured item's name. Tiles are named by what they give.
    var title: LocalizedStringKey = ""
    /// A small ribbon on a featured item, to point at the better deal.
    var badge: LocalizedStringKey?
    /// Owning it turns off the banner and the interstitials.
    var removesAds = false
    /// The helpers it gives, if any, picked out of the current tuning.
    var contents: KeyPath<ShopPacks, JarReward>?
}

extension ShopItem {
    /// "Remove ads" plus helpers, for a little more than "Remove ads" alone:
    /// the obvious good deal for anyone about to remove ads. Hidden once ads
    /// are removed (see `Purchases.isListed`): its helpers alone aren't
    /// worth its price, and Apple can't refund the overlap.
    static let welcomeBundle = ShopItem(
        id: "com.dengolabs.grannyspuzzle.welcomebundle",
        kind: .nonConsumable,
        placement: .featured,
        analyticsName: "welcome_bundle",
        imageName: "shop-bundle-welcome",
        title: "Welcome bundle",
        badge: "Best value",
        removesAds: true,
        contents: \.welcomeBundle
    )

    static let removeAds = ShopItem(
        id: "com.dengolabs.grannyspuzzle.removeads",
        kind: .nonConsumable,
        placement: .featured,
        analyticsName: "remove_ads",
        imageName: "shop-no-ads",
        title: "Remove ads",
        removesAds: true
    )

    static let catHintsSmall = ShopItem(
        id: "com.dengolabs.grannyspuzzle.cathints.small",
        kind: .consumable,
        placement: .tile,
        analyticsName: "cat_hints_small",
        imageName: "shop-cat-small",
        contents: \.catHintsSmall
    )

    static let catHintsBig = ShopItem(
        id: "com.dengolabs.grannyspuzzle.cathints.big",
        kind: .consumable,
        placement: .tile,
        analyticsName: "cat_hints_big",
        imageName: "shop-cat-big",
        contents: \.catHintsBig
    )

    static let grandmasSmall = ShopItem(
        id: "com.dengolabs.grannyspuzzle.grandmas.small",
        kind: .consumable,
        placement: .tile,
        analyticsName: "grandmas_small",
        imageName: "shop-granny-small",
        contents: \.grandmasSmall
    )

    static let grandmasBig = ShopItem(
        id: "com.dengolabs.grannyspuzzle.grandmas.big",
        kind: .consumable,
        placement: .tile,
        analyticsName: "grandmas_big",
        imageName: "shop-granny-big",
        contents: \.grandmasBig
    )

    /// Everything the shop sells, in the order it shows them.
    static let all: [ShopItem] = [
        .welcomeBundle, .removeAds,
        .catHintsSmall, .catHintsBig, .grandmasSmall, .grandmasBig,
    ]
}
