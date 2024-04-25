# msh22-refuge


### Files in this directory
1. DrawDownSF_vol.R
   - Uses msh2022_pond_volume_new_static.csv
   - Uses msh2022_pond_volume_not_sn.csv
   - *Creates volume_drawdown.csv*
  
  Run this file first! Uses csv files with volume and pond depth/surface area data to calculate drawdown for all of the ponds. Based on Emma Campbell's drawdown work using depth rather than volume. Notice that the ponds are split into two categories, "cont" (contour) and "geo" (geometric). Some of the ponds were mapped using a Garmin Cast and then contour maps were made in QGIS to get the volumes of the ponds at different water depths (thus the category contour). However, some of the ponds were not able to be mapped (geometric). Thus in this file I show that the "contour" ponds can be modeled as cylinders (surface area * depth) except with a scaling factor of 1/0.758! I then use this scaling factor to estimate the volumes of the "geometric" ponds. Once all of the ponds have volumes for each sampling date, the drawdown rates are then calculated to get a metric for how fast and how much water was being lost over the summer. At the end of the file a csv is created "volume_drawdown.csv" with this information that is used in the next R file ->
   
2. 2022_pond_factors_submit.Rmd
   - Uses factors_1.csv
   - *Uses volume_drawdown.csv*
   - Creates factor_plots_comb.pdf

Now we get to the good stuff! 
