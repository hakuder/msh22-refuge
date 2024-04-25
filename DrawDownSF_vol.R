#built off Emma's work with refuge factors script

library(readr)
library(gridExtra)
library(reshape2)
library(gridExtra)
library(purrr)
library(RColorBrewer)
library(lubridate)
library(tidyverse)
#library(insol)
library(grid)
library(forcats)

library(scales)
library(moderndive)
library(ggpubr)
library(corrplot)
library(broom)

#drawdown rate calculation

volume_organized <- read.csv("msh2022_pond_volume_not_sn.csv")

# Get day number for each measurement
volume_organized <- volume_organized %>% mutate(
  day = case_when(
    date == "06/07/2022" ~ 0, 
    date == "06/14/2022" ~ 7,
    date == "06/23/2022" ~ 16,
    date == "06/28/2022" ~ 21,
    date == "07/21/2022" ~ 44))

# Convert date to POSIXct class
volume_organized[['date']] <- as.POSIXct(volume_organized[['date']], 
                                         format = "%m/%d/%Y") 
# Create a depth in meters column
volume_organized <- volume_organized %>% mutate(depth_m = depth_in * 0.0254)
# rename column
volume_organized <- volume_organized %>% dplyr::rename(vol = TIN_volume_metercubed)

# ponds with detailed contours
cont_pond_list <- c("H01", "H52", "H48", "H27", "H25", "H10", "H04", "H09", "H06", "H05", "H02b", "H02a")
# ponds without detailed contours
geo_pond_list <- c("H53", "H12", "H21", "H23", "H24", "H32", "H99", "H55")

# separate dataframe into those ponds that already have volumes for each date (cont)
# and those that still need to be estimated (geo)
cont_volume_df <- volume_organized[volume_organized$pond %in% cont_pond_list,]
geo_volume_df <- volume_organized[volume_organized$pond %in% geo_pond_list,]

cont_volume_df$vol_m <- as.numeric(gsub(",", "", cont_volume_df$vol))
geo_volume_df$vol_m <- as.numeric(gsub(",", "", geo_volume_df$vol))

lapply(cont_volume_df,class)
##########################################################################################
# Read in initial size info
static_df <- read.csv("msh2022_pond_volume_new_static.csv")


static_df$vol_m <- as.numeric(gsub(",", "", static_df$vol_m))
# separate out the initial volumes/depths
geo_static_df <- static_df[static_df$pond %in% geo_pond_list,]
geo_static_df <- geo_static_df[,c("pond","surface_area_m","max_depth_f","max_depth_m")]

#######################################################################################
## Show the volume estimate for the ponds without contours is reasonable using the contour pond data

# Contour 
cont_static_df <- static_df[static_df$pond %in% cont_pond_list,]
cont_static_df <- cont_static_df %>% dplyr::select(pond,vol_m,surface_area_m) %>% dplyr::rename(initial_vol = vol_m)
cont_vol_static <- merge(cont_volume_df,cont_static_df)
cont_test <- merge(cont_static_df,cont_volume_df)
# calculate volume estimates if we assume a 0.7 scaled cylinder shape
cont_test <- cont_test %>% mutate(vol_7_cylinder_dt =(1/0.758)*(depth_m)*surface_area_m)

# Plot geometric estimation vs GIS TIN interpolation estimation
# All of the contour data
ml = lm(vol_7_cylinder_dt~vol_m, data = cont_test) 
rsq <- summary(ml)$r.squared 
rsq
ggplot(cont_test, aes(x = vol_m, y = vol_7_cylinder_dt)) + 
  geom_smooth(method = "lm", se =TRUE)+
  geom_point() + 
  ylab(expression(Scaled~Cylinder~Volume~Estimate~(m^3)))+
  xlab(expression(Contour~Volume~Estimate~(m^3)))+
  labs(tag = expression(R^2==0.907))+
  theme(plot.tag.position = c(.4, .8))

summary(ml)

#######################################################################################

# We now calculate the volume estimates for the geo ponds that do not have the contour GIS data
# Choosing (1/0.758)*vol_cylinder 
geo_static_est_vol_df <-
  geo_static_df %>% mutate(
    vol_7_cylinder = (1/0.758)*surface_area_m * max_depth_m
  )

geo_volume_factors_df <- merge(geo_volume_df,geo_static_est_vol_df)

geo_volume_calc_df <-
  geo_volume_factors_df %>% mutate(vol_7_cylinder_dt = (1 / 0.758) * (max_depth_m -
                                                                        diff_m) * surface_area_m)


geo_volume_clean <-
  geo_volume_calc_df %>% dplyr::select(pond, date, surface_area_m, vol_7_cylinder, vol_7_cylinder_dt) %>% dplyr::rename(vol = vol_7_cylinder_dt, initial_vol = vol_7_cylinder)
cont_volume_clean <-
  cont_vol_static %>% dplyr::select(pond, date, surface_area_m, initial_vol, vol_m) %>% dplyr::rename(vol = vol_m)

# Bind them back together now that we have all the needed info
full_vol <- rbind(geo_volume_clean,cont_volume_clean)

# Generate column with the day number
full_vol <- full_vol %>% mutate(
  day = case_when(
    date == "2022-06-07" ~ 0, 
    date == "2022-06-14" ~ 7,
    date == "2022-06-23" ~ 16,
    date == "2022-06-28" ~ 21,
    date == "2022-07-21" ~ 44))

# Plot the drawdown
ggplot(full_vol, aes(x=day, y=vol))+
  geom_point()+
  geom_smooth(method = 'lm', formula = y~x, se=F)+
  facet_wrap(~pond)+
  stat_regline_equation(
    mapping = NULL,
    data = NULL,
    formula = y ~ x,
    label.x.npc = "left",
    label.y.npc = "bottom",
    label.x = NULL,
    label.y = NULL,
    output.type = "expression",
    geom = "text",
    position = "identity",
    na.rm = FALSE,
    show.legend = NA,
    inherit.aes = TRUE
  )

# Fit a linear model for each group and extract the slopes and yints
modsum_vol <- full_vol %>%
  dplyr::group_by(pond,surface_area_m,initial_vol) %>%
  dplyr::do(model = lm(vol ~ day, data = .)) %>%
  dplyr::summarize(pond=pond, surface_area_m=surface_area_m,initial_vol=initial_vol,slope = coef(model)[[2]],yint=coef(model)[[1]]) %>%
  dplyr::mutate(perDD= (-100*slope*44)/yint) #adds the percent of depth lost during the study period

# Write out, then read into 2022_pond_factors_submit.Rmd

write.csv(modsum_vol,file="volume_drawdown.csv",row.names = FALSE)


