relationsClass <- if (requireNamespace("jmvcore", quietly = TRUE)) {
    R6::R6Class(
        "relationsClass",
        inherit = relationsBase,
        private = list(
            .init = function() {
                relations <- self$results$relations
                relations$scripts <- "jglance.umd.js"
                relations$stylesheets <- "jglance.css"
                private$.renderHtml(list(
                    variables = I(list()),
                    error = "Add variables to the options panel to start exploring their relations."
                ))
            },
            .run = function() {
                varNames <- self$options$vars
                if (is.null(varNames) || length(varNames) == 0) {
                    private$.renderHtml(list(
                        variables = I(list()),
                        error = "Add variables to the options panel to start exploring their relations."
                    ))
                    return()
                }

                if (length(varNames) < 2) {
                    varsData <- self$data[varNames]
                    variables <- lapply(varNames, function(name) {
                        private$.summarizeUnivariate(name, varsData[[name]])
                    })
                    private$.renderHtml(list(
                        variables = variables,
                        error = "Add at least one more variable to see associations."
                    ))
                    return()
                }

                # We calculate pairwise associations for all variables.
                # For large datasets, we might want to sample or limit this,
                # but for typical jamovi use-cases (N < 5000, P < 50), it's fast.

                varsData <- self$data[varNames]
                nVars <- length(varNames)

                # 1. Univariate summaries (for labels/types in UI)
                variables <- lapply(varNames, function(name) {
                    v <- varsData[[name]]
                    private$.summarizeUnivariate(name, v)
                })

                # 2. Bivariate associations (The Matrix)
                # We'll store this as a flat list of pairs to keep the JSON simple,
                # or a nested list if preferred. Let's do a nested list: matrix[a][b].
                matrix <- list()
                for (i in seq_len(nVars)) {
                    nameA <- varNames[i]
                    vA <- varsData[[nameA]]
                    matrix[[nameA]] <- list()

                    for (j in seq_len(nVars)) {
                        if (i == j) {
                            matrix[[nameA]][[nameA]] <- 1.0
                            next
                        }
                        nameB <- varNames[j]
                        vB <- varsData[[nameB]]

                        # Optimization: since associations are symmetric, we could
                        # only compute one half. But for small N it's simpler to
                        # just compute all.
                        matrix[[nameA]][[
                            nameB
                        ]] <- private$.calculateAssociation(vA, vB)
                    }
                }

                targetRaw <- self$options$selectedTarget
                targetName <- if (is.null(targetRaw) || length(targetRaw) == 0) {
                    ""
                } else {
                    as.character(targetRaw)
                }
                if (nchar(targetName) == 0 || !(targetName %in% varNames)) {
                    targetName <- varNames[[1]]
                }

                pairDetails <- if (
                    nchar(targetName) > 0 && targetName %in% varNames
                ) {
                    private$.computePairDetails(targetName, varsData, varNames)
                } else {
                    NULL
                }

                payload <- list(
                    variables = variables,
                    associations = matrix,
                    selectedTarget = targetName,
                    pairDetails = pairDetails
                )

                private$.renderHtml(payload)
            },
            .summarizeUnivariate = function(name, v) {
                desc <- attr(v, "jmv-desc")
                if (!is.null(desc) && nchar(desc) == 0) {
                    desc <- NULL
                }

                type <- "continuous"
                if (is.factor(v)) {
                    type <- if (is.ordered(v)) "ordinal" else "nominal"
                }

                # ID check (reusing logic from overview.b.R)
                measureType <- attr(v, "jmv-measure-type")
                isId <- isTRUE(attr(v, "jmv-id")) ||
                    (!is.null(measureType) &&
                        tolower(as.character(measureType)) == "id")
                if (isId) type <- "id"

                list(
                    name = name,
                    description = desc,
                    type = type
                )
            },
            .calculateAssociation = function(v1, v2) {
                # Handle missing values pairwise
                complete <- !is.na(v1) & !is.na(v2)
                if (sum(complete) < 5) return(0.0) # Insufficient data

                x <- v1[complete]
                y <- v2[complete]

                isNum1 <- is.numeric(x)
                isNum2 <- is.numeric(y)

                if (isNum1 && isNum2) {
                    # Cont vs Cont: Pearson R^2
                    # We use abs(cor) because we want a 0-1 strength metric for ranking,
                    # but R^2 is more standard for "variance explained".
                    r <- cor(x, y)
                    return(as.numeric(r^2))
                } else if (!isNum1 && !isNum2) {
                    # Cat vs Cat: Cramer's V
                    tab <- table(x, y)
                    if (nrow(tab) < 2 || ncol(tab) < 2) return(0.0)

                    chi2 <- suppressWarnings(chisq.test(tab)$statistic)
                    n <- sum(tab)
                    v <- as.numeric(sqrt(
                        chi2 / (n * (min(nrow(tab), ncol(tab)) - 1))
                    ))
                    return(if (is.na(v)) 0.0 else v)
                } else {
                    # Cat vs Cont: Eta-squared (from ANOVA)
                    # We treat the numeric one as the dependent variable.
                    dep <- if (isNum1) x else y
                    indep <- if (isNum1) y else x

                    if (length(unique(indep)) < 2) return(0.0)

                    # Quick Eta-squared calculation: (SS_between / SS_total)
                    fit <- aov(dep ~ indep)
                    ss <- summary(fit)[[1]][, "Sum Sq"]
                    eta2 <- ss[1] / sum(ss)
                    return(as.numeric(eta2))
                }
            },
            .computePairDetails = function(targetName, varsData, varNames) {
                targetV <- varsData[[targetName]]
                targetIsNum <- is.numeric(targetV)
                predictorNames <- varNames[varNames != targetName]

                details <- list()
                for (name in predictorNames) {
                    v <- varsData[[name]]
                    complete <- !is.na(targetV) & !is.na(v)
                    n <- sum(complete)

                    if (n < 5) {
                        details[[name]] <- NULL
                        next
                    }

                    tgt <- targetV[complete]
                    pred <- v[complete]
                    predIsNum <- is.numeric(v)

                    if (targetIsNum && predIsNum) {
                        idx <- if (n > 200) sample(n, 200) else seq_len(n)
                        pts <- lapply(idx, function(i) {
                            list(
                                x = as.numeric(pred[i]),
                                y = as.numeric(tgt[i])
                            )
                        })
                        details[[name]] <- list(
                            type = "scatter",
                            points = I(pts),
                            xLabel = name,
                            yLabel = targetName
                        )
                    } else if (targetIsNum && !predIsNum) {
                        lvls <- if (is.factor(pred)) levels(pred) else
                            sort(unique(as.character(pred)))
                        grps <- lapply(lvls, function(lvl) {
                            vals <- tgt[as.character(pred) == lvl]
                            list(
                                label = lvl,
                                mean = as.numeric(mean(vals, na.rm = TRUE)),
                                n = as.integer(length(vals))
                            )
                        })
                        details[[name]] <- list(
                            type = "bars",
                            groups = I(grps),
                            contLabel = targetName,
                            catLabel = name
                        )
                    } else if (!targetIsNum && predIsNum) {
                        lvls <- if (is.factor(tgt)) levels(tgt) else
                            sort(unique(as.character(tgt)))
                        grps <- lapply(lvls, function(lvl) {
                            vals <- pred[as.character(tgt) == lvl]
                            list(
                                label = lvl,
                                mean = as.numeric(mean(vals, na.rm = TRUE)),
                                n = as.integer(length(vals))
                            )
                        })
                        details[[name]] <- list(
                            type = "bars",
                            groups = I(grps),
                            contLabel = name,
                            catLabel = targetName
                        )
                    } else {
                        tgt_lvls <- if (is.factor(tgt)) levels(tgt) else
                            sort(unique(as.character(tgt)))
                        pred_lvls <- if (is.factor(pred)) levels(pred) else
                            sort(unique(as.character(pred)))
                        tab <- table(
                            factor(as.character(tgt), levels = tgt_lvls),
                            factor(as.character(pred), levels = pred_lvls)
                        )
                        rows_list <- lapply(
                            seq_len(nrow(tab)),
                            function(i) I(as.integer(tab[i, ]))
                        )
                        details[[name]] <- list(
                            type = "mosaic",
                            rows = I(tgt_lvls),
                            cols = I(pred_lvls),
                            counts = I(rows_list)
                        )
                    }
                }
                details
            },
            .renderHtml = function(payload) {
                json <- jsonlite::toJSON(
                    payload,
                    auto_unbox = TRUE,
                    null = "null"
                )
                id <- "jglance-relations-container"
                relations <- self$results$relations
                relations$setContent(paste0(
                    '<script>
                (function() {
                    if (!document.getElementById("jglance-css")) {
                        var link = document.createElement("link");
                        link.id = "jglance-css";
                        link.rel = "stylesheet";
                        link.href = "module/jglance.css";
                        document.head.appendChild(link);
                    }
                })();
                </script>
                <div id="',
                    id,
                    '" class="jglance" style="opacity: 0;"></div>
                <script>
                (function render() {
                    var container = document.getElementById("',
                    id,
                    '");
                    if (typeof Jglance === "undefined") {
                        if (container) {
                            container.style.opacity = "0";
                        }
                        setTimeout(render, 1);
                        return;
                    }
                    if (container) {
                        container.style.opacity = "1";
                    }
                    var data = ',
                    json,
                    ';
                    Jglance.createRelations("#',
                    id,
                    '", data);
                })();
                </script>'
                ))
            }
        )
    )
}
