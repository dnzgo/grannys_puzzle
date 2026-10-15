import SwiftUI

/// Credits for the word lists the puzzles are built from.
///
/// These aren't optional: the SCOWL and WordNet licences only allow use if
/// their notices travel with every copy, and LDNOOBW is CC BY 4.0, which
/// asks for attribution. The texts are copied from each source's own licence
/// file; if a source is updated, check its notice again
/// (ContentPipeline/README.md, "Credits the app must show").
///
/// Plain content, shown on a page of the settings card, which supplies the
/// title and the scrolling.
struct AcknowledgementsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Granny's Puzzle's words and clues were chosen with the help of these word lists. Thank you to their authors.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondaryInk)

            ForEach(Credit.all) { credit in
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: credit.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(verbatim: credit.notice)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            }
        }
    }
}

/// One source and its notice. Notices stay in English whatever the app's
/// language: they're legal text, and a translation wouldn't be the notice.
private struct Credit: Identifiable {
    let name: String
    let notice: String

    var id: String { name }

    static let all = [scowl, wordNet, badWords]

    // Where the playable words come from. The 12dicts common-words list the
    // pipeline also reads is Alan Beale's, credited in the last paragraph.
    private static let scowl = Credit(
        name: "SCOWL",
        notice: """
        Spell Checker Oriented Word Lists (SCOWL)
        Copyright 2000–2020 by Kevin Atkinson

        Permission to use, copy, modify, distribute and sell these word lists, the associated scripts, the output created from the scripts, and its documentation for any purpose is hereby granted without fee, provided that the above copyright notice appears in all copies and that both that copyright notice and this permission notice appear in supporting documentation. Kevin Atkinson makes no representations about the suitability of this array for any purpose. It is provided "as is" without express or implied warranty.

        SCOWL includes material from the 12dicts word lists by Alan Beale and from AGID.
        """
    )

    // The dictionary the word senses (and the first draft clues) came from.
    private static let wordNet = Credit(
        name: "WordNet 3.0",
        notice: """
        This software and database is being provided to you, the LICENSEE, by Princeton University under the following license. By obtaining, using and/or copying this software and database, you agree that you have read, understood, and will comply with these terms and conditions.:

        Permission to use, copy, modify and distribute this software and database and its documentation for any purpose and without fee or royalty is hereby granted, provided that you agree to comply with the following copyright notice and statements, including the disclaimer, and that the same appear on ALL copies of the software, database and documentation, including modifications that you make for internal use or for distribution.

        WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved.

        THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" AND PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED. BY WAY OF EXAMPLE, BUT NOT LIMITATION, PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES OF MERCHANT- ABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF THE LICENSED SOFTWARE, DATABASE OR DOCUMENTATION WILL NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.

        The name of Princeton University or Princeton may not be used in advertising or publicity pertaining to distribution of the software and/or database. Title to copyright in this software, database and any associated documentation shall at all times remain with Princeton University and LICENSEE agrees to preserve same.
        """
    )

    // Used only to keep words out of the puzzles; none of it ships in the app.
    private static let badWords = Credit(
        name: "LDNOOBW",
        notice: """
        List of Dirty, Naughty, Obscene, and Otherwise Bad Words, by Shutterstock, licensed under the Creative Commons Attribution 4.0 International licence (CC BY 4.0). Used only to keep unsuitable words out of the puzzles.
        """
    )
}

#Preview {
    ScrollView { AcknowledgementsView().padding() }
        .background(Theme.background)
}
