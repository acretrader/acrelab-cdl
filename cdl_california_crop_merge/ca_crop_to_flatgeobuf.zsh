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

# ******** FlatGeoBuff Parameters ***********
SQL_CA_CROP="$(pwd)/ca_crop_to_flatgeobuf.sql"
CA_CROP_FLATGEOBUF="${OUTPUT_DIR}/ca_crop_${YYYY}"
OUTPUT_SRS="EPSG:5070"


# **************************** BUILD FlatGeoBuff of CA Crop Data ***************************
echo "\n\n\n BUILD CA CROP FLATGEOBUF \n\n\n"
# Extract Polygons from Postgres
OGR2OGR_CMD="ogr2ogr -f FlatGeoBuf ${CA_CROP_FLATGEOBUFF}.fgb -s_srs \"${OUTPUT_SRS}\" -t_srs \"${OUTPUT_SRS}\" -nln ca_crop_${YYYY} PG:\"${DB_CONN_STR}\" -sql @${SQL_CA_CROP}"
echo $OGR2OGR_CMD
eval "${OGR2OGR_CMD}"


## *************************** Create Raster Files from FlatGeoBuff *********************
#create_geotiff() {
#    local input_file="$1"
#    local output_file="$2"
#    local attribute_name="$3"
#    local attribute_dtype="$4"
#    local attribute_colorinterp="$5"
#    local reference_raster="$6"
#
#    # Open the FlatGeoBuf file
#    echo "\n"
#    echo "Opening: $input_file"
#    ogrinfo "$input_file" > /dev/null
#    if [ $? -ne 0 ]; then
#        echo "Error: Could not open the FlatGeoBuf file."
#        return
#    fi
#
#    # Open the reference raster to get its geotransform and spatial reference
#    echo "\n"
#    echo "Opening: $reference_raster"
#    gdalinfo "$reference_raster" > /dev/null
#    if [ $? -ne 0 ]; then
#        echo "Error: Could not open the reference raster."
#        return
#    fi
#
#    # Create a raster GeoTIFF file with the same extent, resolution, and pixel alignment as the reference raster
#    echo "\n"
#    echo "Creating: $output_file using $reference_raster as a reference"
#    #gdal_translate -of GTiff -a_srs "$(gdalsrsinfo -o wkt "$reference_raster")" -a_ullr $(gdalinfo "$reference_raster" | grep "Upper Left" | sed 's/Upper Left  //;s/).*//') -a_nodata 0 "$reference_raster" "$output_file"
#    #gdal_translate -of GTiff -a_srs "$(gdalsrsinfo -o wkt "$reference_raster")" -a_ullr "$(gdalinfo "$reference_raster" | grep \"Upper Left\" | sed 's/Upper Left  //;s/).*//')" -a_nodata 0 "$reference_raster" "$output_file"
#    #gdal_translate -of GTiff -a_srs "$(gdalsrsinfo -o wkt "$reference_raster")" -a_ullr "$(gdalinfo "$reference_raster" | grep -o -E 'Upper Left\s+\(.*\)' | sed 's/Upper Left\s+(\(.*\))/\1/')" -a_nodata 0 "$reference_raster" "$output_file"
#    gdal_translate -of GTiff -a_srs "$(gdalsrsinfo -o wkt "$reference_raster")" -a_ullr "$(gdalinfo "$reference_raster" | grep -o -E 'Upper Left\s+\(.*\)' | sed 's/Upper Left\s+(\(.*\))/\1/')" -a_nodata 0 "$reference_raster" "$output_file"
#
#    # Rasterize the attribute to the GeoTIFF file
#    echo "\n"
#    echo "Rasterizing: $output_file"
#    ogr2ogr -f "GTiff" -where "1=1" -sql "SELECT * FROM $(basename "$input_file" .fgb)" -dialect sqlite -append "$output_file" "$input_file" -nln "$(basename "$input_file" .fgb)" -fieldTypeToString "$attribute_name=$attribute_dtype"
#
#    # Set ColorInterp to something other than "gray" (e.g., "Red", "Green", "Blue", "Palette", etc.)
#    echo "\n"
#    echo "Setting ColorInterp: $output_file"
#    gdal_translate -b 1 -colorinterp $attribute_colorinterp "$output_file" "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
#
#    echo "\n"
#    echo "Completed: $output_file"
#}
#
## Replace 'input_file' with the path to your FlatGeoBuf file
#input_file=${CA_CROP_GEOJSON}.fgb
#
## Replace 'output_directory' with the directory where you want to save the GeoTIFF files
#output_directory=${OUTPUT_DIR}/
#
## Replace 'attribute_names' with the names of the attributes you want to rasterize
##declare -A attribute_names=(
##    ['yr_planted']='Int32'
##    ['crop_id1']='Byte'
##    ['crop_id2']='Byte'
##    ['crop_id3']='Byte'
##    ['crop_id4']='Byte'
##)
#declare -A attribute_names=(
#    ['yr_planted']='Int32'
#)
#
## Replace 'reference_raster' with the path to your existing raster file
#reference_raster='/home/kenny/repos/flavortown/cdl/cdl_ca_crop/geotiffs_cdl_2022_30m_cdls_original.tiff'
#
#for attribute_name in ${(k)attribute_names}; do
#    echo "\n\n\n"
#    echo "****************************************"
#    echo "Rasterizing attribute: $attribute_name"
#    output_file="${output_directory}${YYYY}_${attribute_name}.tif"
#    create_geotiff "$input_file" "$output_file" "$attribute_name" "${attribute_names[$attribute_name]}" "Undefined" "$reference_raster"
#done
#
#echo "Rasterization completed."

