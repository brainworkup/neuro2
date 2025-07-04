% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ReportTemplateR6.R
\name{ReportTemplateR6}
\alias{ReportTemplateR6}
\title{ReportTemplateR6 Class}
\description{
ReportTemplateR6 Class

ReportTemplateR6 Class
}
\details{
An R6 class that encapsulates the Quarto-Typst template system for neuropsychological reports.
This class handles template variables, section inclusion, and report generation.
}
\section{Methods}{

\describe{
\item{initialize}{Initialize a new ReportTemplateR6 object with configuration parameters.}
\item{load_variables}{Load variables from a YAML file or list.}
\item{set_variable}{Set a specific variable value.}
\item{get_variable}{Get a specific variable value.}
\item{set_sections}{Set the sections to include in the report.}
\item{add_section}{Add a section to the report.}
\item{remove_section}{Remove a section from the report.}
\item{generate_template}{Generate the Quarto template file.}
\item{render_report}{Render the report using Quarto.}
}
}

\section{Public fields}{
\if{html}{\out{<div class="r6-fields">}}
\describe{
\item{\code{variables}}{List of variables used in the report template.}

\item{\code{template_dir}}{Directory containing the template files (default: "inst/quarto/templates/typst-report").}

\item{\code{output_dir}}{Directory where generated reports will be saved (default: ".").}

\item{\code{sections}}{List of sections to include in the report.}

\item{\code{data_paths}}{List of paths to data files.}

\item{\code{packages}}{List of R packages required for the report.}
}
\if{html}{\out{</div>}}
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-ReportTemplateR6-new}{\code{ReportTemplateR6$new()}}
\item \href{#method-ReportTemplateR6-load_variables}{\code{ReportTemplateR6$load_variables()}}
\item \href{#method-ReportTemplateR6-set_variable}{\code{ReportTemplateR6$set_variable()}}
\item \href{#method-ReportTemplateR6-get_variable}{\code{ReportTemplateR6$get_variable()}}
\item \href{#method-ReportTemplateR6-set_sections}{\code{ReportTemplateR6$set_sections()}}
\item \href{#method-ReportTemplateR6-add_section}{\code{ReportTemplateR6$add_section()}}
\item \href{#method-ReportTemplateR6-remove_section}{\code{ReportTemplateR6$remove_section()}}
\item \href{#method-ReportTemplateR6-generate_template}{\code{ReportTemplateR6$generate_template()}}
\item \href{#method-ReportTemplateR6-render_report}{\code{ReportTemplateR6$render_report()}}
\item \href{#method-ReportTemplateR6-clone}{\code{ReportTemplateR6$clone()}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-new"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-new}{}}}
\subsection{Method \code{new()}}{
Initialize a new ReportTemplateR6 object with configuration parameters.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$new(
  variables = NULL,
  template_dir = "inst/extdata/_extensions",
  output_dir = ".",
  sections = NULL,
  data_paths = NULL,
  packages = NULL
)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{variables}}{List of variables or path to a YAML file containing variables.}

\item{\code{template_dir}}{Directory containing the template files (default: "inst/quarto/templates/typst-report").}

\item{\code{output_dir}}{Directory where generated reports will be saved (default: ".").}

\item{\code{sections}}{List of sections to include in the report (default: NULL, will use all sections).}

\item{\code{data_paths}}{List of paths to data files (default: NULL).}

\item{\code{packages}}{List of R packages required for the report (default: NULL, will use defaults).}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A new ReportTemplateR6 object
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-load_variables"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-load_variables}{}}}
\subsection{Method \code{load_variables()}}{
Load variables from a YAML file.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$load_variables(file_path)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{file_path}}{Path to the YAML file containing variables.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-set_variable"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-set_variable}{}}}
\subsection{Method \code{set_variable()}}{
Set a specific variable value.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$set_variable(name, value)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{name}}{Name of the variable.}

\item{\code{value}}{Value to set.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-get_variable"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-get_variable}{}}}
\subsection{Method \code{get_variable()}}{
Get a specific variable value.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$get_variable(name)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{name}}{Name of the variable.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
The value of the variable.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-set_sections"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-set_sections}{}}}
\subsection{Method \code{set_sections()}}{
Set the sections to include in the report.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$set_sections(sections)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{sections}}{List of section file names.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-add_section"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-add_section}{}}}
\subsection{Method \code{add_section()}}{
Add a section to the report.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$add_section(section, position = NULL)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{section}}{Section file name.}

\item{\code{position}}{Position to insert the section (default: end of list).}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-remove_section"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-remove_section}{}}}
\subsection{Method \code{remove_section()}}{
Remove a section from the report.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$remove_section(section)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{section}}{Section file name or position.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-generate_template"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-generate_template}{}}}
\subsection{Method \code{generate_template()}}{
Generate the Quarto template file.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$generate_template(output_file = "report_template.qmd")}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{output_file}}{Output file path (default: "report_template.qmd").}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-render_report"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-render_report}{}}}
\subsection{Method \code{render_report()}}{
Render the report using Quarto.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$render_report(
  input_file,
  output_format = "pdf",
  output_file = NULL
)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{input_file}}{Input Quarto file path.}

\item{\code{output_format}}{Output format (default: "pdf").}

\item{\code{output_file}}{Output file path (default: NULL, will use Quarto default).}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Invisibly returns self for method chaining.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReportTemplateR6-clone"></a>}}
\if{latex}{\out{\hypertarget{method-ReportTemplateR6-clone}{}}}
\subsection{Method \code{clone()}}{
The objects of this class are cloneable with this method.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReportTemplateR6$clone(deep = FALSE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{deep}}{Whether to make a deep clone.}
}
\if{html}{\out{</div>}}
}
}
}
