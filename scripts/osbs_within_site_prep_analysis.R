# Title:        osbs Within Site Analysis
# Site:         osbs Forest
# Data Sources: 
# Authors:      Phoebe Zarnetske, Cameo Arnold, Huijie Wei
# Date:         20 Aug 2018

#Close graphics devices
graphics.off()

# Set working directory
setwd("~/Documents/NEON_LTER_2018")
# Google drive directory: "NEON_LTER_2018/data/raw_data/neon"

#Install/load packages
for (package in c("lme4", "plyr", "dplyr", "purrr", "raster", "reshape2", "lubridate", "ggplot2")) {
  if (!require(package, character.only=T, quietly=T)) {
    install.packages(package)
    library(package, character.only=T)
  }
}

# This code for ggplot2 sets the theme to mostly black and white 
# (Arial font, and large font, base size=24)
theme_set(theme_bw(12))
theme_update(axis.text.x = element_text(size = 10, angle = 90),
             axis.text.y = element_text(size = 10))

# ----------------------------------------
# Load all organismal richness and within-site neon plot-level disturbance data 
# ----------------------------------------

# Read in plot-level richness data from each taxon
# The raw data were all pulled on 20 June 2018; github/NEON-biodiversity/neonbiodiversity/code/neon_organism_api_export.R 
#disturbance distance
dist<-read.csv(("neon_plotid_dist2disturbance_osbs.csv"), stringsAsFactors = FALSE)

#organismal data
mammals <- read.csv("./richness/mammal_richness_cumulative_plot.csv")
plants<- read.csv("./richness/plant_richness_cumulative_plot.csv")
birds<- read.csv( "./richness/bird_richness_cumulative_plot.csv")
#beetles<- read.csv(file.path(data_path, "./richness/beetles_richness_cumulative_plot.csv"))
#macroinvert<- read.csv(file.path(data_path, "./richness/macroinvert_richness_cumulative_plot.csv"))
#mosq<- read.csv(file.path(data_path, "./richness/mosq_richness_cumulative_plot.csv"))
#phytop<- read.csv(file.path(data_path,./richness/phytop_richness_cumulative_plot.csv"))
#trees<- read.csv(file.path(data_path,"./richness/tree_richness_cumulative_plot.csv"))
#zoop<- read.csv(file.path(data_path,"./richness/zoop_richness_cumulative_plot.csv"))
#Check files

head(mammals)
head(birds)
head(plants)
#head(beetles)
#head(macroinvert)
#head(mosq)
#head(phytop)
#head(trees)
#head(zoop)

# add a column for taxa
mammals$taxa<-"mammal"
plants$taxa<-"plant"
birds$taxa<-"bird"
#beetles$taxa<-"beetle"
#macroinvert$taxa<-"macroinvertebrates"
#mosq$taxa<-"mosquito"
#phytop$taxa<-"phytoplankton"
#trees$taxa<-"tree"
#zoop$taxa<-"zooplankton"

# do this for each taxonomic group
head(mammals)
head(birds)
head(plants)
#head(beetles)
#head(macroinvert)
#head(mosq)
#head(phytop)
#head(trees)
#head(zoop)

# merge all taxonomic data together; before you do this, make sure there is a column for taxa.
rich<-rbind(birds, plants,mammals)

#subset data for OSBS
unique(rich$siteID)
#use for adding OSBS data
osbs_rich<-rich[rich$siteID=="OSBS",]
head(osbs_rich)
str(osbs_rich)

#Take the maximum richness value before merging with distance data
names(osbs_rich)
osbs_rich_max<-osbs_rich%>%
  group_by(plotID, taxa) %>%
  slice(which.max(richness))
head(osbs_rich_max)
osbs_rich_max<-data.frame(osbs_rich_max)
unique(osbs_rich_max$plotID)
write.csv(osbs_rich_max, file="richness_max_osbs.csv")
#some plotIDs are NA for richness because they have not been surveyed yet.

#subset
keep=c("siteID", "plotID", "richness", "taxa")
osbs_rich_max<-osbs_rich_max[,keep]
head(osbs_rich_max)

#merge with distance data
dist_rich<- merge(dist, osbs_rich_max, by=c("siteID","plotID"),all.x=T)
head(dist_rich)
names(dist_rich)
#----------------------------------------------------------
# Convert distance file to wide format for modeling
#----------------------------------------------------------
# Wide format for disturbance
dist_rich1<-reshape(dist_rich, v.names="distance_m",    # the values you want to transpose to wide format
                    idvar=c("siteID","plotID", "richness", "taxa"),  # your independent variable(s); careful because if you keep the other columns in your dataset, it may be confusing how the other columns relate to these new columns
                    timevar="dist_type",  # the name of the grouping variable.
                    direction="wide") # the direction (can also be long)
