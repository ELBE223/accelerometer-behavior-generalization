# paper_figures.R
#
# Figures (png, 600 dpi) and tables (txt) of the paper from 04_Statistics/results/ (no model fitting).
#   05_Paper_Outputs/main/                Figures 1-3, Tables 1-3 (+ figure_<nn>_*_caption.txt)
#   05_Paper_Outputs/supplementary/       Tables S1-S20, Figures S1-S3, numbered as cited in the
#                                         manuscript (block "Numbering" below)
#   05_Paper_Outputs/output_manifest.csv  every output with title, file, sources, the script
#                                         that made the sources and where the manuscript cites it
# Generated files (table_*, figure_*) in main/ and supplementary/ are deleted before each
# run, so no output with an outdated number is left behind; hand-written files
# (Text S1) are kept.
# Values are means over the five training seeds (D26); scenario "primary".
# Every plot has its legend; title and caption only in <figure>_caption.txt.
# Classes always in the order Resting, Locomotion, Foraging.
# Tables: tab-separated text (Word: Insert > Table > Convert Text to Table).
# A failing item is skipped and logged in 05_Paper_Outputs/errors.txt.
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
out_dir <- file.path(root, "05_Paper_Outputs")
MAIN <- "main"
SUPP <- "supplementary"

# =========================================================
# Settings
# =========================================================
dpi <- 600          # png resolution
base_size <- 8      # font size in pt at the printed size (180 mm = double column)
main_scenario <- "primary"

model_keys <- c("cnn", "resnet", "hydra", "multirocket", "rf", "lgbm")  # thesis order
model_labels <- c(cnn = "CNN", resnet = "ResNet", hydra = "HYDRA", multirocket = "MultiRocket", rf = "RF",
                  lgbm = "LightGBM")
classes <- c("Resting", "Locomotion", "Foraging")  # order in every figure and table
class_pairs <- list(c("Resting", "Locomotion"), c("Resting", "Foraging"), c("Locomotion", "Foraging"))
common_names <- c("Bison bonasus" = "Bison", "Bos taurus" = "Cattle", "Canis lupus familiaris" = "Dog",
                  "Equus caballus" = "Horse", "Equus ferus przewalskii" = "Przewalski's horse",
                  "Erinaceus europaeus" = "Hedgehog", "Giraffa camelopardalis" = "Giraffe",
                  "Procyon lotor" = "Raccoon", "Vulpes vulpes" = "Red fox")
scenarios <- c(primary = "Primary", A = "A: no overlap in training", C = "C: 2.4 s windows",
               majority = "Majority class (80 %)", four_classes = "Four classes (with Other)",
               E = "E: ridden gaits as Locomotion", F = "F: thesis-rule individuals only")

# Palette (light mode).
INK <- "#0b0b0b"
INK_2 <- "#52514e"
GRID <- "#e1e0d9"
AXIS <- "#c3c2b7"
POINT_GREY <- "#a8a79f"
class_colors <- c(Foraging = "#2a78d6", Locomotion = "#eb6834", Resting = "#1baf7a")

# Unicode (escaped, so the script reads the same in every locale).
CHI2 <- "\u03c7\u00b2"
BETA <- "\u03b2"
RHO <- "\u03c1"
DASH <- "\u2013"
MINUS <- "\u2212"
PM <- "\u00b1"

# =========================================================
# Helpers
# =========================================================
read_stats <- function(scenario, name) {
  d <- read.csv(file.path(stats_dir, scenario, paste0(name, ".csv")), check.names = FALSE)
  # pandas writes True/False, which read.csv keeps as text.
  d[] <- lapply(d, function(x) if (is.character(x) && all(x %in% c("True", "False", NA))) as.logical(x) else x)
  d
}
rel_path <- function(path) sub(paste0("^", root, "/"), "", path)
model_factor <- function(x) factor(unname(model_labels[tolower(x)]), levels = unname(model_labels))
short <- function(dataset) sub("_dataset_", " ", dataset)
common <- function(species) ifelse(species %in% names(common_names), common_names[species], species)

num <- function(x, digits = 3) {
  x <- as.numeric(x)
  x[!is.na(x) & abs(x) < 0.5 * 10^-digits] <- 0  # no "-0.000"
  ifelse(is.na(x), DASH, formatC(x, format = "f", digits = digits))
}
int <- function(x) ifelse(is.na(x), DASH, formatC(as.numeric(x), format = "d", big.mark = ","))
stat_v <- function(v) ifelse(is.na(v), DASH, ifelse(v == round(v), formatC(v, format = "d"), num(v, 1)))
p_txt <- function(p) ifelse(is.na(p), DASH, ifelse(p < 0.001, "< 0.001", formatC(p, format = "f", digits = 3)))
med_iqr <- function(m, q1, q3, digits = 3) paste0(num(m, digits), " [", num(q1, digits), ", ", num(q3, digits), "]")
mean_sd <- function(m, s, digits = 3) ifelse(is.na(m), DASH, paste0(num(m, digits), " ", PM, " ", num(s, digits)))
est_ci <- function(e, lo, hi, digits = 3) {
  ifelse(is.na(e), DASH, paste0(num(e, digits), " [", num(lo, digits), ", ", num(hi, digits), "]"))
}
minus <- function(s) gsub("-", MINUS, s, fixed = TRUE)  # typographic minus in figure text
yes_no <- function(x) ifelse(as.logical(x), "yes", "no")

contents <- data.frame(item = character(), section = character(), title = character(), file = character(),
                       caption_file = character(), sources = character())
register <- function(it, path, title, source) {
  contents <<- rbind(contents, data.frame(item = it$label, section = it$folder, title = title, file = rel_path(path),
                                          caption_file = "", sources = paste(source, collapse = ", ")))
}

write_lines_utf8 <- function(lines, file) writeLines(enc2utf8(lines), con = file, useBytes = TRUE)

# =========================================================
# Numbering (as cited in the manuscript; the one place to change it)
# =========================================================
# Every output has a key. Tables 1-3 and Figures 1-3 go to main/, the supplementary items to
# supplementary/. Only items the manuscript cites are made; renumbering one is one change in
# these vectors: file names, titles, captions, cross-references and output_manifest.csv
# follow. Numbers as cited in the manuscript draft of 2026-11-08.
main_tables <- c(h1 = "1", h2 = "2", h3 = "3")
main_figures <- c(h1 = "1", h2 = "2", h3 = "3")
table_numbers <- c(datasets = "S1", mapping = "S2", preprocessing = "S3", features = "S4", models = "S5",
                   trait_definitions = "S6", traits = "S7", distances = "S8", h3_variants = "S9",
                   h1_values = "S10", h1_tests = "S11", h2_values = "S12", h2_posthoc = "S13", h2_loss = "S14",
                   pairwise = "S15", h3_model = "S16", per_classifier = "S17", loso = "S18", seeds = "S19",
                   scenarios = "S20")
figure_numbers <- c(class_windows = "S1", h1_accuracy = "S2", h2_loss = "S3")
# File names: <type>_<nn>_<slug> (main), <type>_s<nn>_<slug> (supplementary).
table_slugs <- c(h1 = "h1_macro_f1", h2 = "h2_class_f1", h3 = "h3_distance_measures",
                 datasets = "datasets", mapping = "label_mapping", preprocessing = "preprocessing",
                 features = "features", models = "classifiers", trait_definitions = "trait_definitions",
                 traits = "trait_values", distances = "species_distances", h3_variants = "h3_robustness",
                 h1_values = "h1_per_dataset", h1_tests = "h1_tests", h2_values = "h2_per_dataset",
                 h2_posthoc = "h2_posthoc", h2_loss = "h2_transfer_loss", pairwise = "pairwise_transfer",
                 h3_model = "h3_mixed_model", per_classifier = "h3_per_classifier", loso = "h3_leave_one_species_out",
                 seeds = "h3_per_seed", scenarios = "sensitivity_scenarios")
figure_slugs <- c(h1 = "h1_macro_f1", h2 = "h2_class_f1", h3 = "h3_trait_distance",
                  class_windows = "class_windows", h1_accuracy = "h1_accuracy", h2_loss = "h2_transfer_loss")
# Hand-written supplementary texts (not made here, listed in output_manifest.csv).
texts <- data.frame(item = "Text S1", title = "Sensitivity scenarios.",
                    file = "supplementary/text_s01_sensitivity_scenarios.md",
                    sources = "00_Documentation/decisions.md (D11, D27)")
