import XCTest
@testable import ArrowwordCore

/// The family's wardrobes: knitted one member at a time, each a little
/// dearer, each sharing colours with the one before.
final class FamilyTests: XCTestCase {
    private let catalog = KnittingCatalog.standard

    private func player(owning members: [FamilyMember] = [], yarn: [YarnColor: Int] = [:]) -> PlayerProgress {
        let owned = members.flatMap { catalog.items(for: $0).map(\.id) }
        return PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: yarn, wardrobe: Set(owned))
    }

    func testTheFamilyIsKnittedForInOrder() {
        XCTAssertEqual(catalog.members, [.cat, .daughter, .son, .granddaughter, .grandson])
        XCTAssertTrue(catalog.members.allSatisfy { catalog.items(for: $0).count == 20 })
    }

    func testEachWardrobeCostsAQuarterMoreThanTheOneBefore() {
        // The totals the pacing note in KnittingCatalog quotes.
        let totals = catalog.members.map { catalog.items(for: $0).map(\.cost).reduce(0, +) }
        XCTAssertEqual(totals, [204, 260, 320, 400, 500])
        // And within each, the cheapest garment still comes first.
        for member in catalog.members {
            let costs = catalog.sets(for: member).compactMap { $0.first?.cost }
            XCTAssertEqual(costs, costs.sorted(), "\(member)")
        }
    }

    func testEachWardrobeKeepsTwoColoursFromTheOneBefore() {
        // So yarn left over from one wardrobe still counts in the next.
        for (previous, next) in zip(catalog.members, catalog.members.dropFirst()) {
            let shared = Set(catalog.colors(for: previous)).intersection(catalog.colors(for: next))
            XCTAssertEqual(shared.count, 2, "\(previous) → \(next)")
        }
    }

    func testANewPlayerKnitsForTheCatAndTheRestAreLocked() {
        let newPlayer = player()
        XCTAssertEqual(catalog.currentMember(for: newPlayer), .cat)
        XCTAssertEqual(catalog.status(of: .cat, for: newPlayer), .current)
        XCTAssertEqual(catalog.status(of: .daughter, for: newPlayer), .locked)
        XCTAssertEqual(catalog.status(of: .grandson, for: newPlayer), .locked)
    }

    func testFinishingAWardrobeOpensTheNext() {
        let progress = player(owning: [.cat])
        XCTAssertEqual(catalog.status(of: .cat, for: progress), .complete)
        XCTAssertEqual(catalog.currentMember(for: progress), .daughter)
        XCTAssertEqual(catalog.status(of: .son, for: progress), .locked)
    }

    func testOneMissingItemKeepsAWardrobeOpen() {
        var progress = player(owning: [.cat])
        progress.wardrobe.remove("cat.blanket.green")
        XCTAssertEqual(catalog.currentMember(for: progress), .cat)
        XCTAssertEqual(catalog.status(of: .daughter, for: progress), .locked)
    }

    func testEveryWardrobeDoneLeavesNoCurrentMember() {
        let progress = player(owning: catalog.members)
        XCTAssertNil(catalog.currentMember(for: progress))
        XCTAssertTrue(catalog.availableItems(for: progress).isEmpty)
        // Levels still give yarn: the last wardrobe's colours.
        XCTAssertEqual(catalog.yarnColors(for: progress), catalog.colors(for: .grandson))
    }

    func testALockedWardrobeCantBeKnittedEvenWithTheYarn() {
        // 20 pink balls would buy the daughter's pink beret (8), but the
        // cat's wardrobe isn't done yet.
        let early = player(yarn: [.pink: 20])
        XCTAssertTrue(catalog.knittableItems(for: early).isEmpty)
        XCTAssertNil(catalog.newlyKnittable(before: player(), after: early))

        let later = player(owning: [.cat], yarn: [.pink: 20])
        XCTAssertEqual(catalog.knittableItems(for: later).first?.id, "daughter.beret.pink")
    }

    func testYarnNeedsLookOnlyAtTheCurrentWardrobe() {
        // 7 pink is one short of the daughter's pink beret, but she's locked:
        // the ask is for the cat's scarf instead.
        let progress = player(yarn: [.pink: 7, .red: 1])
        XCTAssertEqual(progress.closestYarnNeed(in: catalog)?.item.member, .cat)
    }

    func testLevelsDropOnlyTheCurrentWardrobesColours() {
        var generator = SeededGenerator(seed: 3)
        var progress = player(owning: [.cat])
        var dropped: Set<YarnColor> = []
        for _ in 0..<60 {
            let result = LevelResult(correctLetters: 20, judgedLetters: 20, rules: .standard)
            dropped.formUnion(progress.record(result, using: &generator))
        }
        XCTAssertEqual(dropped, Set(catalog.colors(for: .daughter)))
    }

    func testTheLastItemOfAWardrobeIsNoticed() {
        var progress = player(owning: [.cat])
        progress.wardrobe.remove("cat.blanket.green")
        let blanket = catalog.item(withID: "cat.blanket.green")!
        XCTAssertFalse(catalog.isWardrobeComplete(for: blanket, in: progress))
        progress.wardrobe.insert(blanket.id)
        XCTAssertTrue(catalog.isWardrobeComplete(for: blanket, in: progress))
    }
}
