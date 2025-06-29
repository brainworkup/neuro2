---
title: NEUROCOGNITIVE EXAMINATION
patient: Biggie
name: Smalls, Biggie
date_of_report: last-modified
---





```{=typst}
#let name = [{{< var last_name >}}, {{< var first_name >}}]
#let doe = [{{< var date_of_report >}}]
#let patient = [{{< var patient >}}]
// #v(2em, weak: true)
// #show block: set par(leading: 0.65em)
#block[
*PATIENT NAME:* #name \
*DATE OF BIRTH:* {{< var dob >}}, Age {{< var age >}} \
*DATES OF EXAM:* {{< var doe >}}, {{< var doe2 >}}, and {{< var doe3 >}} \
*DATE OF REPORT*: {{< var date_of_report >}} \
]
```

# TESTS ADMINISTERED


::: {.cell}
::: {.cell-output .cell-output-stdout}

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


:::
:::





# NEUROBEHAVIORAL STATUS EXAM

## Reason for Referral

{{< var mr_mrs >}} {{< var last_name >}}, a {{< var age >}}-year-old {{< var handedness >}}-handed {{< var sex >}}, was referred for comprehensive neuropsychological evaluation in the context of [forensic proceedings]. The evaluation was requested to assess cognitive functioning and determine any neurocognitive factors relevant to the current legal matter.

## Background Information

[To be completed based on clinical interview and records review]

## Mental Status/Behavioral Observations

• **Orientation**: Alert and oriented to person, place, time, and situation
• **Appearance**: Appropriately groomed and dressed
• **Behavior**: Cooperative and engaged throughout testing
• **Speech**: Fluent with normal rate and prosody
• **Mood/Affect**: Euthymic with appropriate range
• **Effort**: Adequate effort demonstrated on validity measures




## Behavioral Observations

{{< var patient >}} presented as alert and oriented to person, place, time, and situation. {{< var he_she_cap >}} was appropriately dressed and groomed, and appeared {{< var his_her >}} stated age of {{< var age >}} years. {{< var he_she_cap >}} was cooperative throughout the evaluation and appeared to put forth adequate effort on all tasks.

### Mental Status

- **Attention/Orientation**: Fully oriented ×4 (person, place, time, situation)
- **Appearance**: Well-groomed, appropriately dressed
- **Behavior/Attitude**: Cooperative, engaged, appropriate eye contact
- **Speech/Language**: Fluent, normal rate and prosody
- **Mood/Affect**: Euthymic mood with congruent affect
- **Thought Process**: Linear, goal-directed
- **Thought Content**: No evidence of delusions or hallucinations
- **Insight/Judgment**: Fair to good
- **Effort/Validity**: Adequate effort demonstrated on embedded validity measures



# NEUROCOGNITIVE FINDINGS

## General Cognitive Ability {#sec-iq}

<summary>

Testing of general cognitive ability revealed overall average performance (mean percentile = 51).

</summary>

















```{=typst}
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
```

```{=typst}
// Define the title of the domain
#let title = "General Cognitive Ability"

// Define the file name of the table
#let file_qtbl = "table_iq.png"

// Define the file name of the figure
#let file_fig = "fig_iq_subdomain.svg"

// The title is appended with ' Index Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
```

<!-- ```{=typst}
// Define the title of the domain
#let title = "General Cognitive Ability"

// Define the file name of the table
#let file_qtbl = "table_iq.png"

// Define the file name of the figure
#let file_fig = "fig_iq_narrow.svg"

// The title is appended with ' Index Scores'
#domain(title: [#title Scores], file_qtbl, file_fig)
``` -->



## Academic Skills {#sec-academics}

<summary>

Testing of academic skills revealed overall high average performance (mean percentile = 78).

</summary>

















```{=typst}
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
```

```{=typst}
#let title = "Academic Skills"
#let file_qtbl = "table_academics.png"
#let file_fig = "fig_academics_subdomain.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig,
  )
```


```{=typst}
#let title = "Academic Skills"
#let file_qtbl = "table_academics.png"
#let file_fig = "fig_academics_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig,
  )
```



## Verbal/Language {#sec-verbal}

<summary>

Testing of verbal/language revealed overall average performance (mean percentile = 41).

</summary>

















```{=typst}
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
```
```{=typst}
#let title = "Verbal/Language"
#let file_qtbl = "table_verbal.png"
#let file_fig = "fig_verbal_subdomain.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
)
```
```{=typst}
#let title = "Verbal/Language"
#let file_qtbl = "table_verbal.png"
#let file_fig = "fig_verbal_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
)
```



