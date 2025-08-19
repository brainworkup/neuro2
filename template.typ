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
  name: [Smalls, Biggie],
  doe: [YYYY-MM-DD],
  patient: [Biggie],
  paper: "us-letter",
  body-font: ("IBM Plex Serif"),
  sans-font: ("IBM Plex Sans"),
  fontsize: 12pt,
)

#let case_number = [123456]
#let name = [Smalls, Biggie]
#let doe = [2025-01-20]
#let patient = [Biggie]
#v(2em, weak: true)
#show block: set par(leading: 0.65em)
#block[
*CASE NUMBER:* #case_number \
*PATIENT NAME:* #name \
*DATE OF BIRTH:* YYYY-MM-DD, Age 13 \
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
- Wechsler Adult Intelligence Scale, 4th ed (WAIS-IV): Similarities, Matrix Reasoning, Letter-Number Sequencing, Coding, Symbol Search, Digit Span, Vocabulary, Block Design, Figure Weights, Arithmetic, Cancellation
- Wechsler Adult Intelligence Scale, 5th ed (WAIS-5)
- Wechsler Individual Achievement Test, 4th ed (WIAT-4)
- Wechsler Individual Achievement Test, 4th ed (WIAT-4): Word Reading, Reading Comprehension, Pseudoword Decoding, Orthographic Fluency, Decoding Fluency
- Wechsler Memory Scale, 4th ed (WMS-4)
- Wechsler Memory Scale, 4th ed (WMS-4): Logical Memory, Verbal Paired Associates, Visual Reproduction, Visual Paired Associates, Designs, Spatial Addition, Symbol Span, Spatial Span
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
- Wechsler Individual Achievement Test, 4th ed (WIAT-4): Word Reading, Reading Comprehension, Pseudoword Decoding, Orthographic Fluency, Decoding Fluency
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
- Personality Assessment Inventory, Adolescent (PAI Adolescent)
= NEUROBEHAVIORAL STATUS EXAM
<neurobehavioral-status-exam>
== Reason for Referral
<reason-for-referral>
Biggie Smalls is a 13-year-old, rightright-handed research assistant with 10 years years of education, including a B.A. in Hustling from the University of Bed-Sty. He was referred in order to determine the nature and extent of neurocognitive sequelae emerging from a history of attention-deficit/hyperactivity disorder (ADHD).

The purpose of the current evaluation is ADHD, anxiety, and depression. This report is based on a review of available medical records and information gathered across multiple days of evaluation. Treatment planning and plans for test accommodations were discussed with Biggie during the feedback visit on the final day of the examination.

== Background/History
<backgroundhistory>
=== Developmental/Medical History
<developmentalmedical-history>
Biggie was born full-term with no reported complications during pregnancy or delivery. His early development included some notable features: bed-wetting beyond typical age (with no identified medical cause), difficulties with frustration tolerance when learning new physical skills, and early motor coordination issues described as appearing "a bit floppy when he ran or was active," which reportedly improved during his high school years.

His medical history includes mild asthma (more significant in childhood), an appendectomy, allergy to Mesquite trees, and vision impairment for which he was prescribed contacts but does not wear them. Biggie experienced a fever above 104° at age 13. He was diagnosed with ADHD in elementary school and prescribed medication, which he refused due to disliking "the feeling." He is currently unmedicated and has no history of psychological counseling or psychiatric evaluation. Biggie is right-handed for all activities and typically visits a physician approximately twice yearly, with his last medical visit approximately one year ago.

=== Behavioral/Emotional/Social
<behavioralemotionalsocial>
Biggie is described as having "a big heart," being "fun to be with," and "very social." He demonstrates leadership qualities in peer group interactions but exhibits significant behavioral challenges, including reactive anger when challenged or insulted and a history of fighting when provoked. According to reports, "Most of the time, it is not he who causes the issue, but he is quick to fight if challenged." He associates with peers who reportedly use illegal drugs and alcohol.

Behaviorally, Biggie exhibits overstimulation in play, a short attention span consistent with his ADHD diagnosis, and emotional withholding (difficulty expressing affection and feelings). His interests center around football, boxing, and video games, particularly online gaming with friends. There has been no recent decline in his participation in preferred activities.

=== Family History
<family-history>
Biggie currently resides with his father in an apartment, where he has lived for the past 1.5 years. His parents separated when he was an infant. His mother, NAME, is unemployed with some college education. His father, NAME, is a self-employed executive who completed 11th grade. Biggie has no siblings.

While reportedly closer to his father, Biggie "has a good relationship with mom too." The father serves as the primary disciplinarian with a "more strict" approach, while the mother maintains "more of a friend style relationship." Discipline techniques include grounding and suspension of preferred activities, though Biggie "tends to listen with an attitude." Family activities include sports, conversations, and trips, with English as the primary language spoken at home. He sees his grandparents only a "Few Times a Year."

Significant family health history includes the father's intermittent stress-related hypertension and the mother's "problem with alcohol." Notably, both parents had ADHD, with the mother having taken Ritalin during her school years, suggesting a strong genetic component to Biggie's own ADHD diagnosis.

