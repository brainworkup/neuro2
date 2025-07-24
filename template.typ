// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text(size: 0.92em)
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%, 0%), end: (75%, 0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it
    .children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
    ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): it => block(
  fill: luma(230),
  width: 100%,
  inset: 8pt,
  radius: 2pt,
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
    let figcounter = counter(figure)
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)

    [#figure(kind: kind, supplement: supplement, caption: caption, {
        // Set numbering for subfigures
        show figure.where(kind: kind): it => {
          set figure(numbering: _ => numbering(
            subrefnumbering,
            n-super,
            quartosubfloatcounter.get().first() + 1,
          ))
          it
        }

        // Set caption position
        show figure.where(kind: kind): it => {
          set figure.caption(position: position)
          it
        }

        // Handle caption display
        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // Remove extra output from numbering
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        // Reset counter and include the body content
        quartosubfloatcounter.update(0)
        body
      })#label]
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

  let new_title_block = block_with_new_content(old_title_block, block_with_new_content(
    old_title_block.body,
    old_title_block.body.body.children.at(0) + old_title_block.body.body.children.at(1) + new_title,
  ))

  block_with_new_content(
    old_callout,
    block(below: 0pt, new_title_block) + old_callout.body.children.at(1),
  )
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(
  body: [],
  title: "Callout",
  background_color: rgb("#dddddd"),
  icon: none,
  icon_color: black,
  body_background_color: white,
) = {
  block(
    breakable: false,
    fill: background_color,
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(inset: 1pt, width: 100%, below: 0pt, block(
      fill: background_color,
      width: 100%,
      inset: 8pt,
    )[#text(icon_color, weight: 900)[#icon] #title])
      + if (body != []) {
        block(inset: 1pt, width: 100%, block(fill: body_background_color, width: 100%, inset: 8pt, body))
      },
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

#show: report.with(
  title: "NEUROCOGNITIVE EXAMINATION",
  name: [Smalls, Biggie],
  doe: [true],
  patient: [Biggie],
  paper: "us-letter",
  body-font: "IBM Plex Serif",
  sans-font: "IBM Plex Sans",
  fontsize: 12pt,
)

#let name = [Smalls, Biggie]
#let doe = [2025-01-20]
#let patient = [Biggie]
// #v(2em, weak: true)
// #show block: set par(leading: 0.65em)
#block[
  // *CASE NUMBER:* #case_number \
  *PATIENT NAME:* #name \
  *DATE OF BIRTH:* YYYY-MM-DD, Age 18 \
  *DATES OF EXAM:* YYYY-MM-DD, YYYY-MM-DD, and YYYY-MM-DD \
  *DATE OF REPORT*: 2025-01-20 \
]
= TESTS ADMINISTERED
<tests-administered>
- Comprehensive Neuropsychiatric Symptom and History Interview
- Conners' Adult ADHD Diagnostic Interview for DSM-IV, Part I: History (CAADID Part 1)
- Conners' Adult ADHD Diagnostic Interview for DSM-IV, Part II: Symptoms? (CAADID Part 2)
- Structured Clinical Interview for DSM-5 Disorders, Clinician Version (SCID-5-CV)
- Beck Anxiety Inventory (BAI)
- Beck Depression Inventory, 2nd ed (BDI-2)
- Brown Executive Function/Attention Scales, Parent Report (Brown EF/A Parent)
- Brown Executive Function/Attention Scales, Self-Report (Brown EF/A Self)
- Brown Executive Function/Attention Scales, Teacher Report (Brown EF/A Teacher)
- California Verbal Learning Test, 3rd ed (CVLT-3), Standard Form
- California Verbal Learning Test, 3rd ed, Brief Form (CVLT-3 Brief)
- Childhood Autism Rating Scale, 2nd ed, High-Functioning Version (CARS-2 HF)
- Comprehensive Executive Function Inventory, Adult, Observer (CEFI Adult Observer)
- Comprehensive Executive Function Inventory, Adult, Self-Report Form (CEFI Adult Self-Report)
- Conners' Adult ADHD and Executive Function Rating Scales, 2nd ed, Self-Report (CAARS-2 Self)
- Conners' Adult ADHD and Executive Function Rating Scales, 2nd ed, Observer Report (CAARS-2 Observer)
- Conners' Adult ADHD Rating Scales--Observer Report: Long Version (CAARS--O:L)
- Conners' Adult ADHD Rating Scales--Self-Report: Long Version (CAARS--S:L)
- Delis-Kaplan Executive Function System (D-KEFS):
  - Color-Word Interference
  - Trail Making
  - Design Fluency
  - Verbal Fluency
- Dot Counting Test (DCT)
- Grooved Pegboard Test
- Repeatable Battery for the Assessment of Neuropsychological Status (RBANS)
- Repeatable Battery for the Assessment of Neuropsychological Status, Update, Form A (RBANS Update Form A):
  - Immediate Memory
  - Language
  - Visuospatial/Constructional
  - Attention
  - Delayed Memory
- Repeatable Battery for the Assessment of Neuropsychological Status, Form B (RBANS)
- Repeatable Battery for the Assessment of Neuropsychological Status, Form C (RBANS)
- Repeatable Battery for the Assessment of Neuropsychological Status, Form D (RBANS)
- Rey-Osterrieth Complex Figure Test (ROCFT)
- Trail Making Test (TMT)
- Wechsler Adult Intelligence Scale, 4th ed (WAIS-IV)
- Wechsler Adult Intelligence Scale, 4th ed (WAIS-IV): Similarities, Matrix Reasoning, Letter-Number Sequencing, Coding,
  Symbol Search, Digit Span, Vocabulary, Block Design, Figure Weights, Arithmetic, Cancellation
- Wechsler Adult Intelligence Scale, 5th ed (WAIS-5)
- Wechsler Individual Achievement Test, 4th ed (WIAT-4)
- Wechsler Individual Achievement Test, 4th ed (WIAT-4): Word Reading, Reading Comprehension, Pseudoword Decoding,
  Orthographic Fluency, Decoding Fluency
- Wechsler Memory Scale, 4th ed (WMS-4)
- Wechsler Memory Scale, 4th ed (WMS-4): Logical Memory, Verbal Paired Associates, Visual Reproduction, Visual Paired
  Associates, Designs, Spatial Addition, Symbol Span, Spatial Span
- Wide Range Achievement Test, 5th ed (WRAT-5)
- Wide Range Achievement Test, 5th ed, Blue Form (WRAT-5): Word Reading
- Wide Range Achievement Test, 5th ed, Green Form (WRAT-5): Word Reading
- NIH Executive Abilities--Measures and Instruments for Neurobehavioral Evaluation and Research (NIH EXAMINER):
  - Behavioral Rating Scale
  - Word Fluency
  - Unstructured Task
- Advanced Clinical Solutions (ACS):
  - Word Choice Test
  - Test of Premorbid Functioning (TOPF)
  - Social Cognition
- Neuropsychological Assessment Battery (NAB):
  - Attention Module
  - Language Module
  - Memory Module
  - Spatial Module
  - Executive Functions Module
- Neuropsychological Assessment Battery, Screener (NAB-S):
  - Attention Module
  - Language Module
  - Memory Module
  - Spatial Module
  - Executive Functions Module
- Neuropsychological Assessment Battery (NAB):
  - Judgment
- Hare Psychopathy Checklist, Revised (PCL-R)
- Personality Assessment Inventory (PAI)
- Comprehensive Neurodevelopmental Symptom and History Interview
- Behavioral Assessment System for Children, 3rd ed, Structured Developmental History (BASC-3 SDH)
- Kiddie-SADS
- Adaptive Behavior Assessment System, 3rd ed, Parent Form (ABAS-3 Parent)
- Adaptive Behavior Assessment System, 3rd ed, Parent/Primary Caregiver Form (ABAS-3 Parent)
- Adaptive Behavior Assessment System, 3rd ed, Self-Report Form (ABAS-3 Self)
- Adaptive Behavior Assessment System, 3rd ed, Teacher Form (ABAS-3 Teacher)
- Behavioral Assessment System for Children, 3rd ed, Parent Rating Scales, Adolescent (BASC-3 PRS Adolescent)
- Behavioral Assessment System for Children, 3rd ed, Parent Rating Scales, Child (BASC-3 PRS Child)
- Behavioral Assessment System for Children, 3rd ed, Parent Rating Scales, Preschool (BASC-3 PRS Preschool)
- Behavioral Assessment System for Children, 3rd ed, Self-Report of Personality, Adolescent (BASC-3 SRP Adolescent)
- Behavioral Assessment System for Children, 3rd ed, Self-Report of Personality, Child (BASC-3 SRP Child)
- Behavioral Assessment System for Children, 3rd ed, Teacher Rating Scales, Adolescent (BASC-3 TRS Adolescent)
- Behavioral Assessment System for Children, 3rd ed, Teacher Rating Scales, Child (BASC-3 TRS Child)
- Behavioral Assessment System for Children, 3rd ed, Teacher Rating Scales, Preschool (BASC-3 TRS Preschool)
- Bracken School Readiness Assessment, 4th ed (BSRA-4)
- Brown Executive Function/Attention Scales, Parent Report (Brown EF/A Parent)
- Brown Executive Function/Attention Scales, Self-Report (Brown EF/A Self)
- Brown Executive Function/Attention Scales, Teacher Report (Brown EF/A Teacher)
- California Verbal Learning Test, Child ed (CVLT-C)
- Childhood Autism Rating Scale, 2nd ed (CARS-2)
- Childhood Autism Rating Scale, 2nd ed, High-Functioning Version (CARS-2 HF)
- Childhood Autism Rating Scale, 2nd ed, Questionnaire for Parents or Caregivers (CARS-2 QPC)
- Children's Memory Scale, 3rd ed (CMS-3)
- Clinical Evaluation of Language Fundamentals Preschool, 3rd ed (CELF Preschool-3)
- Clinical Evaluation of Language Fundamentals, 5th ed, Ages 5-8 (CELF-5)
- Clinical Evaluation of Language Fundamentals, 5th ed, Ages 9-21 (CELF-5)
- Comprehensive Executive Function Inventory, Parent Report (CEFI Parent)
- Comprehensive Executive Function Inventory, Self-Report (CEFI Self)
- Comprehensive Executive Function Inventory, Teacher Report (CEFI Teacher)
- Comprehensive Executive Function Inventory, Youth Report (CEFI Youth)
- Conners' Rating Scale, 4th ed, Parent (Conners-4 Parent)
- Conners' Rating Scale, 4th ed, Self-Report (Conners-4 Self)
- Conners' Rating Scale, 4th ed, Teacher (Conners-4 Teacher)
- Delis-Kaplan Executive Function System (D-KEFS):
  - Color-Word Interference Test
  - Trail Making Test
- Grooved Pegboard Test
- Kaufman Test of Educational Achievement, 3rd ed, Form A (KTEA-3 Form A)
- Kaufman Test of Educational Achievement, 3rd ed, Form B (KTEA-3 Form B)
- NEPSY-II Developmental Neuropsychological Battery
- PROMIS Sleep Assessments Pediatric Parent Proxy
- Rating Scale of Impairment (RSI)
- Repeatable Battery for the Assessment of Neuropsychological Status, Form A (RBANS)
- Repeatable Battery for the Assessment of Neuropsychological Status, Form B (RBANS)
- Repeatable Battery for the Assessment of Neuropsychological Status, Form C (RBANS)
- Repeatable Battery for the Assessment of Neuropsychological Status, Form D (RBANS)
- Rey-Osterrieth Complex Figure Test (ROCFT)
- Test of Memory Malingering (TOMM)
- Trail Making Test (TMT)
- Wechsler Adult Intelligence Scale, 5th ed (WAIS-5)
- Wechsler Adult Intelligence Scale, 4th ed (WAIS-IV)
- Wechsler Abbreviated Scale of Intelligence, 2nd ed (WASI-2)
- Wechsler Individual Achievement Test, 4th ed (WIAT-4)
- Wechsler Individual Achievement Test, 4th ed (WIAT-4): Word Reading, Reading Comprehension, Pseudoword Decoding,
  Orthographic Fluency, Decoding Fluency
- Wechsler Intelligence Scale for Children, 5th ed (WISC-V)
- Wechsler Preschool and Primary Scale of Intelligence, 4th ed, Ages 2-3 (WPPSI-IV)
- Wechsler Preschool and Primary Scale of Intelligence, 4th ed, Ages 4-7 (WPPSI-IV)
- Personality Assessment Inventory, Adolescent (PAI-A)
- Wide Range Achievement Test, 5th ed (WRAT-5)
- Wide Range Achievement Test, 5th ed, Blue Form (WRAT-5): Word Reading
- Wide Range Achievement Test, 5th ed, Green Form (WRAT-5): Word Reading
- NIH Executive Abilities--Measures and Instruments for Neurobehavioral Evaluation and Research (NIH EXAMINER):
  - Behavioral Rating Scale
  - Word Fluency
  - Unstructured Task
- Personality Assessment Inventory, Adolescent (PAI-A)
= NEUROBEHAVIORAL STATUS EXAM
<sec-nse>
== Reason for Referral
<reason-for-referral>
Biggie Smalls is a 18-year-old, rightright-handed research assistant with :"12 years" years of education, including a
B.A. in Hustling from the University of Bed-Sty. He was referred in order to determine the nature and extent of
neurocognitive sequelae emerging from a history of attention-deficit/hyperactivity disorder (ADHD).

The purpose of the current evaluation is ADHD, anxiety, and depression. This report is based on a review of available
medical records and information gathered across multiple days of evaluation. Treatment planning and plans for test
accommodations were discussed with Biggie during the feedback visit on the final day of the examination.

== Background
<background>
The following information was obtained during an interview with Biggie and from review of available medical records.
Biggie has been doing well in his classes since starting law school and has never failed. However, issues have begun to
arise that he has been unable to avoid, including being easily distracted, restlessness, constantly fidgeting,
procrastination, and variable attention. He suspects having ADHD and has always struggled with aspects of it. Biggie's
mother tried to get his evaluated and tested when he was younger, but was never able to do so because his school at the
time did not agree that there were major concerns. He has noticed increasing difficulty initiating tasks, especially
when it comes to writing long research papers, and has been procrastinating more and more. Biggie has read up on ADHD
and believes he may have it, but has been able to hide it from others, as he has "gotten good at pretending to pay
attention." He seeks further assessment and evaluation to identify any underlying neurocognitive factors influencing his
academic motivations and performance.

#strong[Cognitive complaints];: sustained attention, working memory, and organization.

== Relevant History
<relevant-history>
=== Past Neuropsychological Test Results
<past-neuropsychological-test-results>
Patient denied having prior testing.

=== Birth/Early Development
<birthearly-development>
- Normal pregnancy, birth, and delivery.
- Developmental milestones achieved on time.

=== Medical History
<medical-history>
#block(above: 1.2em, [
  - #strong[Current];: Consequat ad est amet deserunt dolor amet cillum nisi irure sit consequat officia do..
  - #strong[Family];: Irure anim qui deserunt eu culpa aliqua ea consequat deserunt..
  - #strong[Medications];: None.
  - #strong[Appetite/Weight];: Stable with no significant changes recently.
  - #strong[Sleep];: Normal, no changes.
  - #strong[Neurological Injury];: Voluptate magna do id veniam id laborum in qui magna sint ad cillum commodo.
  - #strong[Psychiatric];: ADHD, anxiety, and depression.

])

