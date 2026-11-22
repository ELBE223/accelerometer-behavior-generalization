# paper_figures.R
#
# Figures (png, 600 dpi) and tables (txt) of the manuscript and the supplement from
# 04_Statistics/results/ and 00_Documentation/ (no model fitting).
#   05_Paper_Outputs/main/                Tables 1-3, Figures 1-3 (+ figure_<nn>_*_caption.txt)
#   05_Paper_Outputs/supplementary/       Tables S1-S17, Figures S1-S3 (+ captions); Texts S1-S2
#                                         are hand-written (text_s*.md) and only listed
#   05_Paper_Outputs/output_manifest.csv  every output with title, file, sources, the script
#                                         that made the sources and where it is cited
# Numbering, titles, column names, notes and captions follow the manuscript and the
# supplement (block "Numbering" below). Generated files (table_*, figure_*) in main/ and
# supplementary/ are deleted before each run, so no output with an outdated number is left
# behind; the hand-written texts are kept.
# Values are means over the five training seeds (D26); scenario "primary".
# Tables: tab-separated text (Word: Insert > Table > Convert Text to Table): title, blank
# line, header row(s), rows, blank line, notes (one paragraph per line). "<br>" marks a line
# break within a cell (Word: replace "<br>" with "^l"); "—" marks an empty cell.
# Figure S1 (workflow) is drawn by hand; its image is copied from 05_Paper_Outputs/assets/.
# A failing item is skipped and logged in 05_Paper_Outputs/errors.txt (exit status 1).
#
# Usage: Rscript 05_Paper_Outputs/paper_figures.R   (packages: ggplot2, patchwork)

required <- c("ggplot2", "patchwork")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Install first: install.packages(c(", paste0("\"", missing, "\"", collapse = ", "), "))", call. = FALSE)
}
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})
options(stringsAsFactors = FALSE, width = 200)
# chi2, beta, rho and the minus sign need a UTF-8 locale (e.g. Rscript in a C locale).
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  for (loc in c("C.UTF-8", "C.utf8", "en_US.UTF-8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", loc)))) break
  }
}

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- if (length(script) == 1L) normalizePath(file.path(dirname(script), "..")) else normalizePath(getwd())
stats_dir <- file.path(root, "04_Statistics", "results")
if (!dir.exists(stats_dir)) {
  stop("04_Statistics/results/ not found under ", root, "; run from the project folder.", call. = FALSE)
}
doc <- function(...) file.path(root, "00_Documentation", ...)
class_summary_file <- file.path(root, "01_Preprocessing", "reports", "pipeline_reports", "class_summary.csv")
datasets_file <- doc("datasets.csv")
sensor_file <- doc("sensor_settings.csv")
mapping_file <- doc("behavior_mapping.csv")
traits_file <- doc("traits", "species_traits_core.csv")
trait_definitions_file <- doc("traits", "core_trait_definitions.csv")
lock_file <- file.path(root, "requirements-lock.txt")
out_dir <- file.path(root, "05_Paper_Outputs")
workflow_file <- file.path(out_dir, "assets", "figure_s01_workflow.png")
MAIN <- "main"
SUPP <- "supplementary"

# =========================================================
# Settings
# =========================================================
dpi <- 600          # png resolution
base_size <- 8      # font size in pt at the printed size (180 mm = double column)
main_scenario <- "primary"

model_keys <- c("cnn", "resnet", "hydra", "multirocket", "rf", "lgbm")  # order in all tables
model_labels <- c(cnn = "CNN", resnet = "ResNet", hydra = "HYDRA", multirocket = "MultiRocket", rf = "RF",
                  lgbm = "LightGBM")
classes <- c("Resting", "Locomotion", "Foraging")  # order in every figure and table
class_pairs <- list(c("Resting", "Locomotion"), c("Resting", "Foraging"), c("Locomotion", "Foraging"))
# Table S17: sensitivity scenarios in this order (definitions: Text S1).
scenarios <- c(primary = "Primary", A = "No training overlap", C = "2.4-s windows, no overlap",
               majority = "Majority label: 80%", four_classes = "Four classes, including Other",
               E = "Ridden gaits and jumping as locomotion", F = "Eligible individuals only")
# Species that share a common name with another study species (Table S15).
vernacular <- c("Equus ferus przewalskii" = "Przewalski’s horse", "Equus caballus" = "domestic horse")

# Palette (light mode).
INK <- "#0b0b0b"
INK_2 <- "#52514e"
GRID <- "#e1e0d9"
AXIS <- "#c3c2b7"
POINT_GREY <- "#a8a79f"
class_colors <- c(Foraging = "#2a78d6", Locomotion = "#eb6834", Resting = "#1baf7a")
CONFUSION_HIGH <- "#2c5985"

# Unicode (escaped, so the script reads the same in every locale).
CHI2 <- "χ²"
BETA <- "β"
RHO <- "ρ"
DASH <- "–"
EMDASH <- "—"
MINUS <- "−"
TIMES <- "×"
R2 <- "R²"
APOS <- "’"
BR <- "<br>"  # line break within a table cell

# =========================================================
# Helpers
# =========================================================
read_stats <- function(scenario, name) {
  d <- read.csv(file.path(stats_dir, scenario, paste0(name, ".csv")), check.names = FALSE)
  # pandas writes True/False, which read.csv keeps as text.
  d[] <- lapply(d, function(x) if (is.character(x) && all(x %in% c("True", "False", NA))) as.logical(x) else x)
  d
}
read_registry <- function(file) read.csv(file, colClasses = "character", fileEncoding = "UTF-8", check.names = FALSE)
rel_path <- function(path) sub(paste0("^", root, "/"), "", path)
model_factor <- function(x) factor(unname(model_labels[tolower(x)]), levels = unname(model_labels))
registry <- read_registry(datasets_file)

# Dataset labels as in the manuscript: the species, with the dataset number only where a
# species has two datasets (Dog 1, Dog 2, Horse 1, Horse 2, Raccoon 1, Raccoon 2).
dataset_label <- function(id) {
  r <- registry[match(id, registry$dataset_id), ]
  n <- as.vector(table(registry$species)[r$species])
  ifelse(n > 1L, paste(r$species, sub(".*_dataset_", "", id)), r$species)
}
# Species labels: the common name, or the dataset label where two species share it (Horse 1,
# Horse 2); `long` adds the vernacular name of those (Table S15).
species_label <- function(sci, long = FALSE) {
  r <- registry[match(sci, registry$scientific_name), ]
  shared <- vapply(r$species, function(s) length(unique(registry$scientific_name[registry$species == s])) > 1L, logical(1))
  out <- ifelse(shared, dataset_label(r$dataset_id), r$species)
  if (long) out <- ifelse(shared, paste0(out, ": ", vernacular[sci]), out)
  unname(out)
}

num <- function(x, digits = 3) {
  x <- as.numeric(x)
  x[!is.na(x) & abs(x) < 0.5 * 10^-digits] <- 0  # no "-0.000"
  ifelse(is.na(x), EMDASH, formatC(x, format = "f", digits = digits))
}
int <- function(x) ifelse(is.na(x), EMDASH, formatC(as.numeric(x), format = "d", big.mark = ","))
stat_v <- function(v) ifelse(is.na(v), EMDASH, ifelse(v == round(v), formatC(v, format = "d"), num(v, 1)))
p_txt <- function(p) ifelse(is.na(p), EMDASH, ifelse(p < 0.001, "< 0.001", formatC(p, format = "f", digits = 3)))
p_eq <- function(p) ifelse(p < 0.001, "p < 0.001", paste("p =", p_txt(p)))
med_iqr <- function(m, q1, q3, digits = 3) paste0(num(m, digits), " [", num(q1, digits), ", ", num(q3, digits), "]")
est_ci <- function(e, lo, hi, digits = 3) {
  ifelse(is.na(e), EMDASH, paste0(num(e, digits), " [", num(lo, digits), ", ", num(hi, digits), "]"))
}
r2_pair <- function(m, c) paste0(num(m, 2), " / ", num(c, 2))
minus <- function(s) gsub("-", MINUS, s, fixed = TRUE)  # typographic minus (main tables, figures)
yes_no <- function(x) ifelse(as.logical(x), "Yes", "No")
number_words <- c("one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve")
words <- function(n) ifelse(n >= 1 & n <= length(number_words), number_words[n], as.character(n))
join_and <- function(x) if (length(x) <= 1L) paste(x) else paste(paste(x[-length(x)], collapse = ", "), "and", x[length(x)])
lock_version <- function(package) {
  v <- sub("^[^=]+==", "", grep(paste0("^", package, "=="), readLines(lock_file), value = TRUE, ignore.case = TRUE))
  if (length(v) != 1L) stop(package, " not in ", rel_path(lock_file))
  v
}

contents <- data.frame(item = character(), section = character(), title = character(), file = character(),
                       caption_file = character(), sources = character())
register <- function(it, path, title, source) {
  contents <<- rbind(contents, data.frame(item = it$label, section = it$folder, title = title, file = rel_path(path),
                                          caption_file = "", sources = paste(source, collapse = ", ")))
}

write_lines_utf8 <- function(lines, file) writeLines(enc2utf8(lines), con = file, useBytes = TRUE)

# =========================================================
# Numbering (as in the manuscript and the supplement; the one place to change it)
# =========================================================
# Every output has a key. Tables 1-3 and Figures 1-3 go to main/, the supplementary items to
# supplementary/. Renumbering an item is one change in these vectors: file names, labels,
# cross-references and output_manifest.csv follow.
main_tables <- c(h1 = "1", h2 = "2", h3 = "3")
main_figures <- c(h1 = "1", h2 = "2", h3 = "3")
table_numbers <- c(datasets = "S1", windows = "S2", mapping = "S3", preprocessing = "S4", features = "S5",
                   models = "S6", trait_definitions = "S7", traits = "S8", h1_same_windows = "S9",
                   h2_posthoc = "S10", h2_loss = "S11", h3_model = "S12", h3_robustness = "S13",
                   per_classifier = "S14", loso = "S15", seeds = "S16", scenarios = "S17")
