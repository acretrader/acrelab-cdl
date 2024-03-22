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
# Check if the necessary tools are available
if ! command -v ogr2ogr &>/dev/null || ! command -v gdal_rasterize &>/dev/null; then
    echo "Error: GDAL tools ogr2ogr and gdal_rasterize are not installed."
    exit 1
fi

# Input parameters
input_file="$(pwd)/2022/ca-crop_2022.fgb"
output_file="$(pwd)/zsh_test.tif"
reference_raster="$(pwd)/geotiffs_cdl_2022_30m_cdls_original.tiff"
attribute_name="cdl_crop_id2"
attribute_dtype="Byte"  # Change according to your attribute's data type
attribute_colorinterp="Palette"  # Change according to your attribute's color interpretation

# Open the reference raster to get its geotransform and spatial reference
echo "getting data from $reference_raster"
ref_geotransform=$(gdalinfo -json "$reference_raster" | jq -r '.geoTransform | map(tostring) | join(" ")')
ref_projection=$(gdalsrsinfo "$reference_raster" | awk -F'[][]' '/ID\["EPSG"/ {id=$2} END {gsub(/[^0-9]/,"",id); print "EPSG:" id}')
echo $ref_geotransform
echo $ref_projection
#ref_projection=$(gdalinfo -json "$reference_raster" | jq -r '.coordinateSystem.wkt')

# Create a raster GeoTIFF file with the same extent, resolution, and pixel alignment as the reference raster
echo "processing $input_file"
#ogr2ogr -f "FlatGeobuf" temp_layer.geojson "$input_file"
#gdal_rasterize -l temp_layer -a "$attribute_name" -tr "$(echo "$ref_geotransform" | cut -d ' ' -f 2)" "$(echo "$ref_geotransform" | cut -d ' ' -f 1)" -a_nodata 0 -ot "$attribute_dtype" -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES -a_srs "$ref_projection" temp_layer.geojson "$output_file"
#gdal_rasterize -l temp_layer -a "$attribute_name" -tr "$(echo "$ref_geotransform" | cut -d ' ' -f 2)" "$(echo "$ref_geotransform" | cut -d ' ' -f 1)" -a_nodata 0 -ot "$attribute_dtype" -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES -a_srs "$ref_projection" "$output_file" "$input_file"
gdal_rasterize -l OGRGeoJSON -a "$attribute_name" -tr "$(echo "$ref_geotransform" | cut -d ' ' -f 2)" "$(echo "$ref_geotransform" | cut -d ' ' -f 1)" -a_nodata 0 -ot "$attribute_dtype" -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES -a_srs "$ref_projection" "$output_file" "$input_file"

# Set ColorInterp to something other than "gray" (e.g., "Red", "Green", "Blue", "Palette", etc.)
gdal_edit.py -a_nodata 0 -colorinterp_1 "$attribute_colorinterp" "$output_file"

# Clean up temporary files
#rm temp_layer.geojson

