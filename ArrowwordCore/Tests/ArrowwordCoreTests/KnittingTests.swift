import Foundation
import XCTest
@testable import ArrowwordCore

final class KnittingCatalogTests: XCTestCase {
    private let catalog = KnittingCatalog.standard

    func testTheCatHasFiveGarmentsInFourColours() {
        let catItems = catalog.items(for: .cat)
        XCTAssertEqual(catItems.count, 20)
        XCTAssertEqual(Set(catItems.map(\.kind)), Set(GarmentKind.allCases))
        XCTAssertEqual(Set(catItems.map(\.color)), Set(YarnColor.allCases))
    }

    func testItemIDsAreUnique() {
        // The wardrobe saves ids; a duplicate would make two items share one.
        let ids = catalog.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPricesRiseFromScarfToBlanket() {
        let price = { (kind: GarmentKind) in
            self.catalog.items.first { $0.kind == kind }?.cost
        }
        XCTAssertEqual(price(.scarf), 6)
        XCTAssertEqual(price(.hat), 8)
        XCTAssertEqual(price(.sweater), 10)
        XCTAssertEqual(price(.mittens), 12)
        XCTAssertEqual(price(.blanket), 15)
        // The pacing note in KnittingCatalog quotes this total.
        XCTAssertEqual(catalog.items(for: .cat).map(\.cost).reduce(0, +), 204)
    }

    func testIDsAreReadableAndFindable() {
        let scarf = KnitItem(member: .cat, kind: .scarf, color: .red, cost: 6)
        XCTAssertEqual(scarf.id, "cat.scarf.red")
        XCTAssertEqual(catalog.item(withID: "cat.scarf.red"), scarf)
    }
}

final class KnittingProgressTests: XCTestCase {
    private let redScarf = KnitItem(member: .cat, kind: .scarf, color: .red, cost: 6)

    func testKnittingSpendsOnlyThatColourAndAddsTheItem() {
        var progress = PlayerProgress(levelNumber: 9, hints: 0, grandmas: 0, yarn: [.red: 7, .blue: 3])

        XCTAssertEqual(progress.knit(redScarf), .knitted)

        XCTAssertEqual(progress.yarnCount(of: .red), 1)
        XCTAssertEqual(progress.yarnCount(of: .blue), 3, "other colours are untouched")
        XCTAssertTrue(progress.owns(redScarf))
    }

    func testCannotKnitWithoutEnoughYarn() {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [.red: 4])
        XCTAssertFalse(progress.canKnit(redScarf))
        XCTAssertEqual(progress.knit(redScarf), .notEnoughYarn(missing: 2))
        XCTAssertEqual(progress.yarnCount(of: .red), 4, "nothing is spent on a failed knit")
    }

    func testEachItemIsKnittedOnlyOnce() {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [.red: 20])
        XCTAssertEqual(progress.knit(redScarf), .knitted)
        XCTAssertEqual(progress.knit(redScarf), .alreadyOwned)
        XCTAssertEqual(progress.yarnCount(of: .red), 14, "the second attempt costs nothing")
    }

    func testTheWardrobeSurvivesSavingAndLoading() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ProgressStore(fileURL: folder.appendingPathComponent("progress.json"))

        var progress = PlayerProgress(levelNumber: 3, hints: 1, grandmas: 1, yarn: [.red: 6])
        _ = progress.knit(redScarf)
        try store.save(progress)

        XCTAssertEqual(try store.load(), progress)
    }

    func testASaveFromBeforeKnittingStillLoads() throws {
        // Exactly what yesterday's app wrote: no "wardrobe" key at all.
        let oldSave = #"{"grandmas": 1, "hints": 3, "levelNumber": 8, "version": 1, "yarn": {"red": 5}}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8))
        XCTAssertEqual(progress.levelNumber, 8)
        XCTAssertEqual(progress.yarnCount(of: .red), 5)
        XCTAssertEqual(progress.wardrobe, [])
    }
}

final class YarnNeedTests: XCTestCase {
    private let catalog = KnittingCatalog.standard

    func testAskForTheColourClosestToAnItem() {
        // 5 yellow is one short of a yellow scarf (6); red needs all 6.
        let progress = PlayerProgress(levelNumber: 9, hints: 0, grandmas: 0, yarn: [.yellow: 5, .red: 1])
        let need = progress.closestYarnNeed(in: catalog)
        XCTAssertEqual(need?.color, .yellow)
        XCTAssertEqual(need?.missing, 1)
        XCTAssertEqual(need?.item.kind, .scarf)
    }