=== Behavioral/Emotional/Social
<behavioralemotionalsocial>
Laborum enim culpa excepteur non dolore ut consequat officia nisi proident.

=== Educational History
<educational-history>
Ea eiusmod eiusmod officia. Ut adipisicing magna nostrud aute in enim laboris ipsum amet. Ex est occaecat irure. Aliqua
ea excepteur non ea dolore culpa commodo irure ipsum non. Ea in nisi laboris id laborum laborum reprehenderit officia in
ad Lorem aliqua consectetur anim. Ex pariatur eu quis tempor. Amet veniam deserunt laborum do laborum eu ex.

=== Occupational History
<occupational-history>
Mollit pariatur ut laborum nulla proident aute. Eu laboris tempor consectetur id qui eu. Exercitation sint cupidatat
ipsum fugiat cupidatat nulla nostrud culpa elit reprehenderit sit Lorem minim officia. Ex exercitation voluptate enim
pariatur voluptate magna commodo. Aute fugiat ad deserunt sunt qui ipsum. Culpa ea proident aliquip irure veniam ut.
Tempor id minim commodo.

=== Cultural/Social Context
<culturalsocial-context>
Deserunt sint esse culpa exercitation adipisicing cupidatat cupidatat incididunt commodo magna. Minim irure non culpa
dolore esse sit. Elit officia nulla consequat esse id consequat quis consequat quis voluptate veniam tempor fugiat. Ut
in adipisicing nisi amet labore.

