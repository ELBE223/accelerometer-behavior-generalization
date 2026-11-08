# stats_h3.R
#
# Purpose:
# - Statistics of H3 (D26): is the transfer performance between two species associated with
#   the trait distance of the species?
#   input      04_Statistics/results/<scenario>/h3_input.csv (04_Statistics/stats_h1_h2.py): pairwise
#              Macro-F1 per model and dataset pair, mean over the seeds
#   distance   Gower distance of the five core traits of D37 with equal weights: log body
#              mass, locomotor specialization, body configuration, relative neck length
#              (ordinal short < intermediate < long < very_long) and food acquisition and
#              handling (00_Documentation/traits/species_traits_core.csv; definitions in
#              00_Documentation/traits/core_traits.md); C4/C5 for the exploratory add-backs
#              in species_traits_exploratory.csv
#   data       pairs of the same species (scientific name) left out; mean over the dataset
#              pairs of a species pair, one value per model and ordered species pair
#   primary    Macro-F1 ~ z(distance) + model + (1 | unordered pair) + (1 | ordered pair)
#              + (1 | source species) + (1 | target species); likelihood-ratio test of ML
#              fits against the model without distance; estimate, SE and 95 % CI
#              (Satterthwaite df) from the REML fit
#   further    interaction distance x model and slopes per model; directional and pair-only
#              random effects; S1 within Macro-F1 of source and target as covariates; S2
#              retention (pairwise / within of the target) and log retention; S3 gawdis
#              distance (w.type "optimized", seed 42); Spearman correlations (Holm over
#              the models); the primary model per seed (seed variability, descriptive)
#   D27        the primary model with RF and LightGBM only (the models of the sensitivity
#              scenarios), to compare the scenarios with
#   D38        trait sensitivity: the primary model with the core distance after one change
#              (D43 adds cattle neck length short, after the results were known)
#              (raccoon separate body configuration, hedgehog neck length intermediate,
#              or one of the five traits left out)
#   D28        leave-one-species-out refits of the primary model; the primary model with
#              other distances: exploratory core + C4 (D36) and core + C5 (D37), EltonTraits
#              core and extended (data/raw/EltonTraits/MamFuncDat.txt, if present),
#              divergence time (TimeTree; D48) and log body mass alone
#   z-scores   computed on the records of each analysis (S1 and S2 lose the pairs with a
#              dataset without within value)
#   prediction the primary model over the observed range of the distance, averaged over the
#              models (random effects 0), with 95 % CI (Satterthwaite df), for the figure
# - Output: 04_Statistics/results/<scenario>/h3_data.csv, h3_models.csv, h3_fixed_effects.csv,
#   h3_random_effects.csv, h3_slopes.csv, h3_spearman.csv, h3_seeds.csv, h3_distances.csv,
#   h3_gawdis_weights.csv, h3_loso.csv, h3_elton_traits.csv, h3_prediction.csv, statistics_h3.txt
#
# Usage (from the project folder):
#   Rscript 04_Statistics/stats_h3.R              # every scenario with an h3_input.csv
#   Rscript 04_Statistics/stats_h3.R primary
#   or in R/RStudio with the project folder as working directory: source("04_Statistics/stats_h3.R")
# Packages: lme4, lmerTest, cluster; optional gawdis (S3) and performance (VIF).

required <- c("lme4", "lmerTest", "cluster")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Install first: install.packages(c(", paste0("\"", missing, "\"", collapse = ", "), "))", call. = FALSE)
}
suppressPackageStartupMessages(library(lmerTest))
has_gawdis <- requireNamespace("gawdis", quietly = TRUE)
has_performance <- requireNamespace("performance", quietly = TRUE)
options(stringsAsFactors = FALSE, contrasts = c("contr.treatment", "contr.poly"), width = 200)

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
# Rscript: the folder above 04_Statistics/; source() or the console (e.g. RStudio): the working
# directory, which must then be the project folder (as in 05_Paper_Outputs/paper_figures.R).
root <- if (length(script) == 1L) normalizePath(file.path(dirname(script), "..")) else normalizePath(getwd())
stats_dir <- file.path(root, "04_Statistics", "results")
if (!dir.exists(stats_dir)) {
  stop("04_Statistics/results/ not found under ", root, "; run from the project folder (setwd() to it in RStudio).", call. = FALSE)
}
trait_file <- file.path(root, "00_Documentation", "traits", "species_traits_core.csv")
# Historical C4/C5 scores, used only by the exploratory add-backs (D36, D37).
exploratory_file <- file.path(root, "00_Documentation", "traits", "species_traits_exploratory.csv")
timetree_file <- file.path(root, "00_Documentation", "timetree_species_list.nwk")
elton_file <- file.path(root, "data", "raw", "EltonTraits", "MamFuncDat.txt")  # Wilman et al. 2014; not shared

model_order <- c("CNN", "ResNet", "HYDRA", "MultiRocket", "RF", "LGBM")  # CNN is the reference
# D37: the five core traits.
core_traits <- c("log_body_mass_g", "dominant_locomotor_mode", "body_configuration_type",
                 "relative_neck_length", "food_acquisition_handling")
# Exploratory add-backs to the primary core, one historical trait each (D36, D37).
addback_traits <- c(core_with_c4 = "expected_trunk_motion_amplitude",
                    core_with_c5 = "expected_directional_change_tendency")
