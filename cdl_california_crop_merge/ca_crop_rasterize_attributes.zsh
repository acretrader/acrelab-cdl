#!/bin/zsh

# Vintage Year
YYYY='2022'


# **************************** BUILD FlatGeoBuff of CA Crop Data ***************************
echo "\n\n\n BUILD CA CROP FLATGEOBUF \n\n\n"
# Extract Polygons from Postgres
#GDAL_CMD="ogr2ogr -f FlatGeoBuf ${CA_CROP_FLATGEOBUFF}.fgb -s_srs \"${OUTPUT_SRS}\" -t_srs \"${OUTPUT_SRS}\" -nln ca_crop_${YYYY} PG:\"${DB_CONN_STR}\" -sql @${SQL_CA_CROP}"
GDAL_CMD="gdal_rasterize -tr ${RESOLUTION} ${RESOLUTION} -burn 1 "
echo $GDAL_CMD
eval "${GDAL_CMD}"
