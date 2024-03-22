from google.cloud import storage as gcs
from sh import Command, gdal_translate, gsutil, rm

# example_url = "https://www.nass.usda.gov/Research_and_Science/Cropland/Release/datasets/2022_30m_cdls.zip"
_BASE_URL = "https://www.nass.usda.gov/Research_and_Science/Cropland/Release/datasets"

_TIF_BUCKET = "acretrader-ds.appspot.com"
_TIF_PATH = "geotiffs/cdl"

_TILE_BUCKET = "acremaps"
_TILE_PATH = "tiles/cdl/{year}"


def gcs_push_tif(tif_name):
    client = gcs.Client()
    client.bucket(_TIF_BUCKET).blob(f"{_TIF_PATH}/{tif_name}").upload_from_filename(tif_name)
    client.close()


def gcs_push_tiles(year, tile_path):
    print(f"Syncing PNG tiles to GCS ...", flush=True)
    gsync = gsutil.bake("-m", "rsync", "-r")
    gsync(year, tile_path)
    rm("-r", year)  # Garbage Collection


def png_tiles(tif_name, year):
    # Arrange commands
    tmp = ["tmp0.vrt", "tmp1.vrt"]
    gd_t_A = gdal_translate.bake("-q", "-strict", "-of", "vrt")
    gd_t_B = gdal_translate.bake("-q", "-of", "vrt", "-expand", "rgba")
    gd2t = Command("gdal2tiles.py").bake(
        "-q",
        "--resume",
        "--exclude",
        "--s_srs=epsg:5070",
        "--profile=mercator",
        "--resampling=near",
        "--zoom=12",
        "--processes=10",
        "--tilesize=256",
        # "--tiledriver=PNG", # need gdal2tiles version 3.6
        "--webviewer=none",
        "--srcnodata=0,0,0,0",
        "--title=2022_CDL",
    )
    tile_path = f"gs://{_TILE_BUCKET}/{_TILE_PATH.format(year=year)}"
    # Make tiles
    print(f"Creating PNG tiles ...", flush=True)
    gd_t_A(tif_name, tmp[0])
    gd_t_B(tmp[0], tmp[1])
    gd2t(tmp[1], year)
    #rm(*tmp)  # Garbage Collection
    # Push tiles
    #gcs_push_tiles(year, tile_path)