str(dist_rich1)
head(dist_rich1)

write.csv(dist_rich1, file="~/Documents/NEON_LTER_2018/dist_rich.csv", row.names=F)

## add the fire frequency and the burn times data
library(rgdal)
firelog<-readOGR(dsn = "./osbs_points/01osbs_points.shp")
names(firelog)

#subset elevation, slope, aspect, and landcover fire frequency and last burn terrestrial data
myvars_fire <- c("elevatn", "siteID", "plotID", "nlcdCls", "slpGrdn", "slpAspc","Freq")
env_fire <- firelog[myvars_fire]
head(env_fire)
str(env_fire)

write.csv(env_fire,file = "osbs_fire_data.csv",row.names = F)

#Currently, it is in latitude and longitude, but in order to measure distance in meters we need to reproject the data into UTMs. You should look up the appropriate zone for your site. For osbs we needed UTM Zone 17. 
env_fire_ter<-spTransform(env_fire, CRS("+proj=utm +zone=17 ellps=WGS84"))
str(env_fire_ter)
env_fire_ter<-data.frame(env_fire_ter)

#We need to make sure we have one value for slope and elevation before proceeding. This shows the duplicate entries by plotID
env_fire_ter[duplicated(env_fire_ter$plotID),]

#Take the average of slp, asp, and elev by plotID.
attach(env_fire_ter)
env_fire_ter<-aggregate(env_fire_ter[c("elevatn","slpAspc","slpGrdn","Freq")],list(plotID=plotID, nlcdCls=nlcdCls),FUN=mean)
detach(env_fire_ter)
head(env_fire_ter)

#Check it
env_fire_ter[duplicated(env_fire_ter$plotID),]

## merge the fire data and richnessdata
head(dist_rich1)
head(env_fire)
# dist_rich2<-merge(dist_rich1,env_fire,by=c("plotID", "nlcdCls", "elevatn", "slpAspc", "slpGrdn"),all=T)
dist_rich2<-left_join(dist_rich1, env_fire@data, by=c("plotID", "nlcdCls", "elevatn", "slpAspc", "slpGrdn"))
head(dist_rich2)

write.csv(dist_rich2,file = "dist_rich_fire_data.csv",row.names = F)


# ------------------------------------------------------------
# Now we are going to look at elevation with species richness
# ------------------------------------------------------------

library(rgdal)

#elevation subset from all NEON spatial data
terrestrial<- readOGR(dsn="./All_NEON_TOS_Plots_V4/All_NEON_TOS_Centroid_V4.shp")
plot(terrestrial, col=cm.colors(5), alpha=1, legend=F, main="Terrestrial Data")
head(terrestrial)

#To subset the data specifically to your site. You must use the exact name as it is written in the data. To look this up, use the following function to list all of the names of the field sites.
unique(terrestrial$siteNam)

#subset osbs
osbs_ter<-terrestrial[terrestrial$siteNam=="Ordway-Swisher Biological Station",]
summary(osbs_ter)
names(osbs_ter)
plot(osbs_ter)

#subset elevation, slope, aspect, and landcover from NEON terrestrial data
myvars <- c("elevatn", "siteID", "plotID", "nlcdCls", "slpGrdn", "slpAspc")
env <- osbs_ter[myvars]
head(env)
str(env)

#Currently, it is in latitude and longitude, but in order to measure distance in meters we need to reproject the data into UTMs. You should look up the appropriate zone for your site. For osbs we needed UTM Zone 17. 
osbs_ter_env<-spTransform(env, CRS("+proj=utm +zone=17 ellps=WGS84"))
str(osbs_ter_env)
osbs_ter_env<-data.frame(osbs_ter_env)

#We need to make sure we have one value for slope and elevation before proceeding. This shows the duplicate entries by plotID
osbs_ter_env[duplicated(osbs_ter_env$plotID),]

#Take the average of slp, asp, and elev by plotID.
attach(osbs_ter_env)
osbs_ter_env<-aggregate(osbs_ter_env[c("elevatn","slpAspc","slpGrdn")],list(plotID=plotID, nlcdCls=nlcdCls),FUN=mean)
detach(osbs_ter_env)
head(osbs_ter_env)

#Check it
osbs_ter_env[duplicated(osbs_ter_env$plotID),]

write.csv(osbs_ter_env, file="~/Documents/NEON_LTER_2018/osbs_environment.csv", row.names=F)
head(osbs_ter_env)
#writing a csv is necessary to merge the files. It will NOT work without first writing a csv and importing it again. 

#merge dist_rich1 and osbs_ter_env
names(dist_rich2)
names(osbs_ter_env)
osbs<-merge(osbs_ter_env, dist_rich2, by=c("plotID", "nlcdCls", "elevatn", "slpAspc", "slpGrdn"),all=T)
head(osbs)