=== Educational History
<educational-history>
Biggie is currently in 10th grade at Home School, having transitioned from NAME High School by choice in 2024. His academic performance has improved in the homeschool setting, where he now earns mostly B's with one A. His educational history includes grade retention in elementary school and consistently performing below grade level on academic testing.

He has demonstrated specific difficulties with mathematics, described as being unable to "comprehend complicated, long math problems" and having "a hard time retaining information." Biggie has been evaluated for special education annually since 5th grade and currently has an active Individualized Education Program (IEP) with an ADHD diagnosis. His homeschool curriculum includes adaptations such as "business math instead of algebra." His anticipated graduation is in 2027.

While the father reports satisfaction with the current educational arrangement, he expresses concern about the lack of opportunity for school sports participation, which he believes "would have been very good for him" and might have prevented Biggie from associating with "kids that were trouble and not athletes."

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
#pagebreak()
= SUMMARY/IMPRESSION
<sec-sirf>
#let domain(file_fig) = {
  let font = (font: "Roboto Slab", size: 0.7em)
  set text(..font)
  figure(
    [#image(file_fig, width: 85%)],
    placement: none,
    caption: figure.caption(
      position: bottom,
      [Overall neurocognitive function subdomain plots of the patient's strengths and weaknesses. _Note:_ _z_-scores have a mean of 0 and a standard deviation of 1.],
    ),
    kind: "image",
    supplement: [Figure],
    gap: 0.5em,
  )
}

#let file_fig = "fig_sirf_overall.svg"
#domain(file_fig)
== Overall Evaluation Interpretation
<overall-evaluation-interpretation>
Neuropsychological evaluation revealed a pattern of cognitive strengths and weaknesses characterized by below-average overall neuropsychological functioning. Notable strengths emerged in visuoperceptual processing and visuoconstructional abilities, where performance reached the high average range for focused spatial tasks. The patient demonstrated average capabilities in basic judgment, decision-making, and orientation to person, place, time, and situation.

== Diagnostic Impression
<diagnostic-impression>
- 294.11 (F02.81) Major Neurocognitive Disorder Due to Another Medical Condition, Moderate, With behavioral disturbance
- 8A68.4 Generalized tonic-clonic seizure
- V61.10 (Z63.0) Relational Problems

== Mental Health Diversion: Contextual Analysis and Interpretation
<mental-health-diversion-contextual-analysis-and-interpretation>
#emph[\1. Does the defendant suffer from any mental disorders as identified in the most recent edition of the Diagnostic and Statistical Manual of Mental Disorders (DSM)?]

Yes, the defendant meets the criteria for multiple mental disorders as defined by DSM-5.

#emph[\2. Were any mental disorders a motivating, causal, or contributing factor to the defendant's involvement in the commission of the offense?]

Yes, causal.

#emph[\3. If any mental disorders were significant factors in the commission of the offense, would the defendant's symptoms of those mental disorders respond to treatment?]

Yes. The defendant's symptoms related to cognitive impairment and mood problems would respond well to treatment.

#emph[\4. Does the defendant agree to comply with treatment as a condition of diversion?]

Yes, the defendant agreed to comply with treatment as a condition of diversion.

#emph[\5. Would the defendant pose an unreasonable risk of danger to public safety (under the meaning of California Penal Code 1001.36), if treated in the community?]

The defendant would not pose "an unreasonable risk of danger to public safety" under the meaning of California Penal Code 1001.36, if treated in the community.

= RECOMMENDATIONS
<sec-recs>
== Recommendations for Medical/Healthcare
<recommendations-for-medicalhealthcare>
- Biggie should receive interventions to enhance concentration, manage anxiety, and improve emotional understanding. This includes social skills training, psychoeducational interventions for self-image improvement, and monitoring for signs of internalization or externalization of problems.

- #strong[Cognitive Behavioral Therapy (CBT):] To develop strategies for improving executive functions and addressing self-esteem issues.

- #strong[Occupational Therapy:] To enhance graphomotor skills for academic tasks and daily activities.

- #strong[Cognitive Training:] Techniques to boost working memory and attention, along with strategies to improve focus.

- #strong[Speech-Language Therapy:] Working with a speech-language pathologist can help improve memory skills, particularly for verbal material.

- #strong[Psychoeducation:] To empower Biggie with self-awareness and enable his to advocate for his needs in various settings.

- Additional support is recommended in areas like attentional function, processing speed, and cognitive efficiency. This can be achieved through occupational therapy, the use of organizational tools, and creating a distraction-free environment.

- Treatment options for ADHD should include behavioral techniques, stimulant medication consideration, environmental organization, and long-term perspective maintenance. Medical treatment discussion with a child and adolescent psychiatrist could be beneficial.

- Additional support is suggested in areas like auditory comprehension and complex figure copying. This can be accomplished through speech-language pathology and occupational therapy respectively. Use of visual aids and breaking down complex tasks into smaller steps can also be helpful.

== Recommendations for School
<recommendations-for-school>
- #strong[Accommodated Testing:] Extended time accommodations are recommended due to relative weakness in processing speed and academic fluency.

- #strong[Calculator Use:] Please consider allowing Biggie to utilize a calculator for class assignments and examinations as he progresses in the mathematics curriculum.

- Biggie should receive additional support in mathematics through:

  - Individual or small group tutoring.
  - Visual aids and hands-on activities.
  - Technology-based learning tools.
  - Real-life math scenarios practice.
  - Extra time for math-related tasks.

- Support within the educational setting, such as an individualized education plan (IEP) or 504 Plan, to address attentional/executive challenges. Academic accommodations should include extended time on tests, reduced copying from the board, or a note-taker to offset slower psychomotor speed and attentional challenges.

- #strong[Adaptive Writing Tools:] Use of ergonomic pens or pencil grips for better control and fewer errors.

- #strong[Graphomotor Exercises:] Drawing or tracing exercises for improved fine motor coordination.

- #strong[Extra Time for Written Tasks:] Additional time for tasks requiring writing to compensate for slower graphomotor speed.

- #strong[Technology Use:] Keyboard or voice-to-text software use to mitigate graphomotor weaknesses' effect on academic performance.

- Tutoring or teaching assistance is recommended for improving his sentence level writing fluency and overall academic fluency in reading, math, and writing.

- A supportive environment at home and school involving clear instructions, task breakdown into smaller steps, and praise for efforts and achievements.

== Recommendations for Home
<recommendations-for-home>
- #strong[Mnemonic Devices:] Use of mnemonic strategies like acronyms or visual images for memory retention.

- #strong[Organizational Strategies:] Note-taking, list-making, and visual schedules can provide external memory support.

- #strong[Task Simplification:] Break down complex information into smaller, manageable parts for effective processing and remembering.

- #strong[Repeated Exposure and Practice:] Repeated exposure to material and additional practice are beneficial due to below-average learning efficiency.

- #strong[Set Reminders:] Use calendars, alarms, written notes, and lists for task reminders.

- #strong[Mindfulness Training:] Technique to ignore distracting thoughts and concentrate on the task at hand, aiding in cognitive control.

== Recommendations for Follow-Up Evaluation
<recommendations-for-follow-up-evaluation>
- A follow-up assessment in 12-18 months is suggested to measure progress and assess the interventions' impact, unless urgent concerns arise. Continuous monitoring and reassessment are vital to adjust support as Biggie develops and his needs change.

It was a pleasure to work with Mr. Smalls. I am available to provide further information or clarification as needed.

Sincerely,

Thank you for considering this report in your evaluation of Mr. Smalls. I am available to provide further information or clarification as needed.

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
<appendix>
== Test Selection Procedures
<test-selection-procedures>
Neuropsychological tests are performance-based, and cognitive performance is summarized above. Cultural considerations were made in selecting measures, interpreting results, and making diagnostic impressions and recommendations. Test scores are reported in comparison to same-age and sex/gender peers, with labels (e.g., Below Average, Average, Above Average; (Guilmette et al., 2020)), intended to be descriptive, not diagnostic. Standardized scores provide important context, but do not alone lead to accurate diagnosis or treatment recommendations.

== Conversion of Test Scores
<conversion-of-test-scores>
#import "@preview/tablem:0.2.0": tablem, three-line-table

#set text(10pt)
#let three-line-table = tablem.with(
  render: (columns: auto, ..args) => {
    table(
      columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr),
      align: (col, row) =>
            if row == 0 { center + horizon }
            else if col == 0 { left + horizon }
            else { center + horizon },
      table.hline(y: 0),
      table.hline(y: 1),
      ..args,
      table.hline(),
    )
  }
)