== Mental Status/Behavioral Observations
<mental-statusbehavioral-observations>
- #strong[Attention/Orientation];: Orientation to person, place, time, and situation was intact.
- #strong[Appearance];: Appropriate grooming and dress for context.
- #strong[Behavior/Attitude];: Cooperative, engaged. No gross behavioral apathy or disinhibition observed.
- #strong[Speech/Language];: Fluent and normal in rate, volume, and prosody.
- #strong[Mood/Affect];: Neutral, range was full and appropriate.
- #strong[Sensory/Motor];: Performance was not limited by any obvious sensory or motor difficulties.
- #strong[Cognitive Process];: Coherent and goal directed.
- #strong[Effort/Validity];: Normal; TOMM Trial 1 = 48/50, TOMM Trial 2 = 50/50, RDS = \>6, DCT = 4.3.

= NEUROCOGNITIVE FINDINGS
<neurocognitive-findings>
== General Cognitive Ability
<sec-iq>
Verbal Comprehension (i.e., the ability to verbalize meaningful concepts, think about verbal information, and express
oneself using words) fell within the High Average and ranked at the 88th percentile. This indicates performance as good
as or better than 88% of same-age peers from the general population.

A subset of intellectual functioning with reduced influences of working memory and processing speed fell within the
Average and ranked at the 61th percentile. This indicates performance as good as or better than 61% of same-age peers
from the general population.

