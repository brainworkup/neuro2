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
  patient: [Smalls, Ethan],
  name: [Ethan],
  doe: [],
  date_of_report: [],
  date: none,
  cols: 1,
  paper: "a4",
  margin: (top: 30mm, right: 25mm, bottom: 30.25mm, left: 25mm),
  lang: "en",
  region: "US",
  font: (),
  body-font: "Libertinus Serif",
  sans-font: "Libertinus Sans",
  fontsize: 11pt,
  sectionnumbering: none,
  doc,
) = {
  // // Metadata
  set document(title: title, author: author)

  let name = []
  let doe = []
  set page(
    header: context {
      let pageNum = counter(page).get().at(0)
      if pageNum == 1 {
        []
      } else {
        set par(leading: 0.65em)
        set text(9pt)
        smallcaps[
          *CONFIDENTIAL* \
          #name \
          #doe
        ]
      }
    },
    numbering: "1",
    number-align: center,
  )

  block(figure(image("logo.png")))
  // #block(figure(image("src/img/logo_looka.png", width: 45%)))

  align(center, text(1.75em, weight: 600)[
    *NEUROCOGNITIVE EXAMINATION*
  ])

  // align headers
  show heading.where(level: 1): set align(center)
  show heading.where(level: 2): set align(left)
  // Set run-in subheadings, starting at level 4.
  show heading: it => {
    if it.level > 3 {
      parbreak()
      text(1em, style: "italic", weight: "regular", it.body + ":")
    } else {
      it
    }
  }
  set par(justify: true)

  // Set heading numbering.
  set heading(numbering: sectionnumbering)

  // Set heading font.
  // show heading: set text(font: sans-font, weight: "semibold")

  // Set list
  // set list(tight: true, body-indent: 0.25em)

  // Links
  show link: set text(font: body-font, fill: rgb(154, 37, 60), weight: 450)
  show link: underline

  // Title row.
  // align(center)[
  //   #block(text(font: sans-font, weight: 600, 1.75em, title))
  //   #v(1em, weak: true)
  // ]

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

#show: report.with(
  title: "NEUROCOGNITIVE EXAMINATION",
  name: [Smalls, Biggie],
  patient: [Biggie],
  paper: "us-letter",
  body-font: ("IBM Plex Serif"),
  sans-font: ("IBM Plex Sans"),
  fontsize: 11pt,
)

#let name = [Smalls, Biggie]
#let doe = [2025-07-16]
#let patient = [Biggie]
// #v(2em, weak: true)
// #show block: set par(leading: 0.65em)
#block[
*PATIENT NAME:* #name \
*DATE OF BIRTH:* 1981-06-27, Age 44 \
*DATES OF EXAM:* 2025-05-28, 2025-05-31, and 2025-06-03 \
*DATE OF REPORT*: 2025-07-16 \
]
= TESTS ADMINISTERED
<tests-administered>
#block[
#block[
```
• WAIS-5
• NAB-S
• CVLT-3 Brief
• Color-Word Interference
• Rey Complex Figure
• WIAT-4
• Test of Premorbid Functioning
• NIH EXAMINER
• CAARS-2 Self
• CAARS-2 Observer
• CEFI Self
• CEFI Observer
• PAI
```

]
]
= NEUROBEHAVIORAL STATUS EXAM
<neurobehavioral-status-exam>
== Reason for Referral
<reason-for-referral>
Mr. Smalls, a 44-year-old right-handed male, was referred for comprehensive neuropsychological evaluation in the context of \[forensic proceedings\]. The evaluation was requested to assess cognitive functioning and determine any neurocognitive factors relevant to the current legal matter.

== Background Information
<background-information>
\[To be completed based on clinical interview and records review\]

== Mental Status/Behavioral Observations
<mental-statusbehavioral-observations>
• #strong[Orientation];: Alert and oriented to person, place, time, and situation • #strong[Appearance];: Appropriately groomed and dressed • #strong[Behavior];: Cooperative and engaged throughout testing • #strong[Speech];: Fluent with normal rate and prosody • #strong[Mood/Affect];: Euthymic with appropriate range • #strong[Effort];: Adequate effort demonstrated on validity measures

== Behavioral Observations
<behavioral-observations>
Biggie presented as alert and oriented to person, place, time, and situation. He was appropriately dressed and groomed, and appeared his stated age of 44 years. He was cooperative throughout the evaluation and appeared to put forth adequate effort on all tasks.

