import os
from sys import argv, exit

from sh import rio, rm, unzip, wget
import utils


def cdl():
    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        if os.path.exists("/run/secrets/gcp_creds"):
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/run/secrets/gcp_creds"
        else:
            print("Please provide 'GOOGLE_APPLICATION_CREDENTIALS'")
            exit(1)
    # Arrange paths
    year = argv[1]
    zip_name = f"{year}_30m_cdls.zip"
    unzip_dir = zip_name[:-4]
    in_tif_name = f"{unzip_dir}/{unzip_dir}.tif"
    out_tif_name = f"{unzip_dir}.tif"
    url = f"{utils._BASE_URL}/{zip_name}"
    #print(f"Downloading {year} CDL data ...", flush=True)
    #wget(url)  # Get the data
    #print(f"Unzipping {year} CDL data ...", flush=True)
    #unzip(zip_name, d=unzip_dir)  # Open the data
    #rm(zip_name)  # Garbage collection
    #print(f"Optimizing GeoTIFF for the Cloud ...", flush=True)
    #rio.cogeo.create("--allow-intermediate-compression", in_tif_name, out_tif_name)  # Make the new tif
    #rm("-r", unzip_dir)  # Garbage Collection
    #print(f"Pushing the COG to GCS ...", flush=True)
    #utils.gcs_push_tif(out_tif_name)  # Push tif to GCS
    ## Make PNG tiles
    utils.png_tiles(out_tif_name, year)
    ## Push PNG tiles to GCS
    #rm(out_tif_name)  # Garbage Collection
    print("Done.")


if __name__ == "__main__":
    cdl() 
