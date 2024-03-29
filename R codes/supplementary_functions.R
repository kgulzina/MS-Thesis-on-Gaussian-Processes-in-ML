######### Complementary/supplementary fuctions #########
## Author: stat_cat
## Date: 01/03/19

calc_Sigma <- function(n, rho){ 
# Calculates the covariance matrix of AR(1) process
#  
# Args:
#   n:   vector(sample) size (integer)
#   rho: fixed correlation value (|real|<=1)
#
# Output:
#   Sigma: symmetric covariance matrix
    
    Sigma <- matrix(NA, nrow = n, ncol = n)
    for(i in 1:n){
        for(j in 1:n){
            Sigma[i,j] <- rho^abs(i-j)
        }
    }
    return(Sigma)
}




calc_corr_deterministic <- function(X, t, n) { 
# Calculate covariances between simulated X's using correlation form used in 
# the GP model assumptions: deterministic w(t)
#
# Args: 
#   X: simulated, in a vector form
#   t: time(T) or length(X) - 1
#   n: sample size
#
# Output:
#   omega: correlation matrix of size n 
    
    omega <- matrix(NA, nrow = n, ncol = n)
    time <- 0:t
    for(i in 1:n) {
        for(j in 1:n) {
            omega[i,j] <- exp(-sum(((t-time+1)/(t+1))*(X[i,]-X[j,])^2))
        }
    }
    return(omega)
}




calc_corr_sampled <- function(X, t, n, theta){
# Calculates covariances between simulated X's using correlation form used in 
# the GP model assumptions: sampled w(t) from specific density
#
# Args: 
#   X: simulated, in a vector form
#   t: time(T) or length(X) - 1
#   n: sample size
#   w: simulated weights, in a vector form
#
# Output:
#   omega: correlation matrix of size n    
    
    l <- length(theta)
    omega <- matrix(NA, nrow = n, ncol = n)
    time <- 0:t
    for(i in 1:n) {
        for(j in i:n) {
            omega[i,j] <- exp(-sum(theta[-l]*(X[i,]-X[j,])^2))
            if (i == j) {
                omega[i,j] = omega[i,j] + theta[l]
            } else {
                omega[j,i] <- omega[i,j]
            }
        }
    }
    return(omega)
}




gcalc_corr <- function(d,w) { #retriev x's from d
# Calculates covariances between X's using correlation form used in the GP
# model assumptions: to find MLE of w(t)
#
# Args: 
#   d: data frame, last column is response Y, others are input X's
#   w: weights, in a vector form
#
# Output:
#   omega: correlation matrix of size n
    
    n <- nrow(d)
    omega <- matrix(NA, nrow = n, ncol = n)
    
    for(i in 1:n){
        for(j in i:n){
            omega[i,j] <- exp(-sum(w*(d[i,-ncol(d)]-d[j,-ncol(d)])^2))
            omega[j,i] <- omega[i,j]
        }
    }
    return(omega)
}




gcalc_corr_scalar <- function(d,w) {
    # Calculates covariances between X's using correlation form used in the GP
    # model assumptions: to find MLE of w(t)
    #
    # Args: 
    #   d: data frame, last column is response Y, others are input X's
    #   w: weights, in a vector form
    #
    # Output:
    #   omega: correlation matrix of size n
    
    n <- nrow(d)
    y <- ncol(d)
    omega <- matrix(NA, nrow = n, ncol = n)
    
    for(i in 1:n){
        for(j in i:n){
            omega[i,j] <- exp(-sum(w*(d[i,-y] - d[j,-y])^2))
            omega[j,i] <- omega[i,j]
        }
    }
    return(omega)
}




calc_gradient_num <- function(f,w,d,epsilon=10^-6){
# Calculates the gradient of a function numerically
# 
# Args:
#   f: function (log-likelihood function)
#   d: data frame, last column is response Y, others are input X's
#   w: weights, in a vector form 
#   
# Output:
#   gr: gradients, in a vector form
    
    n <- length(w)
    gr <- numeric(n) 
    for(i in 1:n) {
        h <- rep(0,n); h[i] <- epsilon
        gr[i] <- (f(w+h,d)-
                      f(w,d))/epsilon
    }
    return(gr)
}




