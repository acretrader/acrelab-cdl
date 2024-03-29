#!/bin/zsh

# DB Connection Creds
DB_HOST="kitchen.acremaps.one"
DB_PORT="5432"
DB_DBNAME="kitchen"
DB_SCHEMA="california_crop_202403"
DB_USER="postgres"
DB_CONN_STR="host=${DB_HOST} user=${DB_USER} port=${DB_PORT} dbname=${DB_DBNAME} active_schema=${DB_SCHEMA}"


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
typeset -A YEAR_YR_PLANTED=(
    [2018]=false
    [2019]=false
    [2020]=true
    [2021]=true
    [2022]=true
    [2023]=true
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
    echo "\n\n##############################################"
    echo "########## Processing Year: ${YYYY} ##########"
    echo "##############################################\n\n"
    # Output directory to put all generated files
    OUTPUT_DIR="$(pwd)/${YYYY}"
    CDL_RASTER=${YYYY}_30m_cdls.tif
    CDL_RASTER_PATH="${OUTPUT_DIR}/${CDL_RASTER}"
    
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
    echo "\nDOWNLOAD CDL GEOTIFF"
    if [ ! -f "${CDL_RASTER_PATH}" ]; then
        echo "Downloading ${CDL_RASTER} from GCS"
        gsutil cp gs://acretrader-ds.appspot.com/geotiffs/cdl/$CDL_RASTER ${CDL_RASTER_PATH}
    else
        echo "${CDL_RASTER_PATH} already exists."
    fi


    # ########################################################################################
    # *************************** Create FlatGeoBuff of CA Crop Data *************************
    # ########################################################################################
    
    # ******** FlatGeoBuff Parameters ***********
    CA_CROP_FLATGEOBUF_NAME="ca_crop_${YYYY}"
    CA_CROP_FLATGEOBUF_FILE="${CA_CROP_FLATGEOBUF_NAME}.fgb"
    CA_CROP_FLATGEOBUF_PATH="${OUTPUT_DIR}/${CA_CROP_FLATGEOBUF_FILE}"
    OUTPUT_SRS="EPSG:5070"
    SQL="${SQL_CA_CROP//\%recording_year/$YYYY}"

    # **************************** BUILD FlatGeoBuff of CA Crop Data ***************************
    echo "\n***BUILD CA CROP FLATGEOBUF***"
    # Extract Polygons from Postgres
    if [ ! -f "${CA_CROP_FLATGEOBUF_PATH}" ]; then
        echo "Extracting polygons from Postgres to ${CA_CROP_FLATGEOBUF_PATH}"
        OGR2OGR_CMD="ogr2ogr -f FlatGeoBuf ${CA_CROP_FLATGEOBUF_PATH} -s_srs \"${OUTPUT_SRS}\" -t_srs \"${OUTPUT_SRS}\" -nln ${CA_CROP_FLATGEOBUF_NAME} PG:\"${DB_CONN_STR}\" -sql \"${SQL}\""
        echo $OGR2OGR_CMD
        eval "${OGR2OGR_CMD}"
    else
        echo "${CA_CROP_FLATGEOBUF_PATH} already exists."
    fi
    
    
    # ########################################################################################
    # *************************** Create Raster Files from FlatGeoBuff *********************
    # ########################################################################################
    
    # Get the corner coordinates of the reference raster and the resolution
    x_min=$(gdalinfo -json $CDL_RASTER_PATH | jq '.cornerCoordinates.lowerLeft[0]')
    y_min=$(gdalinfo -json $CDL_RASTER_PATH | jq '.cornerCoordinates.lowerLeft[1]')
    x_max=$(gdalinfo -json $CDL_RASTER_PATH | jq '.cornerCoordinates.upperRight[0]')
    y_max=$(gdalinfo -json $CDL_RASTER_PATH | jq '.cornerCoordinates.upperRight[1]')
    res=$(gdalinfo -json $CDL_RASTER_PATH | jq '.geoTransform[1]')
    
    # California Crop Attributes and Parameters
    ATTRIBUTES=(
        "cdl_crop_id"
        "yr_planted"
        )
    pos=$(( ${#files[*]} - 1 ))

    # Attribute data types in rasters
    typeset -A ATTRIBUTE_TYPES=(
        ["cdl_crop_id"]=Byte
        ["yr_planted"]=Int16
    )

    # Attribute color interpretations in rasters
    typeset -A ATTRIBUTE_COLORINTERPS=(
        ["cdl_crop_id"]=Palette
        ["yr_planted"]=Gray
    )

    # Array of TIFs that will be merged at end
    TIF_LIST=()
    
    # Loop through all the attributes
    echo "\n ***RASTERIZE CA CROP ATTRIBUTES***"
    for ATTRIBUTE in $ATTRIBUTES
    do
        # ATTRIBUTE FIELDS
        TYPE=${ATTRIBUTE_TYPES[$ATTRIBUTE]}
        COLORINTERP=${ATTRIBUTE_COLORINTERPS[$ATTRIBUTE]}
        YR_PLANTED=${YEAR_YR_PLANTED[$YYYY]}

        # Raster paths
        ATTRIBUTE_TIF_PATH="${OUTPUT_DIR}/${ATTRIBUTE}.tif" # initial rasterization of CA crop data
        CDL_CA_MERGED_TIF_PATH="${OUTPUT_DIR}/cdl_and_ca_${ATTRIBUTE}_merged.tif" # initial merging of CA crop with CDL rasters using gdal_calc (mask/replace)
        CDL_CA_MERGED_TIF_COMPRESSED_PATH="${OUTPUT_DIR}/cdl_and_ca_${ATTRIBUTE}_merged_compressed.tif" # compressed version of the merged raster
        CA_CROP_BOOL_PATH="${OUTPUT_DIR}/ca_${ATTRIBUTE}_bool.tif" # raster of boolean values for CA crop (1=CA crop, 0=not CA crop)
        CA_CROP_BOOL_COMPRESSED_PATH="${OUTPUT_DIR}/ca_${ATTRIBUTE}_bool_compressed.tif" # compressed version of the boolean raster

        # Final raster paths
        FINAL_TIF_PATH=${OUTPUT_DIR}/${YYYY}_CDL_CA_CROP_30M.tif # final compressed raster with CDL color table applied 
        FINAL_VRT_PATH=${OUTPUT_DIR}/${YYYY}_CDL_CA_CROP_30M.vrt # final VRT file 

        # Print attribute info
        echo "\n${YYYY} ${ATTRIBUTE} - attribute_type:${TYPE} / colorinterp:${COLORINTERP} / yr_planted available:${YR_PLANTED}"

        # if attribute is cdl_crop_id then rasterize the attribute and apply color table if applicable
        if [[ "$ATTRIBUTE" == "cdl_crop_id" ]]; then
            # ############################################
            # ###### RASTERIZE ATTRIBUTE AND MERGE #######
            # ############################################
            # Rasterize the attribute to the GeoTIFF file
            echo "\nRasterizing ${ATTRIBUTE} to ${ATTRIBUTE_TIF_PATH}"
            GDAL_CMD="gdal_rasterize -l ${CA_CROP_FLATGEOBUF_NAME} -a ${ATTRIBUTE} -tr ${res} ${res} -te ${x_min} ${y_min} ${x_max} ${y_max} -ot ${TYPE} -a_nodata -9999 -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES ${CA_CROP_FLATGEOBUF_PATH} ${ATTRIBUTE_TIF_PATH}"
            echo $GDAL_CMD
            eval "${GDAL_CMD}"

            # Mask CDL with CA crop
            echo "\nMasking CDL with CA crop ${ATTRIBUTE}"
            GDAL_CALC="gdal_calc.py -A ${ATTRIBUTE_TIF_PATH} -B ${CDL_RASTER_PATH} --quiet --outfile=${CDL_CA_MERGED_TIF_PATH} --type=${TYPE} --calc=\"( (A != 0) * A) + ( (A == 0) * B )\" --co \"COMPRESS=DEFLATE\" --co \"BIGTIFF=YES\""
            echo $GDAL_CALC
            eval "${GDAL_CALC}"

            # Apply color table to merged raster
            echo "\nApplying color table to merged raster"
            GDAL_COLOR_TABLE="gdalattachpct.py ${CDL_RASTER_PATH} ${CDL_CA_MERGED_TIF_PATH} ${CDL_CA_MERGED_TIF_PATH}"
            echo $GDAL_COLOR_TABLE
            eval "${GDAL_COLOR_TABLE}"

            # Compress the merged raster
            echo "\nCompressing the final raster"
            GDAL_COMPRESS="gdal_translate -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES ${CDL_CA_MERGED_TIF_PATH} ${CDL_CA_MERGED_TIF_COMPRESSED_PATH}"
            echo $GDAL_COMPRESS
            eval "${GDAL_COMPRESS}"

            # Add the merged raster to the list of TIFs
            echo "\n${CDL_CA_MERGED_TIF_COMPRESSED_PATH} added to TIF list"
            TIF_LIST+=(${CDL_CA_MERGED_TIF_COMPRESSED_PATH})

            # ############################################
            # ###### CREATE RASTER OF BOOLEAN VALUES #####
            # ############################################
            # Create raster of boolean values for CA crop
            echo "\nCreating raster of boolean values for CA crop"
            GDAL_CA_BOOL="gdal_calc.py -A ${ATTRIBUTE_TIF_PATH} --quiet --outfile=${CA_CROP_BOOL_PATH} --type=${TYPE} --calc=\"(A != 0)\" --co \"COMPRESS=DEFLATE\" --co \"BIGTIFF=YES\""
            echo $GDAL_CA_BOOL
            eval "${GDAL_CA_BOOL}"

            # Compress the boolean raster
            echo "\nCompressing the boolean raster"
            GDAL_COMPRESS_BOOL="gdal_translate -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES ${CA_CROP_BOOL_PATH} ${CA_CROP_BOOL_COMPRESSED_PATH}"
            echo $GDAL_COMPRESS_BOOL
            eval "${GDAL_COMPRESS_BOOL}"

            # Add the boolean raster to the list of TIFs
            echo "\n${CA_CROP_BOOL_COMPRESSED_PATH} added to TIF list"
            TIF_LIST+=(${CA_CROP_BOOL_COMPRESSED_PATH})

            # ############################################
            # ###### CREATE VRT AND TILE PNGs ############
            # ############################################
            echo "\n***CREATE VRT AND TILE PNGs***"

            # File names
            TITLE="${YYYY}_CDL_CA_CROP"
            TMP0_PATH="${OUTPUT_DIR}/tmp0.vrt"
            TMP1_PATH="${OUTPUT_DIR}/tmp1.vrt"
            TILES_PATH="${OUTPUT_DIR}/tiles/${YYYY}"

            # Create tiles
            echo "\nTranslate ${CDL_CA_MERGED_TIF_COMPRESSED_PATH} to VRT"
            gd_t_A="gdal_translate -strict -of VRT ${CDL_CA_MERGED_TIF_COMPRESSED_PATH} ${TMP0_PATH}"
            echo $gd_t_A
            eval "$gd_t_A"

            echo "\nExpand RGBA bands"
            gd_t_B="gdal_translate -of VRT -expand rgba ${TMP0_PATH} ${TMP1_PATH}"
            echo $gd_t_B
            eval "$gd_t_B"

            echo "\nCreate PNG tiles"
            gd2t="gdal2tiles.py --resume --exclude --s_srs=${OUTPUT_SRS} --profile=mercator --resampling=near --zoom=12 --processes=10 --tilesize=256 --webviewer=none --srcnodata=0,0,0,0 --title=${TITLE} ${TMP1_PATH} ${TILES_PATH}" 
            echo $gd2t
            eval "$gd2t"
        else
            if [[ "$YR_PLANTED" == "true" ]]; then
                echo "\n${YYYY} ${ATTRIBUTE} - attribute_type:${TYPE} / colorinterp:${COLORINTERP} / yr_planted available:${YR_PLANTED}"
                echo "***ATTRIBUTE ${ATTRIBUTE} CURRENTLY NOT SUPPORTED FOR RASTERIZATION***"

                ## Rasterize the attribute to the GeoTIFF file
                #if [ ! -f "${ATTRIBUTE_TIF_PATH}" ]; then

                #    echo "\nRasterizing ${ATTRIBUTE} to ${ATTRIBUTE_TIF_PATH}"
                #    GDAL_CMD="gdal_rasterize -l ${CA_CROP_FLATGEOBUF_NAME} -a ${ATTRIBUTE} -tr ${res} ${res} -te ${x_min} ${y_min} ${x_max} ${y_max} -ot ${TYPE} -a_nodata -9999 -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES ${CA_CROP_FLATGEOBUF_PATH} ${ATTRIBUTE_TIF_PATH}"
                #    echo $GDAL_CMD
                #    eval "${GDAL_CMD}"
                #    # Add the raster to the list of TIFs
                #    TIF_LIST+=(${ATTRIBUTE_TIF_PATH})

                #else

                #    echo "${ATTRIBUTE_TIF_PATH} already exists."
                #    TIF_LIST+=(${ATTRIBUTE_TIF_PATH})

                #fi
            fi
        fi

        # If this is the last attribute ...
        if [[ $ATTRIBUTE == ${ATTRIBUTES[-1]} ]]; then

            # ############################################
            # ###### STACK RASTERS INTO VRT AND TIF #####
            # ############################################
            echo "\nStacking rasters into ${FINAL_VRT_PATH}"
            echo "Rasters to be stacked: ${TIF_LIST}"

            # Build VRT
            echo "\nBuilding Stacked VRT: ${FINAL_VRT_PATH}"
            GDAL_BUILD_VRT="gdalbuildvrt -separate ${FINAL_VRT_PATH} ${TIF_LIST}"
            echo $GDAL_BUILD_VRT
            eval "${GDAL_BUILD_VRT}"

            # Stack TIF
            echo "\nBuilding Stacked TIF: ${FINAL_TIF_PATH}"
            GDAL_STACK="gdal_translate -of GTiff -co COMPRESS=DEFLATE -co BIGTIFF=YES ${FINAL_VRT_PATH} ${FINAL_TIF_PATH}"
            echo $GDAL_STACK
            eval "${GDAL_STACK}"
            
            # Apply color table to final raster
            #echo "\nApplying color table to final raster"
            #GDAL_COLOR_TABLE="gdalattachpct.py ${CDL_RASTER_PATH} ${FINAL_TIF_PATH} ${FINAL_TIF_PATH}"
            #echo $GDAL_COLOR_TABLE
            #eval "${GDAL_COLOR_TABLE}"
        fi
    done
done