figure_numbers <- c(workflow = "S1", h2_loss = "S2", confusion = "S3")
text_numbers <- c(scenarios = "S1", elton = "S2")
# File names: <type>_<nn>_<slug> (main), <type>_s<nn>_<slug> (supplementary).
table_slugs <- c(h1 = "h1_macro_f1", h2 = "h2_class_f1", h3 = "h3_distance_measures",
                 datasets = "datasets", windows = "window_counts", mapping = "label_mapping",
                 preprocessing = "preprocessing", features = "features", models = "classifiers",
                 trait_definitions = "trait_definitions", traits = "trait_values",
                 h1_same_windows = "h1_seven_datasets", h2_posthoc = "h2_posthoc", h2_loss = "h2_transfer_loss",
                 h3_model = "h3_mixed_model", h3_robustness = "h3_robustness", per_classifier = "h3_per_classifier",
                 loso = "h3_leave_one_species_out", seeds = "h3_per_seed", scenarios = "sensitivity_scenarios")
figure_slugs <- c(h1 = "h1_macro_f1", h2 = "h2_class_f1", h3 = "h3_trait_distance",
                  workflow = "workflow", h2_loss = "h2_transfer_loss", confusion = "confusion_matrices")
# Hand-written supplementary texts (not made here, listed in output_manifest.csv).
texts <- data.frame(
  key = names(text_numbers),
  title = c("Sensitivity scenarios", "EltonTraits distance variants"),
  file = c("supplementary/text_s01_sensitivity_scenarios.md", "supplementary/text_s02_eltontraits_distances.md"),
  sources = c("00_Documentation/decisions.md (D11, D27); values of Table S17",
              "04_Statistics/stats_h3.R; 04_Statistics/results/primary/h3_elton_traits.csv"))
# Where the manuscript (version of 2026-11-22) cites each item; supplementary items cited
# only by other supplementary items name those.
cited_in <- c("Table 1" = "Results 3.1; Discussion 4.1", "Figure 1" = "Results 3.1; Discussion 4.1",
              "Table 2" = "Results 3.2; Discussion 4.2", "Figure 2" = "Results 3.2; Discussion 4.2",
              "Table 3" = "Results 3.3; Discussion 4.3", "Figure 3" = "Results 3.3; Discussion 4.3",
              "Table S1" = "Methods 2.1", "Figure S1" = "Methods 2.1", "Table S2" = "Methods 2.1",
              "Table S3" = "Methods 2.1", "Table S4" = "Methods 2.2", "Table S5" = "Methods 2.2",
              "Table S6" = "Methods 2.2", "Table S7" = "Methods 2.4", "Table S8" = "Methods 2.3; Methods 2.4",
              "Table S9" = "Methods 2.5; Results 3.1", "Table S10" = "Results 3.2; Table 2",
              "Table S11" = "Methods 2.5; Results 3.2; Discussion 4.2", "Figure S2" = "Results 3.2",
              "Figure S3" = "Results 3.2", "Table S12" = "Methods 2.5; Results 3.3; Table 3",
              "Table S13" = "Methods 2.5; Results 3.3; Discussion 4.3", "Table S14" = "Methods 2.5; Results 3.3",
              "Table S15" = "Methods 2.5; Results 3.3; Discussion 4.3", "Table S16" = "Methods 2.5; Results 3.3",
              "Table S17" = "Methods 2.5; Results 3.1; Results 3.2; Discussion 4.4",
              "Text S1" = "Methods 2.5; Results 3.2; Discussion 4.4; Table S17",
              "Text S2" = "Methods 2.4; Table S13")

# Folder, label and file name (without extension) of an output.
output_item <- function(type, key) {
  main <- if (type == "Table") main_tables else main_figures
  supp <- if (type == "Table") table_numbers else figure_numbers
  slugs <- if (type == "Table") table_slugs else figure_slugs
  if (!key %in% names(slugs)) stop("no file name (slug) for ", type, " '", key, "'")
  prefix <- tolower(type)
  if (key %in% names(main)) {
    number <- main[[key]]
    return(list(folder = MAIN, label = paste(type, number),
                name = sprintf("%s_%02d_%s", prefix, as.integer(number), slugs[[key]])))
  }
  if (key %in% names(supp)) {
    number <- supp[[key]]
    return(list(folder = SUPP, label = paste(type, number),
                name = sprintf("%s_s%02d_%s", prefix, as.integer(sub("^S", "", number)), slugs[[key]])))
  }
  stop(type, " '", key, "' has no number (add it to the numbering above)")
}
table_ref <- function(key) output_item("Table", key)$label
text_ref <- function(key) paste("Text", text_numbers[[key]])

# Script that wrote a source file (column produced_by of output_manifest.csv).
producer <- function(sources) {
  s <- trimws(unlist(strsplit(sources, ",", fixed = TRUE)))
  p <- ifelse(grepl("/(h1_|h2_|h3_input|seed_)", s), "04_Statistics/stats_h1_h2.py",
              ifelse(grepl("/h3_", s), "04_Statistics/stats_h3.R",
                     ifelse(grepl("pipeline_reports/class_summary", s), "01_Preprocessing/assign_classes.py", "")))
  paste(unique(p[nzchar(p)]), collapse = ", ")
}

# Table as text: title, blank line, header row(s) and rows with tabs, blank line, notes (one
# paragraph per line). `key` is a key of main_tables or table_numbers; `header2`: a second
# header row (Table S2). The sources go to output_manifest.csv.
write_table <- function(key, title, table, notes = character(), source = character(), header2 = NULL) {
  it <- output_item("Table", key)
  dir.create(file.path(out_dir, it$folder), recursive = TRUE, showWarnings = FALSE)
  file <- file.path(out_dir, it$folder, paste0(it$name, ".txt"))
  table[] <- lapply(table, function(x) ifelse(is.na(x), EMDASH, as.character(x)))
  if (!is.null(header2) && length(header2) != ncol(table)) stop("second header row of ", it$label, " has the wrong length")
  rows <- do.call(paste, c(unname(as.list(table)), sep = "\t"))
  lines <- c(paste0(it$label, ". ", title), "", paste(names(table), collapse = "\t"),
             if (!is.null(header2)) paste(header2, collapse = "\t"), rows,
             if (length(notes) > 0L) c("", notes))
  write_lines_utf8(lines, file)
  register(it, file, title, source)
  cat("[OK]", rel_path(file), "\n")
}

# `key` is a key of main_figures or figure_numbers.
save_figure <- function(plot, key, width_mm, height_mm, title, source) {
  it <- output_item("Figure", key)
  dir.create(file.path(out_dir, it$folder), recursive = TRUE, showWarnings = FALSE)
  file <- file.path(out_dir, it$folder, paste0(it$name, ".png"))
  ggsave(file, plot, width = width_mm, height = height_mm, units = "mm", dpi = dpi, bg = "white")
  register(it, file, title, source)
  cat("[OK]", rel_path(file), "\n")
}

# Caption of a figure next to it ("Figure S2. <title> <text>").
write_caption <- function(key, caption) {
  it <- output_item("Figure", key)
  file <- file.path(out_dir, it$folder, paste0(it$name, "_caption.txt"))
  write_lines_utf8(paste0(it$label, ". ", caption), file)
  png <- rel_path(file.path(out_dir, it$folder, paste0(it$name, ".png")))
  contents$caption_file[contents$file == png] <<- rel_path(file)
  cat("[OK]", rel_path(file), "\n")
}

# Post-hoc test of a class pair in the order of `classes` (the statistics store the pairs in
# alphabetical order, difference = first - second; reversing the pair changes the sign of
# the differences and of r_rb, and V becomes m(m + 1)/2 - V with m non-zero differences).
posthoc_pair <- function(ph, model, pair) {
  r <- ph[ph$model == model & ph$behavior_1 == pair[1] & ph$behavior_2 == pair[2], ]
  if (nrow(r) == 1L) return(r)
  r <- ph[ph$model == model & ph$behavior_1 == pair[2] & ph$behavior_2 == pair[1], ]
  if (nrow(r) != 1L) stop("post-hoc test missing: ", model, " ", paste(pair, collapse = " vs. "))
  m <- r$n_pairs - r$n_zero
  q1 <- r$diff_q1
  r$behavior_1 <- pair[1]
  r$behavior_2 <- pair[2]
  r$V <- m * (m + 1) / 2 - r$V
  r$rank_biserial <- -r$rank_biserial
  r$diff_mean <- -r$diff_mean
  r$diff_median <- -r$diff_median
  r$diff_q1 <- -r$diff_q3
  r$diff_q3 <- -q1
  r
}

theme_paper <- function() {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      text = element_text(colour = INK),
      axis.text = element_text(colour = INK_2, size = rel(0.9)),
      axis.title = element_text(colour = INK_2, size = rel(0.95)),
      axis.line = element_line(colour = AXIS, linewidth = 0.3),
      axis.ticks = element_line(colour = AXIS, linewidth = 0.3),
      axis.ticks.length = unit(1.5, "pt"),
      panel.grid.major = element_line(colour = GRID, linewidth = 0.25),
      panel.grid.minor = element_blank(),
      panel.spacing = unit(4, "mm"),
      strip.text = element_text(face = "bold", colour = INK, size = rel(1), margin = margin(2, 0, 3, 0)),
      legend.position = "top",
      legend.justification = "right",
      legend.title = element_blank(),
      legend.text = element_text(colour = INK_2, size = rel(0.9)),
      legend.key.size = unit(3.2, "mm"),
      legend.margin = margin(0, 0, 0, 0),
      legend.box.spacing = unit(1.5, "mm"),
      plot.title = element_text(face = "bold", colour = INK, size = rel(1), hjust = 0, margin = margin(0, 0, 4, 0)),
      plot.tag = element_text(face = "bold", colour = INK, size = rel(1.1)),
      plot.background = element_rect(fill = "white", colour = NA),
      plot.margin = margin(4, 6, 4, 4)
    )
}


# =========================================================
# Shared plot builders
# =========================================================
# Figures 1-2 and S2 (180 mm wide; Figures 1-2 125 mm high as in the manuscript, Figure S2
# 118 mm as in the supplement); captions in txt files.
theme_boxes <- function() {
  theme_classic(base_size = 10) +
    theme(strip.background = element_blank(), strip.text = element_text(face = "bold", size = 10),
          panel.spacing = unit(6, "mm"), axis.title = element_text(size = 10),
          axis.text = element_text(colour = "#383838"),
          panel.grid.major.y = element_line(colour = "#e9e9e9", linewidth = 0.25),
          axis.line = element_line(linewidth = 0.3), legend.position = "bottom", legend.title = element_blank(),
          legend.text = element_text(size = 9), legend.key.size = unit(4, "mm"), legend.margin = margin(0, 0, 0, 0),
          plot.margin = margin(8, 9, 8, 8))
}