simulate_d <- function(t, n, theta){
# Simulates data: both X and Y according to GP model described in 
# "CC-Process" log-file
# 
# Args:
#   t: Time(T) or length(X)-1
#   n: sample size
#   w: weights, in a vector form
#
# Outputs:
# d: data frame, last column is response Y, others are input X's 
    
    sigma <- calc_Sigma(t+1, rho = 0.99)
    
    # simulate X's
    x_values <- mvrnorm(n, rep(0, t+1), sigma)
    
    # calculate omega for Y
    omega <- calc_corr_sampled(x_values, t, n, theta)
    
    # simulate Y's
    y <- rmvnorm(1, mean = rep(0, n), sigma = omega)
    
    # combine datasets: functional input and scale output
    d <- cbind(x_values,t(y))
    
    return(d)
}




simulate_trunc_d <- function(t, n, w){
# Simulates data: both X and Y according to GP model described in 
# "CC-Process" log-file
# 
# Args:
#   t: Time(T) or length(X)-1
#   n: sample size
#   w: weights, in a vector form
#
# Outputs:
# d: data frame, last column is response Y, others are input X's 
    
    sigma <- calc_Sigma(t+1, rho = 0.99)
    
    # simulate X's (leaving X's as it is)
    x_values <- mvrnorm(n, rep(0, t+1), sigma)
    
    #calculate omega for Y
    omega <- calc_corr_sampled(x_values, t, n, w)
    
    # simulate Y's
    theta <- rmvnorm(1, mean = rep(0, n), sigma = omega)

    # add minumum positive theta to all theta
    theta <- theta + min(theta[theta > 0])

    # exponentiate theta's
    y <- exp(theta)
    
    # combine datasets: functional input and scale output
    d <- cbind(x_values,t(y))
    
    return(d)
}




simulate_w_mvn <- function(t){
# Simulates weights from MVN ~ (GP), according to assumption in 
# CC-Process - 1c
#
# Args:
#   t: Time(T) or length(X)-1
#
# Output:
#   w: weights, in a vector form
    
    sigma <- 1/(0.36)*calc_Sigma(t+1, 0.99)
    # sigma depends on t, so not constant
    w <- mvrnorm(1, rep(0, t+1), sigma)
    return(w)
}




simulate_trunc_w <- function(t){
# Simulates weights from truncated (positive) MVN ~ (GP), according to 
# the assumptions in CC-Process - 1c
#    
# Args:
#   t: Time(T) or length(X)-1
#
# Output:
#   w: weights, in a vector form
    
    sigma <- 1/(0.36)*calc_Sigma(t+1, 0.99)
    # sigma depends on t, so not constant
    w <- rtmvnorm(1, rep(0, t+1), sigma, lower = rep(0, t+1), 
                  upper = rep(Inf, t+1), algorithm = "gibbs")
    return(w)
}




simulate_log_w_stan <- function(t){ ## this function does not work right know
# Simulates log(weights) from transformed MVN ~ (GP) given in CC-Process 1c  
# and returns transformed result
#    
# Args: 
#   t: Time(T) or length(X)-1
#
# Output:
#   w: weights, in a vector form
    
    # define the density
    sigma <- 1/(0.36)*calc_Sigma(t+1, 0.99)
    dens <- function(theta){
        # theta is a vector of length T
        result <- (2*pi)^(-(t+1)/2)*(det(sigma))^(-1/2)*exp(sum(theta))*
            exp(-1/2*theta%*%solve(sigma)%*%t(theta))
        return(result) ### need a scalar, not vector
    }
    
    require(mcmc)
    out <- metrop(dens, sigma, 1e+3)
    return(out$batch)
}




simulate_log_w <- function(t){
# Simulates log(weights) from  MVN(-2, Pi) given in CC-Process 1c and  
# returns transformed result
#    
# Args: 
#   t: Time(T) or length(X)-1
#
# Output:
#   w: weights, in a vector form
    
    sigma <- 1/(0.36)*calc_Sigma(t+1, 0.99)
    # sigma depends on t, so not constant
    theta <- mvrnorm(1, rep(-3, t+1), sigma)
    w <- exp(theta)
    return(w)
}





estimate_w <- function(opt_f, grad, pars, d, maxit){ 
# Estimates w using eBayes approach, i.e finds MLE estimates of w.
#    
# Args:   
#   opt_f: likelihood function to be optimized
#   grad:  gradient of opt_f
#   pars:  initial values for w
#   d:     data frame, last column is response Y, others are input X's
#   maxit: maximum number of iterations
#
# Output: 
#   opt:   results of optim() 
    
    opt <- optim(par = pars, opt_f, d = d, control = list(fnscale = -1,
                                                          maxit=maxit),
                 gr = grad) 
    
    # print true values of w
    print("True values of theta")
    print(theta)
    
    # estimated w
    return(opt)
}





