overviewClass <- if (requireNamespace('jmvcore', quietly = TRUE))
    R6::R6Class(
        "overviewClass",
        inherit = overviewBase,
        private = list(
            .init = function() {
                overview <- self$results$overview
                overview$scripts <- c("jglance.umd.js")
            },
            .run = function() {
                varNames <- self$options$vars
                if (is.null(varNames) || length(varNames) == 0) {
                    varNames <- names(self$data)
                }

                nRows <- nrow(self$data)
                MAX_LEVELS_DISPLAYED <- 12L

                variables <- lapply(varNames, function(name) {
                    v <- self$data[[name]]
                    if (is.null(v)) {
                        return(NULL)
                    }

                    nMissing <- sum(is.na(v))
                    vClean <- v[!is.na(v)]
                    n <- length(vClean)

                    desc <- attr(v, "jmv-desc")
                    if (!is.null(desc) && nchar(desc) == 0) {
                        desc <- NULL
                    }

                    # ID columns may be flagged in different ways depending on how
                    # the column was marked: jamovi-engine sets `jmv-id = TRUE`,
                    # while files round-tripped through jmvReadWrite expose the
                    # measure type via `jmv-measure-type = 'ID'`.
                    measureType <- attr(v, "jmv-measure-type")
                    isId <- isTRUE(attr(v, "jmv-id")) ||
                        (!is.null(measureType) &&
                            tolower(as.character(measureType)) == "id")

                    if (isId) {
                        # Treat ID columns specially — show count + a sample,
                        # not a distribution. Values may be factor or character.
                        asChar <- as.character(vClean)
                        samples <- head(unique(asChar), 8)
                        list(
                            name = name,
                            description = desc,
                            type = "id",
                            n = n,
                            nMissing = as.integer(nMissing),
                            nUnique = as.integer(length(unique(asChar))),
                            samples = as.list(samples)
                        )
                    } else if (is.factor(v)) {
                        type <- if (is.ordered(v)) "ordinal" else "nominal"
                        tbl <- table(vClean)
                        # Preserve the factor's defined level order
                        # (critical for ordinal, and respects user intent for nominal too).
                        allLevels <- levels(v)
                        nLevels <- length(allLevels)
                        displayedNames <- head(allLevels, MAX_LEVELS_DISPLAYED)
                        levels_list <- lapply(displayedNames, function(lvl) {
                            list(
                                name = lvl,
                                count = as.integer(
                                    if (lvl %in% names(tbl)) tbl[[lvl]] else 0
                                )
                            )
                        })
                        list(
                            name = name,
                            description = desc,
                            type = type,
                            n = n,
                            nMissing = as.integer(nMissing),
                            nLevels = as.integer(nLevels),
                            nTruncated = as.integer(max(
                                0,
                                nLevels - length(displayedNames)
                            )),
                            levels = levels_list
                        )
                    } else if (is.numeric(v)) {
                        if (n < 2) {
                            list(
                                name = name,
                                description = desc,
                                type = "continuous",
                                n = n,
                                nMissing = as.integer(nMissing),
                                min = if (n > 0) min(vClean) else 0,
                                max = if (n > 0) max(vClean) else 0,
                                mean = if (n > 0) mean(vClean) else 0,
                                sd = 0,
                                median = if (n > 0) median(vClean) else 0,
                                histogram = list(
                                    edges = list(),
                                    counts = list()
                                )
                            )
                        } else {
                            h <- hist(vClean, plot = FALSE, breaks = 12)
                            qs <- as.numeric(quantile(
                                vClean,
                                c(0.25, 0.75),
                                na.rm = TRUE
                            ))
                            isInt <- all(abs(vClean - round(vClean)) < 1e-9)
                            nUniq <- length(unique(vClean))
                            list(
                                name = name,
                                description = desc,
                                type = "continuous",
                                n = n,
                                nMissing = as.integer(nMissing),
                                min = min(vClean),
                                max = max(vClean),
                                mean = mean(vClean),
                                sd = sd(vClean),
                                median = median(vClean),
                                q1 = qs[1],
                                q3 = qs[2],
                                integer = isInt,
                                nUnique = as.integer(nUniq),
                                histogram = list(
                                    edges = I(h$breaks),
                                    counts = I(as.integer(h$counts))
                                )
                            )
                        }
                    } else {
                        # text or other — treat as nominal with raw values
                        tbl <- table(as.character(vClean))
                        levels_sorted <- sort(tbl, decreasing = TRUE)
                        nLevels <- length(levels_sorted)
                        displayed <- head(levels_sorted, MAX_LEVELS_DISPLAYED)
                        levels_list <- lapply(
                            seq_along(displayed),
                            function(i) {
                                list(
                                    name = names(displayed)[i],
                                    count = as.integer(displayed[[i]])
                                )
                            }
                        )
                        list(
                            name = name,
                            description = desc,
                            type = "nominal",
                            n = n,
                            nMissing = as.integer(nMissing),
                            nLevels = as.integer(nLevels),
                            nTruncated = as.integer(max(
                                0,
                                nLevels - length(displayed)
                            )),
                            levels = levels_list
                        )
                    }
                })

                variables <- variables[!sapply(variables, is.null)]

                # Pull persisted UI state from options. JS will hydrate from these
                # rather than localStorage (which doesn't survive .omv save/reopen).
                payload <- list(
                    nRows = as.integer(nRows),
                    variables = variables,
                    sortMode = as.character(self$options$sortMode),
                    typeFilter = as.character(self$options$typeFilter),
                    issuesDismissed = isTRUE(self$options$issuesDismissed)
                )

                json <- jsonlite::toJSON(
                    payload,
                    auto_unbox = TRUE,
                    null = "null"
                )
                id <- "jglance-overview-container"

                overview <- self$results$overview
                overview$setContent(paste0(
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
                    if (typeof Jglance === "undefined") {
                        setTimeout(render, 50);
                        return;
                    }
                    var data = ',
                    json,
                    ';
                    var app = Jglance.createOverview("#',
                    id,
                    '", data);
                    /* Once Vue has mounted, show the container. */
                    document.getElementById("',
                    id,
                    '").style.opacity = 1;
                })();
                </script>'
                ))
            }
        )
    )