=== Mental Status
<mental-status>
- #strong[Attention/Orientation];: Fully oriented ×4 (person, place, time, situation)
- #strong[Appearance];: Well-groomed, appropriately dressed
- #strong[Behavior/Attitude];: Cooperative, engaged, appropriate eye contact
- #strong[Speech/Language];: Fluent, normal rate and prosody
- #strong[Mood/Affect];: Euthymic mood with congruent affect
- #strong[Thought Process];: Linear, goal-directed
- #strong[Thought Content];: No evidence of delusions or hallucinations
- #strong[Insight/Judgment];: Fair to good
- #strong[Effort/Validity];: Adequate effort demonstrated on embedded validity measures

= NEUROCOGNITIVE FINDINGS
<neurocognitive-findings>
== General Cognitive Ability
<sec-iq>
Testing of general cognitive ability revealed overall average performance (mean percentile = 51).

// Define a function to create a domain with a title, a table, and a figure
#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
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
        [#emph[_Premorbid Ability_] is an estimate of an individual's intellectual functioning prior to known or suspected onset of brain disease or dysfunction. Neurocognition is independent of intelligence and evaluates cognitive functioning across five domains\: Attention (focus, concentration, and information processing), Language (verbal communication, naming, comprehension, and fluency), Memory (immediate and delayed verbal and visual recall), Spatial (visuospatial perception, construction, and orientation), and Executive Functions (planning, problem-solving, and mental flexibility). #footnote[All scores in these figures have been standardized as z-scores. In this system: A z-score of 0.0 represents average performance; Each unit represents one standard deviation from the average; Scores between -1.0 and +1.0 fall within the normal range; Scores below -1.0 indicate below-average performance and warrant attention; and Scores at or below -2.0 indicate significantly impaired performance and are clinically concerning.]
        ],
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

// The title is appended with ' Index Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
== Academic Skills
<sec-academics>
Testing of academic skills revealed overall high average performance (mean percentile = 78).

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
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
        [
          Reading, writing, and math are the three main academic skills assessed on exam. _Reading ability_ consists of three interrelated abilities: decoding, comprehension, and fluency. _Writing ability_ can be described in terms of spelling, grammar, expression of ideas, and writing fluency. _Math ability_ can be described in terms of calculation skills, applied problem solving, and math fluency.
          ],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
#let title = "Academic Skills"
#let file_qtbl = "table_academics.png"
#let file_fig = "fig_academics_subdomain.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig,
  )
#let title = "Academic Skills"
#let file_qtbl = "table_academics.png"
#let file_fig = "fig_academics_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig,
  )