generate_pars_by_range <- function(t, d, opt_f, grad, maxit) {
# This function will generate initial values. Another papir of initial values # are sampled from AR(1), divided into quiantiles of 30 percents. New initial 
# values are estimated using MLE method, and the new values are the target
# initial values.
#
# Args:
#   t:     Time(T) or length(X)-1
#   d:     data frame, last column is response Y, others are input X's
#   opt_f: likelihood function to be optimized
#   grad:  gradient of opt_f
#   maxit: maximum number of iterations            
#
# Output:
#   pars: initial values, in a vector form

    # simulate pre-initial values
    pars <- simulate_log_w(t)

    # get legth of the range
    range <- (t+1) %/% 3

    # declare target initial values
    result <- c()
    k = 1

    for (i in 1:3) {
        if (i == 3) {
            result[k:(t+1)] = estimate_w(opt_f, grad, pars[k:(t+1)], 
            d[,c(k:(t+1), t+2)], maxit)$par
        } else {
            result[k:(i*range)] = estimate_w(opt_f, grad, pars[k:(i*range)], 
            d[,c(k:(i*range), t+2)], maxit)$par
        } 
        k <- k + range 
    }

    return(result)
}




tempering_loglkl_mvn_penalty <- function(w,d) {
# Calculates the log-likelihood function with penalty. One can use both methods
# of gradient: true one and the one calculated numerically
#
# Args:
#   w:      weights, in a vector form    
#   d:      data frame, last column is response Y, others are input X's
# 
# Output:
#   result: numeric log-likelihood
 
    time <- ncol(d)-2
    # calculate the covariance matrix for yw
    omega <- gcalc_corr(d,w)
    
    # calculate the convariance matrix for w
    sigma <- 1/(0.36)*calc_Sigma(time+1, 0.99)
    
    # data model: log_likelihood 
    p_yw <- dmvnorm(d[,ncol(d)], mean = rep(0, nrow(d)), sigma = omega, log = TRUE)  
    
    # prior on w: log_likelihood
    p_w <- dmvnorm(w, mean = rep(0, time+1), sigma = sigma , log = TRUE)
    
    # the posterior which will be maximized
    result <- p_yw + p_w 
    
    return(k*result)
}




tempering_gradient_loglkl_penalty <- function(w, d){
    # Calculates the gradient of f: log-likelihood with penalty w.r.t w
    #
    # Args: 
    #   w: weights, in a vector form
    #   d: data frame, last column is response Y, others are input X's
    #
    # Output:
    #   gr: gradients, in a vector form
    
    n <- length(w)
    gr <- numeric(n)
    
    # omega
    omega <- calc_corr_sampled(d[,-(n+1)], n-1, nrow(d), w)
    
    # inverse of omega
    inv_omega <- solve(omega)
    
    # inverse of pi
    inv_pi <- solve(1/(0.36)*calc_Sigma(n, 0.99))
    
    for(i in 1:n) {
        dm <- calc_mtrx_deriv(d[,-ncol(d)], n-1, nrow(d), w, i)
        # for penalty term: way 1
        #dpenalty <- 0
        #for (j in 1:n){
        #    temp = -1/2*w[j]*(inv_pi[i,j] + inv_pi[j,i])
        #    dpenalty <- dpenalty + temp
        #}
        
        # for penalty term: way 2
        if (!(i == 1 | i == n)) {
            dpenalty <- -1/2*(w[i-1]*(inv_pi[i-1,i] + inv_pi[i,i-1]) +
                                  2*w[i]*inv_pi[i,i] +
                                  w[i+1]*(inv_pi[i+1,i] + inv_pi[i,i+1]))
        }
        
        else {
            dpenalty <- -w[i]*inv_pi[i,i]
        }
        
        # final gradient
        gr[i] <- -1/2*sum(diag(inv_omega%*%dm)) + 
            1/2*t(d[,n+1])%*%inv_omega%*%dm%*%inv_omega%*%d[,n+1] +
            -1/2*dpenalty
    }
    
    return(k*gr)
    
}