# H1: datasets with a within- and a cross-dataset value (the pairs of the Wilcoxon test).
paired_values <- function(metric) {
  v <- read_stats(main_scenario, "h1_values")
  w <- v[[paste0(metric, "_within")]]
  x <- v[[paste0(metric, "_cross")]]
  keep <- v$model %in% model_keys & is.finite(w) & is.finite(x)
  d <- rbind(data.frame(model = v$model[keep], dataset = v$dataset[keep], mode = "Within", value = w[keep]),
             data.frame(model = v$model[keep], dataset = v$dataset[keep], mode = "Cross", value = x[keep]))
  d$model <- model_factor(d$model)
  d$mode <- factor(d$mode, levels = c("Within", "Cross"))
  d
}

# Figure 1: one point per dataset and setting, lines connect the same dataset (no boxes, no
# legend, as in the manuscript).
plot_within_cross <- function(metric, y_label) {
  ggplot(paired_values(metric), aes(mode, value, group = dataset)) +
    geom_line(colour = "#b1b1b1", linewidth = 0.5) +
    geom_point(colour = "#252525", size = 1.7, alpha = 0.9) +
    facet_wrap(~ model, ncol = 3) +
    scale_x_discrete(expand = expansion(add = 0.3)) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2), expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = y_label) +
    theme_boxes() +
    theme(legend.position = "none")
}

# H2: the test datasets of the Friedman test (complete blocks) per classifier.
class_values <- function(response) {
  v <- read_stats(main_scenario, "h2_values")
  fr <- read_stats(main_scenario, "h2_friedman")
  fr <- fr[fr$response == response & fr$datasets == "all", ]
  blocks <- unlist(lapply(seq_len(nrow(fr)), function(i) paste(fr$model[i], strsplit(fr$blocks[i], " +")[[1]])))
  v <- v[paste(v$model, v$dataset) %in% blocks & v$behavior %in% classes & is.finite(v[[response]]), ]
  data.frame(model = model_factor(v$model), dataset = v$dataset,
             behavior = factor(v$behavior, levels = classes), value = v[[response]])
}

# Figure 2 (no legend, slanted class names) and Figure S2 (legend below the panels).
plot_classes <- function(response, y_label, legend = TRUE, angle = 0) {
  d <- class_values(response)
  lim <- if (response == "cross_f1") c(0, 1) else c(floor(min(d$value, 0) * 5) / 5, ceiling(max(d$value) * 5) / 5)
  ggplot(d, aes(behavior, value)) +
    {if (lim[1] < 0) geom_hline(yintercept = 0, colour = "#9a9a9a", linewidth = 0.3)} +
    geom_boxplot(aes(fill = behavior), width = 0.56, alpha = 0.22, outlier.shape = NA, colour = "#505050",
                 linewidth = 0.4) +
    geom_point(aes(colour = behavior), position = position_jitter(width = 0.09, height = 0, seed = 42),
               size = 1.7, alpha = 0.85) +
    facet_wrap(~ model, ncol = 3) +
    scale_fill_manual(values = class_colors, breaks = classes) +
    scale_colour_manual(values = class_colors, breaks = classes) +
    scale_y_continuous(limits = lim, breaks = seq(lim[1], lim[2], 0.2), labels = function(x) minus(num(x, 1)),
                       expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = y_label) +
    theme_boxes() +
    theme(axis.text.x = if (angle == 0) element_text(size = 8) else element_text(size = 8.5, angle = angle, hjust = 1, vjust = 1),
          legend.position = if (legend) "bottom" else "none")
}

# Number of test datasets of the H1 pairs and of the H2 blocks (the same for all classifiers).
n_paired <- function() {
  n <- unique(table(paired_values("macro_f1")$model) / 2)
  if (length(n) != 1L) stop("the classifiers have different numbers of paired datasets")
  as.integer(n)
}
n_blocks <- function(response, datasets = "all") {
  fr <- read_stats(main_scenario, "h2_friedman")
  n <- unique(fr$n_blocks[fr$response == response & fr$datasets == datasets])
  if (length(n) != 1L) stop("the classifiers have different numbers of Friedman blocks (", response, ", ", datasets, ")")
  n
}

# H2 class table (Table 2 and Table S11): median [IQR] per class, Friedman test (p unadjusted
# and Holm-adjusted over the six classifiers, D44) and Kendall's W.
class_table <- function(response, datasets = "all") {
  de <- read_stats(main_scenario, "h2_descriptives")
  fr <- read_stats(main_scenario, "h2_friedman")
  de <- de[de$response == response & de$datasets == datasets, ]
  fr <- fr[fr$response == response & fr$datasets == datasets, ]
  out <- do.call(rbind, lapply(model_keys, function(m) {
    f <- fr[fr$model == m, ]
    cells <- vapply(classes, function(cl) {
      r <- de[de$model == m & de$behavior == cl, ]
      med_iqr(r$value_median, r$value_q1, r$value_q3)
    }, character(1))
    as.data.frame(as.list(c(Classifier = model_labels[[m]], cells, chi = num(f$chi_sq, 2), p = p_txt(f$p_value),
                            p_holm = p_txt(f$p_holm), W = num(f$kendalls_w, 2))), check.names = FALSE)
  }))
  names(out) <- c("Classifier", classes, CHI2, "p", "p (Holm)", "W")
  out
}

# Names of the H3 analyses in Table S13, in its order (labels of 04_Statistics/stats_h3.R).
h3_labels <- c("primary" = "Primary model",
               "interaction distance x model" = paste("Distance", TIMES, "classifier interaction"),
               "directional random effects" = "Random effects without unordered pair",
               "pair-only random effect" = "Random effect of ordered pair only",
               "S1 within covariates" = "Adjusted for within-dataset Macro-F1",
               "S2 retention" = "Retention as response",
               "S2 log retention" = "Log retention as response",
               "RF and LGBM only (D27)" = "RF and LightGBM only",
               "EltonTraits core" = "EltonTraits distance",
               "EltonTraits extended" = "EltonTraits distance with diet",
               "log body mass" = "Body mass difference",
               "divergence time (TimeTree)" = "Phylogenetic distance",
               "sensitivity: raccoon separate body configuration (D38)" = "Raccoon as separate body configuration group",
               "sensitivity: hedgehog neck length intermediate (D38)" = "Hedgehog relative neck length intermediate",
               "sensitivity: cattle neck length short (D43)" = "Cattle relative neck length short",
               "sensitivity: without body mass (D38)" = "Without body mass",
               "sensitivity: without locomotor specialization (D38)" = "Without locomotor specialization",
               "sensitivity: without body configuration (D38)" = "Without body configuration",
               "sensitivity: without relative neck length (D38)" = "Without relative neck length",
               "sensitivity: without food acquisition and handling (D38)" = "Without food acquisition and handling")

# =========================================================
# Main text: H1
# =========================================================
figure_1 <- function() {
  p <- plot_within_cross("macro_f1", "Macro-F1")
  save_figure(p, "h1", 180, 125, "Within- and cross-dataset Macro-F1.",
              paste0("04_Statistics/results/", main_scenario, "/h1_values.csv"))
  write_caption("h1", paste0("Within- and cross-dataset Macro-F1. Points represent dataset-level Macro-F1 values for the ",
                             words(n_paired()), " datasets evaluated in both settings. ",
                             "Lines connect the within- and cross-dataset results for each dataset."))
}

table_1 <- function() {
  t <- read_stats(main_scenario, "h1_tests")
  t <- t[t$datasets == "all" & t$metric == "macro_f1", ]
  t <- t[match(model_keys, t$model), ]
  out <- data.frame(a = unname(model_labels[t$model]), b = med_iqr(t$within_median, t$within_q1, t$within_q3),
                    c = med_iqr(t$cross_median, t$cross_q1, t$cross_q3), d = med_iqr(t$gap_median, t$gap_q1, t$gap_q3),
                    e = stat_v(t$V), f = p_txt(t$p_value), g = num(t$rank_biserial, 2))
  names(out) <- c("Classifier", "Within-dataset", "Cross-dataset", "Δ Macro-F1", "V", "p", "r")
  write_table("h1", "Paired comparison of within- and cross-dataset Macro-F1.", out,
              paste0("Values are medians [first quartile, third quartile] across ", words(max(t$n_pairs)), " paired datasets. ",
                     "Reported p-values are unadjusted; Δ Macro-F1: within-dataset minus cross-dataset Macro-F1; ",
                     "V: Wilcoxon signed-rank statistic; r: matched-pairs rank-biserial correlation."),
              paste0("04_Statistics/results/", main_scenario, "/h1_tests.csv"))
}

# =========================================================
# Main text: H2
# =========================================================
figure_2 <- function() {
  p <- plot_classes("cross_f1", "Cross-dataset class F1", legend = FALSE, angle = 20)
  save_figure(p, "h2", 180, 125, "Cross-dataset F1 by behavioral class.",
              paste0("04_Statistics/results/", main_scenario, c("/h2_values.csv", "/h2_friedman.csv")))
  write_caption("h2", paste0("Cross-dataset F1 by behavioral class. Points represent dataset-level scores for ",
                             words(n_blocks("cross_f1")), " datasets. Boxes show medians and interquartile ranges."))
}

table_2 <- function() {
  write_table("h2", "Behavioral differences in cross-dataset F1.", class_table("cross_f1"),
              paste0("Class-specific F1 scores are reported as medians [first quartile, third quartile] across ",
                     words(n_blocks("cross_f1")), " datasets. ", CHI2, ": Friedman test statistic (df = 2); ",
                     "p: unadjusted Friedman test p-value; p (Holm): p-value adjusted across the ", words(length(model_keys)),
                     " classifier-specific Friedman tests; W: Kendall", APOS, "s coefficient of concordance. ",
                     "Post-hoc comparisons are reported descriptively in ", table_ref("h2_posthoc"), "."),
              paste0("04_Statistics/results/", main_scenario, c("/h2_descriptives.csv", "/h2_friedman.csv")))
}