# D38: trait sensitivity of the core distance, one change each (all other inputs fixed):
# an edit of the raw trait table and the columns used.
set_value <- function(column, species, value) {
  function(raw) { raw[[column]][raw$species == species] <- value; raw }
}
trait_sensitivity <- c(
  list(raccoon_c3_separate = list(columns = core_traits,
                                  edit = set_value("body_configuration_type", "Procyon lotor", "generalist_quadruped")),
       hedgehog_neck_intermediate = list(columns = core_traits,
                                         edit = set_value("relative_neck_length", "Erinaceus europaeus", "intermediate")),
       # D43, added after the results were known: cattle ratio 0.311 lies near the 0.30 limit.
       cattle_neck_short = list(columns = core_traits,
                                edit = set_value("relative_neck_length", "Bos taurus", "short"))),
  setNames(lapply(core_traits, function(t) list(columns = setdiff(core_traits, t), edit = NULL)),
           paste0("without_", core_traits))
)
sensitivity_labels <- c(
  raccoon_c3_separate = "sensitivity: raccoon separate body configuration (D38)",
  hedgehog_neck_intermediate = "sensitivity: hedgehog neck length intermediate (D38)",
  cattle_neck_short = "sensitivity: cattle neck length short (D43)",
  without_log_body_mass_g = "sensitivity: without body mass (D38)",
  without_dominant_locomotor_mode = "sensitivity: without locomotor specialization (D38)",
  without_body_configuration_type = "sensitivity: without body configuration (D38)",
  without_relative_neck_length = "sensitivity: without relative neck length (D38)",
  without_food_acquisition_handling = "sensitivity: without food acquisition and handling (D38)"
)
stopifnot(setequal(names(trait_sensitivity), names(sensitivity_labels)))
# Levels of the ordinal traits, lowest first; all other non-numeric traits are nominal.
low_to_very_high <- c("low", "moderate", "high", "very_high")
ordinal_levels <- list(relative_neck_length = c("short", "intermediate", "long", "very_long"),
                       expected_trunk_motion_amplitude = low_to_very_high,
                       expected_directional_change_tendency = low_to_very_high)
# Names in EltonTraits and TimeTree, in this order, where the study name is missing there.
other_names <- list("Canis lupus familiaris" = "Canis lupus",
                    "Equus ferus przewalskii" = c("Equus ferus", "Equus caballus"),
                    "Giraffa camelopardalis" = "Giraffa reticulata")
elton_core_columns <- c("BodyMass-Value", "ForStrat-Value", "Activity-Nocturnal", "Activity-Crepuscular",
                        "Activity-Diurnal")
elton_diet_columns <- c("Diet-Inv", "Diet-Vend", "Diet-Vect", "Diet-Vfish", "Diet-Vunk", "Diet-Scav", "Diet-Fruit",
                        "Diet-Nect", "Diet-Seed", "Diet-PlantO")
random_full <- "(1 | unordered_species_pair) + (1 | ordered_species_pair) + (1 | train_species) + (1 | test_species)"
random_directional <- "(1 | ordered_species_pair) + (1 | train_species) + (1 | test_species)"
random_pair_only <- "(1 | ordered_species_pair)"
control <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 200000), check.conv.singular = "ignore")
confidence_level <- 0.95
singular_tol <- 1e-4
gawdis_seed <- 42

standardize <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
fmt <- function(x, digits = 3) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
fmt_p <- function(p) ifelse(is.na(p), "NA", ifelse(p < 0.001, "< 0.001", formatC(p, format = "f", digits = 3)))
table_lines <- function(df) capture.output(print(df, row.names = FALSE))


# --- traits and distances ---------------------------------------------------------------

# Traits of `columns` (core file plus the exploratory scores); `edit` (D38) changes the raw
# table before the conversion.
read_traits <- function(columns = core_traits, edit = NULL) {
  file <- trait_file
  raw <- read.csv(file, check.names = FALSE, strip.white = TRUE)
  extra <- read.csv(exploratory_file, check.names = FALSE, strip.white = TRUE)
  raw <- cbind(raw, extra[match(raw$species, extra$species), setdiff(names(extra), "species"), drop = FALSE])
  if (!is.null(edit)) raw <- edit(raw)
  if (is.null(columns)) columns <- setdiff(names(raw), "species")
  absent <- setdiff(columns, names(raw))
  if (length(absent)) stop(file, " lacks columns: ", paste(absent, collapse = ", "), call. = FALSE)
  traits <- raw[columns]
  if ("log_body_mass_g" %in% names(traits)) traits$log_body_mass_g <- as.numeric(traits$log_body_mass_g)
  for (t in setdiff(names(traits), "log_body_mass_g")) {
    traits[[t]] <- if (t %in% names(ordinal_levels)) {
      factor(tolower(traits[[t]]), levels = ordinal_levels[[t]], ordered = TRUE)
    } else {
      factor(traits[[t]])
    }
  }
  rownames(traits) <- raw$species
  if (any(!complete.cases(traits))) stop("Missing or invalid trait values in ", file, call. = FALSE)
  traits
}

pick_name <- function(species, available) {
  hit <- intersect(c(species, other_names[[species]]), available)
  if (length(hit)) hit[1] else NA_character_
}