#Get rid of NAs for plots not sampled yet.
osbs<- subset(osbs,is.na(osbs$richness)==F)
osbs$richness
osbs[is.na(osbs)] <- 0
head(osbs)

#Get rid of unused Factor levels
osbs$nlcdCls <- factor(osbs$nlcdCls)
osbs$nlcdCls
osbs$plotID <- factor(osbs$plotID)
osbs$plotID

#Check for duplicates
osbs[duplicated(osbs$plotID),]

write.csv(osbs,"osbs_disturbance",row.names = F)

#Now that we have a code with all of the environment, richness, and distance data we can start subsetting by taxa.
#-------------------------------------------------------------------------------
#Separate birds and plants richness
#--------------------------------------------------------------------------------
#birds
osbs_bird<-osbs[osbs$taxa=="bird",]
head(osbs_bird)

#plants
osbs_plant<-osbs[osbs$taxa=="plant",]
head(osbs_plant)

#mammals
osbs_mammal<-osbs[osbs$taxa=="mammal",]
head(osbs_mammal)
#################################################################################
# take a look at the relationship between plant richness and elevation
ep <- ggplot(osbs_plant, aes(x=elevatn, y=richness)) +
  geom_point(aes()) 
ep

# log transform for scatter plot
epl <- ggplot(osbs_plant, aes(x=elevatn, y=richness)) +
  geom_point(aes()) + scale_y_log10()  
epl

# take a look at the relationship between bird richness and elevation, by year
er <- ggplot(osbs_bird, aes(x=elevatn, y=richness)) +
  geom_point(aes()) 
er

# log transform for scatter plot
erl <- ggplot(osbs_bird, aes(x=elevatn, y=richness)) +
  geom_point(aes()) + scale_y_log10()  
erl

# take a look at the relationship between mammal richness and elevation, by year
em <- ggplot(osbs_mammal, aes(x=elevatn, y=richness)) +
  geom_point(aes()) 
em

# log transform for scatter plot
eml <- ggplot(osbs_mammal, aes(x=elevatn, y=richness)) +
  geom_point(aes()) + scale_y_log10()  
eml



#################################################################################
#Histograms

hist(osbs_plant$richness)
hist(osbs_bird$richness)
hist(osbs_mammal$richness)

#################################################################################
#log transformations

#plant
osbs_plant$ln.richness<-log(osbs_plant$richness)
head(osbs_plant)
hist(osbs_plant$ln.richness)


#birds
osbs_bird$ln.richness<-log(osbs_bird$richness)
head(osbs_bird)
hist(osbs_bird$ln.richness)

#mammals
osbs_mammal$ln.richness<-log(osbs_mammal$richness)
head(osbs_mammal)
hist(osbs_mammal$ln.richness)

save.image("neon_within_site_prep.RData")
#############################################

#Now you're ready for modeling. 


# This is the first linear model. First is the plant species richness data ~ all your predictor variables.
plant2<-osbs_plant$Freq^2
pm1<-lm(osbs_plant$ln.richness~osbs_plant$distance_m.building+
          osbs_plant$distance_m.roads+
          osbs_plant$nlcdCls+
          osbs_plant$elevatn+
          osbs_plant$Freq+plant2
        # +osbs_plant$nlcdCls:osbs_plant$Freq
        )
summary(pm1)
anova(pm1)
#significant variables: landcover(nlcdCls)

#Follow this link if you need help interpreting your summary. https://www.quora.com/How-do-I-interpret-the-summary-of-a-linear-model-in-R

# We need to check the normality of this model so that we can ensure that everything is relatively normally distributed.
library(car)
qqPlot(pm1)
plot(pm1)

#Reduced Model 1 - remove roads
pm2<-lm(osbs_plant$ln.richness~osbs_plant$distance_m.building+
          osbs_plant$nlcdCls+
          osbs_plant$elevatn+
          osbs_plant$Freq)
summary(pm2)
anova(pm2)
#significant variables:landcover(nlcdCls)

#Reduced Model 2 - remove building
pm3<-lm(osbs_plant$ln.richness~
          osbs_plant$nlcdCls+
          osbs_plant$elevatn+
          osbs_plant$Freq)
summary(pm3)
anova(pm3)
#significant variables:  landcover(nlcdCls)


#Reduced Model 3 - remove elevation
pm4<-lm(osbs_plant$ln.richness~
          osbs_plant$nlcdCls+
          osbs_plant$Freq)
summary(pm4)
anova(pm4)
#significant variables:  landcover(nlcdCls)

#Reduced Model 4 - remove frequency
pm5<-lm(osbs_plant$ln.richness~
          osbs_plant$nlcdCls)