# =========================================================
# Main text: H3
# =========================================================
# Figure 3 (H3): species pairs and the primary model; the band is the 95 % CI of the primary
# model averaged over the classifiers (h3_prediction.csv of 04_Statistics/stats_h3.R).
figure_3 <- function() {
  d <- read_stats(main_scenario, "h3_data")
  pairs <- aggregate(mean_macro_f1 ~ train_species + test_species + trait_distance_core, data = d, FUN = mean)
  pred <- read_stats(main_scenario, "h3_prediction")
  p <- ggplot(pairs, aes(trait_distance_core, mean_macro_f1)) +
    geom_ribbon(data = pred, aes(x = trait_distance_core, ymin = ci_low, ymax = ci_high, fill = "95% CI"),
                inherit.aes = FALSE, alpha = 0.9) +
    geom_point(aes(shape = "Species pair"), size = 1.9, stroke = 0.3, colour = "white", fill = POINT_GREY) +
    geom_line(data = pred, aes(trait_distance_core, estimate, linetype = "Model prediction"), colour = INK, linewidth = 0.7) +
    scale_shape_manual(values = c("Species pair" = 21)) +
    scale_linetype_manual(values = c("Model prediction" = "solid")) +
    scale_fill_manual(values = c("95% CI" = GRID)) +
    guides(shape = guide_legend(order = 1, override.aes = list(size = 2.2)), linetype = guide_legend(order = 2),
           fill = guide_legend(order = 3)) +
    scale_y_continuous(breaks = seq(0, 1, 0.2), labels = function(x) num(x, 1)) +
    scale_x_continuous(breaks = seq(0, 1, 0.2), labels = function(x) num(x, 1)) +
    coord_cartesian(ylim = c(0, 1)) +
    labs(x = "Trait distance (core traits)", y = "Mean Macro-F1") +
    theme_paper() +
    theme(legend.position = "bottom", legend.justification = "center")
  save_figure(p, "h3", 100, 95, "Cross-species Macro-F1 in relation to functional-biomechanical distance.",
              paste0("04_Statistics/results/", main_scenario, c("/h3_data.csv", "/h3_prediction.csv")))
  write_caption("h3", paste0(
    "Cross-species Macro-F1 in relation to functional-biomechanical distance. Points represent directed source", DASH,
    "target species pairs (n = ", nrow(pairs), "), with Macro-F1 averaged over dataset pairs, classifiers, and training seeds. ",
    "The line shows the estimated mean Macro-F1 from the primary mixed model, averaged across classifiers; ",
    "the shaded band represents its 95% confidence interval."))
}

# Table 3: distance effect for the core traits (test of H3) and the alternative distances.
table_3 <- function() {
  keys <- c("primary", "EltonTraits core", "log body mass", "divergence time (TimeTree)")
  labels <- c("Core functional traits", "EltonTraits", "Body mass difference", "Phylogenetic distance")
  m <- read_stats(main_scenario, "h3_models")
  m <- m[match(keys, m$analysis), ]
  if (anyNA(m$analysis)) stop("analyses missing in h3_models.csv: ", paste(keys[is.na(m$analysis)], collapse = ", "))
  out <- data.frame(a = labels, b = minus(est_ci(m$estimate, m$ci_low, m$ci_high)), c = num(m$lr_chisq, 2),
                    d = p_txt(m$lr_p_value), e = num(m$r2_marginal, 2))
  names(out) <- c("Distance measure", paste0(BETA, " [95% CI]"), CHI2, "p", R2)
  write_table("h3", "Associations between biological distance and cross-species Macro-F1.", out,
              paste0("Each distance measure was analyzed separately using the same mixed-model structure (",
                     m$n_observations[1], " observations across ", words(m$n_models[1]), " classifiers and ",
                     m$n_ordered_pairs[1], " directed species pairs). ", BETA, ": change in Macro-F1 per standard deviation ",
                     "increase in distance, with 95% confidence intervals from restricted maximum-likelihood fits using ",
                     "Satterthwaite degrees of freedom. ", CHI2, ": likelihood-ratio test statistic (df = 1), comparing ",
                     "maximum-likelihood models with and without distance; ", R2, ": marginal ", R2, " for the fixed effects ",
                     "of distance and classifier. The core trait distance represents the primary H3 analysis (full model: ",
                     table_ref("h3_model"), ")."),
              paste0("04_Statistics/results/", main_scenario, "/h3_models.csv"))
}

# =========================================================
# Supplement: tables S1-S8 (data, preprocessing, classifiers, traits)
# =========================================================
used_sensor_rows <- function(id) {
  s <- read_registry(sensor_file)
  s[s$dataset_id == id & s$used == "yes", ]
}
rate_text <- function(hz) sub("\\.?0+$", "", formatC(as.numeric(hz), format = "f", digits = 2))
dataset_ids <- function() sort(unique(read.csv(class_summary_file)$dataset_id))

# Table S1: datasets and recording conditions. The recording text of datasets.csv is checked
# against the settings in sensor_settings.csv (rate, burst duration and interval).
table_s_datasets <- function() {
  ids <- dataset_ids()
  ds <- registry[match(ids, registry$dataset_id), ]
  for (i in seq_along(ids)) {
    s <- used_sensor_rows(ids[i])
    rec <- ds$recording_settings[i]
    ok <- startsWith(rec, paste(unique(rate_text(s$native_hz)), "Hz;")) &&
      all(ifelse(nzchar(s$burst_s), grepl(paste0(s$burst_s, "-s bursts"), rec, fixed = TRUE), grepl("continuous", rec))) &&
      all(!nzchar(s$burst_interval_s) | grepl(paste0("every ", s$burst_interval_s, " s"), rec, fixed = TRUE))
    if (!ok) stop("recording_settings of ", ids[i], " in datasets.csv do not match sensor_settings.csv")
  }
  out <- data.frame(a = paste0(dataset_label(ids), BR, ds$scientific_name), b = ds$source, c = ds$setting,
                    d = ds$sensor_position, e = paste0(ds$sensor_label, BR, ds$recording_settings))
  names(out) <- c("Dataset and species", "Source", "Study setting", "Sensor position", "Sensor and recording settings")
  public <- dataset_label(ids[ds$public == "yes"])
  write_table("datasets", "Datasets and recording conditions.", out,
              paste0(join_and(public), " are publicly available; the remaining datasets are non-public. ",
                     "Burst durations and intervals describe nominal recording settings; retained segments may be shorter. ",
                     "IMU = inertial measurement unit. For Raccoon 2, the juvenile was recorded at 30-s intervals from 27 to ",
                     "30 September 2022; otherwise, the interval was 60 s."),
              c("00_Documentation/datasets.csv", "00_Documentation/sensor_settings.csv"))
}

# Table S2: analytical units and window counts (class_summary.csv; within-dataset test units
# are the valid leave-one-individual-out folds, h1_values.csv).
table_s_windows <- function() {
  cs <- read.csv(class_summary_file)
  cs <- cs[cs$mapping == "primary" & cs$class %in% classes, ]
  v <- read_stats(main_scenario, "h1_values")
  v <- v[v$model == model_keys[1], ]
  ids <- dataset_ids()
  out <- do.call(rbind, lapply(ids, function(id) {
    c1 <- cs[cs$dataset_id == id, ]
    w <- vapply(classes, function(cl) sum(c1$test_windows[c1$class == cl]), numeric(1))
    folds <- v$folds[v$dataset == id]
    data.frame(a = dataset_label(id), b = length(unique(c1$individual_id)), c = if (length(folds) == 1L) folds else 0,
               d = sum(c1$windows), r = w[[1]], l = w[[2]], f = w[[3]], t = sum(w))
  }))
  no_fold <- out$a[out$c == 0]
  total <- data.frame(a = "Total", b = sum(out$b), c = sum(out$c), d = sum(out$d), r = sum(out$r), l = sum(out$l),
                      f = sum(out$f), t = sum(out$t))
  out <- rbind(out, total)
  for (k in c("d", "r", "l", "f", "t")) out[[k]] <- int(out[[k]])
  names(out) <- c("Dataset", "Units", "Within test units", "Training windows", "Evaluation windows", "", "", "")
  n_dog2 <- length(unique(cs$individual_id[cs$dataset_id == "Dog_dataset_2"]))
  write_table("windows", "Analytical units and window counts for the primary analysis.", out,
              paste0("Units are individuals, except in Dog 2, where ", words(n_dog2), " recordings served as separate ",
                     "analytical units. Within test units contributed to valid leave-one-individual-out evaluations, ",
                     "requiring at least 10 test windows and 30 remaining training windows per class",
                     if (length(no_fold)) paste0("; ", join_and(no_fold), " had no valid fold"), ". ",
                     "Training counts describe the available pool of fully labeled, class-homogeneous 2.0-s windows generated ",
                     "at 1.0-s intervals, before subsampling and the cap of 250 windows per dataset and class. Evaluation counts ",
                     "include all retained non-overlapping windows used for cross-dataset evaluation; within-dataset evaluation ",
                     "may include fewer windows because of eligibility requirements."),
              c("01_Preprocessing/reports/pipeline_reports/class_summary.csv", paste0("04_Statistics/results/", main_scenario, "/h1_values.csv")),
              header2 = c("", "", "", "", classes, "Total"))
}

# Table S3: original labels per harmonized class (labels in code-point order).
table_s_mapping <- function() {
  m <- read_registry(mapping_file)
  m <- m[m$dataset_id %in% dataset_ids(), ]
  groups <- c(classes, "Other", "Exclude")
  if (!all(m$class %in% groups)) stop("unknown class in behavior_mapping.csv: ", paste(setdiff(m$class, groups), collapse = ", "))
  keys <- unique(m[order(m$dataset_id, match(m$class, groups)), c("dataset_id", "class")])
  # Code-point order (uppercase before lowercase, umlauts after z), the same in every locale.
  code_points <- function(x) vapply(x, function(s) paste(sprintf("%06x", utf8ToInt(enc2utf8(s))), collapse = ""), character(1))
  labels <- vapply(seq_len(nrow(keys)), function(i) {
    x <- m$label[m$dataset_id == keys$dataset_id[i] & m$class == keys$class[i]]
    paste(x[order(code_points(x))], collapse = "; ")
  }, character(1))
  out <- data.frame(a = dataset_label(keys$dataset_id), b = keys$class, c = labels)
  names(out) <- c("Dataset", "Mapping", "Original labels")
  write_table("mapping", "Mapping of original behavior labels to harmonized classes.", out,
              paste0("Resting, locomotion and foraging were retained in the primary analysis. Other was excluded from the ",
                     "primary analysis but included as a fourth class in the four-class sensitivity analysis; Exclude was ",
                     "omitted from both. Codes are dataset-specific, and Giraffe mappings use the full category/code ",
                     "combination. In the primary analysis, windows were retained only if every sample was labeled and mapped ",
                     "to the same retained class."),
              "00_Documentation/behavior_mapping.csv")
}