# Where the manuscript draft (2026-11-08) cites each numbered item; empty: not cited.
cited_in <- c("Table 1" = "Results 3.1; Discussion 4.1", "Figure 1" = "Results 3.1; Discussion 4.1",
              "Table 2" = "Results 3.2; Discussion 4.2", "Figure 2" = "Results 3.2; Discussion 4.2",
              "Table 3" = "Results 3.3; Discussion 4.3", "Figure 3" = "Results 3.3; Discussion 4.3",
              "Table S1" = "Methods 2.1", "Table S2" = "Methods 2.1", "Figure S1" = "Methods 2.1",
              "Table S3" = "Methods 2.2", "Table S4" = "Methods 2.2", "Table S5" = "Methods 2.2",
              "Table S6" = "Methods 2.4", "Table S7" = "Methods 2.4", "Table S8" = "Methods 2.4",
              "Table S9" = "Results 3.3", "Table S10" = "Results 3.1", "Table S11" = "Results 3.1",
              "Figure S2" = "Results 3.1", "Table S12" = "Results 3.2", "Table S13" = "Results 3.2; Table 2",
              "Table S14" = "Results 3.2", "Figure S3" = "Results 3.2", "Table S15" = "",
              "Table S16" = "Results 3.3; Table 3", "Table S17" = "Results 3.3", "Table S18" = "Results 3.3",
              "Table S19" = "Results 3.3", "Table S20" = "Results 3.1; Results 3.2", "Text S1" = "Results 3.1")

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

# Script that wrote a source file (column produced_by of output_manifest.csv).
producer <- function(sources) {
  s <- trimws(unlist(strsplit(sources, ",", fixed = TRUE)))
  p <- ifelse(grepl("/(h1_|h2_|h3_input|seed_)", s), "04_Statistics/stats_h1_h2.py",
              ifelse(grepl("/h3_", s), "04_Statistics/stats_h3.R",
                     ifelse(grepl("pipeline_reports/class_summary", s), "01_Preprocessing/assign_classes.py", "")))
  paste(unique(p[nzchar(p)]), collapse = ", ")
}

# Table as text: title, blank line, header and rows with tabs, blank line, notes, source.
# `key` is a key of main_tables or table_numbers.
write_table <- function(key, title, table, notes = character(), source = character()) {
  it <- output_item("Table", key)
  dir.create(file.path(out_dir, it$folder), recursive = TRUE, showWarnings = FALSE)
  file <- file.path(out_dir, it$folder, paste0(it$name, ".txt"))
  table[] <- lapply(table, function(x) ifelse(is.na(x), DASH, as.character(x)))
  rows <- do.call(paste, c(unname(as.list(table)), sep = "\t"))
  lines <- c(paste0(it$label, ". ", title), "", paste(names(table), collapse = "\t"), rows, "", notes,
             if (length(source) > 0L) paste0("Source: ", paste(source, collapse = ", ")))
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

# Caption of a figure (the plots carry no explanatory text) next to it, with its label
# ("Figure S2. ...") put in front.
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
# Figures 1-2 and S2-S3: boxes with points; legend below the panels, captions in txt files.
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

plot_within_cross <- function(metric, y_label) {
  ggplot(paired_values(metric), aes(mode, value)) +
    geom_line(aes(group = dataset, linetype = "Same dataset"), colour = "#b1b1b1", linewidth = 0.45, alpha = 0.85) +
    geom_boxplot(aes(group = mode, fill = "Median and IQR"), width = 0.4, colour = "#5c5c5c", alpha = 0.65,
                 outlier.shape = NA, linewidth = 0.35) +
    geom_point(aes(group = dataset, shape = "Test dataset"), colour = "#252525", size = 1.5, alpha = 0.9,
               position = position_jitter(width = 0.035, height = 0, seed = 42)) +
    facet_wrap(~ model, ncol = 3) +
    scale_shape_manual(values = c("Test dataset" = 16)) +
    scale_linetype_manual(values = c("Same dataset" = "solid")) +
    scale_fill_manual(values = c("Median and IQR" = "#f1f1f1")) +
    guides(shape = guide_legend(order = 1), linetype = guide_legend(order = 2, override.aes = list(colour = "#8a8a8a")),
           fill = guide_legend(order = 3)) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2), expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = y_label) +
    theme_boxes()
}

# H2: the test datasets of the Friedman test (complete blocks) per classifier.
class_values <- function(response) {
  v <- read_stats(main_scenario, "h2_values")
  fr <- read_stats(main_scenario, "h2_friedman")
  fr <- fr[fr$response == response, ]
  blocks <- unlist(lapply(seq_len(nrow(fr)), function(i) paste(fr$model[i], strsplit(fr$blocks[i], " +")[[1]])))
  v <- v[paste(v$model, v$dataset) %in% blocks & v$behavior %in% classes & is.finite(v[[response]]), ]
  data.frame(model = model_factor(v$model), dataset = v$dataset,
             behavior = factor(v$behavior, levels = classes), value = v[[response]])
}

plot_classes <- function(response, y_label) {
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
    theme(axis.text.x = element_text(size = 8))
}

caption_within_cross <- function(title, metric, ref) {
  n <- length(unique(paired_values(metric)$dataset))
  paste0(title, " Points: test datasets with both values (n = ", n, "), mean of five training seeds; ",
         "lines connect the same dataset; boxes: median and IQR. Statistics: ", ref, ".")
}

caption_classes <- function(title, response, ref) {
  n <- paste(sort(unique(table(class_values(response)$model) / length(classes))), collapse = " or ")
  paste0(title, " Points: test datasets (n = ", n, "), mean of five training seeds; ",
         "boxes: median and IQR. Statistics: ", ref, ".")
}

