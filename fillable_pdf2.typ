#import "@preview/filler:0.3.1": *

#set document(author: "John Doe")

// Define content type for PDF export.
#show: content-type.with(content-type-pdf)

// Signature field with default style.
#show-field(
(x: 2cm, y: 8cm),
width: auto,
height: auto,
"Signature",
style: (
inset: .1em,
radius: 4pt,
fill: luma(250), // Set the background color
stroke: none, // No border for the signature field itself
),
)

// Electronic signature field with default style.
#show-field(
(x: 8cm, y: 13cm),
width: auto,
height: auto,
"Electronic Signature",
style: (
inset: .2em,
radius: 4pt,
fill: luma(250), // Set the background color
stroke: none, // No border for the signature field itself
),
)

// Define template for fields.
#show: template.with("fields", "content-type" => content-type-pdf)

// Render form with defined fields.
#render-form(
"fields",
)
