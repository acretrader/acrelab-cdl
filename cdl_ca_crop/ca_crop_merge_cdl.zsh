#!/bin/zsh

# Vintage Year
YYYY='2022'

# Output directory to put all generated files
OUTPUT_DIR="$(pwd)/${YYYY}"

# make output file path if not exists
if [ ! -d "$OUTPUT_DIR" ]; then
    # If the directory doesn't exist, create it
    mkdir "$OUTPUT_DIR"
    echo "Directory '$OUTPUT_DIR' created."
else
    echo "Directory '$OUTPUT_DIR' already exists."
fi

# DB Connection Creds
DB_HOST="kitchen.acremaps.one"
DB_PORT="5432"
DB_DBNAME="kitchen"
DB_SCHEMA="california_crop_202401"
DB_USER="postgres"
DB_CONN_STR="host=${DB_HOST} user=${DB_USER} port=${DB_PORT} dbname=${DB_DBNAME} active_schema=${DB_SCHEMA}"

# ******** Tile Parameters ***********
# County Tile Parameters
CA_CROP_FLATGEOBUF="${OUTPUT_DIR}/ca_crop_${YYYY}.fgb"
CDL_TIFF="$(pwd)/cdl_2022_test.tiff"


# **************************** BUILD COUNTY TILES  ***************************
echo "\n\n\n BUILD CA CROP GEOJSON \n\n\n"
# Extract Polygons from Postgres
RESOLUTION=$(gdalinfo -json ${CDL_TIFF} | jq -r '.geoTransform[1]')
OGR2OGR_CMD="gdal_rasterize -a crop_id1 -l ca_crop_2022 -of GTiff -a_nodata 0 -ot INT32 -i -co COMPRESS=DEFLATE -co TILED=YES -co BLOCKXSIZE=512 -co BLOCKYSIZE=512 -tr ${RESOLUTION} ${RESOLUTION} ${CA_CROP_FLATGEOBUF} ${CDL_TIFF}"
echo $OGR2OGR_CMD
eval "${OGR2OGR_CMD}"
