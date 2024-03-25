#!/bin/zsh

# DB Connection Creds
DB_HOST="kitchen.acremaps.one"
DB_PORT="5432"
DB_DBNAME="kitchen"
DB_SCHEMA="california_crop_202401"
DB_USER="postgres"
DB_CONN_STR="host=${DB_HOST} user=${DB_USER} port=${DB_PORT} dbname=${DB_DBNAME} active_schema=${DB_SCHEMA}"

# ############################################


# ########################################################################################
# ################################## LOOP PARAMS #########################################
# ########################################################################################
# YEARS of CDL and CA Crop Data
YEARS=(
    2018
    2019
    2020
    2021
    2022
    2023
)
# California Crop Attributes and Parameters
ATTRIBUTES=(
    "cdl_crop_id"
    "yr_planted"
    )
# Attribute data types in rasters
typeset -A ATTRIBUTE_TYPES=(
    ["cdl_crop_id"]=Byte
    ["yr_planted"]=Int32
)
# Attribute color interpretations in rasters
typeset -A ATTRIBUTE_COLORINTERPS=(
    ["cdl_crop_id"]=Palette
    ["yr_planted"]=Gray
)
# Attributes with color tables extracted from CDL raster
typeset -A ATTRIBUTE_COLOR_TABLES=(
    ["cdl_crop_id"]=true
    ["yr_planted"]=false
)
# SQL Query to extract CA Crop data
SQL_CA_CROP="
    SELECT
        DISTINCT ON (crop.uniqueid)
        crop.uniqueid,
        crop.recording_year,
        NULLIF(crop.yr_planted, 0) as yr_planted,
        crop.class,
        crop.subclass,
        crop.crop_key,
        crop.crop_type,
        crop.class_name,
        crop.subclass_name,
        crop.cdl_crop_id,
        ST_Transform(boundary.geometry, 5070) as geometry
    FROM california_crop_202403.california_crop_flat AS crop
    JOIN california_crop_202403.california_crop_boundary AS boundary ON crop.uniqueid = boundary.uniqueid
    WHERE crop.is_main_crop = TRUE
        AND boundary.recording_year = '%recording_year'
        AND crop.recording_year = '%recording_year'
"


# ########################################################################################
# ############################### LOOP THROUGH YEARS #####################################
# ########################################################################################