# Table S4: dataset-specific preprocessing and conversion.
table_s_preprocessing <- function() {
  ids <- dataset_ids()
  ds <- registry[match(ids, registry$dataset_id), ]
  unit <- c(eobs_counts = "e-obs counts", g = "g", m_s2 = "m/s²")
  rates <- vapply(ids, function(id) paste(unique(rate_text(used_sensor_rows(id)$native_hz)), collapse = ", "), character(1))
  out <- data.frame(a = dataset_label(ids), b = unname(rates), c = unname(unit[ds$raw_unit]), d = ds$segment_definition,
                    e = ds$dataset_rules)
  names(out) <- c("Dataset", "Native rate (Hz)", "Input unit", "Segment definition", "Dataset-specific processing")
  write_table("preprocessing", "Dataset-specific preprocessing and conversion.", out,
              paste0("Acceleration was expressed in g: e-obs counts were converted as (value ", MINUS, " 2048)/512, ",
                     "Horse 2 values were divided by 9.80665, and Cattle values were already in g. Segments were processed ",
                     "separately at 25 Hz using polyphase resampling with anti-aliasing where resampling was required. Windows ",
                     "contained 50 samples (2.0 s) and never crossed segment boundaries; training windows used a 1.0-s step, ",
                     "whereas evaluation windows were non-overlapping. Label mapping and exclusions followed ",
                     table_ref("mapping"), "."),
              c("00_Documentation/datasets.csv", "00_Documentation/sensor_settings.csv"))
}

# Table S5: the 26 window features of RF and LightGBM (01_Preprocessing/features.py).
table_s_features <- function() {
  out <- data.frame(
    a = c("VeDBA mean, SD and maximum", "ODBA mean and SD", "Axis SD", "Axis RMS", "Axis IQR", "Axis skewness",
          "Axis excess kurtosis", "Axis zero crossings", "Dominant frequency", "Spectral centroid", "Spectral entropy"),
    b = c("Window mean, sample SD and maximum of vectorial dynamic body acceleration, calculated as the Euclidean norm of the three dynamic axes at each sample.",
          "Window mean and sample SD of overall dynamic body acceleration, calculated as the sum of the absolute dynamic acceleration values on the three axes at each sample.",
          "Sample standard deviation of each dynamic axis, with n minus 1 in the variance denominator.",
          "Square root of the mean squared dynamic acceleration, computed separately for x, y and z.",
          "The 75th percentile minus the 25th percentile of each dynamic axis, using linearly interpolated quantiles equivalent to R type 7.",
          "Mean cubed deviations from the axis mean, divided by the cube of the sample SD, computed separately for x, y and z.",
          "Mean fourth-power deviations from the axis mean, divided by the fourth power of the sample SD, minus 3, for each axis.",
          "Number of adjacent sample pairs with opposite signs on each dynamic axis. Pairs containing an exact zero are not counted.",
          "Frequency of the largest squared Fourier magnitude in the retained spectrum of mean-centered VeDBA.",
          "Mean retained frequency weighted by the normalized spectral power of mean-centered VeDBA.",
          "Shannon entropy of normalized VeDBA spectral power, divided by the natural logarithm of the number of retained frequency bins."),
    c = c("g", "g", "g", "g", "g", "Unitless", "Unitless", "Count", "Hz", "Hz", "Unitless"),
    d = c(3, 2, 3, 3, 3, 3, 3, 3, 1, 1, 1))
  names(out) <- c("Feature group", "Definition", "Unit", "Number")
  write_table("features", "Handcrafted features used by Random Forest and LightGBM.", out,
              paste0("The ", sum(out$Number), " features were calculated from 2.0-s windows at 25 Hz after subtracting each ",
                     "axis mean; static acceleration was not included. Axis features were computed separately for x, y and z, ",
                     "and spectral features were derived from mean-centered VeDBA. SD = sample standard deviation; RMS = root ",
                     "mean square; IQR = interquartile range; VeDBA = vectorial dynamic body acceleration; ODBA = overall ",
                     "dynamic body acceleration."),
              "01_Preprocessing/features.py")
}

# Table S6: classifiers (02_Models/models.py; package versions from requirements-lock.txt).
table_s_models <- function() {
  raw <- paste0("Raw acceleration (3 ", TIMES, " 50 samples)")
  out <- data.frame(
    a = c("Random Forest", "LightGBM", "CNN", "ResNet", "HYDRA", "MultiRocket"),
    b = c(rep("26 handcrafted features", 2), rep(raw, 4)),
    c = c(paste("scikit-learn", lock_version("scikit-learn")), paste("LightGBM", lock_version("lightgbm")),
          rep(paste("PyTorch", lock_version("torch")), 2), rep(paste("aeon", lock_version("aeon")), 2)),
    d = c("Default parameters; 100 trees", "Default parameters; multiclass objective",
          "3 convolutional blocks (32, 64, 128 filters; kernels 5, 5, 3); batch normalization, ReLU, pooling; dropout 0.25",
          "Stem convolution (64 filters, kernel 7); 3 residual blocks (64, 128, 128 filters; kernels 7, 5, 3); dropout 0.25",
          "Default parameters", "Default parameters"))
  names(out) <- c("Classifier", "Input", "Implementation", "Configuration")
  write_table("models", "Classifier implementations and training settings.", out,
              paste0("CNN and ResNet used training-set channel standardization, Adam optimization (learning rate = 0.001), ",
                     "cross-entropy loss, a batch size of 256, and 30 epochs without early stopping. All classifiers were ",
                     "evaluated using five random seeds (42", DASH, "46). Training was limited to 250 windows per dataset and ",
                     "behavioral class, sampled across segments, with at least 30 training windows required per class."),
              c("02_Models/models.py", "requirements-lock.txt"))
}

# Table S7: definitions of the five core traits.
table_s_trait_definitions <- function() {
  d <- read_registry(trait_definitions_file)
  out <- data.frame(a = d$trait, b = d$definition, c = d$coding, d = d$sources)
  names(out) <- c("Trait", "Definition", "Coding", "Sources")
  write_table("trait_definitions", "Functional-biomechanical traits: definitions, coding and sources.", out,
              source = "00_Documentation/traits/core_trait_definitions.csv")
}

# Table S8: core trait values per species (data codes back to labels, first letter capital).
table_s_traits <- function() {
  tr <- read.csv(traits_file)
  pretty <- function(x) {
    x <- gsub("_", " ", x)
    x <- sub("long necked", "long-necked", sub("low profile", "low-profile", x))
    paste0(toupper(substring(x, 1, 1)), substring(x, 2))
  }
  out <- data.frame(a = paste0(species_label(tr$species), " (", tr$species, ")"), b = num(tr$log_body_mass_g, 3),
                    c = pretty(tr$dominant_locomotor_mode), d = pretty(tr$body_configuration_type),
                    e = pretty(tr$relative_neck_length), f = pretty(tr$food_acquisition_handling))
  out <- out[order(species_label(tr$species)), ]
  names(out) <- c("Species", "Body mass (ln g)", "Locomotor specialization", "Body configuration", "Relative neck length",
                  "Food acquisition and handling")
  write_table("traits", "Species-specific functional-biomechanical trait values.", out,
              paste0("Body mass was expressed as the natural logarithm of mass in grams. Relative neck length was classified ",
                     "using r = C/(T + L + S), where C, T, L, and S represent cervical, thoracic, lumbar, and sacral vertebral ",
                     "lengths, respectively. Categories were defined as short (r < 0.30), intermediate (0.30 ≤ r < 0.40), ",
                     "long (0.40 ≤ r < 1.00), and very long (r ≥ 1.00). All categorical trait assignments were ",
                     "study-specific. The hedgehog neck-length classification was based on expert judgement, while the raccoon ",
                     "classification relied on indirect anatomical evidence. The five traits were combined using equally ",
                     "weighted Gower distance. Body mass values came from EltonTraits for six taxa, Gerstner and Gerstein (2008) ",
                     "for Horse 1, and study-specific records for Hedgehog and Dog; the Dog value was the unweighted mean of the ",
                     "two study means."),
              "00_Documentation/traits/species_traits_core.csv")
}

# =========================================================
# Supplement: tables S9-S11 (H1, H2)
# =========================================================
# Table S9: H1 in the datasets in which within- and cross-dataset evaluation score the same
# windows; p unadjusted, Holm adjustment over the six classifiers in the note (D51).
table_s_h1_same_windows <- function() {
  t <- read_stats(main_scenario, "h1_tests")
  t <- t[t$datasets == "same_test_windows" & t$metric == "macro_f1", ]
  t <- t[match(model_keys, t$model), ]
  v <- read_stats(main_scenario, "h1_values")
  v <- v[v$model == model_keys[1], ]
  sm <- read_stats(main_scenario, "seed_means")
  no_within <- setdiff(unique(sm$test[sm$mode == "cross"]), v$dataset)
  out <- data.frame(a = unname(model_labels[t$model]), b = med_iqr(t$within_median, t$within_q1, t$within_q3),
                    c = med_iqr(t$cross_median, t$cross_q1, t$cross_q3), d = med_iqr(t$gap_median, t$gap_q1, t$gap_q3),
                    e = stat_v(t$V), f = p_txt(t$p_value), g = num(t$rank_biserial, 2))
  names(out) <- c("Classifier", "Within-dataset Macro-F1", "Cross-dataset Macro-F1", "Difference", "Wilcoxon V", "p",
                  "Rank-biserial r")
  holm <- unique(p_txt(t$p_holm))
  holm_text <- if (length(holm) == 1L) paste("all comparisons yielded an adjusted p-value of", holm) else
    paste("the adjusted p-values were", join_and(paste0(p_txt(t$p_holm), " (", model_labels[t$model], ")")))
  exact <- all(t$test_method == "exact")
  write_table("h1_same_windows", paste0("Sensitivity analysis of within- and cross-dataset Macro-F1 in ", words(max(t$n_pairs)),
                                        " fully eligible datasets."), out,
              paste0("Values are medians [first quartile, third quartile] across ", words(max(t$n_pairs)), " datasets, with ",
                     "each dataset-level score averaged over five training seeds. The analysis included ",
                     join_and(dataset_label(v$dataset[v$same_test_windows])), ", for which within- and cross-dataset evaluation ",
                     "scored identical windows. ", join_and(dataset_label(v$dataset[!v$same_test_windows])), " were excluded ",
                     "because some analytical units were ineligible for within-dataset testing",
                     if (length(no_within)) paste0("; ", join_and(dataset_label(no_within)), " had no valid within-dataset evaluation"),
                     ". Difference denotes within-dataset minus cross-dataset Macro-F1. Tests were two-sided ",
                     if (exact) "exact " else "", "Wilcoxon signed-rank tests",
                     if (!exact) " (exact, or the normal approximation with continuity correction where there were ties or zero differences)",
                     ". Reported p-values are unadjusted. After Holm adjustment across the ", words(t$holm_tests[1]),
                     " classifiers, ", holm_text, ". Rank-biserial r is the matched-pairs effect size."),
              paste0("04_Statistics/results/", main_scenario, c("/h1_tests.csv", "/h1_values.csv", "/seed_means.csv")))
}