# H2 summary table (Table 2 for the cross-dataset F1, the transfer-loss table in the
# supplement): median [IQR] per class, Friedman test, Holm-adjusted post-hoc p only after a
# significant Friedman test.
class_table <- function(response, digits = 3, posthoc = FALSE) {
  de <- read_stats(main_scenario, "h2_descriptives")
  fr <- read_stats(main_scenario, "h2_friedman")
  ph <- read_stats(main_scenario, "h2_posthoc")
  de <- de[de$response == response, ]
  fr <- fr[fr$response == response, ]
  ph <- ph[ph$response == response, ]
  rows <- lapply(model_keys, function(m) {
    f <- fr[fr$model == m, ]
    cells <- vapply(classes, function(cl) {
      r <- de[de$model == m & de$behavior == cl, ]
      med_iqr(r$value_median, r$value_q1, r$value_q3, digits)
    }, character(1))
    post <- vapply(class_pairs, function(pair) {
      r <- posthoc_pair(ph, m, pair)
      if (as.logical(r$friedman_significant)) p_txt(r$p_holm) else DASH
    }, character(1))
    out <- c(Classifier = model_labels[[m]], cells, chi = num(f$chi_sq, 2), p = p_txt(f$p_value),
             W = num(f$kendalls_w, 2))
    if (posthoc) out <- c(out, setNames(post, c("ph1", "ph2", "ph3")))
    as.data.frame(as.list(out), check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  names(out) <- c("Classifier", classes, paste0("Friedman ", CHI2), "p", "W",
                  if (posthoc) vapply(class_pairs, function(pair) paste0("p (Holm) ", pair[1], " vs. ", pair[2]), character(1)))
  out
}

# Names of the H3 analyses in figures and tables (descriptive, no S1-S3 codes).
h3_labels <- c("primary" = "Primary model",
               "interaction distance x model" = "Distance \u00d7 classifier interaction",
               "directional random effects" = "Random effects without unordered pair",
               "pair-only random effect" = "Random effect of ordered pair only",
               "S1 within covariates" = "Adjusted for within-dataset Macro-F1",
               "S2 retention" = "Retention as response",
               "S2 log retention" = "Log retention as response",
               "S3 gawdis distance" = "Weighted trait distance (gawdis)",
               "RF and LGBM only (D27)" = "RF and LightGBM only",
               "EltonTraits core" = "EltonTraits",
               "EltonTraits extended" = "EltonTraits with diet",
               "log body mass" = "Body mass difference",
               "divergence time (TimeTree)" = "Phylogenetic distance",
               "exploratory core + C4 (D36)" = "Core traits + trunk motion amplitude",
               "exploratory core + C5 (D37)" = "Core traits + directional change tendency",
               "sensitivity: raccoon separate body configuration (D38)" = "Raccoon as separate body configuration group",
               "sensitivity: hedgehog neck length intermediate (D38)" = "Hedgehog relative neck length intermediate",
               "sensitivity: cattle neck length short (D43)" = "Cattle relative neck length short\u2020",
               "sensitivity: without body mass (D38)" = "Without body mass",
               "sensitivity: without locomotor specialization (D38)" = "Without locomotor specialization",
               "sensitivity: without body configuration (D38)" = "Without body configuration",
               "sensitivity: without relative neck length (D38)" = "Without relative neck length",
               "sensitivity: without food acquisition and handling (D38)" = "Without food acquisition and handling")
h3_variants <- c("primary", "interaction distance x model", "directional random effects", "pair-only random effect",
                 "S1 within covariates", "S2 retention", "S2 log retention", "S3 gawdis distance",
                 "RF and LGBM only (D27)")
h3_distances <- c("EltonTraits core", "EltonTraits extended", "log body mass", "divergence time (TimeTree)")
# Exploratory: the core plus one trait excluded from it (reported in the table, not in the robustness figure).
h3_addbacks <- c("exploratory core + C4 (D36)", "exploratory core + C5 (D37)")
# Trait sensitivity of the core distance, one change each (reported in the table, not in the robustness figure).
h3_trait_sensitivity <- c("sensitivity: raccoon separate body configuration (D38)",
                          "sensitivity: hedgehog neck length intermediate (D38)",
                          "sensitivity: cattle neck length short (D43)",
                          "sensitivity: without body mass (D38)", "sensitivity: without locomotor specialization (D38)",
                          "sensitivity: without body configuration (D38)", "sensitivity: without relative neck length (D38)",
                          "sensitivity: without food acquisition and handling (D38)")

# =========================================================
# H1
# =========================================================
figure_1 <- function() {
  p <- plot_within_cross("macro_f1", "Macro-F1")
  save_figure(p, "h1", 180, 118, "Within- and cross-dataset Macro-F1.",
              paste0("04_Statistics/results/", main_scenario, "/h1_values.csv"))
  write_caption("h1", caption_within_cross("Within- and cross-dataset Macro-F1.", "macro_f1", table_ref("h1")))
}

table_1 <- function() {
  t <- read_stats(main_scenario, "h1_tests")
  t <- t[t$datasets == "all" & t$metric == "macro_f1", ]
  t <- t[match(model_keys, t$model), ]
  out <- data.frame(
    Classifier = unname(model_labels[t$model]),
    `Within-dataset Macro-F1` = med_iqr(t$within_median, t$within_q1, t$within_q3),
    `Cross-dataset Macro-F1` = med_iqr(t$cross_median, t$cross_q1, t$cross_q3),
    `Delta Macro-F1` = med_iqr(t$gap_median, t$gap_q1, t$gap_q3),
    V = stat_v(t$V), p = p_txt(t$p_value), r = num(t$rank_biserial, 2),
    check.names = FALSE)
  names(out)[4] <- "Δ Macro-F1"
  write_table("h1", "Paired comparison of within- and cross-dataset Macro-F1.", out,
              c(paste0("Median [IQR] over the ", max(t$n_pairs), " test datasets with both values; each value is the mean over five training seeds. ",
                       "Δ: within minus cross of the same dataset."),
                "V, p: paired Wilcoxon signed-rank test (exact, two-sided); r: matched-pairs rank-biserial correlation.",
                paste0("Values per dataset: ", table_ref("h1_values"), "; accuracy and further tests: ", table_ref("h1_tests"), ".")),
              paste0("04_Statistics/results/", main_scenario, c("/h1_tests.csv", "/h1_values.csv")))
}

# =========================================================
# H2
# =========================================================
figure_2 <- function() {
  p <- plot_classes("cross_f1", "Cross-dataset class F1")
  save_figure(p, "h2", 180, 118, "Cross-dataset F1 by behavioral class.",
              paste0("04_Statistics/results/", main_scenario, c("/h2_values.csv", "/h2_friedman.csv")))
  write_caption("h2", caption_classes("Cross-dataset F1 by behavioral class.", "cross_f1", table_ref("h2")))
}

table_2 <- function() {
  fr <- read_stats(main_scenario, "h2_friedman")
  n <- paste(sort(unique(fr$n_blocks[fr$response == "cross_f1"])), collapse = " or ")
  write_table("h2", "Behavioral differences in cross-dataset F1.", class_table("cross_f1"),
              c(paste0("Median [IQR] over the ", n, " test datasets with at least 5 test windows per class; each value is the mean over five training seeds."),
                paste0("Friedman test (df = 2) with Kendall's W. Values per dataset: ", table_ref("h2_values"),
                       "; Holm-adjusted post-hoc tests: ", table_ref("h2_posthoc"), ".")),
              paste0("04_Statistics/results/", main_scenario, c("/h2_descriptives.csv", "/h2_friedman.csv")))
}

# =========================================================
# H3
# =========================================================
# Figure 3 (H3): species pairs and the primary model; no colours for single points, no
# text. The band is the 95 % CI of the primary model averaged over the classifiers
# (h3_prediction.csv of 04_Statistics/stats_h3.R); without that file only the line is drawn.
figure_3 <- function() {
  d <- read_stats(main_scenario, "h3_data")
  pairs <- aggregate(mean_macro_f1 ~ train_species + test_species + trait_distance_core, data = d, FUN = mean)
  pred_file <- file.path(stats_dir, main_scenario, "h3_prediction.csv")
  if (file.exists(pred_file)) {
    pred <- read.csv(pred_file)
  } else {
    fe <- read_stats(main_scenario, "h3_fixed_effects")
    fe <- fe[fe$analysis == "primary", ]
    est <- setNames(fe$estimate, fe$term)
    model_terms <- vapply(unique(d$model), function(m) if (paste0("model", m) %in% names(est)) est[[paste0("model", m)]] else 0,
                          numeric(1))
    x <- seq(min(d$trait_distance_core), max(d$trait_distance_core), length.out = 50)
    pred <- data.frame(trait_distance_core = x, ci_low = NA_real_, ci_high = NA_real_,
                       estimate = est[["(Intercept)"]] + mean(model_terms) +
                         est[["z_distance"]] * (x - mean(d$trait_distance_core)) / sd(d$trait_distance_core))
  }
  p <- ggplot(pairs, aes(trait_distance_core, mean_macro_f1)) +
    {if (!anyNA(pred$ci_low)) geom_ribbon(data = pred, aes(x = trait_distance_core, ymin = ci_low, ymax = ci_high, fill = "95% CI"),
                                          inherit.aes = FALSE, alpha = 0.9)} +
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
  m <- read_stats(main_scenario, "h3_models")
  m <- m[m$analysis == "primary", ]
  n_species <- length(unique(c(d$train_species, d$test_species)))
  write_caption("h3", paste0(
    "Cross-species Macro-F1 in relation to functional-biomechanical distance. Points: ordered species pairs (n = ", nrow(pairs),
    "), mean over dataset pairs, classifiers and seeds; line and band: mixed-model prediction with 95% CI. Statistics: ", table_ref("h3"), "."))
}

h3_model_table <- function(keys) {
  m <- read_stats(main_scenario, "h3_models")
  m <- m[match(keys[keys %in% m$analysis], m$analysis), ]
  data.frame(
    Analysis = unname(h3_labels[m$analysis]),
    Response = ifelse(m$response == "mean_macro_f1", "Macro-F1",
                      ifelse(m$response == "log_retention", "Log retention", "Retention")),
    `Records (n)` = m$n_observations,
    `beta [95 % CI]` = est_ci(m$estimate, m$ci_low, m$ci_high),
    SE = num(m$std_error),
    `LR chi2 (df)` = paste0(num(m$lr_chisq, 2), " (", m$lr_df, ")"),
    p = p_txt(m$lr_p_value),
    `R2 marginal` = num(m$r2_marginal, 2),
    `R2 conditional` = num(m$r2_conditional, 2),
    `Singular fit` = yes_no(m$singular_reml),
    check.names = FALSE)
}
h3_header <- function(out) {
  names(out) <- sub("beta", paste(BETA, "per SD"), sub("LR chi2", paste("LR", CHI2), sub("^R2", "R\u00b2", names(out))))
  out
}

# Table 3: distance effect for the core traits (test of H3) and the alternative distances.
table_3 <- function() {
  keys <- c("primary", "EltonTraits core", "log body mass", "divergence time (TimeTree)")
  labels <- c("Core functional traits", "EltonTraits", "Body mass difference", "Phylogenetic distance")
  m <- read_stats(main_scenario, "h3_models")
  m <- m[match(keys, m$analysis), ]
  keep <- !is.na(m$analysis)
  m <- m[keep, ]
  out <- data.frame(a = labels[keep], b = est_ci(m$estimate, m$ci_low, m$ci_high), c = num(m$lr_chisq, 2),
                    d = p_txt(m$lr_p_value), e = num(m$r2_marginal, 2))
  names(out) <- c("Distance measure", paste0(BETA, " per SD (95% CI)"), paste0("LR ", CHI2, "(1)"), "p",
                  "Marginal R\u00b2")
  write_table("h3", "Associations between biological distance and cross-species Macro-F1.", out,
              c(paste0("Macro-F1 ~ distance (z-scored) + classifier + random intercepts of the unordered and ordered species pair and of source and target species; ",
                       m$n_observations[1], " records (", m$n_ordered_pairs[1], " ordered pairs of 9 species, 6 classifiers)."),
                paste0(BETA, " and 95% CI from the REML fit (Satterthwaite df); LR: likelihood-ratio test of ML fits against the model without distance; R\u00b2 after Nakagawa."),
                paste0("The core trait distance is the test of H3. Full model: ", table_ref("h3_model"), "; further variants: ", table_ref("h3_variants"),
                       "; distances: ", table_ref("distances"), ".")),
              paste0("04_Statistics/results/", main_scenario, "/h3_models.csv"))
}

# Table S16 (h3_model): the primary model of H3 (fixed and random effects, tests and fit).
table_s_h3_model <- function() {
  fe <- read_stats(main_scenario, "h3_fixed_effects")
  fe <- fe[fe$analysis == "primary", ]
  m <- read_stats(main_scenario, "h3_models")
  prim <- m[m$analysis == "primary", ]
  inter <- m[m$analysis == "interaction distance x model", ]
  re <- read_stats(main_scenario, "h3_random_effects")
  d <- read_stats(main_scenario, "h3_data")
  term_label <- function(t) {
    if (t == "(Intercept)") return("Intercept (CNN, mean distance)")
    if (t == "z_distance") return("Trait distance (per SD)")
    paste0("Classifier: ", model_labels[[tolower(sub("^model", "", t))]], " vs. CNN")
  }
  fixed <- data.frame(Component = "Fixed effects", Term = vapply(fe$term, term_label, character(1)),
                      Estimate = est_ci(fe$estimate, fe$ci_low, fe$ci_high), SE = num(fe$std_error),
                      df = num(fe$df, 1), t = num(fe$statistic, 2), p = p_txt(fe$p_value))
  groups <- c(unordered_species_pair = "Unordered species pair", ordered_species_pair = "Ordered species pair",
              train_species = "Source species", test_species = "Target species", Residual = "Residual")
  re <- re[match(names(groups), re$group), ]
  random <- data.frame(Component = "Random intercepts (SD)", Term = unname(groups), Estimate = num(re$std_dev),
                       SE = "", df = "", t = "", p = "")
  n_species <- length(unique(c(d$train_species, d$test_species)))
  tests <- data.frame(
    Component = "Tests and fit",
    Term = c("Trait distance (likelihood-ratio test)", "Distance \u00d7 classifier interaction (likelihood-ratio test)",
             "R\u00b2 marginal / conditional", "Records"),
    Estimate = c(paste0(CHI2, "(", prim$lr_df, ") = ", num(prim$lr_chisq, 2)),
                 paste0(CHI2, "(", inter$lr_df, ") = ", num(inter$lr_chisq, 2)),
                 paste0(num(prim$r2_marginal, 2), " / ", num(prim$r2_conditional, 2)),
                 paste0(prim$n_observations, " (", prim$n_ordered_pairs, " ordered pairs of ", n_species, " species, ",
                        prim$n_models, " classifiers)")),
    SE = "", df = "", t = "", p = c(p_txt(prim$lr_p_value), p_txt(inter$lr_p_value), "", ""))
  out <- rbind(fixed, random, tests)
  names(out)[names(out) == "Estimate"] <- "Estimate [95 % CI]"
  zero <- unname(groups[re$group[re$std_dev < 1e-4 & re$group != "Residual"]])
  write_table("h3_model", "Primary mixed model (H3).", out,
              c("Model: Macro-F1 ~ trait distance (z-scored) + classifier + random intercepts of the unordered species pair, the ordered species pair, the source and the target species.",
                paste0("One record per classifier and ordered pair of source and target species (pairs of the same species left out); Macro-F1 as mean over the dataset pairs and five training seeds. ",
                       "Trait distance: Gower distance of five core traits (", table_ref("traits"), ")."),
                "Estimates, 95 % CI and t tests from the REML fit (Satterthwaite df); likelihood-ratio tests of ML fits against the model without the distance (interaction: against this model); R\u00b2 after Nakagawa.",
                if (isTRUE(prim$singular_reml) && length(zero) > 0L)
                  paste0("The REML fit is singular: the variance of ", paste(tolower(zero), collapse = " and "), " is estimated as 0.") else NULL,
                paste0("Summary: ", table_ref("h3"), "; variants: ", table_ref("h3_variants"), "; leave one species out: ", table_ref("loso"),
                       "; slopes per classifier: ", table_ref("per_classifier"), ".")),
              paste0("04_Statistics/results/", main_scenario, c("/h3_fixed_effects.csv", "/h3_models.csv", "/h3_random_effects.csv")))
}

# =========================================================
# Supplement: figures
# =========================================================
figure_s1 <- function() {
  cs <- read.csv(class_summary_file)
  cs <- cs[cs$mapping == "primary", ]
  cs <- cs[cs$class %in% classes, ]
  win <- aggregate(test_windows ~ dataset_id + class, data = cs, FUN = sum)
  total <- tapply(win$test_windows, win$dataset_id, sum)
  order_ds <- names(sort(total))
  win$dataset <- factor(short(win$dataset_id), levels = short(order_ds))
  win$class <- factor(win$class, levels = classes)
  p <- ggplot(win, aes(test_windows, dataset)) +
    geom_col(aes(fill = class), width = 0.65, colour = "white", linewidth = 0.4,
             position = position_stack(reverse = TRUE)) +
    scale_fill_manual(values = class_colors, breaks = classes) +
    scale_x_continuous(labels = function(x) int(x), expand = expansion(mult = c(0, 0.04))) +
    labs(x = "Evaluation windows", y = NULL) +
    theme_paper() +
    theme(legend.position = "top", legend.justification = "center", panel.grid.major.y = element_blank(), axis.line.y = element_blank(),
          axis.ticks.y = element_blank(),
          axis.text.y = element_text(colour = INK, size = rel(1)))
  save_figure(p, "class_windows", 130, 85, "Evaluation windows per dataset and behavioral class.",
              "01_Preprocessing/reports/pipeline_reports/class_summary.csv")
  write_caption("class_windows", paste0(
    "Evaluation windows per dataset and behavioral class. Counts: ", table_ref("datasets"), "."))
}

figure_s2 <- function() {
  p <- plot_within_cross("accuracy", "Accuracy")
  save_figure(p, "h1_accuracy", 180, 118, "Within- and cross-dataset accuracy across classifiers.",
              paste0("04_Statistics/results/", main_scenario, "/h1_values.csv"))
  write_caption("h1_accuracy", caption_within_cross("Within- and cross-dataset accuracy across classifiers.", "accuracy", table_ref("h1_tests")))
}

figure_s3 <- function() {
  p <- plot_classes("transfer_loss_f1", "Transfer loss (F1)")
  save_figure(p, "h2_loss", 180, 118, "Transfer loss by behavioral class and classifier.",
              paste0("04_Statistics/results/", main_scenario, c("/h2_values.csv", "/h2_friedman.csv")))
  write_caption("h2_loss", sub("Points:", "Within- minus cross-dataset F1; points:",
    caption_classes("Transfer loss by behavioral class and classifier.", "transfer_loss_f1", table_ref("h2_loss"))))
}

scenario_rows <- function() {
  present <- names(scenarios)[file.exists(file.path(stats_dir, names(scenarios), "h1_tests.csv"))]
  h1 <- do.call(rbind, lapply(present, function(s) {
    t <- read_stats(s, "h1_tests")
    t <- t[t$model %in% c("rf", "lgbm") & t$datasets == "all" & t$metric == "macro_f1", ]
    cbind(scenario = s, t)
  }))
  h2 <- do.call(rbind, lapply(present, function(s) {
    f <- read_stats(s, "h2_friedman")
    f <- f[f$model %in% c("rf", "lgbm") & f$response == "cross_f1", ]
    cbind(scenario = s, f)
  }))
  h3 <- do.call(rbind, lapply(present[file.exists(file.path(stats_dir, present, "h3_models.csv"))], function(s) {
    m <- read_stats(s, "h3_models")
    key <- if (s == "primary" && "RF and LGBM only (D27)" %in% m$analysis) "RF and LGBM only (D27)" else "primary"
    cbind(scenario = s, m[m$analysis == key, ])
  }))
  list(present = present, h1 = h1, h2 = h2, h3 = h3)
}

# =========================================================
# Supplement: tables
# =========================================================
read_registry <- function(file) read.csv(file, colClasses = "character", fileEncoding = "UTF-8", check.names = FALSE)

# Sensor and sampling per dataset (settings that give windows; sensor_settings.csv).
recording_text <- function(id) {
  s <- read_registry(sensor_file)
  s <- s[s$dataset_id == id & s$used == "yes", ]
  parts <- vapply(seq_len(nrow(s)), function(i) {
    r <- s[i, ]
    rate <- paste0(sub("\\.?0+$", "", formatC(as.numeric(r$native_hz), format = "f", digits = 2)), " Hz",
                   if (r$status == "assumed") " (assumed)" else "")
    rec <- if (nzchar(r$burst_s)) {
      paste0(r$burst_s, "-s bursts", if (nzchar(r$burst_interval_s)) paste0(" every ", r$burst_interval_s, " s") else "")
    } else "continuous"
    paste(c(if (nzchar(r$sensor)) r$sensor, rate, rec), collapse = ", ")
  }, character(1))
  paste(parts, collapse = "; ")
}

# Table S1 (datasets): provenance, setting, sensor and sample sizes.
table_s_datasets <- function() {
  cs <- read.csv(class_summary_file)
  cs <- cs[cs$mapping == "primary" & cs$class %in% classes, ]
  ds <- read_registry(datasets_file)
  v <- read_stats(main_scenario, "h1_values")
  v <- v[v$model == v$model[1], ]
  ids <- sort(unique(cs$dataset_id))
  rows <- lapply(ids, function(id) {
    c1 <- cs[cs$dataset_id == id, ]
    d <- ds[ds$dataset_id == id, ]
    w <- vapply(classes, function(cl) sum(c1$test_windows[c1$class == cl]), numeric(1))
    vi <- v[v$dataset == id, ]
    data.frame(Dataset = short(id), Species = common(d$scientific_name),
               Source = paste0(d$source, if (d$public == "yes") "; public" else ""),
               Setting = d$setting, `Sensor position` = d$sensor_position, `Sensor and sampling` = recording_text(id),
               Individuals = length(unique(c1$individual_id)),
               `Within-dataset test units` = if (nrow(vi) == 1L) as.character(vi$eligible_individuals) else DASH,
               `Training windows` = sum(c1$windows), r = w[[1]], l = w[[2]], f = w[[3]], total = sum(w),
               check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  total <- out[1, ]
  total[] <- ""
  total$Dataset <- "Total"
  total$Individuals <- sum(out$Individuals)
  for (k in c("Training windows", "r", "l", "f", "total")) total[[k]] <- sum(out[[k]])
  out <- rbind(out, total)
  for (k in c("Training windows", "r", "l", "f", "total")) out[[k]] <- int(out[[k]])
  names(out)[names(out) %in% c("r", "l", "f", "total")] <- c(paste("Evaluation windows", classes), "Evaluation windows total")
  n_dog2 <- length(unique(cs$individual_id[cs$dataset_id == "Dog_dataset_2"]))
  write_table("datasets", "Datasets and sample sizes.", out,
              c("Source: thesis or publication; public: openly available dataset (all others are not public).",
                paste0("Individuals: Dog 2 had no animal identities; each of its ", n_dog2,
                       " recordings is treated as an individual (analytical unit)."),
                "Training windows: 2 s windows with 1 s step before the cap of 250 per dataset and class; evaluation windows: non-overlapping 2 s windows. Only windows within one of the three classes.",
                "Within-dataset test units: individuals with at least 10 evaluation windows in every class. Hedgehog 1 has no within-dataset value (one eligible individual).",
                "A second fox dataset was left out because the provenance of its labels is unclear."),
              c("00_Documentation/datasets.csv", "00_Documentation/sensor_settings.csv",
                "01_Preprocessing/reports/pipeline_reports/class_summary.csv", paste0("04_Statistics/results/", main_scenario, "/h1_values.csv")))
}

# Table S2 (mapping): original labels and their class.
table_s_mapping <- function() {
  m <- read_registry(mapping_file)
  m <- m[m$dataset_id %in% read.csv(class_summary_file)$dataset_id, ]
  # Alphabetical within class, umlauts as base letters, the same in every locale.
  key <- chartr("\u00e4\u00f6\u00fc\u00df", "aous", tolower(m$label))
  m <- m[order(m$dataset_id, match(m$class, c(classes, "Other", "Exclude")), key, method = "radix"), ]
  cls <- ifelse(m$class == "Other", "Other (excluded)", ifelse(m$class == "Exclude", "Excluded", m$class))
  out <- data.frame(Dataset = short(m$dataset_id), `Original label` = m$label, Class = cls,
                    `Evaluation windows` = int(as.numeric(m$test_windows)), check.names = FALSE)
  e <- m[nzchar(m$sensitivity_class), ]
  e_text <- vapply(split(e, paste(e$dataset_id, e$sensitivity_class)), function(x) {
    paste0(short(x$dataset_id[1]), ": ", paste(x$label, collapse = ", "), " as ", x$sensitivity_class[1])
  }, character(1))
  write_table("mapping", "Behavior label mapping.", out,
              c(paste0("Original labels as recorded in the source datasets (codes and German terms of the theses); their definitions are given in the sources (",
                       table_ref("datasets"), ") and are available from the authors on request."),
                "Other: outside the three classes; used only in the four-class sensitivity scenario. Excluded: not animal behavior, mixed or unlabeled.",
                "Evaluation windows: non-overlapping 2 s windows with this label only.",
                paste0("Sensitivity scenario E (", table_ref("scenarios"), "): ", paste(e_text, collapse = "; "), ".")),
              "00_Documentation/behavior_mapping.csv")
}

# Table S4 (features): the 26 window features of RF and LightGBM (01_Preprocessing/features.py).
table_s_features <- function() {
  out <- data.frame(
    Feature = c("VeDBA mean, SD, maximum", "ODBA mean, SD", "SD (x, y, z)", "RMS (x, y, z)", "IQR (x, y, z)",
                "Skewness (x, y, z)", "Excess kurtosis (x, y, z)", "Zero crossings (x, y, z)",
                "Dominant frequency, spectral centroid, spectral entropy"),
    Definition = c("Vectorial dynamic body acceleration per sample, √(dx² + dy² + dz²), summarized over the window",
                   "Overall dynamic body acceleration per sample, |dx| + |dy| + |dz|, summarized over the window",
                   "Standard deviation of the dynamic acceleration of each axis (n − 1)",
                   "Root mean square of the dynamic acceleration of each axis",
                   "Interquartile range of the dynamic acceleration of each axis",
                   "Third standardized moment of each axis", "Fourth standardized moment minus 3 of each axis",
                   "Sign changes of the dynamic acceleration of each axis",
                   "Of the VeDBA series (mean removed; FFT without the 0 Hz bin); entropy normalized to 0–1"),
    Number = c(3, 2, 3, 3, 3, 3, 3, 3, 3), check.names = FALSE)
  write_table("features", "Window features.", out,
              c(paste0("Dynamic acceleration (dx, dy, dz): each axis minus its window mean; windows of 2 s at 25 Hz (50 samples). Total: ", sum(out$Number), " features."),
                "Static acceleration (posture) is not a feature."),
              "01_Preprocessing/features.py")
}

# Table S3 (preprocessing): dataset-specific preprocessing.
table_s_preprocessing <- function() {
  ds <- read_registry(datasets_file)
  s <- read_registry(sensor_file)
  ids <- sort(unique(read.csv(class_summary_file)$dataset_id))
  ds <- ds[match(ids, ds$dataset_id), ]
  unit <- c(eobs_counts = "e-obs counts: (raw − 2048) / 512", g = "g (as recorded)", m_s2 = "m s⁻² / 9.80665")
  segments <- vapply(ids, function(id) {
    r <- s[s$dataset_id == id & s$used == "yes", ]
    if (all(nzchar(r$burst_s))) "one per burst" else if (id == "Horse_dataset_2") "dataset segments (≤ 10 s)" else "continuous, split at gaps"
  }, character(1))
  rates <- vapply(ids, function(id) {
    r <- s[s$dataset_id == id & s$used == "yes", ]
    paste(unique(sub("\\.?0+$", "", formatC(as.numeric(r$native_hz), format = "f", digits = 2))), collapse = ", ")
  }, character(1))
  out <- data.frame(Dataset = short(ids), `Conversion to g` = unname(unit[ds$raw_unit]), Segments = unname(segments),
                    `Native rate (Hz)` = unname(rates), `Dataset-specific steps` = ifelse(nzchar(ds$dataset_rules), ds$dataset_rules, DASH),
                    check.names = FALSE)
  write_table("preprocessing", "Dataset-specific preprocessing.", out,
              c("All datasets: each segment resampled to 25 Hz (polyphase filter with anti-aliasing); 2 s windows with 1 s step within segments; segments shorter than 2 s give no window.",
                "Labels assigned after windowing: only windows whose samples all belong to one class (primary analysis). e-obs: 12-bit counts, ±4 g."),
              c("00_Documentation/datasets.csv", "00_Documentation/sensor_settings.csv", "00_Documentation/decisions.md (D03-D07, D15, D19, D20)"))
}

# Table S5 (models): classifiers (02_Models/models.py; package versions from requirements-lock.txt).
table_s_models <- function() {
  out <- data.frame(
    Classifier = c("RF", "LightGBM", "CNN", "ResNet", "HYDRA", "MultiRocket"),
    Input = c(rep("26 window features", 2), rep("Tri-axial window (3 × 50 samples)", 4)),
    Implementation = c("scikit-learn 1.9.1, RandomForestClassifier", "lightgbm 4.7.0, LGBMClassifier", "PyTorch 2.14.1",
                       "PyTorch 2.14.1", "aeon 1.6.0, HydraClassifier", "aeon 1.6.0, MultiRocketClassifier"),
    Configuration = c("Defaults (100 trees)", "Defaults, multiclass objective",
                      "3 convolution blocks (32, 64, 128 filters; kernels 5, 5, 3; batch normalization, ReLU, max pooling), global average pooling, dense layer (64), dropout 0.25",
                      "Stem convolution (64 filters, kernel 7), 3 residual blocks (64, 128, 128 filters; kernels 7, 5, 3), global average pooling, dropout 0.25",
                      "Defaults", "Defaults"),
    check.names = FALSE)
  write_table("models", "Classifier configurations.", out,
              c("CNN and ResNet: channels standardized with mean and SD of the training windows; Adam (learning rate 0.001), cross-entropy loss, batch size 256, 30 epochs, no early stopping.",
                "All classifiers: training seeds 42–46; at most 250 training windows per dataset and class, drawn across segments."),
              c("02_Models/models.py", "requirements-lock.txt"))
}

# Table S6 (trait_definitions): definitions of the five core traits.
table_s_trait_definitions <- function() {
  d <- read_registry(trait_definitions_file)
  out <- data.frame(Trait = d$trait, Definition = d$definition, Coding = d$coding, Sources = d$sources,
                    `Main uncertainty` = d$uncertainty, check.names = FALSE)
  write_table("trait_definitions", "Core trait definitions.", out,
              c(paste0("Species assignments: ", table_ref("traits"), "; pairwise distances: ", table_ref("distances"), ". Categories are study-specific; Gower distance with equal weights."),
                "Full text and references: 00_Documentation/traits/core_traits.md."),
              "00_Documentation/traits/core_trait_definitions.csv")
}

table_s_h1_values <- function() {
  v <- read_stats(main_scenario, "h1_values")
  v <- v[order(match(v$model, model_keys), v$dataset), ]
  out <- data.frame(
    Classifier = unname(model_labels[v$model]), `Test dataset` = short(v$dataset),
    `Within-dataset Macro-F1` = mean_sd(v$macro_f1_within, v$macro_f1_sd_within),
    `Cross-dataset Macro-F1` = mean_sd(v$macro_f1_cross, v$macro_f1_sd_cross),
    `Difference Macro-F1` = num(v$gap_macro_f1),
    `Within-dataset accuracy` = mean_sd(v$accuracy_within, v$accuracy_sd_within),
    `Cross-dataset accuracy` = mean_sd(v$accuracy_cross, v$accuracy_sd_cross),
    `Difference accuracy` = num(v$gap_accuracy),
    `Test windows within-dataset` = int(v$n_test_within), `Test windows cross-dataset` = int(v$n_test_cross),
    `Within-dataset test units` = paste0(v$eligible_individuals, " of ", v$individuals),
    check.names = FALSE)
  write_table("h1_values", "Within- and cross-dataset performance per dataset (H1).", out,
              c(paste0("Macro-F1 and accuracy: mean ", PM, " SD over five training seeds. Difference: within-dataset minus cross-dataset value of the seed means."),
                "Within-dataset: leave one individual out, predictions of all folds pooled; cross-dataset: model trained on all other datasets and tested on the whole dataset.",
                "Where not every individual is a within-dataset test unit, the cross-dataset test also includes the other individuals (more test windows)."),
              paste0("04_Statistics/results/", main_scenario, "/h1_values.csv"))
}

table_s_h1_tests <- function() {
  t <- read_stats(main_scenario, "h1_tests")
  v <- read_stats(main_scenario, "h1_values")
  not_all <- sort(unique(short(v$dataset[!v$same_test_windows])))
  t <- t[order(match(t$metric, c("macro_f1", "accuracy")), match(t$datasets, c("all", "same_test_windows")),
               match(t$model, model_keys)), ]
  out <- data.frame(
    Metric = ifelse(t$metric == "macro_f1", "Macro-F1", "Accuracy"),
    `Test datasets` = ifelse(t$datasets == "all", "All with a within-dataset value",
                             paste("Without", paste(not_all, collapse = ", "))),
    Classifier = unname(model_labels[t$model]), `Test datasets (n)` = t$n_pairs,
    `Within-dataset` = med_iqr(t$within_median, t$within_q1, t$within_q3, 2),
    `Cross-dataset` = med_iqr(t$cross_median, t$cross_q1, t$cross_q3, 2),
    Difference = med_iqr(t$gap_median, t$gap_q1, t$gap_q3, 2),
    `Wilcoxon V` = stat_v(t$V), p = p_txt(t$p_value), `Rank-biserial r` = num(t$rank_biserial, 2),
    `p-value` = ifelse(t$test_method == "exact", "exact", "normal approximation"),
    check.names = FALSE)
  names(out)[names(out) == "Difference"] <- paste0("Difference (within ", MINUS, " cross)")
  write_table("h1_tests", "Wilcoxon tests for both metrics (H1).", out,
              c("Values: median [interquartile range] over the test datasets; the value of a dataset is the mean over five training seeds.",
                paste0("Without ", paste(not_all, collapse = ", "), ": only datasets in which every individual is a within-dataset test unit, so both tests score the same windows."),
                "Two-sided p, exact, or the normal approximation with continuity correction if there are ties or zero differences; rank-biserial r: matched-pairs rank-biserial correlation."),
              paste0("04_Statistics/results/", main_scenario, c("/h1_tests.csv", "/h1_values.csv")))
}

table_s_h2_values <- function() {
  v <- read_stats(main_scenario, "h2_values")
  keys <- unique(v[order(match(v$model, model_keys), v$dataset), c("model", "dataset")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    r <- v[v$model == keys$model[i] & v$dataset == keys$dataset[i], ]
    r <- r[match(classes, r$behavior), ]
    as.data.frame(as.list(c(Classifier = model_labels[[keys$model[i]]], `Test dataset` = short(keys$dataset[i]),
                            setNames(mean_sd(r$cross_f1, r$cross_f1_sd), paste("Cross-dataset F1", classes)),
                            setNames(num(r$transfer_loss_f1), paste("Transfer loss", classes)))),
                  check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  write_table("h2_values", "Class-specific F1 per dataset (H2).", out,
              c(paste0("Cross-dataset F1: mean ", PM, " SD over five training seeds. Transfer loss: within-dataset minus cross-dataset F1 of the seed means (",
                       DASH, ": no within-dataset value)."),
                paste0("Test windows per class: ", table_ref("datasets"), ".")),
              paste0("04_Statistics/results/", main_scenario, "/h2_values.csv"))
}

table_s_h2_loss <- function() {
  out <- class_table("transfer_loss_f1")
  write_table("h2_loss", "Transfer loss by behavioral class (H2).", out,
              c("Transfer loss: median [interquartile range] over the test datasets with a within-dataset value; the value of a dataset is the difference of the means over five training seeds.",
                paste0("Tests as in ", table_ref("h2"), " (", DASH, ": Friedman p >= 0.05). All post-hoc statistics: ", table_ref("h2_posthoc"), ".")),
              paste0("04_Statistics/results/", main_scenario, c("/h2_descriptives.csv", "/h2_friedman.csv", "/h2_posthoc.csv")))
}

table_s_h2_posthoc <- function() {
  raw <- read_stats(main_scenario, "h2_posthoc")
  ph <- do.call(rbind, lapply(c("cross_f1", "transfer_loss_f1"), function(resp) {
    do.call(rbind, lapply(model_keys, function(m) {
      do.call(rbind, lapply(class_pairs, function(pair) posthoc_pair(raw[raw$response == resp, ], m, pair)))
    }))
  }))
  out <- data.frame(
    Response = ifelse(ph$response == "cross_f1", "Cross-dataset F1", "Transfer loss"),
    Classifier = unname(model_labels[ph$model]),
    Comparison = paste(ph$behavior_1, "vs.", ph$behavior_2), `Test datasets (n)` = ph$n_pairs,
    `Difference (median [IQR])` = med_iqr(ph$diff_median, ph$diff_q1, ph$diff_q3, 2),
    `Wilcoxon V` = stat_v(ph$V), p = p_txt(ph$p_value), `p (Holm)` = p_txt(ph$p_holm),
    `Rank-biserial r` = num(ph$rank_biserial, 2), `Friedman test significant` = yes_no(ph$friedman_significant),
    check.names = FALSE)
  write_table("h2_posthoc", "Post-hoc class comparisons (H2).", out,
              c("Difference: first minus second class, per test dataset; rank-biserial r > 0: the first class is higher. Holm adjustment over the three pairs of a classifier and response.",
                paste0("Interpreted only if the Friedman test of the classifier is significant (", table_ref("h2"), "; ", table_ref("h2_loss"), ").")),
              paste0("04_Statistics/results/", main_scenario, "/h2_posthoc.csv"))
}

table_s_pairwise <- function() {
  h <- read_stats(main_scenario, "h3_input")
  m <- aggregate(macro_f1 ~ train + test, data = h, FUN = mean)
  same <- unique(paste(h$train, h$test)[as.logical(h$same_species)])
  names_ds <- sort(unique(c(m$train, m$test)))
  out <- data.frame(`Training dataset` = short(names_ds), check.names = FALSE)
  for (te in names_ds) {
    out[[short(te)]] <- vapply(names_ds, function(tr) {
      v <- m$macro_f1[m$train == tr & m$test == te]
      if (length(v) == 0L) return(DASH)
      paste0(num(v, 2), if (paste(tr, te) %in% same) "*" else "")
    }, character(1))
  }
  write_table("pairwise", "Pairwise transfer between datasets.", out,
              c("Mean over the six classifiers and five training seeds. *: pair of the same species, left out in H3.",
                paste0("The diagonal is empty (within-dataset values: ", table_ref("h1_values"), ").")),
              paste0("04_Statistics/results/", main_scenario, "/h3_input.csv"))
}

table_s_traits <- function() {
  tr <- read.csv(traits_file)
  # Data codes back to the labels of the D37 document (codes replace spaces and hyphens by "_").
  hyphenated <- c(compact_low_profile_body = "compact low-profile body",
                  tall_long_necked_quadruped = "tall long-necked quadruped")
  pretty <- function(x) ifelse(x %in% names(hyphenated), hyphenated[x], gsub("_", " ", x))
  # D37: the five core traits; the historical thesis columns of the CSV are not shown.
  out <- data.frame(Species = common(tr$species), `Scientific name` = tr$species,
                    `Body mass (ln g)` = num(tr$log_body_mass_g, 3),
                    `Locomotor specialization` = pretty(tr$dominant_locomotor_mode),
                    `Body configuration` = pretty(tr$body_configuration_type),
                    `Relative neck length` = pretty(tr$relative_neck_length),
                    `Food acquisition and handling` = pretty(tr$food_acquisition_handling),
                    check.names = FALSE)
  write_table("traits", "Core trait values.", out,
              c("Gower distance with equal weights; relative neck length ordinal (short < intermediate < long < very long), body mass numeric, the other traits nominal.",
                "Relative neck length: hedgehog by expert judgement (intermediate as alternative); raccoon supported indirectly (Davis 1964).",
                paste0("Definitions and sources: ", table_ref("trait_definitions"), ".")),
              "00_Documentation/traits/species_traits_core.csv")
}

table_s_distances <- function() {
  dd <- read_stats(main_scenario, "h3_distances")
  out <- data.frame(`Species 1` = common(dd$species_1), `Species 2` = common(dd$species_2),
                    `Core traits (Gower)` = num(dd$gower_core), `Weighted trait distance (gawdis)` = num(dd$gawdis),
                    EltonTraits = num(dd$elton_core),
                    `EltonTraits with diet` = num(dd$elton_extended), `Body mass difference` = num(dd$log_body_mass),
                    `Phylogenetic distance (Myr)` = num(dd$divergence_time, 1), check.names = FALSE)
  write_table("distances", "Distances between species.", out,
              c("Gower distances range from 0 to 1. Body mass difference: absolute difference of the natural log of body mass (g). Phylogenetic distance: divergence time from TimeTree (million years).",
                "EltonTraits (Wilman et al. 2014): log body mass, foraging stratum and activity; with diet: also the diet composition. Dog as Canis lupus, Przewalski's horse as Equus ferus."),
              paste0("04_Statistics/results/", main_scenario, "/h3_distances.csv"))
}

table_s_per_classifier <- function() {
  sl <- read_stats(main_scenario, "h3_slopes")
  sp <- read_stats(main_scenario, "h3_spearman")
  keys <- c("all models pooled", "CNN", "ResNet", "HYDRA", "MultiRocket", "RF", "LGBM")
  rows <- lapply(keys, function(k) {
    s <- sp[sp$model == k, ]
    l <- sl[sl$model == k, ]
    data.frame(Classifier = if (k == "all models pooled") "All classifiers pooled" else unname(model_labels[tolower(k)]),
               `Records (n)` = s$n,
               Slope = if (nrow(l) == 1L) est_ci(l$estimate, l$ci_low, l$ci_high) else DASH,
               `p (slope)` = if (nrow(l) == 1L) p_txt(l$p_value) else DASH,
               Spearman = est_ci(s$rho, s$ci_low, s$ci_high), `p (Spearman)` = p_txt(s$p_value),
               `p (Spearman, Holm)` = p_txt(s$p_holm), check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  names(out)[names(out) == "Slope"] <- paste(BETA, "per SD [95 % CI]")
  names(out)[names(out) == "Spearman"] <- paste("Spearman", RHO, "[95 % CI]")
  write_table("per_classifier", "Distance effect per classifier (H3).", out,
              c(paste0(BETA, " per SD: slope of the core trait distance for each classifier in the mixed model with the interaction distance \u00d7 classifier (REML, Satterthwaite df);"),
                paste0("the interaction is not significant (", table_ref("h3_model"), "). Spearman correlations: descriptive, 95 % CI by Fisher z, Holm adjustment over the six classifiers.")),
              paste0("04_Statistics/results/", main_scenario, c("/h3_slopes.csv", "/h3_spearman.csv")))
}

table_s_h3_variants <- function() {
  keys <- c("primary", setdiff(h3_variants, "primary"))
  out <- rbind(cbind(Group = "Model variant", h3_model_table(keys)),
               cbind(Group = "Other distance", h3_model_table(h3_distances)),
               cbind(Group = "Trait sensitivity", h3_model_table(h3_trait_sensitivity)),
               cbind(Group = "Exploratory", h3_model_table(h3_addbacks)))
  write_table("h3_variants", "Robustness of the distance effect (H3).", h3_header(out),
              c(paste0(BETA, " per SD: change per SD of the distance with 95 % CI (REML fit, Satterthwaite df); LR: likelihood-ratio test of ML fits against the model without the distance ",
                       "(interaction: against the primary model); R\u00b2 after Nakagawa."),
                "Random effects without unordered pair: random intercepts of the ordered pair, the source and the target species; random effect of ordered pair only: no species effects.",
                "Adjusted for within-dataset Macro-F1: within-dataset Macro-F1 of source and target as covariates (pairs with the hedgehog left out).",
                "Retention as response: transfer Macro-F1 / within-dataset Macro-F1 of the target (hedgehog as target left out). Weighted trait distance: Gower distance with gawdis trait weights.",
                "RF and LightGBM only: the two classifiers of the sensitivity scenarios.",
                paste0("Other distances, each z-scored in the primary model: EltonTraits (with diet); body mass difference; phylogenetic distance (", table_ref("distances"), ")."),
                "Exploratory: Gower distance of the five core traits plus one trait excluded from the core distance (trunk motion amplitude or directional change tendency; ordinal low < moderate < high < very high), equal weights; not part of the test of H3.",
                "Trait sensitivity: the core trait distance after one change, all other inputs fixed: the raccoon in a separate body configuration group, the hedgehog's relative neck length intermediate, the cattle's short, or one of the five traits left out (equal weights over the other four); robustness checks, not tests of H3. \u2020 Added after the results were known."),
              paste0("04_Statistics/results/", main_scenario, "/h3_models.csv"))
}

table_s_loso <- function() {
  l <- read_stats(main_scenario, "h3_loso")
  out <- data.frame(`Species left out` = common(l$left_out), `Scientific name` = l$left_out,
                    `Records (n)` = l$n_observations, `Ordered species pairs` = l$n_ordered_pairs,
                    `beta [95 % CI]` = est_ci(l$estimate, l$ci_low, l$ci_high), SE = num(l$std_error),
                    `LR chi2 (df)` = paste0(num(l$lr_chisq, 2), " (", l$lr_df, ")"), p = p_txt(l$lr_p_value),
                    `R2 marginal` = num(l$r2_marginal, 2), `R2 conditional` = num(l$r2_conditional, 2),
                    `Singular fit` = yes_no(l$singular_reml), check.names = FALSE)
  write_table("loso", "Leave-one-species-out refits (H3).", h3_header(out),
              c(paste0("Distance z-scored again in each refit. Range of ", BETA, ": ", num(min(l$estimate)), " to ", num(max(l$estimate)),
                       "; p < 0.05 in ", sum(l$lr_p_value < 0.05), " of ", nrow(l), " refits.")),
              paste0("04_Statistics/results/", main_scenario, "/h3_loso.csv"))
}

table_s_seeds <- function() {
  s <- read_stats(main_scenario, "h3_seeds")
  out <- data.frame(`Training seed` = s$seed, `Records (n)` = s$n_observations,
                    `beta [95 % CI]` = est_ci(s$estimate, s$ci_low, s$ci_high),
                    SE = num(s$std_error), `LR chi2 (df)` = paste0(num(s$lr_chisq, 2), " (", s$lr_df, ")"),
                    p = p_txt(s$lr_p_value), `R2 marginal` = num(s$r2_marginal, 2),
                    `R2 conditional` = num(s$r2_conditional, 2), `Singular fit` = yes_no(s$singular_reml),
                    check.names = FALSE)
  write_table("seeds", "Primary model per training seed (H3).", h3_header(out),
              paste0("The test of H3 uses the mean over the seeds (", table_ref("h3"), "); the single seeds show the variability between training runs."),
              paste0("04_Statistics/results/", main_scenario, "/h3_seeds.csv"))
}

table_s_scenarios <- function() {
  s <- scenario_rows()
  rows <- lapply(s$present, function(sc) {
    h1 <- s$h1[s$h1$scenario == sc, ]
    h2 <- s$h2[s$h2$scenario == sc, ]
    h3 <- s$h3[s$h3$scenario == sc, ]
    cell_h1 <- function(m) {
      r <- h1[h1$model == m, ]
      if (nrow(r) == 0L) return(c(DASH, DASH))
      c(med_iqr(r$gap_median, r$gap_q1, r$gap_q3, 2), p_txt(r$p_value))
    }
    cell_h2 <- function(m) {
      r <- h2[h2$model == m, ]
      if (nrow(r) == 0L) return(DASH)
      paste0(CHI2, "(", r$df, ") = ", num(r$chi_sq, 2), ", p ", if (r$p_value < 0.001) "< 0.001" else paste("=", p_txt(r$p_value)))
    }
    rf <- cell_h1("rf")
    lg <- cell_h1("lgbm")
    data.frame(Scenario = unname(scenarios[sc]), `Test datasets (n)` = max(h1$n_pairs),
               `H1 difference, RF` = rf[1], `H1 p, RF` = rf[2], `H1 difference, LightGBM` = lg[1], `H1 p, LightGBM` = lg[2],
               `H2 Friedman test, RF` = cell_h2("rf"), `H2 Friedman test, LightGBM` = cell_h2("lgbm"),
               `H3 beta [95 % CI]` = if (nrow(h3) == 1L) est_ci(h3$estimate, h3$ci_low, h3$ci_high) else DASH,
               `H3 p` = if (nrow(h3) == 1L) p_txt(h3$lr_p_value) else DASH, check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  names(out) <- sub("beta", paste(BETA, "per SD"), names(out))
  write_table("scenarios", "Sensitivity scenarios.", out,
              c(paste0("H1: within-dataset minus cross-dataset Macro-F1, median [interquartile range] over the test datasets, paired Wilcoxon signed-rank test. ",
                       "H2: Friedman test of the cross-dataset F1 of the classes (four classes: df 3)."),
                "H3: primary model fitted to the RF and LightGBM results only (also in the primary scenario, so all rows are comparable).",
                "A: 2 s windows without overlap in training; C: 2.4 s windows without overlap; majority class: at least 80 % of the samples of a window in one class;",
                "four classes: with Other; E: ridden gaits of Horse 2 as Locomotion; F: only individuals with all three classes and at least 10 evaluation windows each."),
              c("04_Statistics/results/<scenario>/h1_tests.csv", "04_Statistics/results/<scenario>/h2_friedman.csv",
                "04_Statistics/results/<scenario>/h3_models.csv"))
}

# =========================================================
# Run
# =========================================================
main <- function() {
  jobs <- list(figure_1 = figure_1, table_1 = table_1, figure_2 = figure_2, table_2 = table_2,
               figure_3 = figure_3, table_3 = table_3,
               table_s_mapping = table_s_mapping, table_s_features = table_s_features,
               table_s_preprocessing = table_s_preprocessing, table_s_models = table_s_models,
               table_s_trait_definitions = table_s_trait_definitions, table_s_h3_model = table_s_h3_model,
               figure_s1 = figure_s1, figure_s2 = figure_s2, figure_s3 = figure_s3,
               table_s_datasets = table_s_datasets, table_s_h1_values = table_s_h1_values,
               table_s_h1_tests = table_s_h1_tests, table_s_h2_values = table_s_h2_values,
               table_s_h2_loss = table_s_h2_loss, table_s_h2_posthoc = table_s_h2_posthoc,
               table_s_pairwise = table_s_pairwise, table_s_traits = table_s_traits,
               table_s_distances = table_s_distances, table_s_per_classifier = table_s_per_classifier,
               table_s_h3_variants = table_s_h3_variants, table_s_loso = table_s_loso, table_s_seeds = table_s_seeds,
               table_s_scenarios = table_s_scenarios)
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
    if (file.exists(file.path(out_dir, texts$file[i]))) {
      contents <<- rbind(contents, data.frame(item = texts$item[i], section = SUPP, title = texts$title[i],
                                              file = rel_path(file.path(out_dir, texts$file[i])), caption_file = "",
                                              sources = texts$sources[i]))
    } else {
      errors <- c(errors, paste0(texts$item[i], ": ", texts$file[i], " not found"))
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