Ethan's score on RBANS Total Index (composite indicator of general cognitive functioning) was Average. Fluid Reasoning
(i.e., the ability to use reasoning to identify and apply solutions to problems) fell within the Average and ranked at
the 42th percentile. This indicates performance as good as or better than 42% of same-age peers from the general
population.

General intellectual ability fell within the Average and ranked at the 39th percentile. This indicates performance as
good as or better than 39% of same-age peers from the general population.

The patient's ability to evaluate visual details understand spatial relations among objects and construct geometric
design using models fell within the Low Average and ranked at the 23th percentile. This indicates performance as good as
or better than 23% of same-age peers from the general population.

Working memory (i.e., the ability to consciously register maintain and manipulate auditory and visual information) fell
within the Low Average and ranked at the 21th percentile. This indicates performance as good as or better than 21% of
same-age peers from the general population.

General intellectual functioning that minimizes expressive language demands fell within the Low Average and ranked at
the 19th percentile. This indicates performance as good as or better than 19% of same-age peers from the general
population.

Index of cognitive processing proficiency that reduces crystallized knowledge verbal reasoning and fluid reasoning
demands fell within the Below Average and ranked at the 8th percentile. This indicates performance as good as or better
than 8% of same-age peers from the general population.

Ability to quickly use reasoning to identify and apply solutions to problems fell within the Below Average and ranked at
the 6th percentile. This indicates performance as good as or better than 6% of same-age peers from the general
population.

```{r}
#| label: setup-iq
#| include: false

# Filter by domain
domains <- c("General Cognitive Ability")

# Target phenotype
pheno <- "iq"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  iq <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  iq <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  iq <- readr::read_csv("data/neurocog.parquet")
}
```

== Academic Skills
<sec-academics>
Spontaneous writing fluency at the discourse level fell within the Average and ranked at the 42th percentile, indicating
performance as good as or better than 42% of same-age peers from the general population. Written spelling of words from
dictations fell within the Low Average and ranked at the 14th percentile, indicating performance as good as or better
than 14% of same-age peers from the general population. Single word reading/decoding of a list of regular and irregular
words fell within the Low Average and ranked at the 12th percentile, indicating performance as good as or better than
12% of same-age peers from the general population. Paper-and-pencil math calculation skills, ranging from basic
operations with integers to geometry, algebra, and calculus problems fell within the Low Average and ranked at the 12th
percentile, indicating performance as good as or better than 12% of same-age peers from the general population.

```{r}
#| label: setup-academics
#| include: false

# Filter by domain
domains <- c("Academic Skills")

# Target phenotype
pheno <- "academics"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  academics <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  academics <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  academics <- readr::read_csv("data/neurocog.parquet")
}
```

== Verbal/Language
<sec-verbal>
Verbal concept formation and abstract reasoning fell within the Above Average and ranked at the 91th percentile. This
indicates performance as good as or better than 91% of same-age peers from the general population.

Ethan's score on Semantic Fluency (semantic word fluency/generativity) was High Average. Verbal concept formation and
word knowledge fell within the High Average and ranked at the 84th percentile. This indicates performance as good as or
better than 84% of same-age peers from the general population.

Ethan's score on Language Index (general language processing) was Average. Ethan's score on Picture Naming
(confrontation naming/expressive vocabulary) was Average. Practical knowledge and judgment of general principles and
social situations fell within the Average and ranked at the 25th percentile. This indicates performance as good as or
better than 25% of same-age peers from the general population.

```{r}
#| label: setup-verbal
#| include: false

# Filter by domain
domains <- c("Verbal/Language")

# Target phenotype
pheno <- "verbal"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  verbal <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  verbal <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  verbal <- readr::read_csv("data/neurocog.parquet")
}
```

== Visual Perception/Construction
<sec-spatial>
General sequential (deductive) reasoning and quantitative reasoning fell within the Average and ranked at the 50th
percentile. This indicates performance as good as or better than 50% of same-age peers from the general population.

Fluid and inductive reasoning and conceptual thinking fell within the Average and ranked at the 50th percentile. This
indicates performance as good as or better than 50% of same-age peers from the general population.

A measure of visual-perceptual reasoning and mental transformation abilities that requires examinees to solve visual
puzzles within a time limit fell within the Average and ranked at the 37th percentile. This indicates performance as
good as or better than 37% of same-age peers from the general population.

Inductive reasoning and nonverbal problem-solving fell within the Average and ranked at the 37th percentile. This
indicates performance as good as or better than 37% of same-age peers from the general population.

Understanding visual-spatial relationships to construct unfamiliar geometric designs from a model fell within the Low
Average and ranked at the 16th percentile. This indicates performance as good as or better than 16% of same-age peers
from the general population.

