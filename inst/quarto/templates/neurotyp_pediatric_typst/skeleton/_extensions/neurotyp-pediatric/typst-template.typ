#let report(
  title: "NEUROCOGNITIVE EXAMINATION",
  author: "Joey W. Trampush, Ph.D.",
  name: [],
  doe: [],
  patient: [],
  date: none,
  cols: 1,
  paper: "a4",
  margin: (x: 25mm, y: 30mm),
  lang: "en",
  region: "US",
  font: (),
  body-font: ("Libertinus Serif"),
  sans-font: ("Libertinus Sans"),
  fontsize: 11pt,
  sectionnumbering: none,
  doc,
) = {
  // Metadata
  set document(title: title, author: author)

  // Set page size, margins, and header.
  set page(paper: paper, margin: margin, header: locate(loc => if [#loc.page()] == [1] {
    []
  } else {
    [
      #set par(leading: 0.65em)
      #set text(9pt)
      #smallcaps[
        *CONFIDENTIAL* \
        #name \
        #doe
      ]
    ]
  }), numbering: "1/1", number-align: center, columns: cols)

  // align headers
  show heading.where(level: 0): set align(center)
  show heading.where(level: 1): set align(left)

  // Set paragraph justification and leading.
  set par(justify: true, leading: 1em, linebreaks: "optimized")

  // Set text and body font family.
  set text(font: body-font, size: fontsize, lang: lang, region: region)
  show math.equation: set text(weight: 400)

  // Set heading numbering.
  set heading(numbering: sectionnumbering)

  // Set paragraph spacing.
  show par: set block(above: 1.75em, below: 1.75em)

  // Set heading font.
  show heading: set text(font: sans-font, weight: "semibold")

  // Set run-in subheadings, starting at level 4.
  show heading: it => {
    if it.level > 3 {
      parbreak()
      text(1em, style: "italic", weight: "regular", it.body + ":")
    } else {
      it
    }
  }

  // Configure lists and links.
  show enum: set block(above: 1em, below: 1em)
  // show enum: set par(leading: 0.85em)
  set enum(indent: 0em, body-indent: 0.25em, tight: false)

  show list: set block(above: 1em, below: 1em)
  // show list: set par(leading: 0.85em)
  set list(indent: 0em, body-indent: 0.25em, marker: ([•], [--]), tight: false)

  show link: set text(font: body-font, fill: rgb(4, 1, 23), weight: 450)
  show link: underline

  // Logo
  block(figure(image("src/img/logo.png")))
  // block(figure(image("src/img/bwu_logo.png")))

  // Title row.
  align(center)[
    #block(text(font: sans-font, weight: 600, 1.75em, title))
    #v(0em, weak: true)
  ]

  if date != none {
    align(center)[#block(inset: 1em)[
        #date
      ]]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}
