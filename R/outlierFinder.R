#' Identifies outliers in a similarity matrix.
#' 
#' By default uses the Fisher z-transform for Pearson correlation (atanh), and
#' identifies outliers as those above the quantile of a skew-t distribution
#' with mean and standard deviation estimated from the z-transformed matrix.
#' The quantile is calculated from the Bonferroni-corrected cumulative
#' probability of the upper tail.
#' 
#' 
#' @param similarity.mat A matrix of similarities - larger values mean more
#' similar.
#' @param bonf.prob Bonferroni-corrected probability.  A raw.prob is calculated
#' by dividing this by the number of non-missing values in similarity.mat, and
#' the rejection threshold is qnorm(1-raw.prob, mean, sd) where mean and sd are
#' estimated from the transFun-transformed similarity.mat.
#' @param transFun A function applied to the numeric values of similarity.mat,
#' that should result in normally-distributed values.
#' @param normal.upper.thresh Instead of specifying bonf.prob and transFun, an
#' upper similarity threshold can be set, and values above this will be
#' considered likely duplicates.  If specified, this over-rides bonf.prob.
#' @param tail "upper" to look for samples with very high similarity values,
#' "lower" to look for very low values, or "both" to look for both.
#' @return Returns either NULL or a dataframe with three columns: sample1,
#' sample2, and similarity.
#' @author Levi Waldron, Markus Riester, Marcel Ramos
#' @examples
#' 
#' library(curatedOvarianData)
#' data(GSE32063_eset)
#' cormat <- cor(exprs(GSE32063_eset))
#' outlierFinder(cormat, bonf.prob = 0.05)
#' 
#' @export outlierFinder
outlierFinder <-
  function ###Identifies outliers in a similarity matrix.
### By default uses the
### Fisher z-transform for Pearson correlation (atanh), and
### identifies outliers as those above the quantile of a skew-t
### distribution with mean and standard deviation estimated from the
### z-transformed matrix.  The quantile is calculated from the
### Bonferroni-corrected cumulative probability of the upper tail.
(
  similarity.mat,
  ### A matrix of similarities - larger values mean more similar.
  bonf.prob = 0.05,
  ### Bonferroni-corrected probability.  A raw.prob is calculated by
  ### dividing this by the number of non-missing values in
  ### similarity.mat, and the rejection threshold is qnorm(1-raw.prob,
  ### mean, sd) where mean and sd are estimated from the
  ### transFun-transformed similarity.mat.
  transFun = atanh,
  ### A function applied to the numeric values of similarity.mat, that
  ### should result in normally-distributed values.
  normal.upper.thresh = NULL,
  ### Instead of specifying bonf.prob and transFun, an upper similarity
  ### threshold can be set, and values above this will be considered
  ### likely duplicates.  If specified, this over-rides bonf.prob.
  tail = "upper"
  ### "upper" to look for samples with very high similarity values,
  ### "lower" to look for very low values, or "both" to look for both.
) {
  if (is.null(transFun))
    transFun <- I
  trans.mat <- transFun(similarity.mat)
  if (!is.null(normal.upper.thresh))
    bonf.prob <- NULL
  if (!is.null(bonf.prob)) {
    znum <- na.omit(as.numeric(trans.mat))
    raw.prob <- bonf.prob / length(znum)
    ##        stfit <- st.mle(y=znum)
    stfit <- st.mle(y = znum[is.finite(znum)])
    if (identical(tail, "upper")) {
      z.cutoff <-
        qst(
          p = 1 - raw.prob,
          location = stfit$dp["location"],
          scale = stfit$dp["scale"],
          shape = stfit$dp["shape"],
          df = stfit$dp["df"]
        )
      outlier.mat <- trans.mat > z.cutoff
    } else if (identical(tail, "lower")) {
      z.cutoff <-
        qst(
          p = raw.prob,
          location = stfit$dp["location"],
          scale = stfit$dp["scale"],
          shape = stfit$dp["shape"],
          df = stfit$dp["df"]
        )
      outlier.mat <- trans.mat < z.cutoff
    } else if (identical(tail, "both")) {
      z.cutoff <-
        qst(
          p = c(raw.prob, 1 - raw.prob),
          location = stfit$dp["location"],
          scale = stfit$dp["scale"],
          shape = stfit$dp["shape"],
          df = stfit$dp["df"]
        )
      outlier.mat <-
        (trans.mat < z.cutoff[1]) | (trans.mat > z.cutoff[2])
    } else{
      stop("tail argument should be upper, lower, or both.")
    }
  } else if (!is.null(normal.upper.thresh)) {
    outlier.mat <- trans.mat > normal.upper.thresh
    stfit <- NULL
  } else{
    return(NULL)
  }
  output <-
    .outer2df(
      rownames(outlier.mat),
      colnames(outlier.mat),
      bidirectional = TRUE,
      diag = TRUE
    )
  output$similarity <-
    .outer2df(similarity.mat, bidirectional = TRUE, diag = TRUE)
  output$doppel <-
    .outer2df(outlier.mat, bidirectional = TRUE, diag = TRUE)
  output <- output[!is.na(output$similarity), ]
  output <- output[output[, 1] != output[, 2], ]
  colnames(output)[1:2] <- c("sample1", "sample2")
  return(list(outlierFinder.res = output, stfit = stfit))
  ### Returns either NULL or a dataframe with three columns: sample1, sample2, and similarity.
}