Understanding visual-spatial relationships to construct unfamiliar geometric designs from a model (untimed) fell within
the Low Average and ranked at the 16th percentile. This indicates performance as good as or better than 16% of same-age
peers from the general population.

Ethan's score on Figure Copy (copy of a complex abstract figure) was Low Average. Ethan's score on Line Orientation
(basic perception of visual stimuli) was Low Average. Ethan's score on Visuospatial/Constructional Index (broad
visuospatial processing) was Below Average.

```{r}
#| label: setup-spatial
#| include: false

# Filter by domain
domains <- c("Visual Perception/Construction")

# Target phenotype
pheno <- "spatial"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  spatial <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  spatial <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  spatial <- readr::read_csv("data/neurocog.parquet")
}
```

== Memory
<sec-memory>
Ethan's score on Story Memory (expository story learning) was Above Average. Ethan's score on Story Recall (long-term
recall of a detailed story) was Above Average. Ethan's score on Immediate Memory Index (composite verbal learning of a
word list and a logical story) was Above Average. Ethan's score on List Learning (word list learning) was High Average.
Ethan's score on List Recognition (delayed recognition of a word list) was Average. Ethan's score on Figure Recall
(long-term recall and reconstruction of a complex abstract figure) was Average. Ethan's score on List Recall (long-term
recall of a word list) was Average. Ethan's score on Delayed Memory Index (long-term recall of verbal information) was
Low Average.

```{r}
#| label: setup-memory
#| include: false

# Filter by domain
domains <- c("Memory")

# Target phenotype
pheno <- "memory"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  memory <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  memory <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  memory <- readr::read_csv("data/neurocog.parquet")
}
```

== Attention/Executive
<sec-executive>
Ethan's score on Coding (speed of information processing) was High Average. Ethan's score on Attention Index (general
attentional and executive functioning) was High Average. Ethan's score on Digit Span (attention span and auditory
attention) was Average. Maintenance and resequencing of progressively lengthier sets of pictures in spatial working
memory fell within the Average and ranked at the 37th percentile. This indicates performance as good as or better than
37% of same-age peers from the general population.

Selective attention and attentional fluency on a cancellation task fell within the Average and ranked at the 37th
percentile. This indicates performance as good as or better than 37% of same-age peers from the general population.

Auditory attentional capacity, or how much information can be processed at once fell within the Average and ranked at
the 37th percentile. This indicates performance as good as or better than 37% of same-age peers from the general
population.

A measure of both attentional capacity and working memory fell within the Average and ranked at the 37th percentile.
This indicates performance as good as or better than 37% of same-age peers from the general population.

Rate of test taking, perceptual speed, visual discrimination, and visual attention scanning (random) fell within the
Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers
from the general population.

Rate of test taking, perceptual speed, visual discrimination, and visual attention scanning (structured) fell within the
Average and ranked at the 37th percentile. This indicates performance as good as or better than 37% of same-age peers
from the general population.

Registering, maintaining, and manipulating auditory information fell within the Low Average and ranked at the 16th
percentile. This indicates performance as good as or better than 16% of same-age peers from the general population.

Efficiency of psychomotor speed, visual scanning ability, and visual-motor coordination fell within the Low Average and
ranked at the 9th percentile. This indicates performance as good as or better than 9% of same-age peers from the general
population.

Visual-perceptual decision-making speed fell within the Low Average and ranked at the 9th percentile. This indicates
performance as good as or better than 9% of same-age peers from the general population.

Performance on a measures that requires cognitive flexibility, divided attention, visual search, and the ability to
shift cognitive sets between number and letter sequences fell within the Below Average range. Maintenance and
resequencing of progressively lengthier number strings in working memory fell within the Below Average and ranked at the
2nd percentile. This indicates performance as good as or better than 2% of same-age peers from the general population.

Visual search speed, scanning, speed of processing, and motor speed and coordination on Part A of the Trail Making Test
fell within the Exceptionally Low range.

```{r}
#| label: setup-executive
#| include: false

# Filter by domain
domains <- c("Attention/Executive")

# Target phenotype
pheno <- "executive"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  executive <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  executive <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  executive <- readr::read_csv("data/neurocog.parquet")
}
```

== Motor
<sec-motor>
Nondominant hand dexterity was Exceptionally Low range. Fine-motor dexterity (dominant hand) fell within the
Exceptionally Low range.

```{r}
#| label: setup-motor
#| include: false

# Filter by domain
domains <- c("Motor")

# Target phenotype
pheno <- "motor"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurocog.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  motor <- arrow::read_parquet("data/neurocog.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  motor <- arrow::read_feather("data/neurocog.parquet")
} else {
  # Default to CSV for other formats
  motor <- readr::read_csv("data/neurocog.parquet")
}
```

