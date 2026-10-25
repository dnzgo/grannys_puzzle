# Clue style guide

Everyone writing clues follows this, so clues from different people feel
like one game. The importer checks the mechanical rules (length, giving the
answer away); the rest is up to the writer.

## The rules

1. **20 characters or fewer**, spaces included. A clue cell fits about three
   short lines. Shorter is better.
2. **Plain, everyday words.** A definition, a synonym or a simple
   description: `Purring pet`, `Move quickly`, `Not off`. No cryptic
   wordplay, puns that need explaining, or trivia.
3. **Never contain the answer or a word from its family.** Not `Cat food`
   for CAT, not `Gardener's place` for GARDEN.
4. **Match the answer's form.** A plural answer gets a plural clue, a verb
   gets a verb clue: `Move quickly` (RUN), not `Fast mover`.
5. **Fill-in-the-blank is fine**: `Credit ___` (CARD). Use three
   underscores.
6. **Family friendly: the grandma test.** Would grandma be happy to read it
   out at the kitchen table? No violence, crude humour, politics, religion,
   brands, or names of real living people.
7. **American spelling**, sentence case (`Purring pet`, not `Purring Pet`),
   no full stop.
8. **Three different angles per word** where possible: a definition, an
   example, a fill-in-the-blank. Three versions of the same idea don't help.
9. **Always original.** Never copy clues from published crosswords, puzzle
   apps or clue websites; they're someone else's copyrighted writing.

10. **Abbreviations are welcome, and the clue says so.** Short answers
    are where words repeat most (there are only a few dozen real two-letter
    words), so abbreviations widen the choice a lot: units (KG, CM),
    chemical symbols (FE, AU), countries (TR, UK), organisations (UN, EU),
    music notes (RE, MI). The clue must signal it, so nobody hunts for a
    word: `Kilogram, briefly`, `Iron's symbol`, `Turkey's code`. In
    Turkish: `Kilogramın kısası`, `Demirin simgesi`. Mark them
    `abbreviation` in the part_of_speech column.
    **No brands** (VW, BMW, THY): it's free advertising, it dates quickly,
    and some companies object to their names in games.

Good: `Purring pet` · `Mouser` · `Kitty` (CAT)
Too long: `A small furry animal that purrs` (32)
Gives it away: `Catnap taker`
Too clever: `It has nine lives, allegedly`

## Prompt for Claude

Paste this, then the batch file:

> Write crossword clues for each word in this CSV. Fill in clue_1, clue_2 and
> clue_3 and return the complete CSV, unchanged except for those columns.
>
> Rules: at most 20 characters including spaces. Plain everyday English, like
> a newspaper arrowword for a general audience. Never use the answer or any
> word from its family. Match the answer's part of speech and number. Use a
> different angle for each clue (definition, example, fill-in-the-blank with
> "___"). Family friendly: no violence, crude humour, politics, religion,
> brands or real people. American spelling, sentence case, no full stop.
> All clues must be original. The `definition` column shows the intended
> meaning; leave the clue blank rather than guess if a word is unclear, and
> say why in `notes`.

Then read the result yourself before importing: Claude's draft is a starting
point, and you're the editor.