# EltonTraits of the study species (first name with complete values; foraging stratum
# nominal, activity 0/1 and diet percentages numeric, body mass log), or NULL.
read_elton <- function(species) {
  if (!file.exists(elton_file)) return(NULL)
  raw <- read.delim(elton_file, check.names = FALSE, quote = "", comment.char = "", strip.white = TRUE)
  name_col <- intersect(c("Scientific", "scientificNameStd"), names(raw))[1]
  missing <- setdiff(c(name_col, elton_core_columns, elton_diet_columns), names(raw))
  if (is.na(name_col) || length(missing)) stop(elton_file, " lacks columns: ", paste(missing, collapse = ", "), call. = FALSE)
  raw <- raw[complete.cases(raw[c(elton_core_columns, elton_diet_columns)]), ]
  matched <- vapply(species, pick_name, character(1), available = raw[[name_col]])
  if (anyNA(matched)) stop("Not in EltonTraits: ", paste(species[is.na(matched)], collapse = ", "), call. = FALSE)
  rows <- raw[match(matched, raw[[name_col]]), c(elton_core_columns, elton_diet_columns)]
  out <- data.frame(species = species, elton_name = unname(matched), log_body_mass_g = log(rows[["BodyMass-Value"]]),
                    foraging_stratum = factor(rows[["ForStrat-Value"]]), check.names = FALSE)
  for (col in c(elton_core_columns[3:5], elton_diet_columns)) out[[col]] <- as.numeric(rows[[col]])
  rownames(out) <- species
  out
}

# D48: TimeTree dates Equus caballus vs Equus ferus (tarpan) to 10.1 Myr (CI 8.0-12.1; pairwise
# query 2026-11-08; 11.2 Myr in the tree file), older than the genus Equus (4.0-4.5 Myr). The
# populations of the domestic and the Przewalski's horse diverged 38-72 kyr ago (Orlando et al.
# 2013, Nature 499:74-78, pp. 74 and 76); this pair uses the midpoint, 0.055 Myr. All other
# pairs keep the TimeTree values.
divergence_overrides <- data.frame(species_1 = "Equus caballus", species_2 = "Equus ferus przewalskii", myr = 0.055)

# Divergence time of the study species (million years): height of the TimeTree tree minus
# the depth of the most recent common ancestor; then the overrides above.
read_divergence <- function(species) {
  if (!file.exists(timetree_file)) return(NULL)
  chars <- strsplit(gsub("[[:space:]]", "", paste(readLines(timetree_file, warn = FALSE), collapse = "")), "")[[1]]
  parent <- 0L; edge <- 0; label <- ""
  node <- 1L
  i <- 1L
  while (i <= length(chars) && chars[i] != ";") {
    ch <- chars[i]
    if (ch == "(" || ch == ",") {
      parent <- c(parent, if (ch == "(") node else parent[node]); edge <- c(edge, 0); label <- c(label, "")
      node <- length(parent)
      i <- i + 1L
    } else if (ch == ")") {
      node <- parent[node]
      i <- i + 1L
    } else {
      j <- i
      while (j <= length(chars) && !(chars[j] %in% c("(", ")", ",", ";"))) j <- j + 1L
      token <- strsplit(paste(chars[i:(j - 1L)], collapse = ""), ":", fixed = TRUE)[[1]]
      label[node] <- gsub("_", " ", gsub("'", "", token[1]))
      if (length(token) > 1L) edge[node] <- as.numeric(token[2])
      i <- j
    }
  }
  depth <- edge
  for (k in seq_along(parent)[-1]) depth[k] <- depth[parent[k]] + edge[k]
  tips <- setdiff(seq_along(parent), parent)
  ancestors <- function(k) { out <- k; while (parent[k] > 0L) { k <- parent[k]; out <- c(out, k) }; out }
  tip_of <- tips[match(vapply(species, pick_name, character(1), available = label[tips]), label[tips])]
  if (anyNA(tip_of)) stop("Not in ", timetree_file, ": ", paste(species[is.na(tip_of)], collapse = ", "), call. = FALSE)
  height <- max(depth[tips])
  m <- outer(seq_along(species), seq_along(species), Vectorize(function(a, b) {
    if (a == b) return(0)
    height - depth[intersect(ancestors(tip_of[a]), ancestors(tip_of[b]))[1]]
  }))
  dimnames(m) <- list(species, species)
  for (i in seq_len(nrow(divergence_overrides))) {
    a <- divergence_overrides$species_1[i]
    b <- divergence_overrides$species_2[i]
    if (all(c(a, b) %in% species)) m[a, b] <- m[b, a] <- divergence_overrides$myr[i]
  }
  m
}

