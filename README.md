# <p>  <b>FLASH: Simultaneous Muscle Fiber Typing and Morphometry Analysis</b> </p>

IMAG'IC Core Facility / Institut Cochin

Maxime Di Gallo, Thomas Guilbert & Raphaël Braud-Mussi project

A general intensity quantification macro for FiJi - FiJi Is Just ImageJ.

https://www.researchsquare.com/article/rs-6629157/v1

## Background

Skeletal muscle is a dynamic tissue capable of structural and metabolic remodeling in response to physiological and pathological stimuli. These adaptations are central to understanding the mechanisms underlying conditions such as genetic myopathies, cancer, aging, and recovery from injury. Muscle fiber characterization—assessing fiber type, size, and metabolic profile—is essential for such studies. However, conventional histological methods often rely on serial tissue sections and multiple staining protocols, which are time-consuming, require significant biological material, and introduce methodological bias.

## Methods

We developed FLASH (Fluorescence-based Labeling for Assessing Skeletal muscle Histology), a novel methodology combining enzymatic (SDH or GPDH) and quadruple fluorescent labeling (Laminin, MYH4, MYH2, MYH7) on a single muscle section. The resulting images were analyzed using a custom macro in Fiji/ImageJ, integrating the Cellpose segmentation algorithm. This automated pipeline detects individual muscle fibers, quantifies their cross-sectional area (CSA), identifies fiber types based on myosin isoform expression, and measures enzymatic staining intensity. Batch analysis was implemented to process entire image folders automatically. Validation was performed by comparing automated fiber detection with expert manual segmentation using correlation analysis and Bland-Altman plots.

## Results

The FLASH method allowed simultaneous assessment of both contractile and metabolic properties within individual fibers on the same section, removing the need for serial cuts. The automated image analysis achieved high accuracy in fiber detection (r > 0.95 compared to manual annotation) and produced consistent CSA and fiber-type quantification, even under suboptimal staining conditions. The macro enabled significant time savings by automating the complete analysis workflow, including ROI generation and Excel data export for each image.

## Conclusions

FLASH provides an efficient and robust tool for high-throughput skeletal muscle histology. By combining enzymatic and fluorescent co-labeling with machine learning-based image analysis, this method improves reproductibility, reduces experimental complexity, and minimizes user bias. FLASH is particularly well-suited for large-scale or longitudinal studies investigating muscle adaptation in health and disease.

---

## Installation Guide
#### Note: A test dataset with sample images is available at the end of this document to validate your installation and test the FLASH workflow.
### System Requirements

- **Operating System:** Windows 10/11 (x64), macOS 10.15+, or Linux Ubuntu 18.04+
- **RAM:** 8 GB minimum (16 GB recommended)
- **Disk Space:** 5 GB free space
- **Graphics Card:** NVIDIA (optional, for GPU acceleration)
- **Administrator Rights:** Required only for GPU/CUDA installation

### A. GPU Setup (Windows only - optional)

**Graphics Card Verification:**
1. Open Task Manager (`Ctrl + Shift + Esc`) → Performance tab → GPU
2. **Compatible:** NVIDIA GTX 10xx, RTX series, or newer (6 GB+ VRAM recommended)
3. **Not compatible:** GTX 900 series or older, AMD cards

**CUDA Toolkit 11.8 Installation (Administrator rights required):**
1. Download from: https://developer.nvidia.com/cuda-11-8-0-download-archive
2. Select: Windows → x86_64 → 10/11 → exe (local)
3. Run as administrator, choose "Custom installation" if offered
4. Restart computer after installation
5. Verify: Open cmd and type `nvcc --version`

### B. FIJI/ImageJ Installation and Configuration

**Installation:**
1. Download FIJI from https://imagej.net/software/fiji/downloads
2. Extract to folder (e.g., `C:\Fiji` or `/Applications/Fiji.app`)
3. Launch FIJI to verify installation

**Plugin Configuration:**
1. In FIJI: `Help → Update...`
2. Click "Manage update sites"
3. **Enable these update sites:**
   - ✅ IBMP-CNRS
   - ✅ ImageScience
   - ✅ PTBIOP
4. Click `Close → Apply changes`
5. **Restart FIJI** after installation

### C. Python Environment and Cellpose Installation

**Miniconda Installation:**
1. Download from https://repo.anaconda.com/miniconda/
   - **Windows:** Miniconda3-latest-Windows-x86_64.exe
   - **macOS:** Miniconda3-latest-MacOSX-x86_64.pkg
   - **Linux:** Miniconda3-latest-Linux-x86_64.sh
2. Install (Windows: check "Add to PATH")
3. Restart terminal/command prompt

**Cellpose Environment Setup:**

Open terminal/command prompt and execute:

```bash
# Configure Conda
conda config --set auto_activate_base false
conda config --set channel_priority flexible
conda config --set solver libmamba
conda info

# Clean and create environment
conda env remove -n cellpose -y
conda clean --all -y
conda create -n cellpose python=3.8 -y
conda activate cellpose
```

**Install Cellpose (choose your configuration):**

For **GPU** (Windows with NVIDIA):
```bash
pip install cellpose==3.1.1.2
pip install torch==1.13.1+cu118 torchvision==0.14.1+cu118 torchaudio==0.13.1 --index-url https://download.pytorch.org/whl/cu118 --no-cache-dir
```

