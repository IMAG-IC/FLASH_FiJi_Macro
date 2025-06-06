# <p>  <b>FLASH</b> </p>

IMAG'IC Core Facility / Institut Cochin

Maxime Di Gallo & Thomas Guilbert project

A general intensity quantification macro for FiJi - FiJi Is Just ImageJ.



A. Installing Cellpose

  Cellpose3’s installation should be performed via Anaconda3
    (https://www.anaconda.com/download#downloads), please refer to the cellpose3.1 installation
    guide: https://github.com/MouseLand/cellpose?tab=readme-ov-file#gpu-version-cuda-on-windows-
    or-linux

B. Installing Cellpose Plugins

1. Fiji

    Installation:

     Use the PTBIOP plugin for Cellpose2 in Fiji. This requires enabling additional update sites:

     Go to [Help] > [Update…], restart Fiji if prompted.

     In the Image Updater, select [Manage Update Sites] and enable:

     IBMP-CNRS

     ImageScience

     PTBIOP

     Close the updater and restart Fiji.

    Configuration and Use:

     Set the path to your Cellpose2 environment (commonly C:\Users\YourUser\anaconda3\envs or C:\Users\YourUser\.conda\envs).

     In Fiji, go to Plugins > BIOP > Cellpose > Cellpose setup...

     Set environment type to “conda” and specify the Cellpose2 environment path (e.g., C:\Users\YourUser\anaconda3\envs\cellpose2).

     Version: 2.0. Enable “UseResample” for large images (2048x2048) to smooth ROIs.

2. QuPath

    Installation:

     Download QuPath and the Cellpose extension (v0.7.0).

     Extract the extension and drag-and-drop it into the QuPath application. Leave the extension file as default.

     To find the extension folder, go to Extensions > Installed extensions in QuPath. The path is displayed under the BIOP Cellpose extension.

    Configuration:

     Set the path to your Cellpose2 environment (usually C:\Users\YourUser\anaconda3\envs).

     In QuPath, go to Edit > Preferences… and under Cellpose/Omnipose, specify the location of your Cellpose2 Python environment.

     Close the window after setting the path; no need to save.

References:

  Cellpose in QuPath: https://forum.image.sc/t/cellpose-in-qupath-qupath-extension-cellpose/58901/24

  PTBIOP plugin for Fiji: https://c4science.ch/w/bioimaging_and_optics_platform_biop/image-processing/imagej_tools/update-site/

  Cellpose wrapper for Fiji: https://github.com/BIOP/ijl-utilities-wrappers#ib-fiji---cellpose-wrapper


C. FLASH utilization

Once the image preparation step is done as mentioned in the article, and Cellpose plugin installed, the macro can be run. 

The analysis begins by filling in the various initial parameters on the user interface, which offers two levels
of configuration:

Concerning the basic configuration, the user defines parameters such as the total number of channels
in the image, here 5, the laminin channel that will be used for fiber segmentation, here number 2, the
specific channels for each fiber type (Type I, IIa, IIx, IIb, and other customizable channels - in this case,
we have used SDH), as well as the expected mean diameter of the fibers, which is set at 60 pixels by
default, but when the segmentation is not as good as expected, this is the first parameter to modify
to optimize the tissue segmentations.

An optional checkbox gives access to advanced setings such as fine-tuning of Cellpose sensitivity,
exclusion thresholds for small and large structures, an adaptive thresholding factor for classification,
as well as filtering options and GPU-related performance setings, if you want to refine your analysis.

Once all the desired parameters have been entered and the "OK" button clicked, the user must select
the folder containing the well-prepared images in .TIF format. These images should have consistent
channel correspondences for each fiber type and include only the laminin staining within the region
of interest. Upon folder selection, the FLASH software will automatically process each image
sequentially, performing the analysis and saving the results in the original folder. The output files will
be named by appending identifiers to the original image filenames, ensuring traceability without
requiring further user intervention. The process concludes with a confirmation message indicating
successful completion.
