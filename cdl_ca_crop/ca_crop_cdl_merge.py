import os
import sys

import rasterio
from osgeo import gdal, ogr

# CONSTANTS/INPUTS
REFERENCE_RASTER = "/home/kenny/repos/cdl/cdl_ca_crop/geotiffs_cdl_2022_30m_cdls_original.tiff"
INPUT_FILE = "/home/kenny/repos/cdl/cdl_ca_crop/2022/ca_crop_2022.fgb"
OUTPUT_DIR = "/home/kenny/repos/cdl/cdl_ca_crop/"
ATTRIBUTE_NAMES = {
    "yr_planted": {"dtype": gdal.GDT_Int32, "colorinterp": gdal.GCI_GrayIndex},
    "cdl_crop_id1": {"dtype": gdal.GDT_Byte, "colorinterp": gdal.GCI_PaletteIndex},
    "cdl_crop_id2": {"dtype": gdal.GDT_Byte, "colorinterp": gdal.GCI_PaletteIndex},
    "cdl_crop_id3": {"dtype": gdal.GDT_Byte, "colorinterp": gdal.GCI_PaletteIndex},
    "cdl_crop_id4": {"dtype": gdal.GDT_Byte, "colorinterp": gdal.GCI_PaletteIndex},
}


# FUNCTIONS
def create_geotiff(input_file, output_file, attribute_name, attribute_dtype, attribute_colorinterp, reference_raster):
    """
    Create a GeoTIFF file from a FlatGeoBuf file.

    Args:
    - input_file (str): The path to the FlatGeoBuf file.
    - output_file (str): The path to the output GeoTIFF file.
    - attribute_name (str): The name of the attribute to rasterize.
    - attribute_dtype (int): The data type of the attribute (e.g., gdal.GDT_Byte, gdal.GDT_UInt16, gdal.GDT_Int32, etc.).
    - attribute_colorinterp (int): The color interpretation of the attribute (e.g., gdal.GCI_GrayIndex, gdal.GCI_PaletteIndex, etc.).
    - reference_raster (str): The path to the reference raster file.
    """

    # Open the FlatGeoBuf file
    data_source = ogr.Open(input_file)

    if data_source is None:
        print("Error: Could not open the FlatGeoBuf file.")
        return

    # Get the layer
    layer = data_source.GetLayer()

    # Open the reference raster to get its geotransform and spatial reference
    ref_ds = gdal.Open(reference_raster)
    if ref_ds is None:
        print("Error: Could not open the reference raster.")
        return

    # Create a raster GeoTIFF file with the same extent, resolution, and pixel alignment as the reference raster
    raster_ds = gdal.GetDriverByName("GTiff").Create(
        output_file,
        ref_ds.RasterXSize,
        ref_ds.RasterYSize,
        1,
        attribute_dtype,
        options=["COMPRESS=DEFLATE", "BIGTIFF=YES"],
    )

    # Set the geotransform using the reference raster
    raster_ds.SetGeoTransform(ref_ds.GetGeoTransform())

    # Set the projection
    raster_ds.SetProjection(ref_ds.GetProjection())

    # Rasterize the attribute to the GeoTIFF file
    band = raster_ds.GetRasterBand(1)
    gdal.RasterizeLayer(raster_ds, [1], layer, options=["ATTRIBUTE=" + attribute_name])

    # Set ColorInterp to something other than "gray" (e.g., "Red", "Green", "Blue", "Palette", etc.)
    band.SetColorInterpretation(attribute_colorinterp)  # Change GCI_RedBand to the desired interpretation

    # Close datasets
    raster_ds = None
    data_source = None
    ref_ds = None


def stack_multiband_raster(attribute_names, output_stacked_file):
    file_list = [attribute + '.tif' for attribute in attribute_names]
    #file_list = [
    #    #'cdl_2022_test.tiff',
    #    "yr_planted.tif",
    #    "cdl_crop_id1.tif",
    #    "cdl_crop_id2.tif",
    #    "cdl_crop_id3.tif",
    #    "cdl_crop_id4.tif",
    #]

    # Read metadata of first file
    with rasterio.open(file_list[0]) as src0:
        meta = src0.meta

    # Update meta to reflect the number of layers
    meta.update(count=len(file_list), compress="deflate", bigtiff="yes")

    # Create the stack dataset
    with rasterio.open(output_stacked_file, "w", **meta) as dst:
        for id, layer in enumerate(file_list, start=1):
            with rasterio.open(layer) as src1:
                # Read all bands and write to the corresponding band in the output file
                for band_idx in range(1, src1.count + 1):
                    band_data = src1.read(band_idx)
                    dst.write(band_data, indexes=id)


    # file_list = [
    #     'cdl_2022_test.tiff',
    #     'yr_planted.tif',
    #     'cdl_crop_id1.tif',
    #     'cdl_crop_id2.tif',
    #     'cdl_crop_id3.tif',
    #     'cdl_crop_id4.tif'
    # ]

    # # Read metadata of first file
    # with rasterio.open(file_list[0]) as src0:
    #     meta = src0.meta

    # # Update meta to reflect the number of layers
    # meta.update(count = len(file_list))

    # # Read each layer and write it to stack
    # with rasterio.open('stack.tif', 'w', **meta) as dst:
    #     for id, layer in enumerate(file_list, start=1):
    #         with rasterio.open(layer) as src1:
    #             dst.write_band(id, src1.read(1))


if __name__ == "__main__":

    print('we are in main')

    for attribute_name in ATTRIBUTE_NAMES.keys():
        print(attribute_name)
        attribute_dtype = ATTRIBUTE_NAMES[attribute_name]["dtype"]
        attribute_colorinterp = ATTRIBUTE_NAMES[attribute_name]["colorinterp"]
        output_file = f"{OUTPUT_DIR}{attribute_name}.tif"
        create_geotiff(
            INPUT_FILE, output_file, attribute_name, attribute_dtype, attribute_colorinterp, REFERENCE_RASTER 
        )

    #print("Rasterization completed.")