summary(pm5)
anova(pm5)
#significant variables:  landcover(nlcdCls)


#ANOVA
anova(pm1, pm2) #Not Significant
anova(pm1, pm3) #Not Significant
anova(pm1, pm4) #Not Significant
anova(pm1, pm5) #Not Significant
anova(pm2, pm3) #Not Significant
anova(pm2, pm4) #Not Significant
anova(pm2, pm5) #Not Significant
anova(pm3, pm4) #Not Significant
anova(pm3, pm5) #Not Significant
anova(pm4, pm5) #Not Significant


# # Plot the relationship between ln.richness and land cover 
plot(osbs_plant$nlcdCls, osbs_plant$ln.richness,main="Plants", 
     xlab="Landcover Type", ylab="Species Richness")

# osbs_plant$nlcdCls
# # Compare within landcover types
# # Create objects for each landcover type
# emerg <- subset(osbs_plant, nlcdCls=='emergentHerbaceousWetlands')
# evergr <- subset(osbs_plant, nlcdCls=='evergreenForest')
# woody <- subset(osbs_plant, nlcdCls=='woodyWetlands')
# 
# # Model 1
# emergevergr <- rbind(emerg,evergr)
# glm1 <-glm(ln.richness~nlcdCls,family='gaussian', data=emergevergr)
# Anova(glm1, type="II")
# ## significant p<0.001
# 
# # Model 2
# emergwoody <- rbind(emerg,woody)
# glm2 <-glm(ln.richness~nlcdCls,family='gaussian', data=emergwoody)
# Anova(glm2, type="II")
# ## no significant
# 
# # Model 3
# evergrwoody <- rbind(evergr,woody)
# glm3 <-glm(ln.richness~nlcdCls,family='gaussian', data=evergrwoody)
# Anova(glm3, type="II")
# ## significant p<0.001
# 
# # There is significant difference between " evergreenForest" and other landcover classes

# just for fun,Plot the relationship between richness and the burn frequency
rich.burn<-ggplot(osbs_plant, aes(x = osbs_plant$Freq, y =osbs_plant$richness)) + 
  geom_point() +
  stat_smooth(method = "lm", col = "blue")
rich.burn+labs(title="Plants",
               x ="Fire frequency", y = "Species Richness")


################################################################################
#Birds
#Correlation Tests this computes all pairwise correlations using Pearson's correlation test.
names(osbs_bird)
library(psych)
pairs.panels(osbs_bird[c(2:5,7,9:10,12:13)])
ggsave(filename = 'pairs.pdf', width = 10, height = 10)
# no correlation

# This is the second linear model. First is the bird species richness data ~ all your predictor variables.
names(osbs_bird)
bm1<-lm(osbs_bird$ln.richness~
          osbs_bird$distance_m.building+
          osbs_bird$distance_m.roads+
          osbs_bird$nlcdCls+
          osbs_bird$elevatn+
          osbs_bird$Freq)
summary(bm1)
anova(bm1)
#### no significant result at all

# Normality of Residuals
qqPlot(bm1)
plot(bm1)


##################################### mammals
# This is the second linear model. First is the bird species richness data ~ all your predictor variables.
names(osbs_mammal)
mm1<-lm(osbs_mammal$ln.richness~
          osbs_mammal$distance_m.building+
          osbs_mammal$distance_m.roads+
          osbs_mammal$nlcdCls+
          osbs_mammal$elevatn+
          osbs_mammal$Freq)
summary(mm1)
anova(mm1)
#### lack of data 

# Normality of Residuals
qqPlot(bm1)
plot(bm1)

#Let's look at the relationship between bird richness and plant richness.
osbs_bird$ln.richness<-osbs_bird$ln.richness
osbs_plant$ln.richness<-osbs_plant$ln.richness
bird.plant<-merge(osbs_bird, osbs_plant, by=c("plotID", "nlcdCls", "elevatn", "distance_m.roads")) ## why using the roads not the buildings
names(bird.plant)

#bird v plant model
head(bird.plant)
bird.plant.model<-lm(bird.plant$ln.richness.x~bird.plant$ln.richness.y)
summary(bird.plant.model)

#plot
bird.plant.rich<-ggplot(bird.plant, aes(x = ln.richness.x, y =ln.richness.y)) +
  geom_point() +
  stat_smooth(method = "lm", col = "red")
bird.plant.rich+labs(title="Richness", x ="bird richness", y = "plant richness")
#Here we can see a slightly positive correlation between bird and plant richness. 
#
# Although the relationship is not significant, it can still play a role in the variation seen in bird richness.


#Correlation test
cor.test(bird.plant$ln.richness.x,bird.plant$ln.richness.y)

#Now that within site analysis is complete, we can move on to cross-site prep (neon_all_site_prep.R)

