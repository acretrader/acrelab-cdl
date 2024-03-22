import os
import sys

import rasterio
from osgeo import gdal, ogr

# CONSTANTS/INPUTS
REFERENCE_RASTER = "/home/kenny/repos/cdl/cdl_california_crop_merge/2022/geotiffs_cdl_2022_30m_cdls_original.tiff"
INPUT_FILE = "/home/kenny/repos/cdl/cdl_california_crop_merge/2022/ca_crop_2022.fgb"
OUTPUT_DIR = "/home/kenny/repos/cdl/cdl_california_crop_merge/2022/"
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
    print()
    print()
    print()
    print()

    print(attribute_name)
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

    print(ref_ds.RasterXSize)
    print(ref_ds.RasterYSize)
    print(ref_ds.GetGeoTransform())
    print(ref_ds.GetProjection())

    # Create a raster GeoTIFF file with the same extent, resolution, and pixel alignment as the reference raster
    raster_ds = gdal.GetDriverByName("GTiff").Create(
        output_file,
        ref_ds.RasterXSize,
        ref_ds.RasterYSize,
        1,
        attribute_dtype,
        options=["COMPRESS=DEFLATE", "BIGTIFF=YES"],
    )
    print(raster_ds.GetRasterBand(1).GetMetadata())

    ## Set the geotransform using the reference raster
    #raster_ds.SetGeoTransform(ref_ds.GetGeoTransform())

    ## Set the projection
    #raster_ds.SetProjection(ref_ds.GetProjection())

    ## Rasterize the attribute to the GeoTIFF file
    #band = raster_ds.GetRasterBand(1)
    #gdal.RasterizeLayer(raster_ds, [1], layer, options=["ATTRIBUTE=" + attribute_name])

    ## Set ColorInterp to something other than "gray" (e.g., "Red", "Green", "Blue", "Palette", etc.)
    #band.SetColorInterpretation(attribute_colorinterp)  # Change GCI_RedBand to the desired interpretation

    ## Close datasets
    raster_ds = None
    data_source = None
    ref_ds = None
    return

#def raster_difference(raster1_path, raster2_path, output_path):
#    # Open the input raster files
#    raster1 = gdal.Open(raster1_path)
#    raster2 = gdal.Open(raster2_path)
#    print(raster1)
#    print(raster2)
#
#    # Get raster band 1 from both rasters
#    band1_raster1 = raster1.GetRasterBand(1)
#    band1_raster2 = raster2.GetRasterBand(1)
#
#    # Get raster dimensions
#    width = raster1.RasterXSize
#    height = raster1.RasterYSize
#
#    # Create output raster
#    driver = gdal.GetDriverByName('GTiff')
#    output_raster = driver.Create(output_path, width, height, 1, gdal.GDT_Byte)
#    output_raster.SetProjection(raster1.GetProjection())
#    output_raster.SetGeoTransform(raster1.GetGeoTransform())
#
#    # Compute difference between bands
#    for y in range(height):
#        data1 = band1_raster1.ReadAsArray(0, y, width, 1)
#        data2 = band1_raster2.ReadAsArray(0, y, width, 1)
#        diff = data1 != data2
#        output_raster.GetRasterBand(1).WriteArray(diff, 0, y)
#
#    # Close raster datasets
#    output_raster = None
#    raster1 = None
#    raster2 = None
#    return


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


from osgeo import gdal

def overwrite_raster_values(raster_a_path, raster_b_path, output_path):
    # Open RasterA
    raster_a_ds = gdal.Open(raster_a_path, gdal.GA_ReadOnly)
    if raster_a_ds is None:
        raise FileNotFoundError(f"RasterA '{raster_a_path}' not found.")

    # Open RasterB
    raster_b_ds = gdal.OpenEx(raster_b_path, gdal.GA_Update, open_options=['IGNORE_COG_LAYOUT_BREAKS=YES'])
    #raster_b_ds = gdal.Open(raster_b_path, gdal.GA_Update, open_options=['IGNORE_COG_LAYOUT_BREAKS=YES'])
    if raster_b_ds is None:
        raise FileNotFoundError(f"RasterB '{raster_b_path}' not found.")

    # Get raster dimensions
    cols = raster_b_ds.RasterXSize
    rows = raster_b_ds.RasterYSize

    # Create output raster
    driver = gdal.GetDriverByName('GTiff')
    output_ds = driver.Create(output_path, cols, rows, 1, gdal.GDT_Float32)  # Change GDT_Float32 to match your data type
    output_ds.SetProjection(raster_b_ds.GetProjection())
    output_ds.SetGeoTransform(raster_b_ds.GetGeoTransform())

    # Iterate through each pixel in RasterB
    for y in range(rows):
        for x in range(cols):
            # Read pixel value from RasterB
            raster_b_value = raster_b_ds.GetRasterBand(1).ReadAsArray(x, y, 1, 1)[0][0]

            # Check if the pixel in RasterB has valid data
            if raster_b_value != raster_b_ds.GetRasterBand(1).GetNoDataValue():
                # Get corresponding pixel value from RasterA
                raster_a_value = raster_a_ds.GetRasterBand(1).ReadAsArray(x, y, 1, 1)[0][0]

                # Write pixel value from RasterA to output raster
                output_ds.GetRasterBand(1).WriteArray([[raster_a_value]], x, y)

    # Close datasets
    raster_a_ds = None
    raster_b_ds = None
    output_ds = None

    print(f"Raster values overwritten successfully. Output saved to '{output_path}'.")


if __name__ == "__main__":

    print('we are in main')

    #for attribute_name in ATTRIBUTE_NAMES.keys():
    #    attribute_dtype = ATTRIBUTE_NAMES[attribute_name]["dtype"]
    #    attribute_colorinterp = ATTRIBUTE_NAMES[attribute_name]["colorinterp"]
    #    output_file = f"{OUTPUT_DIR}{attribute_name}.tif"
    #    create_geotiff(
    #        INPUT_FILE, output_file, attribute_name, attribute_dtype, attribute_colorinterp, REFERENCE_RASTER 
    #    )

    ## Example usage
    #raster1_path = '/home/kenny/repos/cdl/cdl_california_crop_merge/2022/geotiffs_cdl_2022_30m_cdls_test.tiff'
    #raster2_path = '/home/kenny/repos/cdl/cdl_california_crop_merge/2022/cdl_crop_id2.tif'
    #output_path = '/home/kenny/repos/cdl/cdl_california_crop_merge/2022/gdal_calc_cdl_ca_diff_test.tif'
    #raster_difference(raster1_path, raster2_path, output_path)
    #print("Rasterization completed.")

    # Example usage
    raster_a_path = "/home/kenny/repos/cdl/cdl_california_crop_merge/2022/cdl_crop_id2.tif"
    raster_b_path = "/home/kenny/repos/cdl/cdl_california_crop_merge/2022/geotiffs_cdl_2022_30m_cdls_test.tiff"
    output_path = "/home/kenny/repos/cdl/cdl_california_crop_merge/2022/merge_test.tif"
    
    overwrite_raster_values(raster_a_path, raster_b_path, output_path)
    