# D28: further distances of the study species (matrices), each where its input exists.
other_distances <- function(species, traits) {
  # D36/D37: the primary core plus one historical trait, all other inputs unchanged.
  out <- lapply(addback_traits, function(t) {
    as.matrix(cluster::daisy(read_traits(columns = c(core_traits, t))[species, ], metric = "gower"))
  })
  # D38: trait sensitivity of the core distance.
  for (n in names(trait_sensitivity)) {
    v <- trait_sensitivity[[n]]
    out[[n]] <- as.matrix(cluster::daisy(read_traits(columns = v$columns, edit = v$edit)[species, ], metric = "gower"))
  }
  out$log_body_mass <- abs(outer(traits[species, "log_body_mass_g"], traits[species, "log_body_mass_g"], "-"))
  dimnames(out$log_body_mass) <- list(species, species)
  elton <- read_elton(species)
  if (!is.null(elton)) {
    core_cols <- c("log_body_mass_g", "foraging_stratum", elton_core_columns[3:5])
    out$elton_core <- as.matrix(cluster::daisy(elton[core_cols], metric = "gower"))
    out$elton_extended <- as.matrix(cluster::daisy(elton[c(core_cols, elton_diet_columns)], metric = "gower"))
  }
  divergence <- read_divergence(species)
  if (!is.null(divergence)) out$divergence_time <- divergence
  list(matrices = out, elton = elton)
}

gawdis_distance <- function(traits, gower) {
  if (!has_gawdis) return(NULL)
  equal <- gawdis::gawdis(traits, w.type = "equal", ord = "classic", silent = TRUE)
  check <- max(abs(as.matrix(equal) - gower))
  analytic <- tryCatch(suppressWarnings(gawdis::gawdis(traits, w.type = "analytic", ord = "classic", silent = TRUE)),
                       error = function(e) NULL)
  set.seed(gawdis_seed)
  optimized <- gawdis::gawdis(traits, w.type = "optimized", ord = "classic", opti.maxiter = 300, silent = TRUE)
  m <- as.matrix(optimized)
  dimnames(m) <- dimnames(gower)
  weights <- data.frame(
    trait = names(traits),
    weight_equal = as.numeric(attr(equal, "weights")),
    correlation_equal = as.numeric(attr(equal, "correls")),
    weight_analytic = if (is.null(analytic)) NA_real_ else as.numeric(attr(analytic, "weights")),
    weight_optimized = as.numeric(attr(optimized, "weights")),
    correlation_optimized = as.numeric(attr(optimized, "correls"))
  )
  list(matrix = m, weights = weights, equal_check = check)
}


# --- H3 table ---------------------------------------------------------------------------

species_pairs <- function(pairs, gower, gawdis_m, others = list()) {
  pairs <- pairs[!as.logical(pairs$same_species), ]
  pairs$retention <- pairs$macro_f1 / pairs$target_within_macro_f1
  keys <- pairs[c("model", "train_species", "test_species")]
  values <- data.frame(mean_macro_f1 = pairs$macro_f1, source_within = pairs$source_within_macro_f1,
                       target_within = pairs$target_within_macro_f1, retention = pairs$retention)
  h3 <- aggregate(values, by = keys, FUN = mean)
  n <- aggregate(list(n_dataset_pairs = rep(1L, nrow(pairs))), by = keys, FUN = sum)
  h3 <- merge(h3, n, by = names(keys))
  h3$log_retention <- log(h3$retention)
  h3$trait_distance_core <- gower[cbind(h3$train_species, h3$test_species)]
  h3$trait_distance_gawdis <- if (is.null(gawdis_m)) NA_real_ else gawdis_m[cbind(h3$train_species, h3$test_species)]
  for (n in names(others)) h3[[paste0("distance_", n)]] <- others[[n]][cbind(h3$train_species, h3$test_species)]
  h3$ordered_species_pair <- factor(paste(h3$train_species, h3$test_species, sep = "__"))
  h3$unordered_species_pair <- factor(ifelse(h3$train_species < h3$test_species,
                                             paste(h3$train_species, h3$test_species, sep = "__"),
                                             paste(h3$test_species, h3$train_species, sep = "__")))
  h3$model <- factor(h3$model, levels = intersect(model_order, unique(h3$model)))
  h3$train_species <- factor(h3$train_species)
  h3$test_species <- factor(h3$test_species)
  h3[order(h3$model, h3$train_species, h3$test_species), ]
}


# --- models -----------------------------------------------------------------------------