#three-line-table[
|*Range*|*Standard Score*|*_T_ Score*|*Scaled Score*|*z-Score*|*Percentile (‰)*|
|---|---|---|---|---|---|
|Exceptionally high score|130 +|70 +|16 +|2 +|98 +|
|Above average score|120 – 129|63 – 69|14 – 15|1.3 – 1.9|91 – 97|
|High average score|110 – 119|57 – 62|12 – 13|0.7 – 1.2|75 – 90|
|Average score|90 – 109|44 – 56|9 – 11|-0.7 – 0.6|25 – 74|
|Low average score|80 – 89|37 – 43|7 – 8|-1.3 – -0.6|9 – 24|
|Below average score|70 – 79|30 – 36|4 – 6|-2 – -1.4|2 – 8|
|Exceptionally low score|< 70|< 30|< 4|< -2|< 2|
]
#block[
#block[
Guilmette, T. J., Sweet, J. J., Hebben, N., Koltai, D., Mahone, M. E., Spiegler, B. J., Stucky, K., Westerveld, M., & Conference Participants. (2020). American Academy of Clinical Neuropsychology consensus conference statement on uniform labeling of performance test scores. #emph[The Clinical Neuropsychologist];, #emph[34];(3), 437--453. #link("https://doi.org/10.1080/13854046.2020.1722244")

] <ref-guilmetteAmericanAcademyClinical2020>
] <refs>



