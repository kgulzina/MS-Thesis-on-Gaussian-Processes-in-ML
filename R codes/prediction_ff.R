####### This code plots a GP process with estimated parameters #######
## log is given "README.md" file in github
## Author: stat_cat
## Date: 06/18/19 - present




# Libraries --------------------------------------------------------------
library(dplyr)
library(ggplot2)
library(plotly)
library(lattice)
source("R codes/supplementary_functions.R")




# Real data - Scalar case -------------------------------------------------
d <- read.csv("data/final_csv/annual_soil_loss.csv")
d_ff <- data.frame(type = "wepp",
                   d[,5:384],
                   soil_loss = d[,4])

# choose years 2007 & 2018, and all slope profiles
#slope_profiles <- unique(d[,370:384])
#watersheds <- rep(unique(d$watershed), each = 3)
#hills <- d %>% filter(year == 2007) %>% select(hill)
years <- d[-c(4)] %>% 
    unique() %>% 
    filter( year == 2007 | year == 2018) 

# add 0.000001 to each year
d_ff_emulator <- data.frame(type = "emulated",
                            d[,-4])

# add small difference (no need for now)
#d_ff_emulator[,-c(1:5, 370:384)] <- d_ff_emulator[,-c(1:5, 370:384)]



# MLE estimates -----------------------------------------------------------
# theta = (w_1, w_2, lambda)
theta_mle <- c(-2.192671e+02, -1.956970e+02,  1.769927e+02,
               -1.949151e+02,  1.768619e+02, -7.646077e+01,  4.879767e-04)

# generate only true parameters (weights + lambda) from theta_mle
basis1 <- generate_trig_basis(15, 1)
basis2 <- generate_trig_basis(365, 1)

logit_w_ff <- theta_mle[-c(4:7)]%*%basis1
logit_v_ff <- theta_mle[-c(1:3, 7)]%*%basis2

# get w and v
w_ff <- exp(logit_w_ff)/(1+exp(logit_w_ff))
v_ff <- exp(logit_v_ff)/(1+exp(logit_v_ff))

# new theta
theta_ff <- c(w_ff, v_ff, theta_mle[7])





# Code predictor - last summer --------------------------------------------
# constants
n <- nrow(d_ff)
sigma_ff <- gcalc_corr_scalar(d_ff[,-1], theta_ff[-381]) + 
    diag(x = theta_ff[381], nrow = n, ncol = n)
sigma_ff_inv <- solve(sigma_ff)


# functions
calc_sigma_star <- function(d, xhat, mle) {
    n <- nrow(d)
    y <- ncol(d)
    res <- c()
    for (i in 1:n) {
        res[i] <- exp(-sum(mle[-381]*(d[i,-y] - unlist(xhat))^2))
        # check all vectors if the same
        if (sum(d[i,-y] == unlist(xhat)) == 380) {
            # add nugget
            res[[i]] <- res[[i]] + mle[381]
        }
    }
    return(res)
}



emulate_soil_loss <- function(d, xhat, mle, sigma_ff_inv) {
    # this code emulates soil loss: y*/y >> mean as a prediction
    sigma_star <- calc_sigma_star(d, xhat, mle)
    
    # yhat = sigma_star'sigma^{-1}y
    yhat <- sigma_star%*%sigma_ff_inv%*%d[,381]
    return(yhat)
}


# example
xhat <- d_ff_emulator[1,-c(1:4)]
emulate_soil_loss(d_ff[,-1], xhat, theta_ff, sigma_ff_inv)





# Emulate -----------------------------------------------------------------
## emulator
soil_loss_ff <- c()
nhat <- nrow(d_ff_emulator)
for (i in 1:nhat) {
    soil_loss_ff[i] <- emulate_soil_loss(d_ff[,-1], 
                                      d_ff_emulator[i, -c(1:4)], 
                                      theta_ff,
                                      sigma_ff_inv)
}
soil_loss <- soil_loss_ff
d_ff_emulator <- cbind(d_ff_emulator, soil_loss)

# for back up save the data set
#write.csv(d_ff_emulator, file = "d_ff_emulator.csv")






# Add SE ------------------------------------------------------------------
## write a function to find CI borders
ci_ff <- function(d, xhat, mle, sigma_ff_inv, mean_ff) {
    sigma_star <- calc_sigma_star(d, xhat, mle)
    
    # calculate variance
    var <- 1 + mle[381] - sigma_star%*%sigma_ff_inv%*%sigma_star
    
    # get sample of 1000
    ss <- rnorm(1000, mean = mean_ff, sd = sqrt(var))
    
    # get quantiles
    res <- quantile(ss, probs = c(0.025, 0.975), na.rm = TRUE)
    return(res)
}


