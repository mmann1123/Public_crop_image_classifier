# read in labeled crop images from Koen do preprocessing and 
# sort into folders with labels
# also does testing images

#library("devtools")
#install_github("khufkens/cropmonitor")
library(cropmonitor)
library(readstata13)
#library(RCurl)
library(foreach)
library(doParallel)
library(raster)

library(jpeg)

my.file.rename <- function(from, to) {
  todir <- dirname(to)
  if (!isTRUE(file.info(todir)$isdir)) dir.create(todir, recursive=TRUE)
  file.copy(from = from,  to = to)
}


# Training Images ----------------------------------------------------------


# image labels 
setwd('/media/ssd/crop_image_classifier/Data/')
in_labels = readRDS('./cropmonitor_subset.rds')
head(in_labels)

# read in raw image data locations
in_data = read.dta13('./Pictures Data CLEAN 04_21_17.dta')

# limit to images we have lodging labels
in_data = in_data[basename(in_data$image) %in% in_labels$image_name[!is.na(in_labels$lodging)],]
head(in_data)


# download raw images
junk= foreach(path = in_data$image,.packages = 'RCurl') %dopar% {
  if(!file.exists(path)){download.file(path,destfile=paste('./RawImages/',basename(path),sep=''),method="libcurl")}
  return(NULL)
}


# resize and rotate images
setwd('/media/ssd/crop_image_classifier/Data/RawImages/')
images = list.files('.',pattern = '.jpg')
images = images[images %in% in_labels$image_name] # retain images that we have lables for
plot(raster(images[1]))
a = read_size(images[1])
plot(a$img)

for(path in images){
  # check that image doesn't exist
  if(file.exists(paste0('/media/ssd/crop_image_classifier/Data/RotateImages/',path))){print('skipping');next}
  print(path)
  # rotate and resize 
  rotated_img = tryCatch(
    read_size(paste('/media/ssd/crop_image_classifier/Data/RawImages/',path,sep='')),
    error=function(e) e
  )
  
  # skip value if rotating the image fails
  if(inherits(rotated_img,"error")){
    gc() # clear memory
    next
  }
  # write out file 
  jpeg::writeJPEG(raster::as.array(rotated_img$img/255),
                  target = paste('/media/ssd/crop_image_classifier/Data/RotateImages/',path,sep=''),
                  quality = 1)
}



# limit to AOI
setwd('/media/ssd/crop_image_classifier/Data/RotateImages/')
images = list.files('.',pattern = '.jpg')
a = raster(images[1])
plot(a)
aoi = estimate_roi(images[1],padding = 0.05)
plot(aoi$roi,add=T)
plot(mask(a,aoi$roi))

cl <- makeCluster(3)
registerDoParallel(cl)

junk= foreach(path = images,.packages = c('cropmonitor','raster','jpeg')) %dopar% {
  img_path = paste('/media/ssd/crop_image_classifier/Data/RotateImages/',path,sep='')
  cropped_img = estimate_roi(img_path,padding = 0.05)
  cropped_img = mask(stack(img_path),cropped_img$roi)
  jpeg::writeJPEG(raster::as.array(cropped_img /255),
                  target = paste('/media/ssd/crop_image_classifier/Data/AoiImages/',path,sep=''),
                  quality = 1)
  return(NULL)
}

# sort into training folders
setwd('/media/ssd/crop_image_classifier/Data/LodgingLabels')
images = list.files('../AoiImages/',pattern = '.jpg')

table(in_labels$labels)
table(in_labels$lodging)

# create dirs for both Lodging Labels and sort images
# dir.create(paste(getwd(),'/Yes',sep=''))
# dir.create(paste(getwd(),'/No',sep=''))

# 
for(img in images){
  # move yes to yes folder 
  if(img %in% in_labels$image_name[in_labels$lodging=='Yes']){
    my.file.rename(from=paste0('/media/ssd/crop_image_classifier/Data/AoiImages/',img),
                   to=paste0('/media/ssd/crop_image_classifier/Data/LodgingLabels/Yes/',img))
  }
  # move no to no folder 
  if(img %in% in_labels$image_name[in_labels$lodging=='No']){
    my.file.rename(from=paste0('/media/ssd/crop_image_classifier/Data/AoiImages/',img),
                   to=paste0('/media/ssd/crop_image_classifier/Data/LodgingLabels/No/',img))
  }
}

# NOTE: SOME LABELS ARE WRONG MANUALLY EDITED



# Testing Images ----------------------------------------------------------



# resize and rotate images
setwd('/media/ssd/crop_image_classifier/Data/TestingImages/')
images = list.files('.',pattern = '.jp*')
plot(raster(images[1]))
a = read_size(images[1])
plot(a$img)

for(path in images){
  # check that image doesn't exist
  if(file.exists(paste0('/media/ssd/crop_image_classifier/Data/TestingImages_Rotated/',path))){print('skipping');next}
  print(path)
  # rotate and resize 
  rotated_img = tryCatch(
    read_size(paste('/media/ssd/crop_image_classifier/Data/TestingImages/',path,sep='')),
    error=function(e) e
  )
  
  # skip value if rotating the image fails
  if(inherits(rotated_img,"error")){
    gc() # clear memory
    next
  }
  # write out file 
  jpeg::writeJPEG(raster::as.array(rotated_img$img/255),
                  target = paste('/media/ssd/crop_image_classifier/Data/TestingImages_Rotated/',path,sep=''),
                  quality = 1)
}



# limit to AOI
setwd('/media/ssd/crop_image_classifier/Data/TestingImages_Rotated/')
images = list.files('.',pattern = '.jpg')
a = raster(images[1])
image(a)
aoi = estimate_roi(images[1],padding = 0.05)
plot(aoi$roi,add=T)
plot(mask(a,aoi$roi))

cl <- makeCluster(3)
registerDoParallel(cl)

junk= foreach(path = images,.packages = c('cropmonitor','raster','jpeg')) %dopar% {
  img_path = paste('/media/ssd/crop_image_classifier/Data/TestingImages_Rotated/',path,sep='')
  cropped_img = estimate_roi(img_path,padding = 0.05)
  cropped_img = mask(stack(img_path),cropped_img$roi)
  jpeg::writeJPEG(raster::as.array(cropped_img /255),
                  target = paste('/media/ssd/crop_image_classifier/Data/TestingImages_AOI/',path,sep=''),
                  quality = 1)
  return(NULL)
}





