import os
from sys import argv, exit

from google.cloud import storage as gcs
from sh import gdalbuildvrt, rm
import utils


def crop_rotation():
    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        if os.path.exists("/run/secrets/gcp_creds"):
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/run/secrets/gcp_creds"
        else:
            print("Please provide 'GOOGLE_APPLICATION_CREDENTIALS'")
            exit(1)
    client = gcs.Client()
    end_year = argv[1]
    start_year = int(end_year) - 2
    source_tifs = [f"{i}_30m_cdls.tif" for i in range(start_year, start_year + 3, 1)]
    list_file = "tmp.txt"
    out_vrt = f"{start_year}-{end_year[-2:]}_30m_3Yrot.vrt"
    vrt_path = f"{utils._TIF_PATH}/{out_vrt}"
    blob_ids = [
        blob.id
        for blob in client.list_blobs(utils._TIF_BUCKET, prefix=utils._TIF_PATH)
        if utils._TIF_PATH in blob.id and any([src in blob.id for src in source_tifs])
    ]
    blob_paths = sorted(
        ["/".join(["/vsigs"] + blob_id.split("/")[:-1]) for blob_id in blob_ids]
    )
    with open(list_file, "w") as FILE:
        _ = [print(p, file=FILE) for p in blob_paths]
    gdalbuildvrt(
        "-separate",
        "-input_file_list",
        list_file,
        out_vrt,
    )
    client.bucket(utils._TIF_BUCKET).blob(vrt_path).upload_from_filename(out_vrt)
    rm(list_file, out_vrt)

if __name__ == "__main__":
    crop_rotation()