== Verbal/Language
<sec-verbal>
Testing of verbal/language revealed overall average performance (mean percentile = 41).

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
  pad(top: 0.5em)[]
    grid(
      columns: (50%, 50%),
      gutter: 8pt,
        figure([#image(file_qtbl)],
          caption: figure.caption(position: top, [#title]),
          kind: "qtbl",
          supplement: [*Table*],
          ),
        figure([#image(file_fig)],
          caption: figure.caption(position: bottom, [
            Verbal and language functioning refers to the ability to access and apply acquired word knowledge, to verbalize meaningful concepts, to understand complex multistep instructions, to think about verbal information, and to express oneself using words.
            ]),
          placement: none,
          kind: "image",
          supplement: [*Figure*],
          gap: 0.5em,
          ),
        )
    }
#let title = "Verbal/Language"
#let file_qtbl = "table_verbal.png"
#let file_fig = "fig_verbal_subdomain.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
)
#let title = "Verbal/Language"
#let file_qtbl = "table_verbal.png"
#let file_fig = "fig_verbal_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
)
== Visual Perception/Construction
<sec-spatial>
Testing of visual perception/construction revealed overall average performance (mean percentile = 50).

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
  pad(top: 0.5em)[]
    grid(
      columns: (50%, 50%),
      gutter: 8pt,
        figure([#image(file_qtbl)],
          caption: figure.caption(position: top, [#title]),
          kind: "qtbl",
          supplement: [*Table*],
          ),
        figure([#image(file_fig)],
          caption: figure.caption(position: bottom, [
            Perception, construction, and visuospatial processing refer to abilities such as mentally visualizing how objects should look from different angles, visualizing how to put objects together so that they fit correctly, and being able to accurately and efficiently copy and/or reproduce visual-spatial information onto paper.
            ]),
          placement: none,
          kind: "image",
          supplement: [*Figure*],
          gap: 0.5em,
          ),
        )
    }
#let title = "Visual Perception/Construction"
#let file_qtbl = "table_spatial.png"
#let file_fig = "fig_spatial.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
)
== Memory
<sec-memory>
Testing of memory revealed overall average performance (mean percentile = 55).

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
  pad(top: 0.5em)[]
    grid(
      columns: (50%, 50%),
      gutter: 8pt,
        figure([#image(file_qtbl)],
          caption: figure.caption(position: top, [#title]),
          kind: "qtbl",
          supplement: [Table],
          ),
        figure([#image(file_fig, width: auto)],
          caption: figure.caption(position: bottom, [
            Learning and memory refer to the rate and ease with which new information (e. g., facts, stories, lists, faces, names) can be encoded, stored, and later recalled from long-term memory.
            ]),
          placement: none,
          kind: "image",
          supplement: [Figure],
          gap: 0.5em,
        ),
      )
  }
#let title = "Memory"
#let file_qtbl = "table_memory.png"
#let file_fig = "fig_memory_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
  )
== Attention/Executive
<sec-executive>
Testing of attention/executive revealed overall average performance (mean percentile = 53).

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
  pad(top: 0.5em)[]
    grid(
      columns: (50%, 50%),
      gutter: 8pt,
        figure([#image(file_qtbl)],
          caption: figure.caption(position: top, [#title]),
          kind: "qtbl",
          supplement: [Table],
          ),
        figure([#image(file_fig, width: auto)],
          caption: figure.caption(position: bottom, [
            Attentional and executive functions underlie most, if not all, domains of cognitive performance. These are behaviors and skills that allow individuals to successfully carry-out instrumental and social activities, academic work, engage with others effectively, problem solve, and successfully interact with the environment to get needs met.
            ]),
          placement: none,
          kind: "image",
          supplement: [Figure],
          gap: 0.5em,
        ),
      )
  }
#let title = "Attention/Executive"
#let file_qtbl = "table_executive.png"
#let file_fig = "fig_executive_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
  )
== ADHD/Executive Function
<sec-adhd>
=== SELF-REPORT
<self-report>
- Self-reported Negative Self-Concept (i.e., poor social relationships, low self-esteem and self confidence) was Exceptionally High.

Corey's score on Inattention (INATTN) Index () was Exceptionally High. \#NAME? - Self-reported ADHD Inattentive Symptoms (i.e., behave in a manner consistent with the DSM-5 Inattentive Presentation of ADHD) was Above Average.

- Self-reported Inattention/Executive Dysfunction (i.e., trouble concentrating, difficulty planning or completing tasks, forgetfulness, absent-mindedness, being disorganized) was Above Average.

- Self-reported Total ADHD Symptoms (i.e., behave in a manner consistent with the DSM-5 diagnostic criteria for Combined Presentation of ADHD) was Above Average.

- Self-reported CAARS 2-ADHD Index (i.e., a composite indicator for identifying individuals 'at-risk' for ADHD) indicated a probability of 88% of having adult ADHD.

\#NAME? - Self-reported ADHD Hyperactive/Impulsive Symptoms (i.e., behave in a manner consistent with the DSM-5 Hyperactive-Impulsive Presentation of ADHD) was High Average.

\#NAME? \#NAME? \#NAME? \#NAME? \#NAME? \#NAME? \#NAME? \#NAME? - AJ's overall level of executive functioning was Low Average. \#NAME? - Inhibitory Control (i.e., control behavior or impulses, including thinking about consequences before acting, maintaining self-control, and thinking before speaking) was Below Average - Self-reported Negative Self-Concept (i.e., poor social relationships, low self-esteem and self confidence) was Exceptionally High.

Corey's score on Inattention (INATTN) Index () was Exceptionally High. \#NAME? - Self-reported ADHD Inattentive Symptoms (i.e., behave in a manner consistent with the DSM-5 Inattentive Presentation of ADHD) was Above Average.

- Self-reported Inattention/Executive Dysfunction (i.e., trouble concentrating, difficulty planning or completing tasks, forgetfulness, absent-mindedness, being disorganized) was Above Average.

- Self-reported Total ADHD Symptoms (i.e., behave in a manner consistent with the DSM-5 diagnostic criteria for Combined Presentation of ADHD) was Above Average.

- Self-reported CAARS 2-ADHD Index (i.e., a composite indicator for identifying individuals 'at-risk' for ADHD) indicated a probability of 88% of having adult ADHD.

\#NAME? - Self-reported ADHD Hyperactive/Impulsive Symptoms (i.e., behave in a manner consistent with the DSM-5 Hyperactive-Impulsive Presentation of ADHD) was High Average.

\#NAME? \#NAME? \#NAME? \#NAME? \#NAME? \#NAME? \#NAME? \#NAME? - AJ's overall level of executive functioning was Low Average. \#NAME? - Inhibitory Control (i.e., control behavior or impulses, including thinking about consequences before acting, maintaining self-control, and thinking before speaking) was Below Average

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
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
      [#image(file_fig)],
      caption: figure.caption(
        position: bottom,
        [Attention and executive functions are multidimensional concepts that contain several related processes. Both concepts require self-regulatory skills and have some common subprocesses; therefore, it is common to treat them together, or even to refer to both processes when talking about one or the other.],
      ),
      placement: none,
      kind: "image",
      supplement: [*Figure*],
      gap: 0.5em,
    ),
  )
}
#let title = "ADHD/Executive Function Self Ratings"
#let file_qtbl = "table_adhd_self.png"
#let file_fig = "fig_adhd_self.svg"
#domain(
  title: [#title],
  file_qtbl,
  file_fig
  )
== Emotional/Behavioral/Personality
<sec-emotion>
summary of PAI …

Corey's score on Anxiety (reflecting a generalized impairment associated with anxiety) was Exceptionally High. Corey's score on Physiological (A) (high scorers my not psychologically experience themselves as anxious, but show physiological signs that most people associate with anxiety) was Exceptionally High. Corey's score on Depression (person feels hopeless, discouraged and useless) was Exceptionally High. Corey's score on Cognitive (D) (a higher scorer is likely to report feeling hopeless and as having failed at most important life tasks) was Exceptionally High. Corey's score on Affective (D) (elevations suggest sadness, a loss of interest in normal activities and a loss if one's sense of pleasure in things that were previously enjoyed) was Exceptionally High. Corey's score on Physiological (D) (elevations suggest a change in level of physical functioning, typically with a disturbance in sleep pattern, a decrease in energy and level of sexual interest and a loss of appetite and/or weight loss) was Exceptionally High. Corey's score on Activity Level (this activity level renders the person confused and difficult to understand) was Exceptionally High. Corey's score on Thought Disorder (suggest problems in concentration and decision-making) was Exceptionally High. Corey's score on Identity Problems (suggest uncertainty about major life issues and difficulties in developing and maintaining a sense of purpose) was Exceptionally High. Corey's score on Cognitive (A) (elevations indicate worry and concern about current (often uncontrollable) issues that compromise the person's ability to concentrate and attend) was Exceptionally High. Corey's score on Borderline Features (behaviors typically associated with borderline personality disorder) was Exceptionally High. Corey's score on Affective (A) (high scorers experience a great deal of tension, have difficulty with relaxing and tend to be easily fatigued as a result of high-perceived stress) was Above Average. Corey's score on Affective Instability (a propensity to experience a particular negative affect (anxiety, depression, or anger is the typical response)) was Above Average. Corey's score on Suicidal Ideation (scores are typically of an individual who is seen in clinical settings) was Above Average. Corey's score on Phobias (indicate impairing phobic behaviors, with avoidance of the feared object or situation) was Above Average. Corey's score on Schizophrenia (associated with an active schizophrenic episode) was Above Average. Corey's score on Anxiety-Related Disorders (reflecting multiple anxiety-disorder diagnoses and broad impairment associated with anxiety) was Above Average. Corey's score on Traumatic Stress (trauma (single or multiple) is the overriding focus of the person's life) was High Average. Corey's score on Somatization (high scorers describe general lethargy and malaise, and the presentation is one of complaintiveness and dissatisfaction) was High Average. Corey's score on Negative Relationships (person is likely to be bitter and resentful about the way past relationships have gone) was High Average. Corey's score on Resentment (increasing tendency to attribute any misfortunes to the neglect of others and to discredit the successes of others as being the result of luck or favoritism) was Average. Corey's score on Somatic Complaints (degree of concern about physical functioning and health matters and the extent of perceived impairment arising from somatic symptoms) was Average. Corey's score on Self-Harm (reflect levels of impulsivity and recklessness that become more hazardous as scores rise) was Average. Corey's score on Nonsupport (social relationships are perceived as offering little support - family relationships may be either distant or combative, whereas friends are generally seen as unavailable or not helpful when needed) was Average. Corey's score on Obsessive-Compulsive (scores marked rigidity and significant ruminative concerns) was Average. Corey's score on Warmth (average scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to tolerate close attachment but also capable of maintaining some distance in relationships as needed) was Average. Corey's score on Health Concerns (elevations indicate a poor health may be a major component of the self-image, with the person accustomed to being in the patient role) was Average. Corey's score on Psychotic Experiences (person may strike others as peculiar and eccentric) was Average. Corey's score on ALC Estimated Score () was Average. Corey's score on Conversion (moderate elevations may be seen in neurological disorders with CNS impairment involving sensorimotor problems, MS, CVA/stroke, or neuropsychological associated with chronic alcoholism) was Average. Corey's score on Social Detachment (reflects a person who neither desires nor enjoys the meaning to personal relationships) was Average. Corey's score on Physical Aggression (suggest that losses of temper are more common and that the person is prone to more physical displays of anger, perhaps breaking objects or engaging in physical confrontations) was Average. Corey's score on Hypervigilance (suggest a person who is pragmatic and skeptical in relationships) was Average. Corey's score on Drug Problems (scores are indicative of a person who may use drugs on a fairly regular basis and may have experienced some adverse consequences as a result) was Average. Corey's score on Paranoia (individuals are likely to be overtly suspicious and hostile) was Average. Corey's score on DRG Estimated Score () was Average. Corey's score on Mania (scores are associated with disorders such as mania, hypomania, or cyclothymia) was Average. Corey's score on Stress (individuals may be experiencing a moderate degree of stress as a result of difficulties in some major life area) was Average. Corey's score on Alcohol Problems (are indicative of an individual who may drink regularly and may have experienced some adverse consequences as a result) was Low Average. Corey's score on Egocentricity (suggest a person who tends to be self-centered and pragmatic in interaction with others) was Low Average. Corey's score on Dominance (average scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to both take and relinquish control in these relationships as needed) was Low Average. Corey's score on Antisocial Behaviors (scores suggest a history of difficulties with authority and with social convention) was Low Average. Corey's score on Aggression (scores are indicative of an individual who may be seen as impatient, irritable, and quick-tempered) was Low Average. Corey's score on Persecution (suggest an individual who is quick to feel that they are being treated inequitably and easily believes that there is concerted effort among others to undermine their best interests) was Low Average. Corey's score on Aggressive Attitude (suggest an individual who is easily angered and frustrated; others may perceive him as hostile and readily provoked) was Low Average. Corey's score on Verbal Aggression (reflects a person who is assertive and not intimidated by confrontation and, toward the upper end of this range, he may be verbally aggressive) was Low Average. Corey's score on Irritability (person is very volatile in response to frustration and his judgment in such situations may be poor) was Low Average. Corey's score on Antisocial Features (individuals are likely to be impulsive and hostile, perhaps with a history of reckless and/or antisocial acts) was Low Average. Corey's score on Stimulus-Seeking (patient is likely to manifest behavior that is reckless and potentially dangerous to himself and/or those around him) was Low Average. Corey's score on Grandiosity (person may have little capacity to recognize personal limitations, to the point where one is not able to think clearly about one's capabilities) was Below Average. Corey's score on Treatment Rejection (average scores suggest a person who acknowledges major difficulties in their functioning, and perceives an acute need for help in dealing with these problems) was Exceptionally Low. Corey's score on Anxiety (reflecting a generalized impairment associated with anxiety) was Exceptionally High. Corey's score on Physiological (A) (high scorers my not psychologically experience themselves as anxious, but show physiological signs that most people associate with anxiety) was Exceptionally High. Corey's score on Depression (person feels hopeless, discouraged and useless) was Exceptionally High. Corey's score on Cognitive (D) (a higher scorer is likely to report feeling hopeless and as having failed at most important life tasks) was Exceptionally High. Corey's score on Affective (D) (elevations suggest sadness, a loss of interest in normal activities and a loss if one's sense of pleasure in things that were previously enjoyed) was Exceptionally High. Corey's score on Physiological (D) (elevations suggest a change in level of physical functioning, typically with a disturbance in sleep pattern, a decrease in energy and level of sexual interest and a loss of appetite and/or weight loss) was Exceptionally High. Corey's score on Activity Level (this activity level renders the person confused and difficult to understand) was Exceptionally High. Corey's score on Thought Disorder (suggest problems in concentration and decision-making) was Exceptionally High. Corey's score on Identity Problems (suggest uncertainty about major life issues and difficulties in developing and maintaining a sense of purpose) was Exceptionally High. Corey's score on Cognitive (A) (elevations indicate worry and concern about current (often uncontrollable) issues that compromise the person's ability to concentrate and attend) was Exceptionally High. Corey's score on Borderline Features (behaviors typically associated with borderline personality disorder) was Exceptionally High. Corey's score on Affective (A) (high scorers experience a great deal of tension, have difficulty with relaxing and tend to be easily fatigued as a result of high-perceived stress) was Above Average. Corey's score on Affective Instability (a propensity to experience a particular negative affect (anxiety, depression, or anger is the typical response)) was Above Average. Corey's score on Suicidal Ideation (scores are typically of an individual who is seen in clinical settings) was Above Average. Corey's score on Phobias (indicate impairing phobic behaviors, with avoidance of the feared object or situation) was Above Average. Corey's score on Schizophrenia (associated with an active schizophrenic episode) was Above Average. Corey's score on Anxiety-Related Disorders (reflecting multiple anxiety-disorder diagnoses and broad impairment associated with anxiety) was Above Average. Corey's score on Traumatic Stress (trauma (single or multiple) is the overriding focus of the person's life) was High Average. Corey's score on Somatization (high scorers describe general lethargy and malaise, and the presentation is one of complaintiveness and dissatisfaction) was High Average. Corey's score on Negative Relationships (person is likely to be bitter and resentful about the way past relationships have gone) was High Average. Corey's score on Resentment (increasing tendency to attribute any misfortunes to the neglect of others and to discredit the successes of others as being the result of luck or favoritism) was Average. Corey's score on Somatic Complaints (degree of concern about physical functioning and health matters and the extent of perceived impairment arising from somatic symptoms) was Average. Corey's score on Self-Harm (reflect levels of impulsivity and recklessness that become more hazardous as scores rise) was Average. Corey's score on Nonsupport (social relationships are perceived as offering little support - family relationships may be either distant or combative, whereas friends are generally seen as unavailable or not helpful when needed) was Average. Corey's score on Obsessive-Compulsive (scores marked rigidity and significant ruminative concerns) was Average. Corey's score on Warmth (average scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to tolerate close attachment but also capable of maintaining some distance in relationships as needed) was Average. Corey's score on Health Concerns (elevations indicate a poor health may be a major component of the self-image, with the person accustomed to being in the patient role) was Average. Corey's score on Psychotic Experiences (person may strike others as peculiar and eccentric) was Average. Corey's score on ALC Estimated Score () was Average. Corey's score on Conversion (moderate elevations may be seen in neurological disorders with CNS impairment involving sensorimotor problems, MS, CVA/stroke, or neuropsychological associated with chronic alcoholism) was Average. Corey's score on Social Detachment (reflects a person who neither desires nor enjoys the meaning to personal relationships) was Average. Corey's score on Physical Aggression (suggest that losses of temper are more common and that the person is prone to more physical displays of anger, perhaps breaking objects or engaging in physical confrontations) was Average. Corey's score on Hypervigilance (suggest a person who is pragmatic and skeptical in relationships) was Average. Corey's score on Drug Problems (scores are indicative of a person who may use drugs on a fairly regular basis and may have experienced some adverse consequences as a result) was Average. Corey's score on Paranoia (individuals are likely to be overtly suspicious and hostile) was Average. Corey's score on DRG Estimated Score () was Average. Corey's score on Mania (scores are associated with disorders such as mania, hypomania, or cyclothymia) was Average. Corey's score on Stress (individuals may be experiencing a moderate degree of stress as a result of difficulties in some major life area) was Average. Corey's score on Alcohol Problems (are indicative of an individual who may drink regularly and may have experienced some adverse consequences as a result) was Low Average. Corey's score on Egocentricity (suggest a person who tends to be self-centered and pragmatic in interaction with others) was Low Average. Corey's score on Dominance (average scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to both take and relinquish control in these relationships as needed) was Low Average. Corey's score on Antisocial Behaviors (scores suggest a history of difficulties with authority and with social convention) was Low Average. Corey's score on Aggression (scores are indicative of an individual who may be seen as impatient, irritable, and quick-tempered) was Low Average. Corey's score on Persecution (suggest an individual who is quick to feel that they are being treated inequitably and easily believes that there is concerted effort among others to undermine their best interests) was Low Average. Corey's score on Aggressive Attitude (suggest an individual who is easily angered and frustrated; others may perceive him as hostile and readily provoked) was Low Average. Corey's score on Verbal Aggression (reflects a person who is assertive and not intimidated by confrontation and, toward the upper end of this range, he may be verbally aggressive) was Low Average. Corey's score on Irritability (person is very volatile in response to frustration and his judgment in such situations may be poor) was Low Average. Corey's score on Antisocial Features (individuals are likely to be impulsive and hostile, perhaps with a history of reckless and/or antisocial acts) was Low Average. Corey's score on Stimulus-Seeking (patient is likely to manifest behavior that is reckless and potentially dangerous to himself and/or those around him) was Low Average. Corey's score on Grandiosity (person may have little capacity to recognize personal limitations, to the point where one is not able to think clearly about one's capabilities) was Below Average. Corey's score on Treatment Rejection (average scores suggest a person who acknowledges major difficulties in their functioning, and perceives an acute need for help in dealing with these problems) was Exceptionally Low.

#let domain(title: none, file_qtbl, file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
    grid(
      columns: (50%, 50%),
      gutter: 8pt,
        figure([#image(file_qtbl)],
          caption: figure.caption(position: top, [#title]),
          kind: "qtbl",
          supplement: [*Table*],
          ),
        figure([#image(file_fig, width: auto)],
          caption: figure.caption(
            position: bottom,
            [
              Emotional, behavioral, and personality scores collapsed across broad domains of functioning.
              ]),
          placement: none,
          kind: "image",
          supplement: [*Figure*],
          gap: 0.5em,
        ),
      )
  }
#let title = "Personality Assessment Scores"
#let file_qtbl = "table_emotion.png"
#let file_fig = "fig_emotion.svg"
#domain(
  title: [#title],
  file_qtbl,
  file_fig
  )
= SUMMARY/IMPRESSION
<summaryimpression>
Biggie is a 44-year-old male who was referred for neuropsychological evaluation. Overall, the current evaluation revealed:

== Cognitive Strengths
<cognitive-strengths>
- \[To be completed based on test results\]

== Cognitive Weaknesses
<cognitive-weaknesses>
- \[To be completed based on test results\]

== Diagnostic Impressions
<diagnostic-impressions>
- \[To be completed based on clinical judgment\]

== Clinical Summary
<clinical-summary>
The pattern of results suggests \[clinical interpretation to be added\]. These findings are consistent with \[diagnostic formulation to be added\].

== Functional Impact
<functional-impact>
\[Discussion of how cognitive findings impact daily functioning\]

= RECOMMENDATIONS
<recommendations>
Based on the results of this evaluation, the following recommendations are offered:

+ #strong[Medical Follow-up];: \[Specific medical recommendations\]

+ #strong[Cognitive Interventions];: \[Specific cognitive recommendations\]

+ #strong[Academic/Occupational];: \[Specific academic or work recommendations\]

+ #strong[Psychosocial Support];: \[Specific support recommendations\]

+ #strong[Re-evaluation];: Consider repeat neuropsychological evaluation in \[timeframe\] to monitor progress.

#horizontalrule

Thank you for referring Biggie for this neuropsychological evaluation. Please feel free to contact me if you have any questions regarding this report.

Respectfully submitted,

\[Examiner Name, Degree\] \[Title\] \[License Number\]

= APPENDIX
<appendix>
== Test Score Classification
<test-score-classification>
#table(
  columns: 3,
  align: (center,left,center,),
  table.header([Range], [Classification], [Percentile],),
  table.hline(),
  [≥ 130], [Very Superior], [98+],
  [120-129], [Superior], [91-97],
  [110-119], [High Average], [75-90],
  [90-109], [Average], [25-74],
  [80-89], [Low Average], [9-24],
  [70-79], [Borderline], [2-8],
  [≤ 69], [Extremely Low], [\<2],
)
== Validity Statement
<validity-statement>
All test results reported herein are considered valid based on behavioral observations and embedded validity indicators.
