import SwiftUI
import ArrowwordCore

extension FamilyMember {
    /// The Polaroid's caption.
    var name: LocalizedStringKey {
        switch self {
        case .cat: "Cat"
        case .daughter: "Daughter"
        case .son: "Son"
        case .granddaughter: "Granddaughter"
        case .grandson: "Grandson"
        }
    }

    /// The wardrobe card's title. Whole sentences per member rather than
    /// one "\(name)'s wardrobe" pattern: Turkish builds the possessive into
    /// the word (Kedinin, Kızının), which a pattern can't do.
    var wardrobeTitle: LocalizedStringKey {
        switch self {
        case .cat: "The cat's wardrobe"
        case .daughter: "Daughter's wardrobe"
        case .son: "Son's wardrobe"
        case .granddaughter: "Granddaughter's wardrobe"
        case .grandson: "Grandson's wardrobe"
        }
    }

    /// The portrait in the asset catalog, e.g. "family-son".
    var photoName: String { "family-\(rawValue)" }

    /// Each Polaroid sits a little crooked, the way photos stuck up by hand
    /// do; fixed per member so the row doesn't change between visits.
    var tilt: Angle {
        switch self {
        case .cat: .degrees(-4)
        case .daughter: .degrees(3)
        case .son: .degrees(-2)
        case .granddaughter: .degrees(4)
        case .grandson: .degrees(-3)
        }
    }
}

/// A family member's photo as a Polaroid: in colour once their wardrobe is
/// complete, black and white while it's being knitted, and an empty photo
/// with a question mark while it's locked.
///
/// The frame, tilt and caption are drawn here rather than in the art, so
/// every photo matches, the caption follows the game's language, and a
/// locked member needs no picture at all.
struct FamilyPolaroid: View {
    let member: FamilyMember
    let status: WardrobeStatus
    let width: CGFloat
    /// From 0 (black and white) to 1 (full colour), to override what the
    /// status says: the moment a wardrobe is finished animates it.
    var colour: Double?

    private var shownColour: Double { colour ?? (status == .complete ? 1 : 0) }

    var body: some View {
        VStack(spacing: width * 0.04) {
            photo
                .frame(width: width * 0.86, height: width * 0.86)
                .clipShape(Rectangle())
            Text(member.name)
                .font(.system(size: max(9, width * 0.13), weight: .semibold, design: .rounded))
                .italic()
                .foregroundStyle(Theme.ink.opacity(status == .locked ? 0.45 : 0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width * 0.9)
        }
        // The Polaroid's frame: even on three sides, deeper at the bottom
        // where the caption is written.
        .padding(.top, width * 0.07)
        .padding(.bottom, width * 0.08)
        .frame(width: width)
        .background(Color.white)
        .shadow(color: .black.opacity(0.18), radius: width * 0.05, y: width * 0.03)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(member.name))
        .accessibilityValue(accessibilityStatus)
    }

    @ViewBuilder
    private var photo: some View {
        if status == .locked {
            ZStack {
                Theme.disabledFill
                Text("?")
                    .font(.system(size: width * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.secondaryInk.opacity(0.6))
            }
        } else {
            Image(member.photoName)
                .resizable()
                .scaledToFill()
                // grayscale(1) is black and white; 0 leaves the colour.
                .grayscale(1 - shownColour)
        }
    }

    private var accessibilityStatus: Text {
        switch status {
        case .complete: Text("Wardrobe complete")
        case .current: Text("Knitting now")
        case .locked: Text("Not open yet")
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        FamilyPolaroid(member: .cat, status: .complete, width: 90).rotationEffect(FamilyMember.cat.tilt)
        FamilyPolaroid(member: .daughter, status: .current, width: 90).rotationEffect(FamilyMember.daughter.tilt)
        FamilyPolaroid(member: .son, status: .locked, width: 90).rotationEffect(FamilyMember.son.tilt)
    }
    .padding(30)
    .background(Theme.background)
}
