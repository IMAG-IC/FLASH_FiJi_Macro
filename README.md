# <p>  <b>FLASH: Simultaneous Muscle Fiber Typing and Morphometry Analysis</b> </p>

IMAG'IC Core Facility / Institut Cochin

Maxime Di Gallo & Thomas Guilbert project

A general intensity quantification macro for FiJi - FiJi Is Just ImageJ.

https://www.researchsquare.com/article/rs-6629157/v1

Background:

Skeletal muscle is a dynamic tissue capable of structural and metabolic remodeling in response to physiological and pathological stimuli. These adaptations are central to understanding the mechanisms underlying conditions such as genetic myopathies, cancer, aging, and recovery from injury. Muscle fiber characterization—assessing fiber type, size, and metabolic profile—is essential for such studies. However, conventional histological methods often rely on serial tissue sections and multiple staining protocols, which are time-consuming, require significant biological material, and introduce methodological bias.

Methods:

We developed FLASH (Fluorescence-based Labeling for Assessing Skeletal muscle Histology), a novel methodology combining enzymatic (SDH or GPDH) and quadruple fluorescent labeling (Laminin, MYH4, MYH2, MYH7) on a single muscle section. The resulting images were analyzed using a custom macro in Fiji/ImageJ, integrating the Cellpose segmentation algorithm. This automated pipeline detects individual muscle fibers, quantifies their cross-sectional area (CSA), identifies fiber types based on myosin isoform expression, and measures enzymatic staining intensity. Batch analysis was implemented to process entire image folders automatically. Validation was performed by comparing automated fiber detection with expert manual segmentation using correlation analysis and Bland-Altman plots.

Results:

The FLASH method allowed simultaneous assessment of both contractile and metabolic properties within individual fibers on the same section, removing the need for serial cuts. The automated image analysis achieved high accuracy in fiber detection (r > 0.95 compared to manual annotation) and produced consistent CSA and fiber-type quantification, even under suboptimal staining conditions. The macro enabled significant time savings by automating the complete analysis workflow, including ROI generation and Excel data export for each image.

Conclusions:

FLASH provides an efficient and robust tool for high-throughput skeletal muscle histology. By combining enzymatic and fluorescent co-labeling with machine learning-based image analysis, this method improves reproductibility, reduces experimental complexity, and minimizes user bias. FLASH is particularly well-suited for large-scale or longitudinal studies investigating muscle adaptation in health and disease.

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
