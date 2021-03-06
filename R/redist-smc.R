#####################################################
# Author: Cory McCartan
# Institution: Harvard University
# Date Created: 2020/07/08
# Purpose: R wrapper to run SMC redistricting code
####################################################

#' SMC Redistricting Sampler
#'
#' \code{redist.smc} uses a Sequential Monte Carlo algorithm to
#' generate nearly independent congressional or legislative redistricting
#' plans according to contiguity, population, compactness, and administrative
#' boundary constraints.
#'
#' This function draws nearly-independent samples from a specific target measure,
#' controlled by the \code{popcons}, \code{compactness}, \code{constraints}, and
#' \code{constraint_fn} parameters.
#'
#' Higher values of \code{compactness} sample more compact districts;
#' setting this parameter to 1 is computationally efficient and generates nicely
#' compact districts.  Values of other than 1 may lead to highly variable
#' importance sampling weights.  By default these weights are truncated at
#' \code{nsims^0.04 / 100} to stabilize the resulting estimates, but if truncation
#' is used, a specific truncation function should probably be chosen by the user.
#'
#' The \code{constraints} parameter allows the user to apply several common
#' redistricting contraints without implementing them by hand. This parameter
#' is a list, which may contain any of the following named entries:
#' * \code{status_quo}: a list with two entries:
#'   * \code{strength}, a number controlling the tendency of the generated districts
#'   to respect the status quo, with higher values preferring more similar
#'   districts.
#'   * \code{current}, a vector containing district assignments for
#'   the current map.
#' * \code{vra}: a list with five entries:
#'   * \code{strength}, a number controlling the strength of the Voting Rights Act
#'   (VRA) constraint, with higher values prioritizing majority-minority districts
#'   over other considerations.
#'   * \code{tgt_vra_min}, the target percentage of minority voters in minority
#'   copportunity districts. Defaults to 0.55.
#'   * \code{tgt_vra_other} The target percentage of minority voters in other
#'   districts. Defaults to 0.25, but should be set to reflect the total minority
#'   population in the state.
#'   * \code{pow_vra}, which controls the allowed deviation from the target
#'   minority percentage; higher values are more tolerant. Defaults to 1.5
#'   * \code{min_pop}, A vector containing the minority population of each
#'   geographic unit.
#' * \code{incumbency}: a list with two entries:
#'   * \code{strength}, a number controlling the tendency of the generated districts
#'   to avoid pairing up incumbents.
#'   * \code{incumbents}, a vector of precinct indices, one for each incumbent's
#'   home address.
#'
#'
#' @param adjobj An adjacency matrix, list, or object of class
#' "SpatialPolygonsDataFrame."
#' @param popvec A vector containing the populations of each geographic unit.
#' @param nsims The number of samples to draw.
#' @param ndists The number of districts in each redistricting plan.
#' @param counties A vector containing county (or other administrative or
#' geographic unit) labels for each unit, which must  be integers ranging from 1
#' to the number of counties.  If provided, the algorithm will only generate
#' maps which split up to \code{ndists-1} counties.  If no county-split
#' constraint is desired, this parameter should be left blank.
#' @param popcons The desired population constraint.  All sampled districts
#' will have a deviation from the target district size no more than this value
#' in percentage terms, i.e., \code{popcons=0.01} will ensure districts have
#' populations within 1% of the target population.
#' @param compactness Controls the compactness of the generated districts, with
#' higher values preferring more compact districts. Must be nonnegative. See the
#' 'Details' section for more information, and computational considerations.
#' @param constraints A list containing information on constraints to implement.
#' See the 'Details' section for more information.
#' @param resample Whether to perform a final resampling step so that the
#' generated plans can be used immediately.  Set this to \code{FALSE} to perform
#' direct importance sampling estimates, or to adjust the weights manually.
#' @param constraint_fn A function which takes in a matrix where each column is
#'  a redistricting plan and outputs a vector of log-weights, which will be
#'  added the the final weights.
#' @param adapt_k_thresh The threshold value used in the heuristic to select a
#' value \code{k_i} for each splitting iteration. Set to 0.9999 or 1 if
#' the algorithm does not appear to be sampling from the target distribution.
#' Must be between 0 and 1.
#' @param seq_alpha The amount to adjust the weights by at each resampling step;
#' higher values prefer exploitation, while lower values prefer exploration.
#' Must be between 0 and 1.
#' @param truncate Whether to truncate the importance sampling weights at the
#' final step by \code{trunc_fn}.  Recommended if \code{compactness} is not 1.
#' @param trunc_fn A function which takes in a vector of weights and returns
#' a truncated vector. Recommended to specify this manually if truncating weights.
#' @param verbose Whether to print out intermediate information while sampling.
#'   Recommended.
#' @param silent Whether to supress all diagnostic information.
#'
#' @return \code{redist.smc} returns an object of class \code{redist}, which
#' is a list containing the following components:
#' \item{aList}{The adjacency list used to sample}
#' \item{cdvec}{The matrix of sampled plans. Each row is a geographical unit,
#' and each column is a sample.}
#' \item{wgt}{The importance sampling weights, normalized to sum to 1.}
#' \item{orig_wgt}{The importance sampling weights before resampling or truncation, normalized to have mean 1.}
#' \item{nsims}{The number of plans sampled.}
#' \item{pct_dist_parity}{The population constraint.}
#' \item{compactness}{The compactness constraint.}
#' \item{counties}{The computed constraint options list (see above).}
#' \item{maxdev}{The maximum population deviation of each sample.}
#' \item{popvec}{The provided vector of unit populations.}
#' \item{counties}{The provided county vector.}
#' \item{adapt_k_thresh}{The provided control parameter.}
#' \item{seq_alpha}{The provided control vector.}
#' \item{algorithm}{The algorithm used, here \code{"smc"}.}
#'
#' @references
#' McCartan, C., & Imai, K. (2020). Sequential Monte Carlo for Sampling Balanced and Compact Redistricting Plans.
#' Available at \url{https://imai.fas.harvard.edu/research/files/SMCredist.pdf}.
#'
#' @examples \dontrun{
#' data(algdat.p10)
#' sampled_basic = redist.smc(algdat.p10$adjlist, algdat.p10$precinct.data$pop,
#'                            nsims=10000, ndists=3, popcons=0.1)
#'
#' sampled_constr = redist.smc(algdat.p10$adjlist, algdat.p10$precinct.data$pop,
#'                             nsims=10000, ndists=3, popcons=0.1,
#'                             constraints=list(
#'                                 status_quo = list(strength=10, current=algdat.p10$cdmat[,1234]),
#'                                 incumbency = lsit(strength=1000, incumbents=c(3, 6, 25))
#'                             ))
#' }
#'
#' @md
#' @importFrom stats qnorm
#' @export
redist.smc = function(adjobj, popvec, nsims, ndists, counties=NULL,
                      popcons=0.01, compactness=1,
                      constraints=list(),
                      resample=TRUE,
                      constraint_fn=function(m) rep(0, ncol(m)),
                      adapt_k_thresh=0.95, seq_alpha=0.1+0.2*compactness,
                      truncate=(compactness != 1),
                      trunc_fn=function(x) pmin(x, 0.01*nsims^0.4),
                      verbose=TRUE, silent=FALSE) {
    V = length(popvec)

    if (missing(adjobj)) stop("Please supply adjacency matrix or list")
    if (missing(popvec)) stop("Please supply vector of geographic unit populations")
    if (missing(nsims)) stop("Please supply number of simulations to run algorithm")
    if (popcons <= 0) stop("Population constraint must be positive")
    if (compactness < 0) stop("Compactness parameter must be non-negative")
    if (adapt_k_thresh < 0 | adapt_k_thresh > 1)
        stop("`adapt_k_thresh` parameter must lie in [0, 1].")
    if (seq_alpha <= 0 | seq_alpha > 1)
        stop("`seq_alpha` parameter must lie in (0, 1].")
    if (nsims < 1)
        stop("`nsims` must be positive.")

    if (is.null(counties)) counties = rep(1, V)
    if (length(unique(counties)) != max(counties))
        stop("County numbers must run from 1 to n_county with no interruptions.")

    # Other constraints
    if (is.null(constraints$status_quo))
        constraints$status_quo = list(strength=0, current=rep(1, length(popvec)))
    if (is.null(constraints$vra))
        constraints$vra = list(strength=0, tgt_vra_min=0.55, tgt_vra_other=0.25,
                               pow_vra=1.5, min_pop=rep(0, length(popvec)))
    if (is.null(constraints$incumbency))
        constraints$incumbency = list(strength=0, incumbents=integer())

    if (length(constraints$vra$min_pop) != length(popvec))
        stop("Length of minority population vector must match the number of units.")
    if (min(constraints$status_quo$current) == 0)
        constraints$status_quo$current = constraints$status_quo$current + 1
    n_current = max(constraints$status_quo$current)

    # sanity-check everything
    preproc = redist.preproc(adjobj, popvec, rep(0, V), ndists, popcons,
                             temper="none", constraint="none")
    adjlist = preproc$data$adjlist
    class(adjlist) = "list"

    verbosity = 1
    if (verbose) verbosity = 3
    if (silent) verbosity = 0

    lp = rep(0, nsims)
    maps = smc_plans(nsims, adjlist, counties, popvec, ndists, popcons, compactness,
                     constraints$status_quo$strength, constraints$status_quo$current, n_current,
                     constraints$vra$strength, constraints$vra$tgt_vra_min,
                     constraints$vra$tgt_vra_other, constraints$vra$pow_vra, constraints$vra$min_pop,
                     constraints$incumbency$strength, constraints$incumbency$incumbents,
                     lp, adapt_k_thresh, seq_alpha, verbosity);

    dev = max_dev(maps, popvec, ndists)
    maps = maps

    lr = -lp + constraint_fn(maps)
    wgt = exp(lr - mean(lr))
    wgt = wgt / mean(wgt)
    orig_wgt = wgt 
    if (truncate)
        wgt = trunc_fn(wgt)
    wgt = wgt/sum(wgt)
    n_eff = length(wgt) * mean(wgt)^2 / mean(wgt^2)

    if (n_eff/nsims <= 0.05)
        warning("Less than 5% efficiency. Consider weakening constraints and/or adjusting `seq_alpha`.")

    if (resample) {
        maps = maps[, sample(nsims, nsims, replace=T, prob=wgt)]
        wgt = rep(1/nsims, nsims)
    }

    algout = list(
        aList = adjlist,
        cdvec = maps,
        wgt = wgt,
        orig_wgt = orig_wgt,
        nsims = nsims,
        n_eff = n_eff,
        pct_dist_parity = popcons,
        compactness = compactness,
        constraints = constraints,
        maxdev = dev,
        popvec = popvec,
        counties = if (max(counties)==1) NULL else counties,
        adapt_k_thresh = adapt_k_thresh,
        seq_alpha = seq_alpha,
        algorithm="smc"
    )
    class(algout) = "redist"

    algout
}

#' Confidence Intervals for Importance Sampling Estimates
#'
#' Builds a confidence interval for a quantity of interest,
#' given importance sampling weights.
#'
#' @param x A numeric vector containing the quantity of interest
#' @param wgt A numeric vector containing the nonnegative importance weights.
#'   Will be normalized automatically.
#' @param conf The confidence level for the interval.
#'
#' @returns A two-element vector of the form [lower, upper] containing
#' the importance sampling confidence interval.
#'
#' @export
redist.smc_is_ci = function(x, wgt, conf=0.99) {
    wgt = wgt / sum(wgt)
    mu = sum(x*wgt)
    sig = sqrt(sum((x - mu)^2 * wgt^2))
    mu + qnorm(c((1-conf)/2, 1-(1-conf)/2))*sig
}
