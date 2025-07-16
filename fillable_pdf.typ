
#set document(author: "John Doe")
#set page(paper: "a4")

// Create a simple form layout using built-in Typst functionality
= Fillable Form

#v(2cm)

// Name field
#block[
  Name: #box(width: 6cm, height: 1cm, stroke: 1pt + gray, inset: 5pt, fill: luma(250))[
    #text(size: 10pt, fill: gray)[Enter your name here]
  ]
]

#v(1cm)

// Email field
#block[
  Email: #box(width: 6cm, height: 1cm, stroke: 1pt + gray, inset: 5pt, fill: luma(250))[
    #text(size: 10pt, fill: gray)[Enter your email here]
  ]
]

#v(2cm)

// Signature field
#block[
  Signature: #box(width: 8cm, height: 3cm, stroke: 1pt + gray, inset: 5pt, fill: luma(250))[
    #text(size: 10pt, fill: gray)[Sign here]
  ]
]

#v(1cm)

// Date field
#block[
  Date: #box(width: 4cm, height: 1cm, stroke: 1pt + gray, inset: 5pt, fill: luma(250))[
    #text(size: 10pt, fill: gray)[MM/DD/YYYY]
  ]
]

#v(2cm)

// Checkbox example
#block[
  #box(width: 0.5cm, height: 0.5cm, stroke: 1pt + black) I agree to the terms and conditions
]

#v(1cm)

// Radio button example
#block[
  Preferred contact method:
  #v(0.5em)
  #circle(radius: 0.25cm, stroke: 1pt + black) Email
  #h(1cm)
  #circle(radius: 0.25cm, stroke: 1pt + black) Phone
  #h(1cm)
  #circle(radius: 0.25cm, stroke: 1pt + black) Mail
]