# Table S10: post-hoc class comparisons (Holm over the three pairs of a classifier and response).
table_s_h2_posthoc <- function() {
  raw <- read_stats(main_scenario, "h2_posthoc")
  raw <- raw[raw$datasets == "all", ]
  ph <- do.call(rbind, lapply(c("cross_f1", "transfer_loss_f1"), function(resp) {
    do.call(rbind, lapply(model_keys, function(m) {
      do.call(rbind, lapply(class_pairs, function(pair) posthoc_pair(raw[raw$response == resp, ], m, pair)))
    }))
  }))
  out <- data.frame(a = ifelse(ph$response == "cross_f1", "Cross-dataset F1", "Transfer loss"),
                    b = unname(model_labels[ph$model]), c = paste(ph$behavior_1, "vs.", ph$behavior_2),
                    d = med_iqr(ph$diff_median, ph$diff_q1, ph$diff_q3), e = stat_v(ph$V), f = p_txt(ph$p_value),
                    g = p_txt(ph$p_holm), h = num(ph$rank_biserial, 2))
  names(out) <- c("Response", "Classifier", "Comparison", "Difference", "Wilcoxon V", "p", "p (Holm)", "Rank-biserial r")
  n_cross <- unique(ph$n_pairs[ph$response == "cross_f1"])
  n_loss <- unique(ph$n_pairs[ph$response == "transfer_loss_f1"])
  if (length(n_cross) != 1L || length(n_loss) != 1L) stop("different numbers of datasets in the post-hoc tests")
  significant <- any(ph$friedman_significant_holm)
  write_table("h2_posthoc", "Pairwise post-hoc comparisons of behavioral classes.", out,
              paste0("Cross-dataset F1 comparisons included ", n_cross, " target datasets; transfer-loss comparisons included ",
                     "the ", words(n_loss), " datasets with both within- and cross-dataset scores. Dataset-level scores were ",
                     "averaged over five training seeds. Difference is the median [first quartile, third quartile] of paired ",
                     "differences, calculated as the first class minus the second. Transfer loss denotes within-dataset minus ",
                     "cross-dataset F1. Tests were two-sided ", if (all(ph$test_method == "exact")) "exact " else "",
                     "Wilcoxon signed-rank tests, with Holm adjustment across the three class comparisons within each ",
                     "classifier and response. Rank-biserial r is the matched-pairs effect size. ",
                     if (!significant) paste0("None of the corresponding Friedman tests remained significant after Holm ",
                                              "adjustment across the ", words(length(model_keys)), " classifiers. All ",
                                              "post-hoc comparisons are therefore reported descriptively, including those ",
                                              "with pairwise Holm-adjusted p-values below 0.05.")
                     else paste0("Post-hoc comparisons are interpreted only where the corresponding Friedman test remained ",
                                 "significant after Holm adjustment across the ", words(length(model_keys)), " classifiers.")),
              paste0("04_Statistics/results/", main_scenario, "/h2_posthoc.csv"))
}

# Table S11: transfer loss by class, primary dataset set and the datasets with identical
# evaluation windows (D44).
table_s_h2_loss <- function() {
  v <- read_stats(main_scenario, "h1_values")
  excluded <- dataset_label(unique(v$dataset[!v$same_test_windows]))
  sets <- c(all = "Primary", same_test_windows = "Sensitivity")
  out <- do.call(rbind, lapply(names(sets), function(ds) {
    data.frame(Dataset = paste0(sets[[ds]], ", n = ", n_blocks("transfer_loss_f1", ds)),
               class_table("transfer_loss_f1", datasets = ds), check.names = FALSE)
  }))
  names(out) <- c("Dataset", "Classifier", classes, paste("Friedman", CHI2), "p", "p (Holm)", paste0("Kendall", APOS, "s W"))
  write_table("h2_loss", "Behavior-specific transfer losses and sensitivity analysis.", out,
              paste0("Transfer loss is within-dataset minus cross-dataset F1, summarized as median [first quartile, third ",
                     "quartile] across datasets after averaging scores over five training seeds. Positive values indicate lower ",
                     "F1 under cross-dataset transfer. The primary comparison included ", words(n_blocks("transfer_loss_f1")),
                     " datasets with both evaluation scores. The sensitivity analysis excluded ", join_and(excluded),
                     ", retaining the ", words(n_blocks("transfer_loss_f1", "same_test_windows")), " datasets for which both ",
                     "evaluations scored identical windows. Friedman tests compared the three behavioral classes within each ",
                     "classifier and dataset set (df = 2). Holm adjustment was applied across the ", words(length(model_keys)),
                     " classifier-specific tests separately for each dataset set. Kendall", APOS, "s W is the effect size. ",
                     "Pairwise comparisons for the primary dataset set are reported in ", table_ref("h2_posthoc"), "."),
              paste0("04_Statistics/results/", main_scenario, c("/h2_descriptives.csv", "/h2_friedman.csv", "/h1_values.csv")))
}

# =========================================================
# Supplement: tables S12-S16 (H3)
# =========================================================
# Table S12: the primary mixed model (fixed and random effects, tests and fit).
table_s_h3_model <- function() {
  fe <- read_stats(main_scenario, "h3_fixed_effects")
  fe <- fe[fe$analysis == "primary", ]
  m <- read_stats(main_scenario, "h3_models")
  prim <- m[m$analysis == "primary", ]
  inter <- m[m$analysis == "interaction distance x model", ]
  re <- read_stats(main_scenario, "h3_random_effects")
  d <- read_stats(main_scenario, "h3_data")
  term_label <- function(t) {
    if (t == "(Intercept)") return("Intercept: CNN at mean distance")
    if (t == "z_distance") return("Trait distance, per SD")
    paste(model_labels[[tolower(sub("^model", "", t))]], "vs. CNN")
  }
  fixed <- data.frame(a = "Fixed effects", b = vapply(fe$term, term_label, character(1)),
                      c = est_ci(fe$estimate, fe$ci_low, fe$ci_high), d = num(fe$std_error), e = num(fe$df, 1),
                      f = num(fe$statistic, 2), g = p_txt(fe$p_value))
  groups <- c(unordered_species_pair = "Unordered species pair", ordered_species_pair = "Ordered species pair",
              train_species = "Source species", test_species = "Target species", Residual = "Residual")
  re <- re[match(names(groups), re$group), ]
  random <- data.frame(a = ifelse(re$group == "Residual", "Residual SD", "Random-effect SD"), b = unname(groups),
                       c = num(re$std_dev), d = NA, e = NA, f = NA, g = NA)
  tests <- data.frame(
    a = c("Likelihood-ratio test", "Likelihood-ratio test", "Model fit", "Sample size"),
    b = c("Trait distance", paste("Distance", TIMES, "classifier interaction"), paste("Marginal / conditional", R2), "Observations"),
    c = c(paste0(CHI2, "(", prim$lr_df, ") = ", num(prim$lr_chisq, 2)), paste0(CHI2, "(", inter$lr_df, ") = ", num(inter$lr_chisq, 2)),
          r2_pair(prim$r2_marginal, prim$r2_conditional), as.character(prim$n_observations)),
    d = NA, e = NA, f = NA, g = c(p_txt(prim$lr_p_value), p_txt(inter$lr_p_value), NA, NA))
  out <- rbind(fixed, random, tests)
  names(out) <- c("Component", "Term", "Estimate [95% CI] or value", "SE", "df", "t", "p")
  n_species <- length(unique(c(d$train_species, d$test_species)))
  write_table("h3_model", "Primary mixed-effects model for cross-species transfer.", out,
              paste0("The response was cross-species Macro-F1, with one observation per classifier and ordered source", DASH,
                     "target species pair, averaged over the contributing dataset pairs and five training seeds. The analysis ",
                     "included ", prim$n_ordered_pairs, " ordered pairs of ", words(n_species), " species and ",
                     words(prim$n_models), " classifiers; same-species transfers were excluded. Fixed effects were standardized ",
                     "trait distance and classifier, with CNN as the reference. Random intercepts represented unordered species ",
                     "pair, ordered species pair, source species and target species. Fixed-effect estimates, confidence ",
                     "intervals and t tests were obtained from the restricted maximum-likelihood fit using Satterthwaite degrees ",
                     "of freedom. Likelihood-ratio tests compared maximum-likelihood fits with and without the distance term; the ",
                     "interaction test compared the interaction model with the additive model. The distance t-test p-value and ",
                     "likelihood-ratio p-value therefore refer to different tests. Marginal ", R2, " represents fixed effects, and ",
                     "conditional ", R2, " represents fixed and random effects."),
              paste0("04_Statistics/results/", main_scenario, c("/h3_fixed_effects.csv", "/h3_models.csv", "/h3_random_effects.csv")))
}