## Visual Perception/Construction {#sec-spatial}

<summary>

Testing of visual perception/construction revealed overall average performance (mean percentile = 50).

</summary>

















```{=typst}
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
```

```{=typst}
#let title = "Visual Perception/Construction"
#let file_qtbl = "table_spatial.png"
#let file_fig = "fig_spatial.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
)
```



## Memory {#sec-memory}

<summary>

Testing of memory revealed overall average performance (mean percentile = 55).

</summary>

















```{=typst}
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
```

<!-- ```{=typst}
#let title = "Memory"
#let file_qtbl = "table_memory.png"
#let file_fig = "fig_memory_subdomain.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
  )
``` -->

```{=typst}
#let title = "Memory"
#let file_qtbl = "table_memory.png"
#let file_fig = "fig_memory_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
  )
```



## Attention/Executive {#sec-executive}

<summary>

Testing of attention/executive revealed overall average performance (mean percentile = 53).

</summary>

















```{=typst}
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
```

<!-- ```{=typst}
#let title = "Attention/Executive"
#let file_qtbl = "table_executive.png"
#let file_fig = "fig_executive_subdomain.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
  )
``` -->

```{=typst}
#let title = "Attention/Executive"
#let file_qtbl = "table_executive.png"
#let file_fig = "fig_executive_narrow.svg"
#domain(
  title: [#title Scores],
  file_qtbl,
  file_fig
  )
```



## ADHD/Executive Function {#sec-adhd}



















### SELF-REPORT

<summary>



</summary>
- Self-reported Negative Self-Concept (i.e., poor social relationships, low self-esteem and self confidence) was Exceptionally High.

Corey's score on Inattention (INATTN) Index () was Exceptionally High.
#NAME?
- Self-reported ADHD Inattentive Symptoms (i.e., behave in a manner consistent with the DSM-5 Inattentive Presentation of ADHD) was Above Average.

- Self-reported Inattention/Executive Dysfunction (i.e., trouble concentrating, difficulty planning or completing tasks, forgetfulness, absent-mindedness, being disorganized) was Above Average.

- Self-reported Total ADHD Symptoms (i.e., behave in a manner consistent with the DSM-5 diagnostic criteria for Combined Presentation of ADHD) was Above Average.

- Self-reported CAARS 2-ADHD Index (i.e., a composite indicator for identifying individuals 'at-risk' for ADHD) indicated a probability of 88% of having adult ADHD.

#NAME?
- Self-reported ADHD Hyperactive/Impulsive Symptoms (i.e., behave in a manner consistent with the DSM-5 Hyperactive-Impulsive Presentation of ADHD) was High Average.

#NAME?
#NAME?
#NAME?
#NAME?
#NAME?
#NAME?
#NAME?
#NAME?
- AJ's overall level of executive functioning was Low Average.
#NAME?
- Inhibitory Control (i.e., control behavior or impulses, including thinking about consequences before acting, maintaining self-control, and thinking before speaking) was Below Average



```{=typst}
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
```
```{=typst}
#let title = "ADHD/Executive Function Self Ratings"
#let file_qtbl = "table_adhd_self.png"
#let file_fig = "fig_adhd_self.svg"
#domain(
  title: [#title],
  file_qtbl,
  file_fig
  )
```
<!-- ### OBSERVER RATINGS -->

<!-- {{< include _02-09_adhd_adult_text_observer.qmd >}} -->

````{=html}
<!-- ```{=typst}
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
      supplement: [Table],
    ),
    figure(
      [#image(file_fig)],
      caption: figure.caption(
        position: bottom,
        [
          Observer-report of the patient's ADHD symptoms and executive functioning in daily life.
        ],
      ),
      placement: none,
      kind: "image",
      supplement: [Figure],
      gap: 0.5em,
    ),
  )
}
``` -->
````

````{=html}
<!-- ```{=typst}
#let title = "ADHD Observer Ratings"
#let file_qtbl = "table_adhd_observer.png"
#let file_fig = "fig_adhd_observer.svg"
#domain(title: [#title], file_qtbl, file_fig)
``` -->
````



## Emotional/Behavioral/Personality {#sec-emotion}

<summary>

summary of PAI ...