== Personality Disorders
<sec-emotion>
Ethan's score on Alcohol Problems (are indicative of an individual who may drink regularly and may have experienced some
adverse consequences as a result) was Average. Ethan's score on Drug Problems (scores are indicative of a person who may
use drugs on a fairly regular basis and may have experienced some adverse consequences as a result) was Average. Ethan's
self-reported Rule-breaking behavior was Above Average. Ethan's self-reported Demonstration of clear, logical thought
patterns and a general awareness of surroundings was Above Average. Ethan's self-reported Behavioral symptoms index
composite scale was Above Average. Ethan's self-reported Maintain necessary levels of attention was Above Average.
Ethan's self-reported Externalizing problems composite scale was Above Average. Ethan's self-reported Avoid social
situations and appears to be capable of developing and maintaining friendships with others was Above Average. Ethan's
self-reported Ratings of aggressive behavior and to act aggressively was High Average. Ethan's self-reported Tendency to
be overly active, rush through work or activities, and act without thinking was High Average. Ethan's self-reported
Excessive feelings of unhappiness, sadness, or stress was High Average. Ethan's self-reported Internalizing problems
composite scale was Average. Ethan's self-reported Able to adequately perform simple daily tasks in a safe and efficient
manner was Average. Ethan's self-reported Tendency to be nervous, fearful, or worried about real or imagined problems
was Average. Ethan's self-reported Exhibits appropriate expressive and receptive communication skills and displays a
strong ability to seek out and find new information independently was Low Average. Ethan's self-reported Adaptation to
most situations and able to quickly recover from situations that are difficult was Low Average. Ethan's self-reported
Health-related problems was Low Average. Ethan's self-reported Overall adaptive functioning composite score was Low
Average. Ethan's self-reported Socially adept and at ease was Below Average. Ethan's self-reported Creative, works well
under pressure, and/or can effectively unite others to work together was Below Average. Ethan's score on Warmth (average
scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to
tolerate close attachment but also capable of maintaining some distance in relationships as needed) was Average. Ethan's
score on Treatment Rejection (average scores suggest a person who acknowledges major difficulties in their functioning,
and perceives an acute need for help in dealing with these problems) was Average. Ethan's score on Dominance (average
scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to
both take and relinquish control in these relationships as needed) was Average. Ethan's score on Stress (individuals may
be experiencing a moderate degree of stress as a result of difficulties in some major life area) was Low Average.
Ethan's score on Nonsupport (social relationships are perceived as offering little support - family relationships may be
either distant or combative, whereas friends are generally seen as unavailable or not helpful when needed) was Low
Average. Ethan's score on Grandiosity (person may have little capacity to recognize personal limitations, to the point
where one is not able to think clearly about one's capabilities) was High Average. Ethan's score on Obsessive-Compulsive
(scores marked rigidity and significant ruminative concerns) was Average. Ethan's score on Anxiety-Related Disorders
(reflecting multiple anxiety-disorder diagnoses and broad impairment associated with anxiety) was Average. Ethan's score
on Traumatic Stress (trauma (single or multiple) is the overriding focus of the person's life) was Average. Ethan's
score on Affective (D) (elevations suggest sadness, a loss of interest in normal activities and a loss if one's sense of
pleasure in things that were previously enjoyed) was Average. Ethan's score on Physical Aggression (suggest that losses
of temper are more common and that the person is prone to more physical displays of anger, perhaps breaking objects or
engaging in physical confrontations) was Average. Ethan's score on Persecution (suggest an individual who is quick to
feel that they are being treated inequitably and easily believes that there is concerted effort among others to
undermine their best interests) was Average. Ethan's score on Phobias (indicate impairing phobic behaviors, with
avoidance of the feared object or situation) was Average. Ethan's score on Mania (scores are associated with disorders
such as mania, hypomania, or cyclothymia) was Average. Ethan's score on Verbal Aggression (reflects a person who is
assertive and not intimidated by confrontation and, toward the upper end of this range, he may be verbally aggressive)
was Average. Ethan's score on Conversion (moderate elevations may be seen in neurological disorders with CNS impairment
involving sensorimotor problems, MS, CVA/stroke, or neuropsychological associated with chronic alcoholism) was Low
Average. Ethan's score on Hypervigilance (suggest a person who is pragmatic and skeptical in relationships) was Low
Average. Ethan's score on Health Concerns (elevations indicate a poor health may be a major component of the self-image,
with the person accustomed to being in the patient role) was Low Average. Ethan's score on Suicidal Ideation (scores are
typically of an individual who is seen in clinical settings) was Low Average. Ethan's score on Social Detachment
(reflects a person who neither desires nor enjoys the meaning to personal relationships) was Low Average. Ethan's score
on Somatic Complaints (degree of concern about physical functioning and health matters and the extent of perceived
impairment arising from somatic symptoms) was Low Average. Ethan's score on Somatization (high scorers describe general
lethargy and malaise, and the presentation is one of complaintiveness and dissatisfaction) was Low Average. Ethan's
score on Cognitive (D) (a higher scorer is likely to report feeling hopeless and as having failed at most important life
tasks) was Low Average. Ethan's score on Irritability (person is very volatile in response to frustration and his
judgment in such situations may be poor) was Low Average. Ethan's score on Aggression (scores are indicative of an
individual who may be seen as impatient, irritable, and quick-tempered) was Low Average. Ethan's score on Cognitive (A)
(elevations indicate worry and concern about current (often uncontrollable) issues that compromise the person's ability
to concentrate and attend) was Low Average. Ethan's score on Physiological (A) (high scorers my not psychologically
experience themselves as anxious, but show physiological signs that most people associate with anxiety) was Low Average.
Ethan's score on Depression (person feels hopeless, discouraged and useless) was Low Average. Ethan's score on Paranoia
(individuals are likely to be overtly suspicious and hostile) was Low Average. Ethan's score on Thought Disorder
(suggest problems in concentration and decision-making) was Low Average. Ethan's score on Activity Level (this activity
level renders the person confused and difficult to understand) was Low Average. Ethan's score on Resentment (increasing
tendency to attribute any misfortunes to the neglect of others and to discredit the successes of others as being the
result of luck or favoritism) was Low Average. Ethan's score on Psychotic Experiences (person may strike others as
peculiar and eccentric) was Low Average. Ethan's score on Anxiety (reflecting a generalized impairment associated with
anxiety) was Below Average. Ethan's score on Affective (A) (high scorers experience a great deal of tension, have
difficulty with relaxing and tend to be easily fatigued as a result of high-perceived stress) was Below Average. Ethan's
score on Physiological (D) (elevations suggest a change in level of physical functioning, typically with a disturbance
in sleep pattern, a decrease in energy and level of sexual interest and a loss of appetite and/or weight loss) was Below
Average. Ethan's score on Schizophrenia (associated with an active schizophrenic episode) was Below Average. Ethan's
score on Aggressive Attitude (suggest an individual who is easily angered and frustrated; others may perceive him as
hostile and readily provoked) was Below Average. Ethan's score on Antisocial Behaviors (scores suggest a history of
difficulties with authority and with social convention) was Average. Ethan's score on Egocentricity (suggest a person
who tends to be self-centered and pragmatic in interaction with others) was Average. Ethan's score on Antisocial
Features (individuals are likely to be impulsive and hostile, perhaps with a history of reckless and/or antisocial acts)
was Average. Ethan's score on Negative Relationships (person is likely to be bitter and resentful about the way past
relationships have gone) was Average. Ethan's score on Stimulus-Seeking (patient is likely to manifest behavior that is
reckless and potentially dangerous to himself and/or those around him) was Average. Ethan's score on Self-Harm (reflect
levels of impulsivity and recklessness that become more hazardous as scores rise) was Average. Ethan's score on
Borderline Features (behaviors typically associated with borderline personality disorder) was Low Average. Ethan's score
on Identity Problems (suggest uncertainty about major life issues and difficulties in developing and maintaining a sense
of purpose) was Low Average. Ethan's score on Affective Instability (a propensity to experience a particular negative
affect (anxiety, depression, or anger is the typical response)) was Low Average.