# Table S13: robustness analyses of the distance effect (model variants, alternative
# distances, trait sensitivity).
table_s_h3_robustness <- function() {
  m <- read_stats(main_scenario, "h3_models")
  missing <- setdiff(names(h3_labels), m$analysis)
  if (length(missing)) stop("analyses missing in h3_models.csv: ", paste(missing, collapse = ", "))
  m <- m[match(names(h3_labels), m$analysis), ]
  out <- data.frame(a = unname(h3_labels), b = m$n_observations, c = est_ci(m$estimate, m$ci_low, m$ci_high),
                    d = paste0(num(m$lr_chisq, 2), " (", m$lr_df, ")"), e = p_txt(m$lr_p_value),
                    f = r2_pair(m$r2_marginal, m$r2_conditional), g = yes_no(m$singular_reml))
  names(out) <- c("Analysis", "n", paste(BETA, "per SD [95% CI]"), paste("LR", CHI2, "(df)"), "p",
                  paste(R2, "marginal / conditional"), "Singular fit")
  write_table("h3_robustness", "Robustness analyses of the biological-distance association.", out,
              paste0(BETA, " represents the change in the response per standard deviation of distance. Estimates and 95% ",
                     "confidence intervals were obtained from restricted maximum-likelihood fits using Satterthwaite degrees of ",
                     "freedom. LR denotes likelihood-ratio tests of maximum-likelihood fits against the corresponding model ",
                     "without distance; the interaction test compared the interaction and additive models. These robustness ",
                     "analyses are exploratory, and p-values are unadjusted for multiple testing. The model without the unordered ",
                     "pair retained random intercepts for ordered pair, source species and target species. The ordered-pair-only ",
                     "model omitted the species effects. Adjustment for within-dataset Macro-F1 included source and target ",
                     "performance as covariates and excluded pairs involving Hedgehog. Retention was transfer Macro-F1 divided by ",
                     "the target", APOS, "s within-dataset Macro-F1; Hedgehog was excluded as a target. Alternative distances ",
                     "replaced the core trait distance in the primary model. EltonTraits variable selection and coding are ",
                     "described in Supplementary ", text_ref("elton"), ". Trait sensitivity analyses changed one coding decision ",
                     "or omitted one core trait, retaining equal weights for the remaining traits. The cattle neck-length variant ",
                     "was added after the results were known. Singular fit indicates a boundary fit of the random-effects ",
                     "structure. Values are rounded."),
              paste0("04_Statistics/results/", main_scenario, "/h3_models.csv"))
}

# Table S14: slopes per classifier (interaction model) and Spearman correlations.
table_s_per_classifier <- function() {
  sl <- read_stats(main_scenario, "h3_slopes")
  sp <- read_stats(main_scenario, "h3_spearman")
  inter <- read_stats(main_scenario, "h3_models")
  inter <- inter[inter$analysis == "interaction distance x model", ]
  keys <- c("CNN", "ResNet", "HYDRA", "MultiRocket", "RF", "LGBM")
  sl <- sl[match(keys, sl$model), ]
  sp <- sp[match(keys, sp$model), ]
  out <- data.frame(a = unname(model_labels[tolower(keys)]), b = est_ci(sl$estimate, sl$ci_low, sl$ci_high),
                    c = p_txt(sl$p_value), d = est_ci(sp$rho, sp$ci_low, sp$ci_high), e = p_txt(sp$p_value),
                    f = p_txt(sp$p_holm))
  names(out) <- c("Classifier", paste(BETA, "per SD [95% CI]"), "p (slope)", paste("Spearman", RHO, "[95% CI]"),
                  "p (Spearman)", "p (Spearman, Holm)")
  n <- unique(sp$n)
  if (length(n) != 1L) stop("different numbers of species pairs per classifier")
  write_table("per_classifier", "Classifier-specific associations between trait distance and cross-species Macro-F1.", out,
              paste0("Each classifier contributed ", n, " ordered source", DASH, "target species pairs. ", BETA, " represents the ",
                     "classifier-specific slope of standardized core trait distance in the mixed-effects model containing the ",
                     "distance ", TIMES, " classifier interaction. Estimates and confidence intervals were obtained from the ",
                     "restricted maximum-likelihood fit using Satterthwaite degrees of freedom. The overall interaction was ",
                     if (inter$lr_p_value < 0.05) "significant" else "not significant", " (likelihood-ratio ", CHI2, "(",
                     inter$lr_df, ") = ", num(inter$lr_chisq, 2), ", ", p_eq(inter$lr_p_value), "). Spearman correlations are ",
                     "descriptive summaries of the species-pair associations. Their confidence intervals were calculated using ",
                     "Fisher", APOS, "s z transformation, and their p-values were Holm-adjusted across the ",
                     words(length(keys)), " classifiers. These correlations do not account for the dyadic dependence ",
                     "represented in the mixed-effects model."),
              paste0("04_Statistics/results/", main_scenario, c("/h3_slopes.csv", "/h3_spearman.csv", "/h3_models.csv")))
}

# Table S15: leave-one-species-out refits of the primary model.
table_s_loso <- function() {
  l <- read_stats(main_scenario, "h3_loso")
  l <- l[order(species_label(l$left_out)), ]
  out <- data.frame(a = species_label(l$left_out, long = TRUE), b = est_ci(l$estimate, l$ci_low, l$ci_high),
                    c = num(l$std_error), d = num(l$lr_chisq, 2), e = p_txt(l$lr_p_value),
                    f = r2_pair(l$r2_marginal, l$r2_conditional), g = yes_no(l$singular_reml))
  names(out) <- c("Species excluded", paste(BETA, "per SD [95% CI]"), "SE", paste("LR", CHI2), "p",
                  paste(R2, "marginal / conditional"), "Singular fit")
  n <- unique(l[c("n_observations", "n_ordered_pairs", "n_models")])
  if (nrow(n) != 1L) stop("the leave-one-species-out refits differ in size")
  n_species <- length(unique(l$left_out)) - 1L
  write_table("loso", "Leave-one-species-out robustness analysis.", out,
              paste0("Each analysis removed all source", DASH, "target pairs involving the indicated species and refitted the ",
                     "primary mixed-effects model. Each refit included ", n$n_observations, " observations: ", n$n_ordered_pairs,
                     " ordered pairs of ", words(n_species), " remaining species across ", words(n$n_models), " classifiers. ",
                     "Trait distance was standardized again within each refit. ", BETA, " and its 95% confidence interval were ",
                     "obtained from the restricted maximum-likelihood fit. LR denotes the likelihood-ratio test against the ",
                     "corresponding model without distance (df = 1). These exploratory p-values are unadjusted for multiple ",
                     "testing. Singular fit indicates a boundary fit of the random-effects structure."),
              paste0("04_Statistics/results/", main_scenario, "/h3_loso.csv"))
}

# Table S16: the primary model per training seed.
table_s_seeds <- function() {
  s <- read_stats(main_scenario, "h3_seeds")
  out <- data.frame(a = s$seed, b = est_ci(s$estimate, s$ci_low, s$ci_high), c = num(s$std_error),
                    d = num(s$lr_chisq, 2), e = p_txt(s$lr_p_value), f = r2_pair(s$r2_marginal, s$r2_conditional),
                    g = yes_no(s$singular_reml))
  names(out) <- c("Training seed", paste(BETA, "per SD [95% CI]"), "SE", paste("LR", CHI2), "p",
                  paste(R2, "marginal / conditional"), "Singular fit")
  n <- unique(s[c("n_observations", "n_ordered_pairs", "n_models")])
  if (nrow(n) != 1L) stop("the seed fits differ in size")
  write_table("seeds", "Seed-level robustness analysis of the biological-distance association.", out,
              paste0("The primary mixed-effects model was fitted separately to the results of each training seed. Each fit ",
                     "included ", n$n_observations, " observations representing ", n$n_ordered_pairs, " ordered species pairs ",
                     "and ", words(n$n_models), " classifiers. ", BETA, " is the change in cross-species Macro-F1 per standard ",
                     "deviation of core trait distance, with confidence intervals obtained from the restricted maximum-likelihood ",
                     "fit. LR denotes the likelihood-ratio test against the corresponding model without distance (df = 1). These ",
                     "analyses describe variability between training runs; the primary H3 analysis uses scores averaged over all ",
                     words(nrow(s)), " seeds. Singular fit indicates a boundary fit of the random-effects structure."),
              paste0("04_Statistics/results/", main_scenario, "/h3_seeds.csv"))
}

# =========================================================
# Supplement: table S17 (sensitivity scenarios)
# =========================================================
scenario_rows <- function() {
  present <- names(scenarios)[file.exists(file.path(stats_dir, names(scenarios), "h1_tests.csv"))]
  h1 <- do.call(rbind, lapply(present, function(s) {
    t <- read_stats(s, "h1_tests")
    t <- t[t$model %in% c("rf", "lgbm") & t$datasets == "all" & t$metric == "macro_f1", ]
    cbind(scenario = s, t)
  }))
  h2 <- do.call(rbind, lapply(present, function(s) {
    f <- read_stats(s, "h2_friedman")
    f <- f[f$model %in% c("rf", "lgbm") & f$response == "cross_f1" & f$datasets == "all", ]
    cbind(scenario = s, f)
  }))
  h3 <- do.call(rbind, lapply(present[file.exists(file.path(stats_dir, present, "h3_models.csv"))], function(s) {
    m <- read_stats(s, "h3_models")
    key <- if (s == "primary") "RF and LGBM only (D27)" else "primary"
    cbind(scenario = s, m[m$analysis == key, ])
  }))
  list(present = present, h1 = h1, h2 = h2, h3 = h3)
}