</summary>
Corey's score on Anxiety
(reflecting a generalized impairment associated with anxiety) was Exceptionally High.
Corey's score on Physiological (A)
(high scorers my not psychologically experience themselves as anxious, but show physiological signs that most people associate with anxiety) was Exceptionally High.
Corey's score on Depression
(person feels hopeless, discouraged and useless) was Exceptionally High.
Corey's score on Cognitive (D)
(a higher scorer is likely to report feeling hopeless and as having failed at most important life tasks) was Exceptionally High.
Corey's score on Affective (D)
(elevations suggest sadness, a loss of interest in normal activities and a loss if one's sense of pleasure in things that were previously enjoyed) was Exceptionally High.
Corey's score on Physiological (D)
(elevations suggest a change in level of physical functioning, typically with a disturbance in sleep pattern, a decrease in energy and level of sexual interest and a loss of appetite and/or weight loss) was Exceptionally High.
Corey's score on Activity Level
(this activity level renders the person confused and difficult to understand) was Exceptionally High.
Corey's score on Thought Disorder
(suggest problems in concentration and decision-making) was Exceptionally High.
Corey's score on Identity Problems
(suggest uncertainty about major life issues and difficulties in developing and maintaining a sense of purpose) was Exceptionally High.
Corey's score on Cognitive (A)
(elevations indicate worry and concern about current (often uncontrollable) issues that compromise the person's ability to concentrate and attend) was Exceptionally High.
Corey's score on Borderline Features
(behaviors typically associated with borderline personality disorder) was Exceptionally High.
Corey's score on Affective (A)
(high scorers experience a great deal of tension, have difficulty with relaxing and tend to be easily fatigued as a result of high-perceived stress) was Above Average.
Corey's score on Affective Instability
(a propensity to experience a particular negative affect (anxiety, depression, or anger is the typical response)) was Above Average.
Corey's score on Suicidal Ideation
(scores are typically of an individual who is seen in clinical settings) was Above Average.
Corey's score on Phobias
(indicate impairing phobic behaviors, with avoidance of the feared object or situation) was Above Average.
Corey's score on Schizophrenia
(associated with an active schizophrenic episode) was Above Average.
Corey's score on Anxiety-Related Disorders
(reflecting multiple anxiety-disorder diagnoses and broad impairment associated with anxiety) was Above Average.
Corey's score on Traumatic Stress
(trauma (single or multiple) is the overriding focus of the person's life) was High Average.
Corey's score on Somatization
(high scorers describe general lethargy and malaise, and the presentation is one of complaintiveness and dissatisfaction) was High Average.
Corey's score on Negative Relationships
(person is likely to be bitter and resentful about the way past relationships have gone) was High Average.
Corey's score on Resentment
(increasing tendency to attribute any misfortunes to the neglect of others and to discredit the successes of others as being the result of luck or favoritism) was Average.
Corey's score on Somatic Complaints
(degree of concern about physical functioning and health matters and the extent of perceived impairment arising from somatic symptoms) was Average.
Corey's score on Self-Harm
(reflect levels of impulsivity and recklessness that become more hazardous as scores rise) was Average.
Corey's score on Nonsupport
(social relationships are perceived as offering little support - family relationships may be either distant or combative, whereas friends are generally seen as unavailable or not helpful when needed) was Average.
Corey's score on Obsessive-Compulsive
(scores marked rigidity and significant ruminative concerns) was Average.
Corey's score on Warmth
(average scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to tolerate close attachment but also capable of maintaining some distance in relationships as needed) was Average.
Corey's score on Health Concerns
(elevations indicate a poor health may be a major component of the self-image, with the person accustomed to being in the patient role) was Average.
Corey's score on Psychotic Experiences
(person may strike others as peculiar and eccentric) was Average.
Corey's score on ALC Estimated Score
() was Average.
Corey's score on Conversion
(moderate elevations may be seen in neurological disorders with CNS impairment involving sensorimotor problems, MS, CVA/stroke, or neuropsychological associated with chronic alcoholism) was Average.
Corey's score on Social Detachment
(reflects a person who neither desires nor enjoys the meaning to personal relationships) was Average.
Corey's score on Physical Aggression
(suggest that losses of temper are more common and that the person is prone to more physical displays of anger, perhaps breaking objects or engaging in physical confrontations) was Average.
Corey's score on Hypervigilance
(suggest a person who is pragmatic and skeptical in relationships) was Average.
Corey's score on Drug Problems
(scores are indicative of a person who may use drugs on a fairly regular basis and may have experienced some adverse consequences as a result) was Average.
Corey's score on Paranoia
(individuals are likely to be overtly suspicious and hostile) was Average.
Corey's score on DRG Estimated Score
() was Average.
Corey's score on Mania
(scores are associated with disorders such as mania, hypomania, or cyclothymia) was Average.
Corey's score on Stress
(individuals may be experiencing a moderate degree of stress as a result of difficulties in some major life area) was Average.
Corey's score on Alcohol Problems
(are indicative of an individual who may drink regularly and may have experienced some adverse consequences as a result) was Low Average.
Corey's score on Egocentricity
(suggest a person who tends to be self-centered and pragmatic in interaction with others) was Low Average.
Corey's score on Dominance
(average scores reflect an individual who is likely to be able to adapt to different interpersonal situations, by being able to both take and relinquish control in these relationships as needed) was Low Average.
Corey's score on Antisocial Behaviors
(scores suggest a history of difficulties with authority and with social convention) was Low Average.
Corey's score on Aggression
(scores are indicative of an individual who may be seen as impatient, irritable, and quick-tempered) was Low Average.
Corey's score on Persecution
(suggest an individual who is quick to feel that they are being treated inequitably and easily believes that there is concerted effort among others to undermine their best interests) was Low Average.
Corey's score on Aggressive Attitude
(suggest an individual who is easily angered and frustrated; others may perceive him as hostile and readily provoked) was Low Average.
Corey's score on Verbal Aggression
(reflects a person who is assertive and not intimidated by confrontation and, toward the upper end of this range, he may be verbally aggressive) was Low Average.
Corey's score on Irritability
(person is very volatile in response to frustration and his judgment in such situations may be poor) was Low Average.
Corey's score on Antisocial Features
(individuals are likely to be impulsive and hostile, perhaps with a history of reckless and/or antisocial acts) was Low Average.
Corey's score on Stimulus-Seeking
(patient is likely to manifest behavior that is reckless and potentially dangerous to himself and/or those around him) was Low Average.
Corey's score on Grandiosity
(person may have little capacity to recognize personal limitations, to the point where one is not able to think clearly about one's capabilities) was Below Average.
Corey's score on Treatment Rejection
(average scores suggest a person who acknowledges major difficulties in their functioning, and perceives an acute need for help in dealing with these problems) was Exceptionally Low.















```{=typst}
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
```
```{=typst}
#let title = "Personality Assessment Scores"
#let file_qtbl = "table_emotion.png"
#let file_fig = "fig_emotion.svg"
#domain(
  title: [#title],
  file_qtbl,
  file_fig
  )
```




<!-- {{< pagebreak >}} -->


# SUMMARY/IMPRESSION

{{< var patient >}} is a {{< var age >}}-year-old {{< var sex >}} who was referred for neuropsychological evaluation. Overall, the current evaluation revealed:

## Cognitive Strengths
- [To be completed based on test results]

## Cognitive Weaknesses
- [To be completed based on test results]

## Diagnostic Impressions
- [To be completed based on clinical judgment]




## Clinical Summary

The pattern of results suggests [clinical interpretation to be added]. These findings are consistent with [diagnostic formulation to be added].

## Functional Impact

[Discussion of how cognitive findings impact daily functioning]




# RECOMMENDATIONS

Based on the results of this evaluation, the following recommendations are offered:

1. **Medical Follow-up**: [Specific medical recommendations]

2. **Cognitive Interventions**: [Specific cognitive recommendations]

3. **Academic/Occupational**: [Specific academic or work recommendations]

4. **Psychosocial Support**: [Specific support recommendations]

5. **Re-evaluation**: Consider repeat neuropsychological evaluation in [timeframe] to monitor progress.




---

Thank you for referring {{< var patient >}} for this neuropsychological evaluation. Please feel free to contact me if you have any questions regarding this report.

Respectfully submitted,

[Examiner Name, Degree]
[Title]
[License Number]



<!-- {{< pagebreak >}} -->


# APPENDIX

## Test Score Classification


::: {.cell}
::: {.cell-output-display}


|  Range  |Classification | Percentile |
|:-------:|:--------------|:----------:|
|  ≥ 130  |Very Superior  |    98+     |
| 120-129 |Superior       |   91-97    |
| 110-119 |High Average   |   75-90    |
| 90-109  |Average        |   25-74    |
|  80-89  |Low Average    |    9-24    |
|  70-79  |Borderline     |    2-8     |
|  ≤ 69   |Extremely Low  |     <2     |


:::
:::


## Validity Statement

All test results reported herein are considered valid based on behavioral observations and embedded validity indicators.