    func testNothingToAskForWhenSomethingCanAlreadyBeKnitted() {
        let progress = PlayerProgress(levelNumber: 9, hints: 0, grandmas: 0, yarn: [.blue: 6])
        XCTAssertNil(progress.closestYarnNeed(in: catalog))
    }

    func testOwnedItemsAreSkipped() {
        // The red scarf is done, so 7 red is now one short of the red hat (8).
        let progress = PlayerProgress(
            levelNumber: 9, hints: 0, grandmas: 0, yarn: [.red: 7],
            wardrobe: Set(YarnColor.allCases.map { "cat.scarf.\($0.rawValue)" })
        )
        XCTAssertEqual(progress.closestYarnNeed(in: catalog)?.item.id, "cat.hat.red")
    }

    func testAFinishedWardrobeNeedsNothing() {
        let progress = PlayerProgress(
            levelNumber: 9, hints: 0, grandmas: 0, yarn: [:],
            wardrobe: Set(catalog.items.map(\.id))
        )
        XCTAssertNil(progress.closestYarnNeed(in: catalog))
    }
}

final class CollectionTests: XCTestCase {
    private let catalog = KnittingCatalog.standard

    private func progress(yarn: [YarnColor: Int], owned: Set<String> = []) -> PlayerProgress {
        PlayerProgress(levelNumber: 9, hints: 0, grandmas: 0, yarn: yarn, wardrobe: owned)
    }

    func testALevelThatTipsAColourOverAPriceMakesThatItemNew() {
        // 5 red is one short of a red scarf (6); the level brings the sixth.
        let before = progress(yarn: [.red: 5])
        let after = progress(yarn: [.red: 6])
        XCTAssertEqual(catalog.newlyKnittable(before: before, after: after)?.id, "cat.scarf.red")
    }

    func testSomethingAlreadyAffordableIsNotNewAgain() {
        // The red scarf was affordable before this level too: grandma has
        // already mentioned it, so she doesn't repeat herself.
        let before = progress(yarn: [.red: 6])
        let after = progress(yarn: [.red: 7])
        XCTAssertNil(catalog.newlyKnittable(before: before, after: after))
    }

    func testTheCheapestNewItemIsTheOneMentioned() {
        // 8 red makes the red hat newly affordable, and the red scarf too:
        // the scarf comes first.
        let before = progress(yarn: [.red: 5])
        let after = progress(yarn: [.red: 8])
        XCTAssertEqual(catalog.newlyKnittable(before: before, after: after)?.id, "cat.scarf.red")
    }

    func testOwnedItemsAreNeverNew() {
        let owned: Set<String> = ["cat.scarf.red"]
        let before = progress(yarn: [.red: 5], owned: owned)
        let after = progress(yarn: [.red: 6], owned: owned)
        XCTAssertNil(catalog.newlyKnittable(before: before, after: after), "the red hat needs 8")
    }

    func testASetIsOneGarmentInEveryColour() {
        let scarf = catalog.item(withID: "cat.scarf.red")!
        XCTAssertEqual(Set(catalog.itemsInSet(of: scarf).map(\.color)), Set(YarnColor.allCases))
        XCTAssertTrue(catalog.itemsInSet(of: scarf).allSatisfy { $0.kind == .scarf })
    }

    func testTheSetIsCompleteOnlyWithEveryColour() {
        let blueScarf = catalog.item(withID: "cat.scarf.blue")!
        let three: Set<String> = ["cat.scarf.red", "cat.scarf.yellow", "cat.scarf.green"]
        XCTAssertFalse(catalog.isSetComplete(for: blueScarf, in: progress(yarn: [:], owned: three)))
        XCTAssertTrue(catalog.isSetComplete(for: blueScarf, in: progress(yarn: [:], owned: three.union(["cat.scarf.blue"]))))
    }

    func testReceivingAPrizeAddsBothHelpers() {
        var player = progress(yarn: [:])
        player.receive(JarReward(hints: 3, grandmas: 1))
        XCTAssertEqual(player.hints, 3)
        XCTAssertEqual(player.grandmas, 1)
    }
}