```{r}
#| label: setup-emotion
#| include: false

# Filter by domain
domains <- c("Personality Disorders")

# Target phenotype
pheno <- "emotion"

# Read the data file into a data frame
file_ext <- tools::file_ext("data/neurobehav.parquet")
if (file_ext == "parquet") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Parquet files.")
  }
  emotion <- arrow::read_parquet("data/neurobehav.parquet")
} else if (file_ext == "feather") {
  # Check if arrow package is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required to read Feather files.")
  }
  emotion <- arrow::read_feather("data/neurobehav.parquet")
} else {
  # Default to CSV for other formats
  emotion <- readr::read_csv("data/neurobehav.parquet")
}
```

= SUMMARY/IMPRESSION
<sec-sirf>
#let domain(file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  figure(
    [#image(file_fig, width: 85%)],
    placement: none,
    caption: figure.caption(position: bottom, [Overall neurocognitive function subdomain plots of the patient's
      strengths and weaknesses. _Note:_ _z_-scores have a mean of 0 and a standard deviation of 1.]),
    kind: "image",
    supplement: [Figure],
    gap: 0.5em,
  )
}
#let file_fig = "fig_sirf_overall.svg"
#domain(file_fig)
== Overall Evaluation Interpretation
<overall-evaluation-interpretation>
Neuropsychological evaluation revealed a pattern of cognitive strengths and weaknesses characterized by below-average
overall neuropsychological functioning. Notable strengths emerged in visuoperceptual processing and visuoconstructional
abilities, where performance reached the high average range for focused spatial tasks. The patient demonstrated average
capabilities in basic judgment, decision-making, and orientation to person, place, time, and situation.

== Diagnostic Impression
<diagnostic-impression>
- 294.11 (F02.81) Major Neurocognitive Disorder Due to Another Medical Condition, Moderate, With behavioral disturbance
- 8A68.4 Generalized tonic-clonic seizure
- V61.10 (Z63.0) Relational Problems

== Mental Health Diversion: Contextual Analysis and Interpretation
<mental-health-diversion-contextual-analysis-and-interpretation>
#emph[\1. Does the defendant suffer from any mental disorders as identified in the most recent edition of the Diagnostic
  and Statistical Manual of Mental Disorders (DSM)?]

Yes, the defendant meets the criteria for multiple mental disorders as defined by DSM-5.

#emph[\2. Were any mental disorders a motivating, causal, or contributing factor to the defendant's involvement in the
  commission of the offense?]

Yes, causal.

#emph[\3. If any mental disorders were significant factors in the commission of the offense, would the defendant's
  symptoms of those mental disorders respond to treatment?]

Yes. The defendant's symptoms related to cognitive impairment and mood problems would respond well to treatment.

#emph[\4. Does the defendant agree to comply with treatment as a condition of diversion?]

Yes, the defendant agreed to comply with treatment as a condition of diversion.

#emph[\5. Would the defendant pose an unreasonable risk of danger to public safety (under the meaning of California
  Penal Code 1001.36), if treated in the community?]

The defendant would not pose "an unreasonable risk of danger to public safety" under the meaning of California Penal
Code 1001.36, if treated in the community.

= RECOMMENDATIONS
<sec-recs>
== Recommendations for Medical/Healthcare
<recommendations-for-medicalhealthcare>
- Biggie should receive interventions to enhance concentration, manage anxiety, and improve emotional understanding.
  This includes social skills training, psychoeducational interventions for self-image improvement, and monitoring for
  signs of internalization or externalization of problems.

- #strong[Cognitive Behavioral Therapy (CBT):] To develop strategies for improving executive functions and addressing
  self-esteem issues.

- #strong[Occupational Therapy:] To enhance graphomotor skills for academic tasks and daily activities.

- #strong[Cognitive Training:] Techniques to boost working memory and attention, along with strategies to improve focus.

- #strong[Speech-Language Therapy:] Working with a speech-language pathologist can help improve memory skills,
  particularly for verbal material.

- #strong[Psychoeducation:] To empower Biggie with self-awareness and enable his to advocate for his needs in various
  settings.

- Additional support is recommended in areas like attentional function, processing speed, and cognitive efficiency. This
  can be achieved through occupational therapy, the use of organizational tools, and creating a distraction-free
  environment.

- Treatment options for ADHD should include behavioral techniques, stimulant medication consideration, environmental
  organization, and long-term perspective maintenance. Medical treatment discussion with a child and adolescent
  psychiatrist could be beneficial.