fit_lmer <- function(formula, data, reml) {
  seen <- character()
  fit <- withCallingHandlers(
    tryCatch(lmerTest::lmer(formula, data = data, REML = reml, control = control), error = function(e) e),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  if (inherits(fit, "error")) return(list(fit = NULL, notes = conditionMessage(fit)))
  list(fit = fit, notes = paste(unique(c(fit@optinfo$conv$lme4$messages, seen)), collapse = " | "))
}

# Prediction of a fitted primary model on a grid of the distance (original scale), averaged
# over the models (each model dummy 1 / number of models; random effects 0): estimate and
# CI of each linear combination with Satterthwaite df (lmerTest::contest).
predict_distance <- function(fit, data, n = 50L) {
  if (is.null(fit)) return(NULL)
  beta <- lme4::fixef(fit)
  x <- seq(min(data$trait_distance_core), max(data$trait_distance_core), length.out = n)
  z <- (x - mean(data$trait_distance_core)) / sd(data$trait_distance_core)  # as standardize()
  model_terms <- grep("^model", names(beta), value = TRUE)
  do.call(rbind, lapply(seq_len(n), function(i) {
    L <- setNames(numeric(length(beta)), names(beta))
    L[["(Intercept)"]] <- 1
    L[["z_distance"]] <- z[i]
    if (length(model_terms) > 0L) L[model_terms] <- 1 / nlevels(data$model)
    ct <- lmerTest::contest(fit, matrix(L, nrow = 1L), joint = FALSE, confint = TRUE, level = confidence_level)
    data.frame(trait_distance_core = x[i], z_distance = z[i], estimate = ct[["Estimate"]],
               std_error = ct[["Std. Error"]], df = ct[["df"]], ci_low = ct[["lower"]], ci_high = ct[["upper"]])
  }))
}

prepare <- function(h3, needed, distance) {
  data <- droplevels(h3[complete.cases(h3[needed]), ])
  data$z_distance <- standardize(data[[distance]])
  data$z_source_within <- standardize(data$source_within)
  data$z_target_within <- standardize(data$target_within)
  data
}

fixed_table <- function(fit, label) {
  if (is.null(fit)) return(NULL)
  co <- as.data.frame(coef(summary(fit)))
  df <- if ("df" %in% names(co)) co$df else Inf
  critical <- qt((1 + confidence_level) / 2, df = df)
  data.frame(analysis = label, term = rownames(co), estimate = co$Estimate, std_error = co$`Std. Error`,
             df = df, statistic = co$`t value`,
             p_value = if ("Pr(>|t|)" %in% names(co)) co$`Pr(>|t|)` else NA_real_,
             ci_low = co$Estimate - critical * co$`Std. Error`, ci_high = co$Estimate + critical * co$`Std. Error`,
             row.names = NULL)
}

# Nakagawa R2 of a random-intercept model: variance of the fixed-effect predictions, sum of
# the random-intercept variances, residual variance. Computed here because
# performance::r2_nakagawa gives no conditional and a too high marginal R2 when a variance
# is estimated as 0 (singular fit).
r2_nakagawa <- function(fit) {
  var_fixed <- var(as.vector(lme4::getME(fit, "X") %*% lme4::fixef(fit)))
  vc <- as.data.frame(lme4::VarCorr(fit))
  var_random <- sum(vc$vcov[vc$grp != "Residual"])
  total <- var_fixed + var_random + vc$vcov[vc$grp == "Residual"]
  c(marginal = var_fixed / total, conditional = (var_fixed + var_random) / total)
}

# Likelihood-ratio test of two nested ML fits; estimate of `term` from the REML fit.
compare <- function(label, data, response, null_rhs, full_rhs, term, random = random_full) {
  formula <- function(rhs) as.formula(paste(response, "~", rhs, "+", random))
  null_ml <- fit_lmer(formula(null_rhs), data, FALSE)
  full_ml <- fit_lmer(formula(full_rhs), data, FALSE)
  full_reml <- fit_lmer(formula(full_rhs), data, TRUE)
  row <- data.frame(analysis = label, response = response, term = term, random_effects = random,
                    n_observations = nrow(data), n_ordered_pairs = nlevels(data$ordered_species_pair),
                    n_models = nlevels(data$model), estimate = NA_real_, std_error = NA_real_, df = NA_real_,
                    ci_low = NA_real_, ci_high = NA_real_, lr_chisq = NA_real_, lr_df = NA_real_,
                    lr_p_value = NA_real_, aic_null = NA_real_, aic_full = NA_real_, singular_reml = NA,
                    r2_marginal = NA_real_, r2_conditional = NA_real_,
                    notes = paste(setdiff(c(null_ml$notes, full_ml$notes, full_reml$notes), ""), collapse = " || "))
  if (is.null(null_ml$fit) || is.null(full_ml$fit) || is.null(full_reml$fit)) {
    return(list(row = row, reml = full_reml$fit))
  }
  lr <- suppressMessages(anova(null_ml$fit, full_ml$fit))
  row$lr_chisq <- lr$Chisq[2]
  row$lr_df <- lr$Df[2]
  row$lr_p_value <- lr$`Pr(>Chisq)`[2]
  row$aic_null <- AIC(null_ml$fit)
  row$aic_full <- AIC(full_ml$fit)
  row$singular_reml <- isSingular(full_reml$fit, tol = singular_tol)
  fe <- fixed_table(full_reml$fit, label)
  if (term %in% fe$term) {
    hit <- fe[fe$term == term, ]
    row[c("estimate", "std_error", "df", "ci_low", "ci_high")] <- hit[c("estimate", "std_error", "df", "ci_low", "ci_high")]
  }
  r2 <- r2_nakagawa(full_reml$fit)
  row$r2_marginal <- r2[["marginal"]]
  row$r2_conditional <- r2[["conditional"]]
  list(row = row, reml = full_reml$fit)
}

spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  n <- sum(ok)
  if (n < 4L) return(c(n = n, rho = NA, p_value = NA, ci_low = NA, ci_high = NA))
  test <- suppressWarnings(cor.test(x[ok], y[ok], method = "spearman", exact = FALSE))
  rho <- unname(test$estimate)
  z <- atanh(pmin(pmax(rho, -0.999999), 0.999999))
  half <- qnorm((1 + confidence_level) / 2) / sqrt(n - 3)
  c(n = n, rho = rho, p_value = test$p.value, ci_low = tanh(z - half), ci_high = tanh(z + half))
}


# --- one scenario -----------------------------------------------------------------------

