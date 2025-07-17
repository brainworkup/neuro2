#import "@preview/in-dexter:0.0.5": make-index, index

#set document(author: "John Doe")

// Simple fillable form using basic Typst elements
#set page(paper: "a4")
#set text(size: 12pt)

// Title
#align(center, text(size: 16pt, weight: "bold")[Fillable Form])

#v(2cm)

// Name field
#grid(
  columns: (1fr, 2fr),
  gutter: 1em,
  [Name:], 
  rect(width: 100%, height: 1.5em, stroke: 0.5pt, fill: rgb(250, 250, 250))[
    #text(fill: gray)[Click to enter name]
  ]
)

#v(1cm)

// Date field
#grid(
  columns: (1fr, 2fr),
  gutter: 1em,
  [Date:], 
  rect(width: 100%, height: 1.5em, stroke: 0.5pt, fill: rgb(250, 250, 250))[
    #text(fill: gray)[Click to enter date]
  ]
)

#v(1cm)

// Signature field
#grid(
  columns: (1fr, 2fr),
  gutter: 1em,
  [Signature:], 
  rect(width: 100%, height: 3em, stroke: 0.5pt, fill: rgb(250, 250, 250))[
    #text(fill: gray)[Click to sign]
  ]
)

#v(1cm)

// Electronic signature field
#grid(
  columns: (1fr, 2fr),
  gutter: 1em,
  [Electronic Signature:], 
  rect(width: 100%, height: 2em, stroke: 0.5pt, fill: rgb(250, 250, 250))[
    #text(fill: gray)[Click to enter electronic signature]
  ]
)
