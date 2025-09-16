#let report(
  title: "NEUROCOGNITIVE EXAMINATION",
  author: "Joey W. Trampush, Ph.D.",
  name: [],
  doe: [],
  patient: [],
  date: none,
  cols: 1,
  margin: auto,
  // margin: (x: 1.25in, y: 1.25in),
  lang: "en",
  region: "US",
  // paper: "us-letter",
  font: "libertinus serif",
  fontsize: 11pt,
  title-size: 1.5em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  toc: false,
  doc,
) = {
  // Metadata
  set document(title: title, author: author)

  // Set page size, margins, and header.
  // Set up page properties
  set page(
    // paper: paper,
    margin: margin,
    header: none,
    numbering: "1/1",
    number-align: center,
    columns: cols,
  )

  // Add conditional header using page state
  set page(header: context {
    if counter(page).get().first() > 1 {
      // Only add header on pages after the first
      block[
        #set par(leading: 0.65em)
        #set text(9pt)
        #smallcaps[
          *CONFIDENTIAL* \
          #name \
          #doe
        ]
      ]
    }
  })

  // align headers
  show heading.where(level: 0): set align(center)
  show heading.where(level: 1): set align(left)

  // Set paragraph justification and leading.
  set par(justify: true)

  // Set text and body font family.
  set text(font: font, size: fontsize, lang: lang, region: region)
  show math.equation: set text(weight: 400)

  // Set heading numbering.
  set heading(numbering: sectionnumbering)

  // Set heading font.
  show heading: set text(font: heading-family)

  // Set run-in subheadings, starting at level 4.
  show heading: it => {
    if it.level > 3 {
      parbreak()
      text(1em, style: "italic", weight: "regular", it.body + ":")
    } else {
      it
    }
  }

  show link: set text(font: font, fill: rgb(4, 1, 23), weight: 450)
  show link: underline

  // Logo
  block(figure(image("inst/resources/logo.png")))
  // block(figure(image("inst/resources/bwu_logo.png")))

  // Title row.
  align(center)[
    #block(text(font: font, weight: 600, 1.75em, title))
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

#set table(
  inset: 6pt,
  stroke: none,
)
