// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

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
  body-font: "Libertinus Serif",
  sans-font: "Libertinus Sans",
  fontsize: 11pt,
  sectionnumbering: none,
  doc,
) = {
  // Metadata
  set document(title: title, author: author)

  // Set page size, margins, and header.
  // Set up page properties
  set page(
    paper: paper,
    margin: margin,
    header: none, // Start with no header
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
  set par(justify: true, leading: 1em, linebreaks: "optimized")

  // Set text and body font family.
  set text(font: body-font, size: fontsize, lang: lang, region: region)
  show math.equation: set text(weight: 400)

  // Set heading numbering.
  set heading(numbering: sectionnumbering)

  // Set paragraph spacing.
  set par(spacing: 1.75em)

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
  block(figure(image("inst/resources/img/logo.png")))
  // block(figure(image("inst/resources/img/bwu_logo.png")))

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

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: report.with(
  title: "NEUROCOGNITIVE EXAMINATION",
  paper: "us-letter",
  body-font: ("IBM Plex Serif"),
  sans-font: ("IBM Plex Sans"),
  fontsize: 12pt,
)

= Background Information
<background-information>
This comprehensive neuropsychological assessment was conducted to evaluate cognitive and behavioral functioning across multiple domains.

= Test Results
<test-results>
== General Cognitive Ability
<sec-iq>
Verbal Comprehension (i.e., the ability to verbalize meaningful concepts, think about verbal information, and express oneself using words) fell within the High Average and ranked at the 88th percentile. This indicates performance as good as or better than 88% of same-age peers from the general population.

A subset of intellectual functioning with reduced influences of working memory and processing speed fell within the Average and ranked at the 61th percentile. This indicates performance as good as or better than 61% of same-age peers from the general population.

Ethan's score on RBANS Total Index (composite indicator of general cognitive functioning) was Average. Fluid Reasoning (i.e., the ability to use reasoning to identify and apply solutions to problems) fell within the Average and ranked at the 42th percentile. This indicates performance as good as or better than 42% of same-age peers from the general population.

General intellectual ability fell within the Average and ranked at the 39th percentile. This indicates performance as good as or better than 39% of same-age peers from the general population.

The patient's ability to evaluate visual details understand spatial relations among objects and construct geometric design using models fell within the Low Average and ranked at the 23th percentile. This indicates performance as good as or better than 23% of same-age peers from the general population.

Working memory (i.e., the ability to consciously register maintain and manipulate auditory and visual information) fell within the Low Average and ranked at the 21th percentile. This indicates performance as good as or better than 21% of same-age peers from the general population.

General intellectual functioning that minimizes expressive language demands fell within the Low Average and ranked at the 19th percentile. This indicates performance as good as or better than 19% of same-age peers from the general population.

Index of cognitive processing proficiency that reduces crystallized knowledge verbal reasoning and fluid reasoning demands fell within the Below Average and ranked at the 8th percentile. This indicates performance as good as or better than 8% of same-age peers from the general population.

Ability to quickly use reasoning to identify and apply solutions to problems fell within the Below Average and ranked at the 6th percentile. This indicates performance as good as or better than 6% of same-age peers from the general population.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Premorbid Ability is an estimate of an individual's
intellectual functioning prior to known or suspected onset of brain disease or
dysfunction\. General Ability is the overall skill to reason\, solve problems\,
and gain useful knowledge\. Crystallized Knowledge involves understanding the
world through language and reasoning\. Fluid Reasoning is the logical analysis
and solution of new problems\, identifying underlying patterns\, and applying
logic\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "General Cognitive Ability"

// Define the file name of the table
#let file_qtbl = "table_iq.png"

// Define the file name of the figure
#let file_fig = "fig_iq_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "General Cognitive Ability"

// Define the file name of the table
#let file_qtbl = "table_iq.png"

// Define the file name of the figure
#let file_fig = "fig_iq_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Academic Skills
<sec-academics>
Spontaneous writing fluency at the discourse level fell within the Average and ranked at the 42th percentile, indicating performance as good as or better than 42% of same-age peers from the general population. Written spelling of words from dictations fell within the Low Average and ranked at the 14th percentile, indicating performance as good as or better than 14% of same-age peers from the general population. Single word reading/decoding of a list of regular and irregular words fell within the Low Average and ranked at the 12th percentile, indicating performance as good as or better than 12% of same-age peers from the general population. Paper-and-pencil math calculation skills, ranging from basic operations with integers to geometry, algebra, and calculus problems fell within the Low Average and ranked at the 12th percentile, indicating performance as good as or better than 12% of same-age peers from the general population.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Reading\, writing\, and math are the three main academic skills assessed on exam\. Reading ability consists of three interrelated abilities: decoding\, comprehension\, and fluency\. Writing ability can be described in terms of spelling\, grammar\, expression of ideas\, and writing fluency\. Math ability can be described in terms of calculation skills\, applied problem solving\, and math fluency\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "Academic Skills"

// Define the file name of the table
#let file_qtbl = "table_academics.png"

// Define the file name of the figure
#let file_fig = "fig_academics_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "Academic Skills"

// Define the file name of the table
#let file_qtbl = "table_academics.png"

// Define the file name of the figure
#let file_fig = "fig_academics_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Verbal/Language
<sec-verbal>
Verbal concept formation and abstract reasoning fell within the Above Average and ranked at the 91th percentile. This indicates performance as good as or better than 91% of same-age peers from the general population.

Ethan's score on Semantic Fluency (semantic word fluency/generativity) was High Average. Verbal concept formation and word knowledge fell within the High Average and ranked at the 84th percentile. This indicates performance as good as or better than 84% of same-age peers from the general population.

Ethan's score on Language Index (general language processing) was Average. Ethan's score on Picture Naming (confrontation naming/expressive vocabulary) was Average. Practical knowledge and judgment of general principles and social situations fell within the Average and ranked at the 25th percentile. This indicates performance as good as or better than 25% of same-age peers from the general population.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Verbal and language functioning refers to the ability to
access and apply acquired word knowledge\, to verbalize meaningful concepts\, to
understand complex multistep instructions\, to think about verbal information\,
and to express oneself using words\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "Verbal/Language"

// Define the file name of the table
#let file_qtbl = "table_verbal.png"

// Define the file name of the figure
#let file_fig = "fig_verbal_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "Verbal/Language"

// Define the file name of the table
#let file_qtbl = "table_verbal.png"

// Define the file name of the figure
#let file_fig = "fig_verbal_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Visual Perception/Construction
<sec-spatial>
General sequential (deductive) reasoning and quantitative reasoning fell within the Average and ranked at the 50th percentile. This indicates performance as good as or better than 50% of same-age peers from the general population.

Fluid and inductive reasoning and conceptual thinking fell within the Average and ranked at the 50th percentile. This indicates performance as good as or better than 50% of same-age peers from the general population.

A measure of visual-perceptual reasoning and mental transformation abilities that requires examinees to solve visual puzzles within a time limit fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Inductive reasoning and nonverbal problem-solving fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Understanding visual-spatial relationships to construct unfamiliar geometric designs from a model fell within the Low Average and ranked at the 16th percentile. This indicates performance as good as or better than 16% of same-age peers from the general population.

Understanding visual-spatial relationships to construct unfamiliar geometric designs from a model (untimed) fell within the Low Average and ranked at the 16th percentile. This indicates performance as good as or better than 16% of same-age peers from the general population.

Ethan's score on Figure Copy (copy of a complex abstract figure) was Low Average. Ethan's score on Line Orientation (basic perception of visual stimuli) was Low Average. Ethan's score on Visuospatial/Constructional Index (broad visuospatial processing) was Below Average.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Perception\, construction\, and visuospatial processing
refer to abilities such as mentally visualizing how objects should look from
different angles\, visualizing how to put objects together so that they fit
correctly\, and being able to accurately and efficiently copy and/or reproduce
visual\-spatial information onto paper\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "Visual Perception/Construction"

// Define the file name of the table
#let file_qtbl = "table_spatial.png"

// Define the file name of the figure
#let file_fig = "fig_spatial_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "Visual Perception/Construction"

// Define the file name of the table
#let file_qtbl = "table_spatial.png"

// Define the file name of the figure
#let file_fig = "fig_spatial_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Memory
<sec-memory>
Ethan's score on Story Memory (expository story learning) was Above Average. Ethan's score on Story Recall (long-term recall of a detailed story) was Above Average. Ethan's score on List Recognition (delayed recognition of a word list) was Average. Ethan's score on List Recall (long-term recall of a word list) was Average.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Learning and memory refer to the rate and ease with which new information \(e\.g\.\, facts\, stories\, lists\, faces\, names\) can be encoded\, stored\, and later recalled from long\-term memory\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "Memory"

// Define the file name of the table
#let file_qtbl = "table_memory.png"

// Define the file name of the figure
#let file_fig = "fig_memory_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "Memory"

// Define the file name of the table
#let file_qtbl = "table_memory.png"

// Define the file name of the figure
#let file_fig = "fig_memory_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Attention/Executive
<sec-executive>
Ethan's score on Coding (speed of information processing) was High Average. Ethan's score on Attention Index (general attentional and executive functioning) was High Average. Ethan's score on Digit Span (attention span and auditory attention) was Average. Maintenance and resequencing of progressively lengthier sets of pictures in spatial working memory fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Selective attention and attentional fluency on a cancellation task fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Auditory attentional capacity, or how much information can be processed at once fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

A measure of both attentional capacity and working memory fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Rate of test taking, perceptual speed, visual discrimination, and visual attention scanning (random) fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Rate of test taking, perceptual speed, visual discrimination, and visual attention scanning (structured) fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Registering, maintaining, and manipulating auditory information fell within the Low Average and ranked at the 16th percentile. This indicates performance as good as or better than 16% of same-age peers from the general population.

Efficiency of psychomotor speed, visual scanning ability, and visual-motor coordination fell within the Low Average and ranked at the 9th percentile. This indicates performance as good as or better than 9% of same-age peers from the general population.

Visual-perceptual decision-making speed fell within the Low Average and ranked at the 9th percentile. This indicates performance as good as or better than 9% of same-age peers from the general population.

Performance on a measures that requires cognitive flexibility, divided attention, visual search, and the ability to shift cognitive sets between number and letter sequences fell within the Below Average range. Maintenance and resequencing of progressively lengthier number strings in working memory fell within the Below Average and ranked at the 2nd percentile. This indicates performance as good as or better than 2% of same-age peers from the general population.

Visual search speed, scanning, speed of processing, and motor speed and coordination on Part A of the Trail Making Test fell within the Exceptionally Low range.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Attentional and executive functions underlie most\, if
not all\, domains of cognitive performance\. These are behaviors and skills that
allow individuals to successfully carry\-out instrumental and social activities\,
academic work\, engage with others effectively\, problem solve\, and successfully
interact with the environment to get needs met\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "Attention/Executive"

// Define the file name of the table
#let file_qtbl = "table_executive.png"

// Define the file name of the figure
#let file_fig = "fig_executive_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "Attention/Executive"

// Define the file name of the table
#let file_qtbl = "table_executive.png"

// Define the file name of the figure
#let file_fig = "fig_executive_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Motor
<sec-motor>
Nondominant hand dexterity was Exceptionally Low range. Fine-motor dexterity (dominant hand) fell within the Exceptionally Low range.

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)

  // Make all figure labels (Table X:, Figure X:) bold
  show figure.caption: it => {
    context {
      let supplement = it.supplement
      let counter = it.counter.display(it.numbering)
      block[*#supplement #counter:* #it.body]
    }
  }

  pad(top: 0.5em)[]
  grid(
    columns: (50%, 50%),
    gutter: 8pt,
    figure(
      [#image(file_qtbl)],
      caption: figure.caption(position: top, [#title]),
      kind: "qtbl",
      supplement: [*Table*],
    ),
    figure(
      [#image(file_fig, width: auto)],
      caption: figure.caption(
        position: bottom,
        [Sensorimotor tasks refer to the capacity to control hand
movements quickly\, smoothly\, and with adequate precision\, which are required to
engage in activities such as writing and drawing\.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
// Define the title of the domain
#let title = "Motor"

// Define the file name of the table
#let file_qtbl = "table_motor.png"

// Define the file name of the figure
#let file_fig = "fig_motor_subdomain.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
// Define the title of the domain
#let title = "Motor"

// Define the file name of the table
#let file_qtbl = "table_motor.png"

// Define the file name of the figure
#let file_fig = "fig_motor_narrow.svg"

// The title is appended with ' Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
= Summary and Recommendations
<summary-and-recommendations>
Based on the comprehensive assessment results, the following patterns emerged…

== Clinical Impressions
<clinical-impressions>
- Summary of key findings
- Areas of strength and concern
- Diagnostic considerations

== Recommendations
<recommendations>
+ Educational accommodations
+ Therapeutic interventions
+ Follow-up assessments