- Additional support is suggested in areas like auditory comprehension and complex figure copying. This can be
  accomplished through speech-language pathology and occupational therapy respectively. Use of visual aids and breaking
  down complex tasks into smaller steps can also be helpful.

== Recommendations for School
<recommendations-for-school>
- #strong[Accommodated Testing:] Extended time accommodations are recommended due to relative weakness in processing
  speed and academic fluency.

- #strong[Calculator Use:] Please consider allowing Biggie to utilize a calculator for class assignments and
  examinations as he progresses in the mathematics curriculum.

- Biggie should receive additional support in mathematics through:

  - Individual or small group tutoring.
  - Visual aids and hands-on activities.
  - Technology-based learning tools.
  - Real-life math scenarios practice.
  - Extra time for math-related tasks.

- Support within the educational setting, such as an individualized education plan (IEP) or 504 Plan, to address
  attentional/executive challenges. Academic accommodations should include extended time on tests, reduced copying from
  the board, or a note-taker to offset slower psychomotor speed and attentional challenges.

- #strong[Adaptive Writing Tools:] Use of ergonomic pens or pencil grips for better control and fewer errors.

- #strong[Graphomotor Exercises:] Drawing or tracing exercises for improved fine motor coordination.

- #strong[Extra Time for Written Tasks:] Additional time for tasks requiring writing to compensate for slower
  graphomotor speed.

- #strong[Technology Use:] Keyboard or voice-to-text software use to mitigate graphomotor weaknesses' effect on academic
  performance.

- Tutoring or teaching assistance is recommended for improving his sentence level writing fluency and overall academic
  fluency in reading, math, and writing.

- A supportive environment at home and school involving clear instructions, task breakdown into smaller steps, and
  praise for efforts and achievements.

== Recommendations for Home
<recommendations-for-home>
- #strong[Mnemonic Devices:] Use of mnemonic strategies like acronyms or visual images for memory retention.

- #strong[Organizational Strategies:] Note-taking, list-making, and visual schedules can provide external memory
  support.

- #strong[Task Simplification:] Break down complex information into smaller, manageable parts for effective processing
  and remembering.

- #strong[Repeated Exposure and Practice:] Repeated exposure to material and additional practice are beneficial due to
  below-average learning efficiency.

- #strong[Set Reminders:] Use calendars, alarms, written notes, and lists for task reminders.

- #strong[Mindfulness Training:] Technique to ignore distracting thoughts and concentrate on the task at hand, aiding in
  cognitive control.

== Recommendations for Follow-Up Evaluation
<recommendations-for-follow-up-evaluation>
- A follow-up assessment in 12-18 months is suggested to measure progress and assess the interventions' impact, unless
  urgent concerns arise. Continuous monitoring and reassessment are vital to adjust support as Biggie develops and his
  needs change.

It was a pleasure to work with Mr. Smalls. I am available to provide further information or clarification as needed.

Sincerely,

Thank you for considering this report in your evaluation of Mr. Smalls. I am available to provide further information or
clarification as needed.

Respectfully submitted,

#align(left)[#box(image("inst/resources/img/jwt_sig.png", width: 7em))]
#v(2em, weak: true)
#show block: set par(leading: 0.65em)
#block[
  *Joey W. Trampush, Ph.D.* \
  Chief Neuropsychologist \
  Brainworkup Neuropsychology, LLC \
  Assistant Professor \
  Department of Psychiatry and the Behavioral Sciences \
  Keck School of Medicine of USC \
  CA License No. PSY29212
]
= APPENDIX
== Test Selection Procedures
<test-selection-procedures>
Neuropsychological tests are performance-based, and cognitive performance is summarized above. Cultural considerations
were made in selecting measures, interpreting results, and making diagnostic impressions and recommendations. Test
scores are reported in comparison to same-age and sex/gender peers, with labels (e.g., Below Average, Average, Above
Average; (Guilmette et al., 2020)), intended to be descriptive, not diagnostic. Standardized scores provide important
context, but do not alone lead to accurate diagnosis or treatment recommendations.

== Conversion of Test Scores
<conversion-of-test-scores>
#import "@preview/tablem:0.2.0": tablem, three-line-table

#set text(10pt)
#let three-line-table = tablem.with(render: (columns: auto, ..args) => {
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (col, row) => if row == 0 { center + horizon } else if col == 0 { left + horizon } else { center + horizon },
    table.hline(y: 0),
    table.hline(y: 1),
    ..args,
    table.hline(),
  )
})

#three-line-table[
  |*Range*|*Standard Score*|*_T_ Score*|*Scaled Score*|*z-Score*|*Percentile (‰)*| |---|---|---|---|---|---|
  |Exceptionally high score|130 +|70 +|16 +|2 +|98 +| |Above average score|120 – 129|63 – 69|14 – 15|1.3 – 1.9|91 – 97|
  |High average score|110 – 119|57 – 62|12 – 13|0.7 – 1.2|75 – 90| |Average score|90 – 109|44 – 56|9 – 11|-0.7 – 0.6|25
  – 74| |Low average score|80 – 89|37 – 43|7 – 8|-1.3 – -0.6|9 – 24| |Below average score|70 – 79|30 – 36|4 – 6|-2
  – -1.4|2 – 8| |Exceptionally low score|< 70|< 30|< 4|< -2|< 2|
]
#block[
  #block[
    Guilmette, T. J., Sweet, J. J., Hebben, N., Koltai, D., Mahone, M. E., Spiegler, B. J., Stucky, K., Westerveld, M.,
    & Conference Participants. (2020). American Academy of Clinical Neuropsychology consensus conference statement on
    uniform labeling of performance test scores. #emph[The Clinical Neuropsychologist];, #emph[34];(3), 437--453. #link("https://doi.org/10.1080/13854046.2020.1722244")

  ] <ref-guilmetteAmericanAcademyClinical2020>
] <refs>