for YYYY in $YEARS;
do
    # Output directory to put all generated files
    OUTPUT_DIR="$(pwd)/${YYYY}"
    CDL_RASTER=${YYYY}_30m_cdls.tif
    
    # make output file path if not exists
    if [ ! -d "$OUTPUT_DIR" ]; then
        # If the directory doesn't exist, create it
        mkdir "$OUTPUT_DIR"
        echo "Directory '$OUTPUT_DIR' created."
    else
        echo "Directory '$OUTPUT_DIR' already exists."
    fi
    
    # ########################################################################################
    # *************************** Download CDL Geotiff from GCS ******************************
    # ########################################################################################
    if [ ! -f "${OUTPUT_DIR}/${CDL_RASTER}" ]; then
        echo "Downloading ${CDL_RASTER} from GCS"
        gsutil cp gs://acretrader-ds.appspot.com/geotiffs/cdl/$CDL_RASTER ${OUTPUT_DIR}/.
    else
        echo "${OUTPUT_DIR}/${CDL_RASTER} already exists."
    fi
    

    # NOTE:THIS WORKS
    # ########################################################################################
    # *************************** Create FlatGeoBuff of CA Crop Data *************************
    # ########################################################################################
    
    # ******** FlatGeoBuff Parameters ***********
    CA_CROP_FLATGEOBUF_NAME="ca_crop_${YYYY}"
    CA_CROP_FLATGEOBUF_FILE="${CA_CROP_FLATGEOBUF_NAME}.fgb"
    CA_CROP_FLATGEOBUF_PATH="${OUTPUT_DIR}/${CA_CROP_FLATGEOBUF_FILE}"
    OUTPUT_SRS="EPSG:5070"
    SQL="${SQL_CA_CROP//\%recording_year/$YYYY}"
    echo $SQL

    # **************************** BUILD FlatGeoBuff of CA Crop Data ***************************
    echo "\n\n\n BUILD CA CROP FLATGEOBUF \n\n\n"
    # Extract Polygons from Postgres
    OGR2OGR_CMD="ogr2ogr -f FlatGeoBuf ${CA_CROP_FLATGEOBUF_PATH} -s_srs \"${OUTPUT_SRS}\" -t_srs \"${OUTPUT_SRS}\" -nln ${CA_CROP_FLATGEOBUF_NAME} PG:\"${DB_CONN_STR}\" -sql ${SQL}"
    echo $OGR2OGR_CMD
    eval "${OGR2OGR_CMD}"
    
    
    # NOTE: THIS WORKS
    # ########################################################################################
    # *************************** Create Raster Files from FlatGeoBuff *********************
    # ########################################################################################
    
    # ******** Raster Parameters ***********
    REFERENCE_RASTER="${OUTPUT_DIR}/${CDL_RASTER}"
    
    # Get the corner coordinates of the reference raster
    x_min=$(gdalinfo -json $REFERENCE_RASTER | jq '.cornerCoordinates.lowerLeft[0]')
    y_min=$(gdalinfo -json $REFERENCE_RASTER | jq '.cornerCoordinates.lowerLeft[1]')
    x_max=$(gdalinfo -json $REFERENCE_RASTER | jq '.cornerCoordinates.upperRight[0]')
    y_max=$(gdalinfo -json $REFERENCE_RASTER | jq '.cornerCoordinates.upperRight[1]')
    res=$(gdalinfo -json $REFERENCE_RASTER | jq '.geoTransform[1]')
    
    
    # Loop through all the attributes
    for ATTRIBUTE in $ATTRIBUTES;
    do
        # ATTRIBUTE FIELDS
        TYPE=${ATTRIBUTE_TYPES[$ATTRIBUTE]}
        COLORINTERP=${ATTRIBUTE_COLORINTERPS[$ATTRIBUTE]}
        COLOR_TABLE=${ATTRIBUTE_COLOR_TABLES[$ATTRIBUTE]}
        echo "\n${ATTRIBUTE}: ${TYPE} / ${COLORINTERP} / ${COLOR_TABLE}"
    
        # Rasterize the attribute to the GeoTIFF file
        GDAL_CMD="gdal_rasterize -l ${CA_CROP_FLATGEOBUF_NAME} -a ${ATTRIBUTE} -tr ${res} ${res} -te ${x_min} ${y_min} ${x_max} ${y_max} -ot ${TYPE} -a_nodata -9999 -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES ${CA_CROP_FLATGEOBUF_PATH} ${OUTPUT_DIR}/ca_crop_${YYYY}_${ATTRIBUTE}.tif"
        echo $GDAL_CMD
        eval "${GDAL_CMD}"
    
        # Mask/replace CDL with CA crop data 
        GDAL_CMD='gdal_calc.py -A ca_crop_2022_cdl_crop_id2.tif -B geotiffs_cdl_2022_30m_cdls_test.tiff --outfile=gdal_calc_mask_cdl_crop_id2.tif --calc="((A != 0) * A) + ((A == 0) * B)" --co "COMPRESS=DEFLATE" --co "BIGTIFF=YES"'
        echo $GDAL_CMD
        eval "${GDAL_CMD}"
    
        # Add CDL color table to the attribute raster
        if $COLOR_TABLE; then
            echo "${ATTRIBUTE} has a color table"
            GDAL_COLOR_TABLE="gdalattachpct.py ${REFERENCE_RASTER} ${OUTPUT_DIR}/ca_crop_${YYYY}_${ATTRIBUTE}.tif ${OUTPUT_DIR}/ca_crop_${YYYY}_${ATTRIBUTE}.tif"
            echo $GDAL_COLOR_TABLE
            eval "${GDAL_COLOR_TABLE}"
        fi
    done
done


# NOTE: NEXT STEPS
# 1. Loop through all the attributes
# 2. Stack the rasters
# 3. Create a single raster with all the attributes
# 4. Create a single raster with all the attributes and the reference raster
# 5. Mask/replace CDL with CA crop (could use gdal_calc.py if it's not too slow)


## **************************** BUILD FlatGeoBuff of CA Crop Data ***************************
#echo "\n\n\n BUILD CA CROP FLATGEOBUF \n\n\n"
## Extract Polygons from Postgres
#OGR2OGR_CMD="ogr2ogr -f FlatGeoBuf ${CA_CROP_FLATGEOBUF}.fgb -s_srs \"${OUTPUT_SRS}\" -t_srs \"${OUTPUT_SRS}\" -nln ca_crop_${YYYY} PG:\"${DB_CONN_STR}\" -sql @${SQL_CA_CROP}"
#echo $OGR2OGR_CMD
#eval "${OGR2OGR_CMD}"




# WARN: This is all archived code
# ########################################################################################
# ########################################################################################
# ************************************** ARCHIVE ***************************************
# ########################################################################################
# ########################################################################################
#
#
# ########################################################################################
# *************************** Create Raster Files from FlatGeoBuff *********************
# ########################################################################################

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

