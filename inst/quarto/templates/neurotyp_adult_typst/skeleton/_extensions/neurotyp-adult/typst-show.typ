#show: report.with(
$if(title)$
  title: "$title$",
$endif$
$if(name)$
  name: [$name$],
$endif$
$if(doe)$
  doe: [$doe$],
$endif$
$if(patient)$
  patient: [$patient$],
$endif$
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(mainfont)$
  font: ("$mainfont$"),
$endif$
$if(bodyfont)$
  body-font: ("$bodyfont$"),
$endif$
$if(sansfont)$
  sans-font: ("$sansfont$"),
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(section-numbering)$
  sectionnumbering: "$section-numbering$",
$endif$
)
