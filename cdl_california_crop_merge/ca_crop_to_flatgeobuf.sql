WITH croptyp1 AS (
    SELECT
        crop.uniqueid,
        crop.recording_year,
        NULLIF(crop.yr_planted, 0) as yr_planted,
        crop.class,
        crop.subclass,
        crop.crop_key,
        crop.crop_type,
        crop.class_name,
        crop.subclass_name,
        crop.cdl_crop_id
    FROM california_crop_202403.california_crop_flat AS crop
    WHERE crop.crop_type = 'croptyp1'
        AND crop.recording_year = '2022'
),
croptyp2 AS (
    SELECT
        crop.uniqueid,
        crop.recording_year,
        NULLIF(crop.yr_planted, 0) as yr_planted,
        crop.class,
        crop.subclass,
        crop.crop_key,
        crop.crop_type,
        crop.class_name,
        crop.subclass_name,
        crop.cdl_crop_id
    FROM california_crop_202403.california_crop_flat AS crop
    WHERE crop.crop_type = 'croptyp2'
        AND crop.recording_year = '2022'
),
croptyp3 AS (
    SELECT
        crop.uniqueid,
        crop.recording_year,
        NULLIF(crop.yr_planted, 0) as yr_planted,
        crop.class,
        crop.subclass,
        crop.crop_key,
        crop.crop_type,
        crop.class_name,
        crop.subclass_name,
        crop.cdl_crop_id
    FROM california_crop_202403.california_crop_flat AS crop
    WHERE crop.crop_type = 'croptyp3'
        AND crop.recording_year = '2022'
),
croptyp4 AS (
    SELECT
        crop.uniqueid,
        crop.recording_year,
        NULLIF(crop.yr_planted, 0) as yr_planted,
        crop.class,
        crop.subclass,
        crop.crop_key,
        crop.crop_type,
        crop.class_name,
        crop.subclass_name,
        crop.cdl_crop_id
    FROM california_crop_202403.california_crop_flat AS crop
    WHERE crop.crop_type = 'croptyp4'
        AND crop.recording_year = '2022'
)
SELECT
    croptyp1.uniqueid,
    croptyp1.recording_year,
    croptyp1.yr_planted,
    croptyp1.crop_key as crop_key1,
    croptyp1.class_name as class_name1,
    croptyp1.subclass_name as subclass_name1,
    croptyp1.cdl_crop_id as cdl_crop_id1,
    croptyp2.crop_key as crop_key2,
    croptyp2.class_name as class_name2,
    croptyp2.subclass_name as subclass_name2,
    croptyp2.cdl_crop_id as cdl_crop_id2,
    croptyp3.crop_key as crop_key3,
    croptyp3.class_name as class_name3,
    croptyp3.subclass_name as subclass_name3,
    croptyp3.cdl_crop_id as cdl_crop_id3,
    croptyp4.crop_key as crop_key4,
    croptyp4.class_name as class_name4,
    croptyp4.subclass_name as subclass_name4,
    croptyp4.cdl_crop_id as cdl_crop_id4,
    ST_Transform(boundary.geometry, 5070) as geometry
FROM croptyp1
LEFT JOIN croptyp2 ON croptyp1.uniqueid = croptyp2.uniqueid
LEFT JOIN croptyp3 ON croptyp1.uniqueid = croptyp3.uniqueid
LEFT JOIN croptyp4 ON croptyp1.uniqueid = croptyp4.uniqueid
JOIN california_crop_202403.california_crop_boundary AS boundary ON croptyp1.uniqueid = boundary.uniqueid
WHERE boundary.recording_year = '2022'
;