## did not work
estimate_by_tempering_method <- function(k, opt_f, grad, pars, d, maxit) {
# Takes the power of lkl_function, then log. After it calculates the gradient  # and finds estimates according to the new log_likelihood function.
#
# Args:
#   k:     power of log_likelihood
#   d:     observed data
#   opt_f: likelihood function to be optimized
#   grad:  gradient of opt_f
#   maxit: maximum number of iterations
#
# Output:  output of optim()

    opt <- optim(par = pars, k*opt_f, d = d, control = list(fnscale = -1,
                                                          maxit=maxit),
                 k*grad)

    # print true values of w
    print("True values of w")
    print(w)

    return(opt)
}





## have to modify these two, can later add gradient
simulate_w_dlm <- function (theta, s) {
# Simulates weights as a linear combinations of q Fourier s-dimensional
# vectors (trignometric ~ periodic basis vectors of R^s).
# Args:
#   theta:  coefficients of harmonics, in a vector form
#   s:      dimension of weight, Time(T) + 1 or Length(X)
#
# Output:
#   w:      weights, in a vector forn
    
    # get q
    q <- (length(theta) - 1)/2
    
    # generate basis
    basis <- generate_trig_basis(s, q)
    
    # generate logit_w
    logit_w <- theta%*%basis
    
    # get w
    w <- exp(logit_w)/(1+exp(logit_w))
    
    return (w)
}




simulate_coeff_dlm <- function(q) {
# Simulates coefficients for the trigonometric basis of R^s. Uses the
# structure and nature of weights, giving more significance to leading
# harmonics after e_0. For simplicity, we'll use uniform dist for now.
#
# Args:
#   q:      number of harmonics
#
# Output:
#   coeffs: coefficients of harmonics, in a vector form
    
    coeffs <- runif(2*q+1, min = -1, max = 1)
    
    return(coeffs)
} 



generate_freq_w <- function(s, j) {
# Generates Fourier frequencies to be used in basis vectors.
#
# Args:
#   s:      dimension of weight, Time(T) + 1 or Length(X)
#   j:      frequency time
#
# Output:
#   w_j:    frequency at time j
    
    w_j <- 2*pi*j/s
    
    return(w_j)
}




generate_trig_basis <- function(s, q) {
# Generates trigonometric basis -- harmonics. 
#
# Args:
#   s:      dimension of weight, Time(T) + 1 or Length(X)
#   q:      number of harmonics
#
# Output:
#   basis:  harmonics, in a matrix format
    
    # vector of sequence 1:s
    v <- 1:s
    
    # basis with first constant row
    basis <- (rep(1, times = s))
    
    # fill the rest harmonics
    for (j in 1:q) {
        # generate frequencies
        temp <- generate_freq_w(s, j) * v
        basis <- rbind(basis,
                       cos(temp),
                       sin(temp))
    }
    
    return(basis)
}




dynamic_loglkl_mvn_penalty <- function(theta, d) {
#
# Args:
#   theta:
#   d:
#
# Output:
#   result:

    # some constants
    time <- ncol(d)-2
    q <- (length(theta) - 1) / 2
    
    # penalty on w
    basis <- generate_trig_basis(time+1, q)
    logit_w <- theta%*%basis
    
    # get w
    w <- exp(logit_w)/(1+exp(logit_w))
    
    # calculate the covariance matrix for yw
    omega <- gcalc_corr(d,w)
    
    # data model: log_likelihood 
    p_yw <- dmvnorm(d[,ncol(d)], mean = rep(0, nrow(d)), sigma = omega)  
    
    # the posterior which will be maximized
    result <- p_yw

    return(result)
}


dynamic_lkl_mvn_penalty_ridge <- function(theta, d) {
    #
    # Args:
    #   theta:
    #   d:
    #
    # Output:
    #   result:
    
    # some constants
    n <- nrow(d)
    time <- ncol(d)-2
    
    # length of theta parameter
    lambdal <- length(theta)
    
    # q is fixed for both   
    q <- (length(theta) - 2) / 2
    
    # penalty on w
    basis <- generate_trig_basis(time+1, q)
    logit_w <- theta[-lambdal]%*%basis
    
    # get w
    w <- exp(logit_w)/(1+exp(logit_w))
    
    # calculate the covariance matrix for ywv + penalty
    omega <- gcalc_corr(d, w) + diag(theta[lambdal],
                                     ncol = n,
                                     nrow = n)
    
    # data model: log_likelihood 
    p_yw <- dmvnorm(d[,ncol(d)], mean = rep(0, nrow(d)), sigma = omega)  
    
    # the posterior which will be maximized
    result <- p_yw
    
    return(result)
}


# repeat rows
rep_row <- function(x, n) {
    matrix(rep(x, each = n), nrow = n)
}











