For **CPU only** (Linux or Windows without GPU):
```bash
pip install cellpose==3.1.1.2
pip install torch==1.13.1.1+cpu torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --no-cache-dir
```
For **MAC** :
```bash
conda install -c conda-forge numpy=1.24.3 scipy matplotlib -y conda install -c conda-forge opencv scikit-image imageio numba -y  
conda install -c conda-forge imagecodecs -y
pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2
pip install cellpose==3.1.1.2
```

**Common dependencies:**
```bash
pip install numpy==1.24.3 opencv-python-headless scikit-image imageio matplotlib scipy numba
```

**Verify Installation:**
```bash
# Basic test
python -c "import cellpose; print('Cellpose successfully installed!')"

# GPU test (Windows with NVIDIA only)
python -c "import torch; print('CUDA available:', torch.cuda.is_available())"

# Cellpose GPU test
python -c "from cellpose import models; model = models.Cellpose(gpu=True); print('Cellpose GPU: OK' if model.gpu else 'GPU not available')"
```

### D. Cellpose Plugin Configuration in FIJI

1. In FIJI: open any image
2. Go to `Plugins → BIOP → Cellpose/Omnipose → Cellpose...`
3. **Verify parameters:**
   - ✅ `--use_gpu` is present (add if missing)
   - ❌ `--do_3d` should NOT be present (remove if present)

### E. FLASH Macro Installation

1. Save the FLASH macro code in a file named `FLASH.ijm`
2. **Place in FIJI's plugins folder:**
   - **Windows:** `C:\Fiji\plugins\`
   - **macOS:** `/Applications/Fiji.app/plugins/`
   - **Linux:** `/path/to/fiji/plugins/`
3. **Restart FIJI**
4. Access via `Plugins → FLASH` or `Plugins → Macros → Run...`

### F. Image Preparation Requirements

**Format specifications:**
- **Format:** .tif or .tiff only
- **Type:** Multi-channel images (3-5 channels recommended)
- **Resolution:** Minimum 1024×1024 pixels
- **Depth:** 8-bit or 16-bit

**Channel organization example:**
1. **Channel 1:** Type IIb (MYH4) - optional
2. **Channel 2:** Laminin (membranes) - **required for segmentation**
3. **Channel 3:** Type I (MYH7) - optional
4. **Channel 4:** SDH (Oxidative) - optional
5. **Channel 5:** Type IIa (MYH2) - optional

**Folder preparation:**
- Create analysis folder and copy all images
- Ensure identical channel organization across all images
- Verify all files are in .tif format

---

## FLASH Utilization

Once the image preparation step is done as mentioned in the article, and Cellpose plugin installed, the macro can be run.

The analysis begins by filling in the various initial parameters on the user interface, which offers two levels of configuration:

**Basic Configuration:**
The user defines parameters such as:
- **Total number of channels** in the image (e.g., 5)
- **Laminin channel** for fiber segmentation (e.g., channel 2)
- **Specific channels for each fiber type** (Type I, IIa, IIx, IIb, and other customizable channels - in this case, we have used SDH)
- **Expected mean diameter** of the fibers (default: 60 pixels) - modify this first if segmentation needs optimization
- **Auto-calibrate diameter** option (recommended)

**Advanced Settings (Optional):**
An optional checkbox gives access to advanced settings such as:
- Fine-tuning of Cellpose sensitivity
- Exclusion thresholds for small and large structures
- Adaptive thresholding factor for classification
- Filtering options and GPU-related performance settings

**Processing:**
Once all desired parameters have been entered and the "OK" button clicked, the user must select the folder containing the well-prepared images in .TIF format. These images should have consistent channel correspondences for each fiber type and include only the laminin staining within the region of interest.

Upon folder selection, the FLASH software will automatically process each image sequentially, performing the analysis and saving the results in the original folder. The output files will be named by appending identifiers to the original image filenames, ensuring traceability without requiring further user intervention.

**Output Files (per image):**
- `ImageName_Final.tif` - Image with colored overlay
- `ImageName_Classified_Results.csv` - Classification results
- `ImageName_ROI_Set.zip` - Regions of interest
- `ImageName_cellposeMask.tif` - Segmentation mask

The process concludes with a confirmation message indicating successful completion.

---

## Troubleshooting

**Common Issues:**

- **CUDA Error:** Check graphics card compatibility, reinstall CUDA Toolkit 11.8, restart computer
- **Cellpose not working:** Verify environment activation with `conda activate cellpose`
- **Images not detected:** Check .tif/.tiff format and channel organization
- **Poor segmentation:** Adjust mean diameter parameter (first parameter to modify)
- **Memory issues:** Use smaller image batches, close unnecessary applications

---

## References

- Cellpose in QuPath: https://forum.image.sc/t/cellpose-in-qupath-qupath-extension-cellpose/58901/24
- PTBIOP plugin for Fiji: https://c4science.ch/w/bioimaging_and_optics_platform_biop/image-processing/imagej_tools/update-site/
- Cellpose wrapper for Fiji: https://github.com/BIOP/ijl-utilities-wrappers#ib-fiji---cellpose-wrapper
- Cellpose installation guide: https://github.com/MouseLand/cellpose?tab=readme-ov-file#gpu-version-cuda-on-windows-or-linux

**Protocol tested on:** Windows 10/11, macOS 12+, Ubuntu 20.04+  
**Version:** FLASH v3.1 – July 2025

---

## Test Dataset

**Sample images for testing and demonstration:** Di Gallo, M. (2025). myoFLASH_Dataset . Institut Cochin. https://doi.org/10.57889/J4RZ-JC76