# example
ci_ff(d_ff[,-1], d_ff_emulator[1,-c(1:4, 385)], 
      theta_ff, sigma_ff_inv, soil_loss_ff[1] )

## add CI for the whole xgrid
nhat <- nrow(d_ff_emulator)
for (i in 1:nhat) {
    ci <- ci_sf(d_ff[,-1], 
                d_ff_emulator[i, -c(1:4, 385)], 
                theta_ff,
                sigma_ff_inv,
                soil_loss_ff[i])
    d_ff_emulator$q1[i] <- ci[1]
    d_ff_emulator$q2[i] <- ci[2]
}






# Visualization -----------------------------------------------------------
## filter wepp data
wepp_soil_loss <- d %>% dplyr::select(watershed, hill, year, soil_loss) %>% 
    mutate(hillslope = paste(watershed, hill),
              soil_loss = soil_loss,
              year = year,
              type = "wepp")

## wepp: year 2007 & 2018
wepp2007 <- wepp_soil_loss %>% 
    filter(year == 2017) %>% 
    ggplot(aes(x = hillslope, y = soil_loss)) +
    geom_bar(stat = "identity") +
    ggtitle("Annual soil loss distribution in 2007") +
    ylab("soil loss (kg/m^2)") +
    xlab("WEPP") +
    theme_light() +
    coord_flip()
wepp2007

wepp2018 <- wepp_soil_loss %>% 
    filter(year == 2018) %>% 
    ggplot(aes(x = hillslope, y = soil_loss)) +
    geom_bar(stat = "identity") +
    ggtitle("Annual soil loss distribution in 2018") +
    ylab("soil loss (kg/m^2)") +
    xlab("WEPP")
    theme_light() +
    coord_flip()
wepp2018

# filter emulator data
emulator_soil_loss <- d_ff_emulator %>%
    dplyr::select(watershed, hill, year, soil_loss) %>% 
    mutate(hillslope = paste(watershed, hill),
           type = "emulator")

## emulator: year 2007 & 2018
emulator2007 <- emulator_soil_loss %>% 
    filter(year == 2007) %>% 
    ggplot(aes(x = hillslope, y = soil_loss)) +
    geom_bar(stat = "identity") +
    ylab("soil loss (kg/m^2)") + 
    xlab("Emulator") +
    theme_light() +
    coord_flip()
emulator2007

emulator2018 <- emulator_soil_loss %>% 
    filter(year == 2018) %>% 
    ggplot(aes(x = hillslope, y = soil_loss)) +
    geom_bar(stat = "identity") +
    ylab("soil loss (kg/m^2)") +
    xlab("Emulator") +
    theme_light() +
    coord_flip()
emulator2018

# if you want something together (didn't use)
ggarrange(wepp2007, emulator2007, nrow = 2, align = "v")
ggarrange(wepp2018, emulator2018, nrow = 2, align = "v")


# mix the datasets
d_ff_mixed <-rbind(wepp_soil_loss, emulator_soil_loss)

## plot mixed: year 2007
label1 <- wepp_soil_loss %>% filter(year == 2007) %>% dplyr::select(soil_loss) -
    emulator_soil_loss %>% filter(year == 2007) %>% dplyr::select(soil_loss)


d_ff_mixed %>% filter(year == 2007) %>% 
    mutate(label = rep(label1$soil_loss, 2)) %>% 
    ggplot(aes(x = hillslope, y = soil_loss, 
               shape = type, color = type, label = label)) +
    geom_point() +
    ggtitle("Annual soil loss distribution in 2007") +
    ylab("soil loss (kg/m^2)") +
    theme_light() +
    coord_flip() + geom_text(size = 2, hjust = -0.05, col = "black")

# publish
#dev.copy(pdf,'ff_2007.pdf')
#dev.copy2pdf(out.type = "pdf")
#dev.off()

## plot mixed: year 2018
label2 <- wepp_soil_loss %>% filter(year == 2018) %>% dplyr::select(soil_loss) -
    emulator_soil_loss %>% filter(year == 2018) %>% dplyr::select(soil_loss)

d_ff_mixed %>% filter(year == 2018) %>% 
    mutate(label = rep(label2$soil_loss, 2)) %>% 
    ggplot(aes(x = hillslope, y = soil_loss, 
               shape = type, color = type, label = label)) +
    geom_point() +
    ggtitle("Annual soil loss distribution in 2018") +
    ylab("soil loss (kg/m^2)") +
    theme_light() +
    coord_flip() + geom_text(size = 2, hjust = -0.05, col = "black")

# publish
#dev.copy(pdf,'ff_2018.pdf')
#dev.copy2pdf(out.type = "pdf")
dev.copy2pdf(out.type = "pdf")
dev.off()