run_scenario <- function(scenario) {
  dir <- file.path(stats_dir, scenario)
  pairs <- read.csv(file.path(dir, "h3_input.csv"))
  pairs$same_species <- as.logical(pairs$same_species)  # written by pandas as True/False
  by_seed_file <- file.path(dir, "h3_input_by_seed.csv")
  traits <- read_traits()
  study_species <- sort(unique(c(pairs$train_species, pairs$test_species)))
  missing_species <- setdiff(study_species, rownames(traits))
  if (length(missing_species) > 0L) stop("No traits for: ", paste(missing_species, collapse = ", "), call. = FALSE)
  traits <- traits[study_species, ]
  gower <- as.matrix(cluster::daisy(traits, metric = "gower"))
  gaw <- gawdis_distance(traits, gower)
  other <- other_distances(study_species, traits)
  h3 <- species_pairs(pairs, gower, if (is.null(gaw)) NULL else gaw$matrix, other$matrices)
  mt <- if (nlevels(h3$model) > 1L) "model" else NULL
  rhs <- function(...) paste(c(..., mt), collapse = " + ")
  null_rhs <- if (is.null(mt)) "1" else "model"

  # Analyses: label, data, response, null and full fixed effects, tested term, random effects.
  core <- c("mean_macro_f1", "trait_distance_core")
  d_primary <- prepare(h3, core, "trait_distance_core")
  d_s1 <- prepare(h3, c(core, "source_within", "target_within"), "trait_distance_core")
  d_s2 <- prepare(h3, c("retention", "trait_distance_core"), "trait_distance_core")
  cov <- "z_source_within + z_target_within"
  specs <- list(
    list("primary", d_primary, "mean_macro_f1", null_rhs, rhs("z_distance"), "z_distance", random_full),
    list("interaction distance x model", d_primary, "mean_macro_f1", rhs("z_distance"),
         if (is.null(mt)) "z_distance" else "z_distance * model", "z_distance:model", random_full),
    list("directional random effects", d_primary, "mean_macro_f1", null_rhs, rhs("z_distance"), "z_distance",
         random_directional),
    list("pair-only random effect", d_primary, "mean_macro_f1", null_rhs, rhs("z_distance"), "z_distance",
         random_pair_only),
    list("S1 within covariates", d_s1, "mean_macro_f1", paste(null_rhs, "+", cov),
         paste(rhs("z_distance"), "+", cov), "z_distance", random_full),
    list("S2 retention", d_s2, "retention", null_rhs, rhs("z_distance"), "z_distance", random_full),
    list("S2 log retention", d_s2, "log_retention", null_rhs, rhs("z_distance"), "z_distance", random_full)
  )
  if (!is.null(gaw)) {
    d_s3 <- prepare(h3, c("mean_macro_f1", "trait_distance_gawdis"), "trait_distance_gawdis")
    specs[[length(specs) + 1L]] <- list("S3 gawdis distance", d_s3, "mean_macro_f1", null_rhs, rhs("z_distance"),
                                        "z_distance", random_full)
  }
  # D27: the primary model with only the models of the sensitivity scenarios, to compare with them.
  feature_models <- c("RF", "LGBM")
  if (nlevels(h3$model) > 2L && all(feature_models %in% levels(h3$model))) {
    specs[[length(specs) + 1L]] <- list("RF and LGBM only (D27)", prepare(h3[h3$model %in% feature_models, ], core,
                                        "trait_distance_core"), "mean_macro_f1", "model", "z_distance + model",
                                        "z_distance", random_full)
  }

  # D28: the primary model with the other distances.
  other_labels <- c(core_with_c4 = "exploratory core + C4 (D36)", core_with_c5 = "exploratory core + C5 (D37)",
                    elton_core = "EltonTraits core", elton_extended = "EltonTraits extended",
                    divergence_time = "divergence time (TimeTree)", log_body_mass = "log body mass")
  other_labels <- other_labels[names(other_labels) %in% names(other$matrices)]
  for (n in names(other_labels)) {
    col <- paste0("distance_", n)
    specs[[length(specs) + 1L]] <- list(other_labels[[n]], prepare(h3, c("mean_macro_f1", col), col), "mean_macro_f1",
                                        null_rhs, rhs("z_distance"), "z_distance", random_full)
  }
  # D38: the primary model with the core distance after one trait change.
  for (n in names(sensitivity_labels)) {
    col <- paste0("distance_", n)
    specs[[length(specs) + 1L]] <- list(sensitivity_labels[[n]], prepare(h3, c("mean_macro_f1", col), col), "mean_macro_f1",
                                        null_rhs, rhs("z_distance"), "z_distance", random_full)
  }
  fits <- lapply(specs, function(s) do.call(compare, setNames(s, c("label", "data", "response", "null_rhs",
                                                                 "full_rhs", "term", "random"))))
  models <- do.call(rbind, lapply(fits, `[[`, "row"))
  names(fits) <- models$analysis
  fixed <- do.call(rbind, lapply(names(fits), function(n) fixed_table(fits[[n]]$reml, n)))
  primary_fit <- fits[["primary"]]$reml
  random <- if (is.null(primary_fit)) NULL else as.data.frame(VarCorr(primary_fit))[c("grp", "vcov", "sdcor")]
  prediction <- predict_distance(primary_fit, d_primary)
  if (!is.null(random)) names(random) <- c("group", "variance", "std_dev")

  # Slopes per model: the interaction model written with one slope per model.
  slopes <- NULL
  if (!is.null(mt)) {
    sf <- fit_lmer(as.formula(paste("mean_macro_f1 ~ 0 + model + model:z_distance +", random_full)), d_primary, TRUE)
    slopes <- fixed_table(sf$fit, "slopes per model")
    slopes <- slopes[grepl(":z_distance$", slopes$term), ]
    slopes$model <- sub("^model", "", sub(":z_distance$", "", slopes$term))
  }

  # Descriptive Spearman correlations of distance and Macro-F1.
  sp <- rbind(c(model = "all models pooled", spearman(h3$trait_distance_core, h3$mean_macro_f1)),
              do.call(rbind, lapply(levels(h3$model), function(m) {
                g <- h3[h3$model == m, ]
                c(model = m, spearman(g$trait_distance_core, g$mean_macro_f1))
              })))
  sp <- as.data.frame(sp)
  for (col in setdiff(names(sp), "model")) sp[[col]] <- as.numeric(sp[[col]])
  sp$p_holm <- NA_real_
  per_model <- sp$model != "all models pooled"
  sp$p_holm[per_model] <- p.adjust(sp$p_value[per_model], method = "holm")

  # Seeds: the primary model per seed (descriptive).
  seeds <- NULL
  if (file.exists(by_seed_file)) {
    by_seed <- read.csv(by_seed_file)
    seeds <- do.call(rbind, lapply(sort(unique(by_seed$seed)), function(s) {
      h <- species_pairs(by_seed[by_seed$seed == s, ], gower, NULL)
      d <- prepare(h, core, "trait_distance_core")
      cbind(seed = s, compare("primary", d, "mean_macro_f1", null_rhs, rhs("z_distance"), "z_distance")$row)
    }))
  }

  # D28: leave-one-species-out (all pairs with the species left out, distance z-scored again).
  loso <- do.call(rbind, lapply(study_species, function(sp) {
    d <- prepare(h3[h3$train_species != sp & h3$test_species != sp, ], core, "trait_distance_core")
    cbind(left_out = sp, compare("primary", d, "mean_macro_f1", null_rhs, rhs("z_distance"), "z_distance")$row)
  }))

  # S1 collinearity: correlations of the covariates with the distance (and VIF).
  s1_cor <- data.frame(variable = c("source_within", "target_within"),
                       r_with_trait_distance = c(cor(d_s1$source_within, d_s1$trait_distance_core),
                                                 cor(d_s1$target_within, d_s1$trait_distance_core)))
  vif <- NULL
  if (has_performance && !is.null(fits[["S1 within covariates"]]$reml)) {
    vif <- tryCatch(as.data.frame(performance::check_collinearity(fits[["S1 within covariates"]]$reml))[c("Term", "VIF")],
                    error = function(e) NULL)
  }

  distances <- as.data.frame(as.table(gower))
  names(distances) <- c("species_1", "species_2", "gower_core")
  distances <- distances[as.character(distances$species_1) < as.character(distances$species_2), ]
  if (!is.null(gaw)) distances$gawdis <- gaw$matrix[cbind(as.character(distances$species_1), as.character(distances$species_2))]
  for (n in names(other$matrices)) {
    distances[[n]] <- other$matrices[[n]][cbind(as.character(distances$species_1), as.character(distances$species_2))]
  }

  out <- list(h3_data = h3, h3_models = models, h3_fixed_effects = fixed, h3_random_effects = random,
              h3_slopes = slopes, h3_spearman = sp, h3_seeds = seeds, h3_distances = distances,
              h3_gawdis_weights = if (is.null(gaw)) NULL else gaw$weights, h3_loso = loso,
              h3_elton_traits = other$elton, h3_prediction = prediction)
  for (n in names(out)) if (!is.null(out[[n]])) write.csv(out[[n]], file.path(dir, paste0(n, ".csv")), row.names = FALSE)

  # Report.
  n_species <- length(study_species)
  model_line <- function(r) {
    sprintf("  %-30s n %3d  beta %s [%s, %s]  SE %s  LR chi2(%s) %s  p %s%s", r$analysis, r$n_observations,
            fmt(r$estimate), fmt(r$ci_low), fmt(r$ci_high), fmt(r$std_error), ifelse(is.na(r$lr_df), "NA", r$lr_df),
            fmt(r$lr_chisq, 2), fmt_p(r$lr_p_value), ifelse(isTRUE(r$singular_reml), "  (singular fit)", ""))
  }
  report <- c(
    paste("STATISTICS H3 - scenario", scenario), strrep("=", 100), "",
    paste("Input:", file.path("04_Statistics", "results", scenario, "h3_input.csv"), "(pairwise Macro-F1, mean over the seeds)"),
    paste("Traits:", file.path("00_Documentation", "traits", basename(trait_file)), "(five core traits of D37; Gower distance, equal weights)"),
    "",
    "STRUCTURE",
    sprintf("  models %d (%s); species %d; ordered species pairs %d; unordered %d; records %d",
            nlevels(h3$model), paste(levels(h3$model), collapse = ", "), n_species,
            nlevels(h3$ordered_species_pair), nlevels(h3$unordered_species_pair), nrow(h3)),
    sprintf("  dataset pairs of the same species left out: %d (per model)",
            sum(pairs$same_species & pairs$model == pairs$model[1])),
    "",
    "TRAIT DISTANCE EFFECT (beta per SD of the distance; 95 % CI from the REML fit, Satterthwaite df;",
    "likelihood-ratio test of ML fits; S2 on the retention scale)",
    vapply(which(!models$analysis %in% c(other_labels, sensitivity_labels)), function(i) model_line(models[i, ]), character(1)),
    "",
    sprintf("  R2 (Nakagawa) of the primary model: marginal %s, conditional %s", fmt(models$r2_marginal[1]),
            fmt(models$r2_conditional[1])),
    "",
    "OTHER DISTANCES (D28/D36/D37; primary model, distance z-scored)",
    "  core + C4 / core + C5: exploratory six-trait add-backs of one excluded trait each.",
    vapply(which(models$analysis %in% other_labels), function(i) model_line(models[i, ]), character(1)),
    if (!"elton_core" %in% names(other$matrices)) {
      paste0("  EltonTraits: skipped (", file.path("data", "raw", "EltonTraits", "MamFuncDat.txt"), " not found)")
    },
    if (!is.null(other$elton)) {
      paste("  EltonTraits names:", paste(sprintf("%s = %s", other$elton$species, other$elton$elton_name)[
        other$elton$species != other$elton$elton_name], collapse = "; "))
    },
    "",
    "TRAIT SENSITIVITY (D38, D43; primary model with the core distance after one change, z-scored; robustness only)",
    vapply(which(models$analysis %in% sensitivity_labels), function(i) model_line(models[i, ]), character(1)),
    "",
    "LEAVE ONE SPECIES OUT (D28; primary model without all pairs of the species)",
    sprintf("  %-26s n %3d  beta %s [%s, %s]  LR chi2 %s  p %s%s", loso$left_out, loso$n_observations,
            fmt(loso$estimate), fmt(loso$ci_low), fmt(loso$ci_high), fmt(loso$lr_chisq, 2), fmt_p(loso$lr_p_value),
            ifelse(loso$singular_reml %in% TRUE, "  (singular fit)", "")),
    sprintf("  range of beta: %s to %s; p < 0.05 in %d of %d refits", fmt(min(loso$estimate, na.rm = TRUE)),
            fmt(max(loso$estimate, na.rm = TRUE)), sum(loso$lr_p_value < 0.05, na.rm = TRUE), nrow(loso)),
    ""
  )
  if (!is.null(seeds)) {
    report <- c(report, "PRIMARY MODEL PER SEED (descriptive)",
                vapply(seq_len(nrow(seeds)), function(i) {
                  r <- seeds[i, ]
                  sprintf("  seed %d  beta %s [%s, %s]  LR chi2 %s  p %s", r$seed, fmt(r$estimate), fmt(r$ci_low),
                          fmt(r$ci_high), fmt(r$lr_chisq, 2), fmt_p(r$lr_p_value))
                }, character(1)),
                sprintf("  range of beta over the seeds: %s to %s", fmt(min(seeds$estimate)), fmt(max(seeds$estimate))), "")
  }
  if (!is.null(slopes)) {
    report <- c(report, "SLOPES PER MODEL (interaction model, REML)",
                sprintf("  %-12s %s [%s, %s]", slopes$model, fmt(slopes$estimate), fmt(slopes$ci_low), fmt(slopes$ci_high)), "")
  }
  report <- c(report, "SPEARMAN CORRELATIONS (distance vs. Macro-F1, descriptive; CI by Fisher z, Holm over the models)",
              sprintf("  %-18s n %3d  rho %s [%s, %s]  p %s  Holm %s", sp$model, as.integer(sp$n), fmt(sp$rho),
                      fmt(sp$ci_low), fmt(sp$ci_high), fmt_p(sp$p_value), fmt_p(sp$p_holm)), "",
              "S1: CORRELATIONS OF THE COVARIATES WITH THE DISTANCE", table_lines(s1_cor))
  if (!is.null(vif)) report <- c(report, "", "S1: VARIANCE INFLATION FACTORS", table_lines(vif))
  if (!is.null(gaw)) {
    report <- c(report, "", sprintf("S3: GAWDIS TRAIT WEIGHTS (equal weights reproduce the Gower distance: max. difference %.1e)",
                                    gaw$equal_check), table_lines(gaw$weights))
  } else {
    report <- c(report, "", "S3: skipped (package gawdis not installed)")
  }
  no_within <- unique(c(as.character(h3$train_species[is.na(h3$source_within)])))
  report <- c(report, "", "NOTES",
              paste("  Species without within value (left out in S1; as target in S2):",
                    if (length(no_within)) paste(no_within, collapse = ", ") else "none"),
              "  Fit notes (convergence, singularity) are in column notes of h3_models.csv.")
  writeLines(enc2utf8(report), file.path(dir, "statistics_h3.txt"), useBytes = TRUE)
  cat(scenario, ": ", nrow(h3), " records -> ", dir, "\n", sep = "")
}

scenarios <- commandArgs(trailingOnly = TRUE)
if (length(scenarios) == 0L) {
  scenarios <- basename(dirname(Sys.glob(file.path(stats_dir, "*", "h3_input.csv"))))
}
if (length(scenarios) == 0L) stop("No h3_input.csv in 04_Statistics/results; run 04_Statistics/stats_h1_h2.py first.", call. = FALSE)
for (s in scenarios) run_scenario(s)