table_s_scenarios <- function() {
  s <- scenario_rows()
  out <- do.call(rbind, lapply(s$present, function(sc) {
    h1 <- s$h1[s$h1$scenario == sc, ]
    h2 <- s$h2[s$h2$scenario == sc, ]
    h3 <- s$h3[s$h3$scenario == sc, ]
    cell_h1 <- function(m) {
      r <- h1[h1$model == m, ]
      if (nrow(r) == 0L) return(c(EMDASH, EMDASH))
      c(med_iqr(r$gap_median, r$gap_q1, r$gap_q3), p_txt(r$p_value))
    }
    cell_h2 <- function(m) {
      r <- h2[h2$model == m, ]
      if (nrow(r) == 0L) return(EMDASH)
      paste0(CHI2, "(", r$df, ") = ", num(r$chi_sq, 2), ", ", p_eq(r$p_value))
    }
    rf <- cell_h1("rf")
    lg <- cell_h1("lgbm")
    data.frame(a = unname(scenarios[sc]), b = max(h1$n_pairs), c = rf[1], d = rf[2], e = lg[1], f = lg[2],
               g = cell_h2("rf"), h = cell_h2("lgbm"),
               i = if (nrow(h3) == 1L) est_ci(h3$estimate, h3$ci_low, h3$ci_high) else EMDASH,
               j = if (nrow(h3) == 1L) p_txt(h3$lr_p_value) else EMDASH)
  }))
  names(out) <- c("Scenario", "H1 n", "H1 difference, RF", "H1 p, RF", "H1 difference, LightGBM", "H1 p, LightGBM",
                  "H2 Friedman test, RF", "H2 Friedman test, LightGBM", paste("H3", BETA, "per SD [95% CI]"), "H3 p")
  # Datasets of H1 that a scenario loses (no valid within-dataset evaluation there).
  h1_sets <- lapply(setNames(s$present, s$present), function(sc) unique(read_stats(sc, "h1_values")$dataset))
  lost <- lapply(s$present, function(sc) setdiff(h1_sets[["primary"]], h1_sets[[sc]]))
  lost_text <- unlist(lapply(seq_along(lost), function(i) {
    if (length(lost[[i]]) == 0L) return(NULL)
    sc <- s$present[i]
    name <- if (sc == "four_classes") "the four-class scenario" else paste0("the scenario “", scenarios[[sc]], "”")
    paste0("In ", name, ", ", join_and(dataset_label(lost[[i]])), " additionally lacked valid within-dataset evaluations, ",
           "leaving ", words(length(h1_sets[[sc]])), " paired datasets.")
  }))
  write_table("scenarios", paste0("Sensitivity analyses of H1", DASH, "H3 using Random Forest and LightGBM."), out,
              c(paste(c("H1 difference is within-dataset minus cross-dataset Macro-F1, summarized as median [first quartile, third quartile] across datasets with both evaluation scores. H1 p-values are unadjusted and are from paired Wilcoxon signed-rank tests. H1 n denotes the number of paired datasets.",
                        lost_text), collapse = " "),
                "H2 reports Friedman tests of cross-dataset F1 across behavioral classes. All H2 p-values shown here are unadjusted. The four-class scenario compares four classes and is therefore not directly equivalent to the three-class comparisons.",
                paste0("H3 reports the standardized distance coefficient and unadjusted likelihood-ratio p-value from the primary ",
                       "mixed-effects model fitted to RF and LightGBM only. This restriction also applies to the primary reference ",
                       "row, ensuring comparable classifier coverage across scenarios. All H1", DASH, "H3 p-values in this table are ",
                       "unadjusted and are reported for exploratory comparison across scenarios. Scenario definitions are provided ",
                       "in Supplementary ", text_ref("scenarios"), ".")),
              c("04_Statistics/results/<scenario>/h1_tests.csv", "04_Statistics/results/<scenario>/h1_values.csv",
                "04_Statistics/results/<scenario>/h2_friedman.csv", "04_Statistics/results/<scenario>/h3_models.csv"))
}

# =========================================================
# Supplement: figures
# =========================================================
# Figure S1: the workflow diagram (drawn by hand; 05_Paper_Outputs/assets/).
figure_s_workflow <- function() {
  it <- output_item("Figure", "workflow")
  if (!file.exists(workflow_file)) stop(rel_path(workflow_file), " not found")
  dir.create(file.path(out_dir, it$folder), recursive = TRUE, showWarnings = FALSE)
  file <- file.path(out_dir, it$folder, paste0(it$name, ".png"))
  file.copy(workflow_file, file, overwrite = TRUE)
  register(it, file, "Overview of the analytical workflow.", rel_path(workflow_file))
  cat("[OK]", rel_path(file), "\n")
  write_caption("workflow", paste0(
    "Overview of the analytical workflow. Eleven accelerometer datasets representing nine terrestrial mammal species ",
    "were processed using a common preprocessing and behavioral harmonization framework. Six classifiers were evaluated ",
    "across three generalization settings to address hypotheses H1", DASH, "H3. The Horse branch groups Horse 1 ",
    "(Przewalski", APOS, "s horse) and Horse 2 (domestic horse), which were treated as separate species in the ",
    "cross-species analyses."))
}

# Figure S2: transfer loss by class.
figure_s_h2_loss <- function() {
  p <- plot_classes("transfer_loss_f1", "Transfer loss (F1)")
  save_figure(p, "h2_loss", 180, 118, "Transfer loss by behavioral class and classifier.",
              paste0("04_Statistics/results/", main_scenario, c("/h2_values.csv", "/h2_friedman.csv")))
  write_caption("h2_loss", paste0("Transfer loss by behavioral class and classifier. Within- minus cross-dataset F1; ",
                                  "points: test datasets (n = ", n_blocks("transfer_loss_f1"), "), mean of five training seeds; ",
                                  "boxes: median and interquartile range. Statistics: ", table_ref("h2_loss"), "."))
}

# Figure S3: mean row-normalized cross-dataset confusion matrices (h2_confusion_cross.csv of
# 04_Statistics/stats_h1_h2.py, from 03_Evaluation/results/primary/<model>/confusion.csv).
figure_s_confusion <- function() {
  file <- file.path(stats_dir, main_scenario, "h2_confusion_cross.csv")
  if (!file.exists(file)) {
    need <- file.path("03_Evaluation", "results", main_scenario, model_keys, "confusion.csv")
    stop(rel_path(file), " not found; it needs ", paste(need[!file.exists(file.path(root, need))], collapse = ", "),
         " and a run of 04_Statistics/stats_h1_h2.py")
  }
  d <- read.csv(file)
  d <- d[d$truth %in% classes & d$pred %in% classes, ]
  d$model <- model_factor(d$model)
  d$truth <- factor(d$truth, levels = rev(classes))
  d$pred <- factor(d$pred, levels = classes)
  d$label <- paste0(formatC(d$percent_mean, format = "f", digits = 1), "%")
  p <- ggplot(d, aes(pred, truth, fill = percent_mean)) +
    geom_tile(colour = "white", linewidth = 0.8) +
    geom_text(aes(label = label, colour = percent_mean > 50), size = 2.9) +
    scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = INK), guide = "none") +
    scale_fill_gradient(low = "white", high = CONFUSION_HIGH, limits = c(0, 100), breaks = seq(0, 100, 25),
                        labels = function(x) paste0(x, "%"), name = "Proportion") +
    facet_wrap(~ model, ncol = 3) +
    coord_equal() +
    labs(x = "Predicted behavior", y = "True behavior") +
    theme_minimal(base_size = 10) +
    theme(panel.grid = element_blank(), strip.text = element_text(face = "bold", size = 10),
          axis.text = element_text(colour = INK_2), axis.text.x = element_text(angle = 30, hjust = 1),
          legend.title = element_text(size = 10), plot.background = element_rect(fill = "white", colour = NA))
  save_figure(p, "confusion", 180, 112.5, "Row-normalized confusion matrices for cross-dataset evaluation by classifier.",
              paste0("04_Statistics/results/", main_scenario, "/h2_confusion_cross.csv"))
  write_caption("confusion", paste0(
    "Row-normalized confusion matrices for cross-dataset evaluation by classifier. Rows represent true behaviors and columns ",
    "represent predicted behaviors. For each classifier, counts were normalized within each true behavior for each target ",
    "dataset and training seed. Cell values show the resulting percentages averaged across ", max(d$n_datasets),
    " target datasets and ", words(max(d$n_seeds)), " training seeds, with equal weight given to each dataset and seed. ",
    "Diagonal cells show the percentage of correctly classified windows for each behavior."))
}

# =========================================================
# Run
# =========================================================
main <- function() {
  jobs <- list(table_1 = table_1, figure_1 = figure_1, table_2 = table_2, figure_2 = figure_2,
               table_3 = table_3, figure_3 = figure_3,
               table_s_datasets = table_s_datasets, table_s_windows = table_s_windows,
               table_s_mapping = table_s_mapping, table_s_preprocessing = table_s_preprocessing,
               table_s_features = table_s_features, table_s_models = table_s_models,
               table_s_trait_definitions = table_s_trait_definitions, table_s_traits = table_s_traits,
               table_s_h1_same_windows = table_s_h1_same_windows, table_s_h2_posthoc = table_s_h2_posthoc,
               table_s_h2_loss = table_s_h2_loss, table_s_h3_model = table_s_h3_model,
               table_s_h3_robustness = table_s_h3_robustness, table_s_per_classifier = table_s_per_classifier,
               table_s_loso = table_s_loso, table_s_seeds = table_s_seeds, table_s_scenarios = table_s_scenarios,
               figure_s_workflow = figure_s_workflow, figure_s_h2_loss = figure_s_h2_loss,
               figure_s_confusion = figure_s_confusion)
  dir.create(out_dir, showWarnings = FALSE)
  # Remove the generated files of the last run (not the hand-written texts), so a renumbered
  # or dropped item leaves no file with an outdated number behind.
  for (folder in c(MAIN, SUPP)) {
    old <- list.files(file.path(out_dir, folder), pattern = "^(table|figure)_.*\\.(txt|png)$", full.names = TRUE)
    if (length(old) > 0L) file.remove(old)
  }
  errors <- character()
  for (name in names(jobs)) {
    result <- tryCatch({
      jobs[[name]]()
      NULL
    }, error = function(e) conditionMessage(e))
    if (!is.null(result)) {
      errors <- c(errors, paste0(name, ": ", result))
      cat("[ERROR]", name, ":", result, "\n")
    }
  }
  for (i in seq_len(nrow(texts))) {
    label <- text_ref(texts$key[i])
    if (file.exists(file.path(out_dir, texts$file[i]))) {
      contents <<- rbind(contents, data.frame(item = label, section = SUPP, title = texts$title[i],
                                              file = rel_path(file.path(out_dir, texts$file[i])), caption_file = "",
                                              sources = texts$sources[i]))
    } else {
      errors <- c(errors, paste0(label, ": ", texts$file[i], " not found"))
    }
  }
  # output_manifest.csv: main, then supplementary; tables, figures, texts; by number.
  m <- contents
  type <- sub(" .*", "", m$item)
  number <- suppressWarnings(as.numeric(sub("^[A-Za-z]+ S?", "", m$item)))
  m <- m[order(match(m$section, c(MAIN, SUPP)), match(type, c("Table", "Figure", "Text")), number), ]
  m$produced_by <- vapply(m$sources, producer, character(1), USE.NAMES = FALSE)
  m$cited_in <- ifelse(m$item %in% names(cited_in), cited_in[m$item], "")
  m$cited_in[!nzchar(m$cited_in)] <- "not cited yet"
  write.csv(m, file.path(out_dir, "output_manifest.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  cat("[OK]", rel_path(file.path(out_dir, "output_manifest.csv")), "\n")
  error_file <- file.path(out_dir, "errors.txt")
  if (length(errors) > 0L) {
    write_lines_utf8(c("PAPER FIGURE ERRORS", paste0("Created: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "", errors),
                     error_file)
    return(1L)
  }
  if (file.exists(error_file)) file.remove(error_file)
  0L
}

status <- main()
if (!interactive()) quit(status = status, save = "no")
