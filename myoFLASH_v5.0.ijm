// Maxime Di Gallo & Thomas Guilbert & Raphael Braud-Mussi
// 2025/07/24
//
// myoFLASH_v3.1.ijm
//
// myoFLASH: A general muscle fibers intensity quantification macro for FiJi 
// This macro works by selecting a folder containing only .tif files with multiple channels, including one delineating the outline of the muscle fibres (laminin).
//
// The operation of this macro has been validated with version 3.1.1.2 of Cellpose. To switch to the CellposeSAM version, simply set the "Auto-calibrate diameter"
// parameter to false and set the "FibreDiameter" variable to 60 by default.
//
// Keywords: muscle fibers, muscle metabolism, fiber typing, immunofluorescence, myosin, cellpose, automated analysis
//
// This macro refers to DOI article 10.21203/rs.3.rs-6629157/v1
//
// licence CC BY 4.0
//
//
//
// ===================================================================================================================
// ============================================== STRUCTURE DES FONCTIONS ============================================
// ===================================================================================================================



						
// ============================================ CONFIGURATION ET INTERFACE ===========================================


function showEnhancedDialog() {
    Dialog.create("MyoFLASH Analysis");
    Dialog.addMessage("myoFLASH - Automated Muscle Fiber Analysis", 25, "000000");
    Dialog.addMessage("Channel Configuration", 18, "#8a7cc2");
    Dialog.addNumber("Total number of channels:", 4, 0, 2, "");
    Dialog.addNumber("Laminin channel:", 2, 0, 2, "(delineates fibers)");
	Dialog.addCheckbox("Auto-calibrate diameter", true);
	Dialog.addNumber("Manual fiber diameter:", 60, 0, 3, "pixels (ignored if auto-calibrate is checked)");
	
    Dialog.addMessage("Fiber size measurement", 18, "#8a7cc2");
	Dialog.addChoice("Size measurement method:", newArray("Cross Sectional Area (CSA)", "Minimum Feret Diameter"), "Cross Sectional Area (CSA)");
    
    Dialog.addMessage("Fiber types to analyze", 18, "#8a7cc2");
    Dialog.addNumber("Type IIb channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addNumber("Type IIx channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addNumber("Type IIa channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addNumber("Type I channel:", 0, 0, 2, "(0 = Off)");
    
    Dialog.addMessage("Custom channel (optional)", 18, "#c1666b");
    Dialog.addNumber("Channel number:", 0, 0, 2, "(0 = Off)");
    Dialog.addString("Channel name:", "", 10);
    
    // Advanced options in a collapsible panel
    Dialog.addCheckbox("Show advanced options", false);

    Dialog.show();
    
    // Base values
    totalChannels = Dialog.getNumber();
    LaminineCannal = Dialog.getNumber();
    autoCalibrate = Dialog.getCheckbox();
	manualDiameter = Dialog.getNumber();
	// Autocalibration
	if (autoCalibrate) {
	    FibreDiameter = 0; 
  } else {
	    FibreDiameter = manualDiameter;
  } IIbChannel = Dialog.getNumber();
    IIxChannel = Dialog.getNumber();
    IIaChannel = Dialog.getNumber();
    IChannel = Dialog.getNumber();
    customChannel = Dialog.getNumber();
    customChannelName = Dialog.getString();
    sizeMeasurementMethod = Dialog.getChoice();
    showAdvanced = Dialog.getCheckbox();
    
    // Show advanced parameters
    if (showAdvanced) {
        Dialog.create("Advanced Options");
        
        Dialog.addMessage("Segmentation parameters", 14, "#4285F4");
        Dialog.addSlider("Cellpose sensitivity:", 0.1, 2.0, 1.0);
        Dialog.addSlider("Small fiber exclusion threshold:", 50, 500, 200);
        
        Dialog.addMessage("Classification parameters", 14, "#0F9D58");
        Dialog.addSlider("Adaptive threshold factor:", 0.1, 0.6, 0.3);
        Dialog.addCheckbox("Filter fibers without homogeneous staining", true);
        
        // Détection du système et option GPU
        os = getInfo("os.name");
        isWindowsOrLinux = indexOf(toLowerCase(os), "windows") >= 0 || indexOf(toLowerCase(os), "linux") >= 0;
        
        if (isWindowsOrLinux) {
            Dialog.addMessage("GPU options", 14, "#DB4437");
            Dialog.addCheckbox("Use GPU (CUDA)", true);
            Dialog.addMessage("Note: GPU acceleration requires a CUDA-compatible graphics card");
        }
        
        Dialog.addMessage("Visualization options", 14, "#F4B400");
        Dialog.addCheckbox("Use channel colors for overlay", true);
        Dialog.addSlider("Overlay opacity:", 10, 90, 30);
        
        Dialog.show();
        
        // Advances parameters
        cellposeSensitivity = Dialog.getNumber();
        exclusionThreshold = Dialog.getNumber();
        adaptiveThresholdFactor = Dialog.getNumber();
        filterNonHomogeneous = Dialog.getCheckbox();
        
        if (isWindowsOrLinux) {
            useGPU = Dialog.getCheckbox();
        } else {
            useGPU = false;
        }
        
        useChannelColors = Dialog.getCheckbox();
        overlayOpacity = Dialog.getNumber();
    } else {
        // default values
        cellposeSensitivity = 1.0;
        exclusionThreshold = 200;
        adaptiveThresholdFactor = 0.3;
        filterNonHomogeneous = true;
        useGPU = isWindowsOrLinux;
        useChannelColors = true;
        overlayOpacity = 30;
    }
    
    // All parameters in a table
    params = newArray(totalChannels, LaminineCannal, autoCalibrate, FibreDiameter, 
	               IIbChannel, IIxChannel, IIaChannel, IChannel, 
	               customChannel, customChannelName, sizeMeasurementMethod,
	               cellposeSensitivity, exclusionThreshold, adaptiveThresholdFactor,
	               filterNonHomogeneous, useGPU, useChannelColors, overlayOpacity);
    
    return params;
}

function smallImageProgress(currentFile, totalFiles, step, totalSteps, message) {
    // Calculate progress percentage
    progress = ((currentFile / totalFiles) + (step / (totalSteps * totalFiles))) * 100;
    
    // Save current image ID
    currentID = 0;
    currentTitle = "";
    if (nImages > 0) {
        currentID = getImageID();
        currentTitle = getTitle();
    }
    
    // ===== CRÉER UNE FENÊTRE PLUS GRANDE =====
    // Taille augmentée : 700x280 au lieu de 450x120
    if (!isOpen("Progress")) {
        newImage("Progress", "RGB", 700, 280, 1);
        // Position centrer-haut de l'écran pour mieux voir
        setLocation(screenWidth/2 - 350, 50);
    }
    
    // Select progress image and update
    selectWindow("Progress");
    
    // === FOND DÉGRADÉ (gris clair) ===
    run("Select All");
    setBackgroundColor(245, 245, 245);
    run("Clear", "slice");

	setColor(161, 201, 201); // RGB pour #a1c9c9
	fillRect(0, 0, 700, 35);
    
    // === TITRE ===
    setColor(0, 0, 0);  // Blanc
    setFont("Candara", 25, "bold antialiased");
    drawString("myoFLASH Analysis Running", 180, 25);
    
    // === INDICATEUR "NE FERME PAS" EN GRAS ===
    setColor(200, 50, 50);  // Rouge
    setFont("Candara", 14, "bold antialiased");
    drawString("DO NOT CLOSE ANY WINDOW - Process running...", 25, 60);
    
    // === INFOS FICHIER (violet) ===
    setColor(80, 80, 80);
    setFont("Candara", 14, "bold");
    
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    hourStr = "" + hour; if (hour < 10) hourStr = "0" + hour;
    minuteStr = "" + minute; if (minute < 10) minuteStr = "0" + minute;
    secondStr = "" + second; if (second < 10) secondStr = "0" + second;
    dateStr = dayOfMonth + "/" + month + "/" + year;
    timestamp = hourStr + ":" + minuteStr + ":" + secondStr;
    
    // Afficher avec meilleur spacing
    drawString("File: " + (currentFile+1) + " / " + totalFiles, 35, 95);
    drawString("Step: " + getTaskName(step) + " (" + Math.round(progress) + "%)", 35, 120);
    drawString("Time: " + timestamp, 35, 145);

    // === BARRE DE PROGRESSION GRANDE ET COLORÉE ===
    // Fond de la barre
    setColor(230, 230, 230);
    fillRect(35, 170, 630, 35);
    
    // === GRADIENT BARRE (vert progressif) ===
    // Du vert foncé (#11998e) au vert clair (#38ef7d)
    filledWidth = Math.round(630 * progress / 100);
    for (px = 0; px < filledWidth; px++) {
        progress_bar = px / Math.max(1, filledWidth);
        r_bar = round(17 + (56 - 17) * progress_bar);
        g_bar = round(153 + (239 - 153) * progress_bar);
        b_bar = round(142 + (125 - 142) * progress_bar);
        setColor(r_bar, g_bar, b_bar);
        fillRect(35 + px, 170, 1, 35);
    }
    
    // === BORDURE COLORÉE DE LA BARRE (bordeaux) ===
    setColor(139, 21, 56);  // #8B1538
    drawRect(35, 170, 630, 35);
    
    // === POURCENTAGE CENTRÉ SUR LA BARRE ===
    setColor(50, 50, 50);
    setFont("Candara", 18, "bold antialiased");
    drawString(Math.round(progress) + "%", 355, 195);
    
    // === MESSAGE DE PROGRESSION (bas) ===
    setColor(80, 80, 80);
    setFont("Candara", 16, "");
    drawString("Processing: " + message, 35, 260);
    
    // === BARRE DE STATUS TOUT EN BAS (très fine) ===
    // Fond gris
    setColor(200, 200, 200);
    fillRect(0, 275, 700, 5);
    
    // Remplissage coloré (même gradient que barre principale)
    filledWidthBottom = Math.round(700 * progress / 100);
    for (px = 0; px < filledWidthBottom; px++) {
        progress_bar = px / Math.max(1, filledWidthBottom);
        r_bar = round(17 + (56 - 17) * progress_bar);
        g_bar = round(153 + (239 - 153) * progress_bar);
        b_bar = round(142 + (125 - 142) * progress_bar);
        setColor(r_bar, g_bar, b_bar);
        fillRect(px, 275, 1, 5);
    }
    
    // Back to original image
    if (currentID > 0 && isOpen(currentTitle)) {
        selectWindow(currentTitle);
    } else if (isOpen("Original_For_Analysis")) {
        selectWindow("Original_For_Analysis");
    } else if (isOpen("Originale")) {
        selectWindow("Originale");
    }
    
    // Update status bar too
    showProgress(progress/100);
    showStatus("(" + (currentFile+1) + "/" + totalFiles + ") " + message);
}

function getTaskName(stepNumber) {
    taskNames = newArray("Initializing", "Preparing image", "Configuring Cellpose", "Running Cellpose", 
                         "Processing mask", "Measuring fibers", "Calculating thresholds", 
                         "Classifying fibers", "Creating visualization", "Saving results");
    
    if (stepNumber >= 0 && stepNumber < taskNames.length) {
        return taskNames[stepNumber];
    } else {
        return "Step " + stepNumber;
    }
}


// ============================================== TRAITEMENT D'IMAGES ET SEGMENTATION =======================================


function configureCellpose() {
    // Definir les chemins potentiels pour diffÃ©rents systÃ¨mes d'exploitation
    function getPotentialCellposePaths() {
    os = getInfo("os.name");
    osLower = toLowerCase(os);
    homeDir = getDirectory("home");
    
    potentialPaths = newArray();
    
    // Chemins gÃ©nÃ©riques Windows
    if (indexOf(osLower, "windows") >= 0) {
        potentialPaths = Array.concat(potentialPaths, newArray(
            "C:\\ProgramData\\Anaconda3\\envs\\cellpose",
            "C:\\ProgramData\\Miniconda3\\envs\\cellpose",
            "C:\\ProgramData\\mambaforge\\envs\\cellpose",
            "C:\\ProgramData\\miniforge3\\envs\\cellpose",
            homeDir + "Anaconda3\\envs\\cellpose",
            homeDir + "Miniconda3\\envs\\cellpose",
            homeDir + "mambaforge\\envs\\cellpose",
            homeDir + "miniforge3\\envs\\cellpose",
            homeDir + "AppData\\Local\\Anaconda3\\envs\\cellpose",
            homeDir + "AppData\\Local\\Miniconda3\\envs\\cellpose",
            homeDir + "AppData\\Local\\mambaforge\\envs\\cellpose",
            homeDir + "AppData\\Local\\miniforge3\\envs\\cellpose",
            homeDir + ".conda\\envs\\cellpose"
        ));
    }
    
    // Chemins pour Mac - utilisation de homeDir au lieu de ~/
    if (indexOf(osLower, "mac") >= 0) {
        potentialPaths = Array.concat(potentialPaths, newArray(
            "/opt/homebrew/miniconda3/envs/cellpose",
            homeDir + "miniforge3/envs/cellpose",
            homeDir + "mambaforge/envs/cellpose",
            homeDir + "opt/anaconda3/envs/cellpose",
            homeDir + "opt/miniconda3/envs/cellpose",
            homeDir + "anaconda3/envs/cellpose",
            homeDir + "miniconda3/envs/cellpose",
            homeDir + ".conda/envs/cellpose",
            "/opt/anaconda3/envs/cellpose",
            "/opt/miniconda3/envs/cellpose",
            "/usr/local/anaconda3/envs/cellpose",
            "/usr/local/miniconda3/envs/cellpose",
            "/opt/homebrew/anaconda3/envs/cellpose"
        ));
    }
    
    // Chemins pour Linux - utilisation de homeDir au lieu de ~/
    if (indexOf(osLower, "linux") >= 0) {
        potentialPaths = Array.concat(potentialPaths, newArray(
            homeDir + "miniconda3/envs/cellpose",
            homeDir + "miniforge3/envs/cellpose",
            homeDir + "mambaforge/envs/cellpose",
            homeDir + "anaconda3/envs/cellpose",
            homeDir + ".conda/envs/cellpose",
            homeDir + ".local/share/anaconda3/envs/cellpose",
            homeDir + ".local/share/miniconda3/envs/cellpose",
            "/opt/conda/envs/cellpose",
            "/opt/anaconda3/envs/cellpose",
            "/opt/miniconda3/envs/cellpose",
            "/usr/local/anaconda3/envs/cellpose",
            "/usr/local/miniconda3/envs/cellpose",
            "/home/conda/envs/cellpose"
        ));
    }
    
    return potentialPaths;
}
    
    // Trouver l'environnement Cellpose
function findCellposeEnvironment(paths) {
    homeDir = getDirectory("home");
    
    for (i = 0; i < paths.length; i++) {
        currentPath = paths[i];
        
        // Remplacer %USERPROFILE% de maniÃ¨re sÃ©curisÃ©e
        if (indexOf(currentPath, "%USERPROFILE%") >= 0) {
            // Extraction manuelle sans utiliser replace()
            beforeVar = substring(currentPath, 0, indexOf(currentPath, "%USERPROFILE%"));
            afterVar = substring(currentPath, indexOf(currentPath, "%USERPROFILE%") + 13);
            expandedPath = beforeVar + homeDir + afterVar;
        } else if (startsWith(currentPath, "~/")) {
            // Remplacer les tildes pour Mac/Linux
            expandedPath = homeDir + substring(currentPath, 2);
        } else {
            expandedPath = currentPath;
        }
        
        // VÃ©rifier l'existence du chemin
        if (File.exists(expandedPath)) {
            return expandedPath;
        }
    }
    return "";
}
    
    // RÃ©cupÃ©rer les chemins potentiels
    potentialPaths = getPotentialCellposePaths();
    
    // Trouver l'environnement Cellpose
    condaPath = findCellposeEnvironment(potentialPaths);
    
    // VÃ©rifier si un environnement a Ã©tÃ© trouvÃ©
    if (condaPath == "") {
        exit("Unable to find Cellpose environment. Please check your installation.");
    }
    
    // PrÃ©parer les paramÃ¨tres de base Cellpose
    cellposeParams = "model=cyto2 diameter=" + FibreDiameter + " ch1=" + LaminineCannal + " ch2=0";
    cellposeParams = "env_path=" + condaPath + " env_type=conda " + cellposeParams;
    
    cellposeParams = cellposeParams + " additional_flags=--verbose";
    cellposeParams = cellposeParams + " no_dialog=true";
    cellposeParams = cellposeParams + " batch_mode=true";
    
    // Configuration GPU
    os = getInfo("os.name");
    osLower = toLowerCase(os);
    gpuAvailable = false;
    
    // Tester la disponibilitÃ© du GPU selon le systÃ¨me d'exploitation
    if (indexOf(osLower, "windows") >= 0 || indexOf(osLower, "linux") >= 0) {
    // Essayer de vÃ©rifier la prÃ©sence de CUDA/GPU
    cudaPath = "C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA";
    gpuAvailable = File.exists(cudaPath);
}
    
    // Activer le GPU si disponible et demandÃ©
    if (useGPU && gpuAvailable) {
        cellposeParams += " additional_flags=--use_gpu";
    } else if (useGPU && !gpuAvailable) {
        print("GPU not available. Using CPU.");
    }
    
    return cellposeParams;
}

function testGPUAvailability() {
    // RÃ©cupÃ©rer le nom du systÃ¨me d'exploitation
    os = getInfo("os.name");
    osLower = toLowerCase(os);
    
    // VÃ©rification spÃ©cifique pour Windows et Linux
    if (indexOf(osLower, "windows") >= 0 || indexOf(osLower, "linux") >= 0) {
        // Chemins potentiels pour l'installation CUDA
        cudaPaths = newArray(
            "C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA",
            "C:\\Program Files\\NVIDIA Corporation\\CUDA",
            "/usr/local/cuda"
        );
        
        // VÃ©rifier l'existence des chemins CUDA
        gpuFound = false;
        for (i = 0; i < cudaPaths.length; i++) {
            if (File.exists(cudaPaths[i])) {
                gpuFound = true;
                break;
            }
        }
        
        // Si CUDA est trouvÃ©, supposer que le GPU est disponible sans exÃ©cuter nvidia-smi
        if (gpuFound) {
            return true;
        }
    }
    
    // Par dÃ©faut, retourner false
    return false;
}

function getPlatformSafePath(path) {
    // Standardiser la gestion des sÃ©parateurs de chemin
    os = getInfo("os.name");
    if (indexOf(toLowerCase(os), "windows") >= 0) {
        // Windows - s'assurer que les chemins utilisent backslash
        path = replace(path, "/", "\\");
        // S'assurer qu'il y a un backslash Ã  la fin si nÃ©cessaire
        if (!endsWith(path, "\\")) {
            path = path + "\\";
        }
    } else {
        // Mac/Linux - s'assurer que les chemins utilisent slash
        path = replace(path, "\\", "/");
        // S'assurer qu'il y a un slash Ã  la fin si nÃ©cessaire
        if (!endsWith(path, "/")) {
            path = path + "/";
        }
    }
    return path;
}


// ================================================ ANALYSE DE FIBRES ================================================


// Fonction pour calculer la moyenne
function calculateMean(values) {
        sum = 0;
        n = values.length;
        for (i = 0; i < n; i++) {
            sum += values[i];
        }
        return sum / n;
}
	
// Fonction pour calculer l'Ã©cart-type
function calculateStd(values, mean) {
	    sumSquares = 0;
	    n = values.length;
	    for (i = 0; i < n; i++) {
	        diff = values[i] - mean;
	        sumSquares += diff * diff;
	    }
	    return sqrt(sumSquares / (n - 1));
}

// Fonction pour calculer la Median Absolute Deviation
function calculateMAD(values, median) {
    // La MAD est la mÃ©diane des Ã©carts absolus par rapport Ã  la mÃ©diane
    // Elle est robuste aux valeurs aberrantes contrairement Ã  l'Ã©cart-type
    
    deviations = newArray(values.length);
    for (i = 0; i < values.length; i++) {
        deviations[i] = abs(values[i] - median);
    }
    
    mad = calculateMedian(deviations);
    
    // Facteur de correction pour rendre la MAD comparable Ã  l'Ã©cart-type
    // pour une distribution normale : MAD * 1.4826 â‰ˆ Ã©cart-type
    return mad * 1.4826;
}

// Fonction pour calculer la mÃ©diane
function calculateMedian(values) {
    // Handle empty array case
    if (values.length == 0) {
        return 0; // Return 0 or another appropriate default value
    }
    
    temp = Array.copy(values);
    Array.sort(temp);
    n = temp.length;
    if (n % 2 == 0) 
        return (temp[n/2] + temp[(n/2)-1]) / 2;
    else
        return temp[floor(n/2)];
}

// ========== SYSTÈME DE CACHE OPTIMISÉ ==========
// Variables globales pour le cache
var cachedAreas, cachedMeans, cachedStdDevs, cachedMins, cachedMaxs;
var cacheInitialized = false;

function initializeMeasurementCache(imageID) {
    nROIs = roiManager("count");
    
    // Pré-allocation des arrays
    cachedAreas = newArray(nROIs);
    cachedMeans = newArray(nROIs);
    cachedStdDevs = newArray(nROIs);
    cachedMins = newArray(nROIs);
    cachedMaxs = newArray(nROIs);
    
    // MESURE UNIQUE
    selectImage(imageID);
    run("Set Measurements...", "area mean min max standard integrated redirect=None decimal=3");
    roiManager("Deselect");
    roiManager("Measure");
    
    // Transfert dans les arrays
    for (i = 0; i < nROIs; i++) {
        cachedAreas[i] = getResult("Area", i);
        cachedMeans[i] = getResult("Mean", i);
        cachedStdDevs[i] = getResult("StdDev", i);
        cachedMins[i] = getResult("Min", i);
        cachedMaxs[i] = getResult("Max", i);
    }
    
    run("Clear Results");
    cacheInitialized = true;
}

function getCachedArea(roiIndex) {
    if (!cacheInitialized) return 0;
    if (roiIndex < cachedAreas.length) return cachedAreas[roiIndex];
    return 0;
}

function getCachedMean(roiIndex) {
    if (!cacheInitialized) return 0;
    if (roiIndex < cachedMeans.length) return cachedMeans[roiIndex];
    return 0;
}

function getCachedStdDev(roiIndex) {
    if (!cacheInitialized) return 0;
    if (roiIndex < cachedStdDevs.length) return cachedStdDevs[roiIndex];
    return 0;
}

function getCachedMin(roiIndex) {
    if (!cacheInitialized) return 0;
    if (roiIndex < cachedMins.length) return cachedMins[roiIndex];
    return 0;
}

function getCachedMax(roiIndex) {
    if (!cacheInitialized) return 0;
    if (roiIndex < cachedMaxs.length) return cachedMaxs[roiIndex];
    return 0;
}

// Détection de distribution bimodale avec modèle de mélange gaussien simplifié
function detectBimodalDistribution(values) {

    // Variables pour l'algorithme EM
    maxIterations = 30;
    convergenceThreshold = 0.001;
    
    // Initialisation aléatoire des paramètres
    mean = calculateMean(values);
    std = calculateStd(values, mean);
    
    // Initialisation biaisée pour accélérer la convergence
    mu1 = mean - 0.5 * std;
    mu2 = mean + 0.5 * std;
    sigma1 = std;
    sigma2 = std;
    weight1 = 0.5;
    weight2 = 0.5;
    
    // Boucle d'algorithme EM
    converged = false;
    for (iter = 0; iter < maxIterations && !converged; iter++) {
        // Arrays pour stocker les probabilités d'appartenance
        p1 = newArray(values.length);
        p2 = newArray(values.length);
        
        // Étape E: calcul des probabilités d'appartenance
        sumP1 = 0;
        sumP2 = 0;
        
        for (i = 0; i < values.length; i++) {
            // Prob. densité pour chaque gaussienne
            g1 = exp(-0.5 * pow((values[i] - mu1) / sigma1, 2)) / (sigma1 * sqrt(2 * PI));
            g2 = exp(-0.5 * pow((values[i] - mu2) / sigma2, 2)) / (sigma2 * sqrt(2 * PI));
            
            // Probabilités pondérées
            w1g1 = weight1 * g1;
            w2g2 = weight2 * g2;
            sum = w1g1 + w2g2;
            
            // Prob. d'appartenance normalisées
            if (sum > 0) {
                p1[i] = w1g1 / sum;
                p2[i] = w2g2 / sum;
            } else {
			    if (values[i] < (mu1 + mu2) / 2) {
			        p1[i] = 1;
			    } else {
			        p1[i] = 0;
			    }
			    p2[i] = 1 - p1[i];
			}
            
            sumP1 += p1[i];
            sumP2 += p2[i];
        }
        
        // Étape M: mise à jour des paramètres
        oldMu1 = mu1;
        oldMu2 = mu2;
        
        // Nouveaux poids
        if (sumP1 + sumP2 > 0) {
            weight1 = sumP1 / (sumP1 + sumP2);
            weight2 = sumP2 / (sumP1 + sumP2);
        }
        
        // Nouvelles moyennes
        mu1 = 0;
        mu2 = 0;
        
        for (i = 0; i < values.length; i++) {
            mu1 += p1[i] * values[i];
            mu2 += p2[i] * values[i];
        }
        
        if (sumP1 > 0) mu1 /= sumP1;
        if (sumP2 > 0) mu2 /= sumP2;
        
        // Assurer que mu1 < mu2
        if (mu1 > mu2) {
            temp = mu1; mu1 = mu2; mu2 = temp;
            temp = sumP1; sumP1 = sumP2; sumP2 = temp;
            tempArray = p1; p1 = p2; p2 = tempArray;
        }
        
        // Nouveaux écarts-types
        sigma1 = 0;
        sigma2 = 0;
        
        for (i = 0; i < values.length; i++) {
            sigma1 += p1[i] * pow(values[i] - mu1, 2);
            sigma2 += p2[i] * pow(values[i] - mu2, 2);
        }
        
        if (sumP1 > 0) sigma1 = sqrt(sigma1 / sumP1);
        if (sumP2 > 0) sigma2 = sqrt(sigma2 / sumP2);
        
        // Éviter sigma trop petit (instabilité numérique)
        minSigma = std / 10;
        sigma1 = maxOf(sigma1, minSigma);
        sigma2 = maxOf(sigma2, minSigma);
        
        // Vérifier la convergence
        if (abs(mu1 - oldMu1) < convergenceThreshold && abs(mu2 - oldMu2) < convergenceThreshold) {
            converged = true;
        }
    }
    
    // Calculer le coefficient D d'Ashman
    ashmanD = abs(mu1 - mu2) / sqrt(sigma1*sigma1 + sigma2*sigma2);
    
    // Déterminer si la distribution est bimodale
    isBimodal = (ashmanD >= 2.0 && abs(mu1 - mu2) > std * 0.8);
    
    // Retourner le résultat avec les paramètres estimés
    returnArray = newArray(7);
	if (isBimodal) {
	    returnArray[0] = 1;
	} else {
	    returnArray[0] = 0;
	}
	returnArray[1] = mu1;
	returnArray[2] = sigma1;
	returnArray[3] = mu2;
	returnArray[4] = sigma2;
	returnArray[5] = weight1;
	returnArray[6] = weight2;
	return returnArray;
}

function calculateAdaptiveBaseFactor(values, mean, median, std, cv) {
    
    if (cv > 1.5) {
        // Très élevé : bimodale cachée extrême
        baseFactor = 0.75;
    }
    else if (cv > 0.75) {
        // Élevé : bimodale cachée
        baseFactor = 0.5;
    }
    else if (cv > 0.5) {
        // Modéré : distribution plus compacte
        baseFactor = -1;
    }
    else if (cv > 0.25) {
        // Bas : distribution compacte, dominant
        baseFactor = -1.5;
    }
    else {
        // Très bas : quasi-unimodal
        baseFactor = -2;
    }
    
    // Limite de sécurité
    baseFactor = maxOf(baseFactor, -2.5);
    baseFactor = minOf(baseFactor, 1);
 
    return baseFactor;
}

// Fonction de seuil adaptatif améliorée
function enhancedAdaptiveThreshold(values, imageID, roiManagerString, roiIndices, channelIndex) {
    
    // Analyse statistique de base
    mean = calculateMean(values);
    median = calculateMedian(values);
    std = calculateStd(values, mean);
    
    // Analyse statistique avancée
    sortedValues = Array.copy(values);
    Array.sort(sortedValues);
    
    // Extraire les quartiles
    q1 = sortedValues[floor(sortedValues.length * 0.25)];
    q3 = sortedValues[floor(sortedValues.length * 0.75)];
    iqr = q3 - q1;
    
    // Détection avancée de distribution (unimodale vs bimodale)
    ashmanD = 0;
    if (values.length >= 20) {
        bimodalParams = detectBimodalDistribution(values);
        isBimodal = bimodalParams[0];
        
        if (isBimodal) {
            mu1 = bimodalParams[1];
            sigma1 = bimodalParams[2];
            mu2 = bimodalParams[3];
            sigma2 = bimodalParams[4];
            
            ashmanD = abs(mu1 - mu2) / sqrt(sigma1*sigma1 + sigma2*sigma2);
        }
    weight1 = bimodalParams[5];
    weight2 = bimodalParams[6];
    }
    
    // Analyse de texture pour chaque ROI
    textureScores = newArray(values.length);
    for (t = 0; t < textureScores.length; t++) {
        textureScores[t] = 1.0;
    }
    
    if (imageID > 0 && roiIndices.length > 0) {
        selectImage(imageID);
        if (channelIndex > 0) {
            Stack.setChannel(channelIndex);
        }
        
        for (i = 0; i < roiIndices.length; i++) {
            textureScores[i] = analyzeTexture(roiManagerString, roiIndices[i]);
        }
    }
    
    // Détermination du seuil en fonction du type de distribution
    if (ashmanD >= 2.0) {
        // Distribution clairement bimodale - utiliser la vallée entre les deux pics
        threshold = (mu1 + mu2) / 2;
        threshold = adjustThresholdByTexture(threshold, textureScores);
        return threshold;
    } else {
        // Distribution unimodale ou bimodale cachée
        cv = std / median;  // Coefficient de variation
        
        // === NOUVEAU : Utiliser les poids du EM pour adapter le baseFactor ===
        baseFactor = calculateAdaptiveBaseFactor(values, mean, median, std, cv);

        threshold = median + (baseFactor * std);
    }
        threshold = adjustThresholdByTexture(threshold, textureScores);
 
        return threshold;
}

// Analyse de texture pour chaque ROI
function analyzeTexture(roiManagerString, roiIndex) {
    // Sélectionner la ROI
    roiManager("select", roiIndex);
    
    // Mesurer divers paramètres de texture
    if (useCSA) {
	    run("Set Measurements...", "area mean standard modal min median skewness kurtosis redirect=None decimal=3");
	} else {
	    run("Set Measurements...", "area mean standard modal min median skewness kurtosis feret's redirect=None decimal=3");
	}
    run("Measure");
    
    mean = getResult("Mean", nResults-1);
    stdDev = getResult("StdDev", nResults-1);
    median = getResult("Median", nResults-1);
    mode = getResult("Mode", nResults-1);
    skewness = getResult("Skewness", nResults-1);
    kurtosis = getResult("Kurtosis", nResults-1);
    if (useCSA) {
	    sizeValue = getResult("Area", nResults-1);
	} else {
	    sizeValue = getResult("MinFeret", nResults-1);
	}
	    
    // Effacer les résultats pour ne pas encombrer la table
    run("Clear Results");
    
    // Calcul du coefficient de variation (mesure d'homogénéité)
    cv = stdDev / mean;
    
    // Évaluer l'homogénéité en fonction de plusieurs paramètres
    // Plus le score est élevé, plus le signal est considéré homogène et fiable
    homogeneityScore = 1.0;
    
    // Pénaliser forte hétérogénéité
    if (cv > 0.35) {
        // Pénalité graduelle commençant à CV 0.25 au lieu de 0.3
        homogeneityScore *= (1.0 / (1.0 + 0.35 * (cv - 0.35)));
    }
    
    // Pénaliser forte asymétrie
    if (abs(skewness) > 1) { // Seuil réduit de 1.0 à 0.9
        homogeneityScore *= (1.0 / (1.0 + 0.2 * (abs(skewness) - 1))); // Facteur légèrement ajusté
    }
    
    // Pénaliser une distribution non normale (pics ou queues lourdes)
    kurtosisNormal = 3.0; // Valeur pour distribution normale
    if (abs(kurtosis - kurtosisNormal) > 1.8) { // Seuil réduit de 1.5 à 1.4
        homogeneityScore *= (1.0 / (1.0 + 0.05 * (abs(kurtosis - kurtosisNormal) - 1.2)));
    }
    
    // Pénaliser un fort écart entre moyenne et médiane (indicateur d'asymétrie)
    if (mean > 0 && abs(mean - median) / mean > 0.22) { // Seuil réduit de 0.2 à 0.18
        homogeneityScore *= (1.0 / (1.0 + 0.24 * (abs(mean - median) / mean - 0.22)));
    }
    
    // Les très petites ou très grandes ROIs peuvent être problématiques
	if (useCSA) {
	    if (sizeValue > 200 && sizeValue < 3000) {
	        homogeneityScore *= 1.25; // Petit bonus de 5%
	    }
	} else {
	    if (sizeValue > 10 && sizeValue < 100) { // Ajustement pour MinFeret
	        homogeneityScore *= 1.25; // Petit bonus de 5%
	    }
	}
    // Retourner le score d'homogénéité (entre 0 et 1)
    // Plus le score est proche de 1, plus la texture est homogène
    return minOf(1.0, maxOf(0.35, homogeneityScore));
}

// Ajustement du seuil en fonction de la texture
function adjustThresholdByTexture(threshold, textureScores) {
    // Calculer le score de texture moyen
    avgTextureScore = 0;
    for (i = 0; i < textureScores.length; i++) {
        avgTextureScore += textureScores[i];
    }
    avgTextureScore /= textureScores.length;
    
    if (avgTextureScore < 0.6) {
        // Texture hétérogène - augmenter le seuil (jusqu'à +20%)
        adjustment = 1.0 + (0.6 - avgTextureScore) * 0.333; // max +20% quand score = 0
        return threshold * adjustment;
    } else if (avgTextureScore > 0.8) {
        // Texture homogène - diminuer légèrement le seuil (jusqu'à -5%)
        adjustment = 1.0 - (avgTextureScore - 0.8) * 0.25; // max -5% quand score = 1
        return threshold * adjustment;
    } else {
        // Zone neutre - pas d'ajustement
        return threshold;
    }
}

function detectPeripheralStainingFromCache(roiIndex) {
    // Utiliser les stats du cache pour détecter les marquages périphériques
    // Sans refaire de mesures !
    cachedStd = getCachedStdDev(roiIndex);
    cachedMean = getCachedMean(roiIndex);
    
    if (cachedMean > 0) {
        cv = cachedStd / cachedMean;
        // Marquage périphérique = CV très élevé + forte variation
        // Seuil empirique : CV > 0.45 indique une distribution asymétrique
        return cv > 0.45;
    }
    return false;
}

function calculateHomogeneity(values, roiIndex) {
    // Statistiques de base des valeurs
    valueMean = calculateMean(values);
    valueMedian = calculateMedian(values);
    valueStd = calculateStd(values, valueMean);
    cv = valueStd / valueMean; // Coefficient de variation
    
    // Facteurs de pénalité - commencer avec une valeur de base
    penaltyFactors = 1.0;
    
    // Sélectionner la ROI actuelle pour les mesures
    roiManager("select", roiIndex);
    
    // Obtenir les propriétés de la ROI DU CACHE (pas de remesure!)
    area = getCachedArea(roiIndex);
    fullRoiMean = getCachedMean(roiIndex);
    fullRoiStd = getCachedStdDev(roiIndex);
    
    // 1. Pénaliser les très petites ROI (probablement du bruit)
    if (area < 200) {
        penaltyFactors *= (1 + (1 - area/200) * 0.8);
    }
    
    // 2. Pénaliser les ROI très hétérogènes
    if (cv > 0.40) {  // Seuil réduit de 0.3 à 0.25
        penaltyFactors *= (1 + (cv - 0.40) * 0.4);  // Pénalité augmentée
    }
    
    // 3. Analyse centre-périphérie simplifiée
    if (fullRoiStd/fullRoiMean > 0.65) {  // Seuil réduit de 0.5 à 0.45
        penaltyFactors *= (1 + 1 * (fullRoiStd/fullRoiMean - 0.65));
    }
	
    // 4. Ajustement en fonction de la valeur moyenne relative
    allValues = Array.copy(values);
    Array.sort(allValues);
    globalMedian = calculateMedian(allValues);
    
    if (valueMean < 0.3 * globalMedian) {
        penaltyFactors *= (1 + 0.3 * (1 - (valueMean/(0.3*globalMedian))));
    }
    
    // Limiter le facteur de pénalité maximum
    penaltyFactors = minOf(3.0, penaltyFactors);
    
    // S'assurer que la ROI originale est toujours sélectionnée à la fin
    roiManager("select", roiIndex);
    
    return penaltyFactors;
}

// ============================================ CLASSIFICATION DES FIBRES ====================================================

//Fonction calcul de fibre dominante lors d'hybrides IIb-IIa/IIb-I/IIx-I
function getDominantClassification(values, thresholds, types) {
	  
    scores = newArray(values.length);
    maxScore = -1;
    dominantType = "";
    
    for (i = 0; i < values.length; i++) {
        if (values[i] > thresholds[i]) {
            scores[i] = (values[i] - thresholds[i]) / thresholds[i];
            if (scores[i] > maxScore) {
                maxScore = scores[i];
                dominantType = types[i];
            }
        }
    }
    
    return dominantType;
}


// ================================================ VISUALISATION ET SORTIE ================================================


function getClassificationColor(classification, channelColors, fiberTypeChannels) {
    // Initialiser les composantes de couleur
    r = 128; g = 128; b = 128; // Couleur grise par dÃ©faut
    
    // Si c'est une classification simple "O"
    if (classification == "O") {
        return newArray(128, 128, 128); // Gris pour nÃ©gatif
    }
    
    // VÃ©rifier si c'est une fibre hybride (contient un tiret)
    if (indexOf(classification, "-") >= 0) {
        types = split(classification, "-");
        rTotal = 0; gTotal = 0; bTotal = 0;
        validTypeCount = 0;
        
        // Pour chaque type dans la classification hybride
        for (t = 0; t < types.length; t++) {
            typeChannel = -1;
            
            // Trouver le canal correspondant au type
            for (i = 0; i < fiberTypeChannels.length; i++) {
                if (types[t] == channelNames[i]) {
                    typeChannel = fiberTypeChannels[i] - 1; // -1 car les indices commencent Ã  0
                    break;
                }
            }
            
            // Si le type a un canal correspondant, ajouter sa couleur
            if (typeChannel >= 0 && typeChannel < channelColors.length/3) {
                rTotal += channelColors[typeChannel*3];
                gTotal += channelColors[typeChannel*3+1];
                bTotal += channelColors[typeChannel*3+2];
                validTypeCount++;
            }
        }
        
        // Calculer la moyenne si des types valides ont Ã©tÃ© trouvÃ©s
        if (validTypeCount > 0) {
            // MÃ©lange logarithmique pour accentuer les couleurs combinÃ©es
            r = pow(rTotal/validTypeCount, 0.8);
            g = pow(gTotal/validTypeCount, 0.8);
            b = pow(bTotal/validTypeCount, 0.8);
            
            // Normalisation pour accentuer la visibilitÃ©
            maxComponent = maxOf(maxOf(r, g), b);
            if (maxComponent > 0) {
                factor = 255 / maxComponent;
                r = minOf(255, r * factor);
                g = minOf(255, g * factor);
                b = minOf(255, b * factor);
            }
        }
    } 
    else {
        // Classification simple (un seul type)
        typeChannel = -1;
        
        // Trouver le canal correspondant au type
        for (i = 0; i < channelNames.length; i++) {
            if (classification == channelNames[i]) {
                typeChannel = selectedChannels[i] - 1; // -1 car les indices commencent Ã  0
                break;
            }
        }
        
        // Si le type a un canal correspondant, utiliser sa couleur
        if (typeChannel >= 0 && typeChannel < channelColors.length/3) {
            r = channelColors[typeChannel*3];
            g = channelColors[typeChannel*3+1];
            b = channelColors[typeChannel*3+2];
        }
    }
    
    return newArray(r, g, b);
}

function extractChannelColors() {
    // Obtenir l'image originale
    origID = getImageID();
    origTitle = getTitle();
    getDimensions(width, height, channels, slices, frames);
    
    // CrÃ©er un tableau pour stocker les couleurs extraites
    channelColors = newArray(channels * 3); // R,G,B pour chaque canal
    
    // Pour chaque canal, extraire la couleur dominante
    for (c = 1; c <= channels; c++) {
        // CrÃ©er une copie temporaire du canal
        selectImage(origID);
        Stack.setChannel(c);
        run("Duplicate...", "title=temp_channel");
        tempID = getImageID();
        
        // DÃ©finir un seuil pour extraire les pixels les plus brillants (signal)
        setAutoThreshold("Default dark");
        getThreshold(lower, upper);
        
        // DÃ©finir un seuil Ã©levÃ© pour ne garder que le signal fort
        setThreshold(maxOf(lower, (lower+upper)*0.6), upper);
        run("Create Selection");
        
        // Si la sÃ©lection est vide (pas de pixels au-dessus du seuil), utiliser toute l'image
        if (selectionType() == -1) {
            run("Select All");
        }
        
        // Mesurer la couleur moyenne dans la sÃ©lection
        run("Measure");
        meanIntensity = getResult("Mean", nResults-1);
        
        // Normaliser la couleur pour qu'elle soit vive mais pas trop saturÃ©e
        normalizationFactor = 230 / maxOf(1, meanIntensity);
        
        // DÃ©terminer la couleur en fonction du canal
        if (c == 1) { // Premier canal souvent en rouge
            channelColors[(c-1)*3] = minOf(255, meanIntensity * normalizationFactor);
            channelColors[(c-1)*3+1] = 0;
            channelColors[(c-1)*3+2] = 0;
        } 
        else if (c == 2) { // DeuxiÃ¨me canal souvent en vert
            channelColors[(c-1)*3] = 0;
            channelColors[(c-1)*3+1] = minOf(255, meanIntensity * normalizationFactor);
            channelColors[(c-1)*3+2] = 0;
        }
        else if (c == 3) { // TroisiÃ¨me canal souvent en bleu
            channelColors[(c-1)*3] = 0;
            channelColors[(c-1)*3+1] = 0;
            channelColors[(c-1)*3+2] = minOf(255, meanIntensity * normalizationFactor);
        }
        else if (c == 4) { // QuatriÃ¨me canal souvent en magenta
            channelColors[(c-1)*3] = minOf(255, meanIntensity * normalizationFactor);
            channelColors[(c-1)*3+1] = 0;
            channelColors[(c-1)*3+2] = minOf(255, meanIntensity * normalizationFactor);
        }
        else { // Canaux supplÃ©mentaires
            // Attribution de couleurs pour les canaux > 4
            if (c % 3 == 0) {
                channelColors[(c-1)*3] = minOf(255, meanIntensity * normalizationFactor);
                channelColors[(c-1)*3+1] = minOf(255, meanIntensity * normalizationFactor * 0.7);
                channelColors[(c-1)*3+2] = 0;
            } else if (c % 3 == 1) {
                channelColors[(c-1)*3] = 0;
                channelColors[(c-1)*3+1] = minOf(255, meanIntensity * normalizationFactor * 0.7);
                channelColors[(c-1)*3+2] = minOf(255, meanIntensity * normalizationFactor);
            } else {
                channelColors[(c-1)*3] = minOf(255, meanIntensity * normalizationFactor);
                channelColors[(c-1)*3+1] = 0;
                channelColors[(c-1)*3+2] = minOf(255, meanIntensity * normalizationFactor * 0.5);
            }
        }
        
        // Nettoyer
        run("Select None");
        close("temp_channel");
        run("Clear Results");
    }
    
    // Revenir Ã  l'image originale
    selectImage(origID);
    
    return channelColors;
}


// Fonction pour obtenir la lettre de colonne Ã  partir d'un index (0-based)
function getColumnLetter(index) {
    letters = newArray("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z");
    
    if (index < 26) {
        return letters[index];
    } else {
        firstLetter = letters[floor(index/26) - 1];
        secondLetter = letters[index % 26];
        return firstLetter + secondLetter;
    }
}

// Calculer l'index de la colonne de classification
function getClassificationColumnIndex(baseColumns, channelCount) {
    return baseColumns + channelCount - 1;
}

// ======================================================= UTILITAIRES =========================================================


function parseRoiString(roiString, maxRoi) {
    // Convertir une chaÃ®ne de numÃ©ros de ROI en tableau d'indices
    // Format supportÃ©: "1,3,5-10,15"
    
    if (roiString == "") return newArray(0);
    
    // Traiter les Ã©lÃ©ments sÃ©parÃ©s par des virgules
    elements = split(roiString, ",");
    roiIndices = newArray(0);
    
    for (i = 0; i < elements.length; i++) {
        element = elements[i];
        element = replace(element, " ", ""); // Supprimer les espaces
        
        // VÃ©rifier si c'est une plage (ex: "5-10")
        if (indexOf(element, "-") > 0) {
            rangeParts = split(element, "-");
            if (rangeParts.length == 2) {
                start = parseInt(rangeParts[0]);
                end = parseInt(rangeParts[1]);
                
                // Validation des nombres
                if (!isNaN(start) && !isNaN(end)) {
                    // Convertir de numÃ©ros de ROI (1-based) Ã  indices (0-based)
                    start = maxOf(1, start) - 1; 
                    end = minOf(maxRoi, end) - 1;
                    
                    // Ajouter chaque indice dans la plage
                    for (j = start; j <= end; j++) {
                        roiIndices = Array.concat(roiIndices, j);
                    }
                }
            }
        }
        // Sinon, c'est un nombre individuel
        else {
            roi = parseInt(element);
            if (!isNaN(roi)) {
                // Convertir de numÃ©ro de ROI (1-based) Ã  indice (0-based)
                roi = maxOf(1, roi) - 1;
                if (roi < maxRoi) {
                    roiIndices = Array.concat(roiIndices, roi);
                }
            }
        }
    }
    
    return roiIndices;
}

function findMinValue(array) {
    if (array.length == 0) return 0;
    min = array[0];
    for (i = 1; i < array.length; i++) {
        if (array[i] < min) min = array[i];
    }
    return min;
}

function findMaxValue(array) {
    if (array.length == 0) return 0;
    max = array[0];
    for (i = 1; i < array.length; i++) {
        if (array[i] > max) max = array[i];
    }
    return max;
}
	
function getDateTimeString() {
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    return year + "-" + (month+1) + "-" + dayOfMonth + " " + hour + ":" + minute;
}

function normalizeFileName(fileName) {
    return fileName;
}



// ===================================================================================================================
// ================================================== WORKFLOW =======================================================
// ===================================================================================================================



// =============================================== INITIALISATION ====================================================


// DÃ©terminer l'os
os = getInfo("os.name");
isWindowsOrLinux = indexOf(toLowerCase(os), "windows") >= 0 || indexOf(toLowerCase(os), "linux") >= 0;

// Initialiser useGPU par dÃ©faut
useGPU = isWindowsOrLinux;

// Obtenir tous les paramÃ¨tres depuis la boÃ®te de dialogue amÃ©liorÃ©e
params = showEnhancedDialog();

// Extraire les paramÃ¨tres
totalChannels = params[0];
LaminineCannal = params[1];
autoCalibrate = params[2];
FibreDiameter = params[3];
IIbChannel = params[4];
IIxChannel = params[5];
IIaChannel = params[6];
IChannel = params[7];
customChannel = params[8];
customChannelName = params[9];
sizeMeasurementMethod = params[10];
useCSA = (sizeMeasurementMethod == "Cross Sectional Area (CSA)");
cellposeSensitivity = params[11];
exclusionThreshold = params[15];
adaptiveThresholdFactor = params[13];
filterNonHomogeneous = params[14];
useGPU = params[15];
useChannelColors = params[16];
overlayOpacity = params[17];

// VÃ©rification que les canaux sÃ©lectionnÃ©s ne dÃ©passent pas le nombre total de canaux
if (LaminineCannal > totalChannels || 
    (IIbChannel > totalChannels && IIbChannel != 0) || 
    (IIxChannel > totalChannels && IIxChannel != 0) || 
    (IIaChannel > totalChannels && IIaChannel != 0) || 
    (IChannel > totalChannels && IChannel != 0) ||
    (customChannel > totalChannels && customChannel != 0)) {
    exit("Error: Selected channel numbers cannot exceed total number of channels (" + totalChannels + ")");
}

	IIbThreshold = 0;
	IIxThreshold = 0;
	IIaThreshold = 0;
	IThreshold = 0;
	customThreshold = 0;

// Mise Ã  jour des variables globales
var GLOBAL_LAST_DIR = "";
var GLOBAL_LAST_IMAGE = "";

// =============================================== PREPARATION =================================================


// CrÃ©er un tableau des canaux Ã  mesurer
selectedChannels = newArray();
channelNames = newArray();

if (IIbChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IIbChannel);
    channelNames = Array.concat(channelNames, "IIb");
}
if (IIxChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IIxChannel);
    channelNames = Array.concat(channelNames, "IIx");
}
if (IIaChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IIaChannel);
    channelNames = Array.concat(channelNames, "IIa");
}
if (IChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IChannel);
    channelNames = Array.concat(channelNames, "I");
}
if (customChannel > 0 
//&& lengthOf(customChannelName) > 0
) {
    selectedChannels = Array.concat(selectedChannels, customChannel);
    channelNames = Array.concat(channelNames, customChannelName);
}

// ========================================= TRAITEMENT PAR LOTS ================================================

// Choix du dossier des images Ã  analyser
dir = getDirectory("Directory selection (tiff images required)");
ListeFichier0=getFileList(dir);
ListeFichier=Array.sort(ListeFichier0);
nbFichiers = ListeFichier.length ;

for(k=0; k<nbFichiers; k++){
	
							// ======= 1. Ouverture et préparation de l'image ======
							
smallImageProgress(k, nbFichiers, 0, 10, "Starting analysis of " + ListeFichier[k]);

	//  Ouverture de l'image 4 canaux numéro 1
	dir = getPlatformSafePath(dir);
	open(dir+ListeFichier[k]);

	// passer le nom de l'image en paramètre
	ImageName = getTitle();

	// renommer 'Originale'
	rename("Originale");
	
	// Prétraitement de l'image pour améliorer la segmentation
	selectImage("Originale");

smallImageProgress(k, nbFichiers, 1, 10, "Image opened");

	// Appel Cellpose
	fijiPath = getDirectory("imagej");
	userHome = getDirectory("home");
	cellposeCommand = configureCellpose();
	condaPath = substring(cellposeCommand, indexOf(cellposeCommand, "env_path=") + 9, indexOf(cellposeCommand, " ", indexOf(cellposeCommand, "env_path=")));

smallImageProgress(k, nbFichiers, 2, 10, "Configuring Cellpose");
	
	
cellposeCommand = "env_path="+condaPath+" env_type=conda model=cyto3 model_path="+fijiPath+" diameter="+FibreDiameter+" ch1="+LaminineCannal+" ch2=0";

	// Ajout de l'option GPU si sÃ©lectionnÃ©e et disponible
	if (isWindowsOrLinux && useGPU) {
	    cellposeCommand = cellposeCommand + " additional_flags=--use_gpu";
	}
	
							// ========== 2. Segmentation avec Cellpose ==========
							
smallImageProgress(k, nbFichiers, 3, 10, "Running Cellpose");

	cellposeCommand = cellposeCommand + " additional_flags=--verbose";
    cellposeCommand = cellposeCommand + " no_dialog=true";
    cellposeCommand = cellposeCommand + " batch_mode=true";

	run("Cellpose ...", cellposeCommand);
	
	// Sauvegarder l'image Masque avec le paramÃ¨tre "nom de l'image"

	saveAs("tif", dir+ImageName+"_cellposeMask.tif");

	roiManager('reset');
	hei = getHeight()-1;
	wid = getWidth();
	name = 1;
	currentPix = 0;
	grayVal = 0;
	setForegroundColor(0,0,0);
	
	for(j = 0; j<hei; j++) {
	    for(i = 0; i<wid; i++) {
	        if(getPixel(i,j)==grayVal+1) {
	            currentPix = getPixel(i, j);
	            doWand(i, j, 0.0, "8-connected smooth");
	            Roi.getBounds(x, y, width, height);
	            if(width*height >3) {
	                grayVal++;
	                Roi.setName(IJ.pad(name,5));
	                roiManager("add");
	                name++;
	            }
	        }
	    }
	}
	if (roiManager("count") > 0) {
    roiManager("select all");
    run("Properties... ", "stroke=black width=1");
    roiManager("deselect");
} else {
    print("Warning: No ROIs to set properties for");
}
	roiManager("Deselect");
	roiManager("Sort");
	
	// ###- sauvegarder les ROI
	roiManager("Save", dir+ImageName+"_ROI_Set.zip");

	// fermer l'image des masques
	selectImage(ImageName+"_cellposeMask.tif");
	close();
	
							// ========== 3. Analyse et mesure des fibres  ===========
						
smallImageProgress(k, nbFichiers, 5, 10, "Measuring fiber properties");

	//Lancer la macro 02_Macro_Analyse_MAIRE.ijm conditionnÃ©e aux canaux ALL - paramÃ¨tre canal laminine
	if (useCSA) {
	    run("Set Measurements...", "area mean");
	} else {
	    run("Set Measurements...", "area mean feret's");
	}
	nROIs = roiManager("count");
	getDimensions(w, h, channels, slices, frames);
	
	// ===== MESURES PAR CANAL (structure originale, légèrement optimisée) =====
	for(i=0; i<selectedChannels.length; i++) {
	    
	    setSlice(selectedChannels[i]);
	    
	    // Mesurer UNE FOIS TOUS les ROIs pour ce canal (plus rapide qu'en boucle)
	    roiManager("Deselect");
	    roiManager("Measure");
	    
	    // Sauvegarder
	    selectWindow("Results");
	    saveAs("Results", dir + ImageName + "Measurements_" + channelNames[i] + ".csv");
	    
	    // IMPORTANT: Fermer et réinitialiser Results après CHAQUE canal
	    selectWindow("Results");
	    run("Close");
	    
	    // Petit nettoyage
	    if (i % 2 == 0) {
	        run("Collect Garbage");
	    }
	}

	roiManager('reset');
	run("Select None");
	selectImage("Originale");
	rename("Original_For_Analysis");
	
	// Charger les ROIs
	if (roiManager("count") == 0) {
	    roiManager("reset");
	    roiManager("Open", dir+ImageName+"_ROI_Set.zip");
	}
	
	// INITIALISER LE CACHE (mesure unique)
	initializeMeasurementCache(getImageID());
	
	// Création et remplissage du fichier compilé après les mesures de tous les canaux
	output = File.open(dir + ImageName + "_Compiled_Results.csv");
	
	// Ecrire les en-têtes
	if (useCSA) {
	    headers = "ROI,Size_CSA";
	} else {
	    headers = "ROI,Size_MinFeret";
	}
	for(i=0; i<channelNames.length; i++) {
	    headers = headers + ",Mean_" + channelNames[i];
	}
	print(output, headers);
	
	// Premier canal : Label, Area, Mean
	firstResults = File.openAsString(dir + ImageName + "Measurements_" + channelNames[0] + ".csv");
	firstLines = split(firstResults, "\n");
	firstData = Array.slice(firstLines, 1);
	
	// Ã‰crire les donnÃ©es du premier canal avec Area
	for (i = 0; i < firstData.length; i++) {
	    values = split(firstData[i], ",");
	    line = values[0] + "," + values[1]; // ROI et Area
	    line = line + "," + values[2];  // Mean du premier canal
	    
	    // Ajouter les moyennes des autres canaux
	    for (c = 1; c < selectedChannels.length; c++) {
	        chanResults = File.openAsString(dir + ImageName + "Measurements_" + channelNames[c] + ".csv");
	        chanLines = split(chanResults, "\n");
	        chanData = Array.slice(chanLines, 1);
	        chanValues = split(chanData[i], ",");
	        line = line + "," + chanValues[2];
	    }
	    print(output, line);
	}
	
File.close(output);

	// Créer et remplir le fichier compilé avec ratios pour tous les canaux mesurés
    output = File.open(dir + ImageName + "_Compiled_Results.csv");
    
    // Écrire les en-têtes sans ratios
	if (useCSA) {
	    headers = "ROI,Size_CSA";
	} else {
	    headers = "ROI,Size_MinFeret";
	}
	for(i=0; i<channelNames.length; i++) {
	    headers = headers + ",Mean_" + channelNames[i];
	}
	print(output, headers);

    // Premier canal : Label, Area, Mean
    firstResults = File.openAsString(dir + ImageName + "Measurements_" + channelNames[0] + ".csv");
    firstLines = split(firstResults, "\n");
    firstData = Array.slice(firstLines, 1);
    
	// Charger les ROIs pour MinFeret si nÃ©cessaire
	if (!useCSA) {
	    roiManager("reset");
	    roiManager("Open", dir+ImageName+"_ROI_Set.zip");
	}
	
	// Extraire les valeurs et calculer les ratios
	for (i = 0; i < firstData.length; i++) {
	    values = split(firstData[i], ",");
	    if (useCSA) {
	        sizeValue = values[1]; // Area
	    } else {
	        // Pour MinFeret, mesurer directement
	        roiManager("select", i);
	        run("Set Measurements...", "feret's redirect=None decimal=3");
	        run("Measure");
	        sizeValue = getResult("MinFeret", nResults-1);
	        run("Clear Results");
	    }
    line = values[0] + "," + sizeValue; // ROI et taille
        
        // Ajouter les moyennes de canaux
        mean_values = newArray(selectedChannels.length);
        for (c = 0; c < selectedChannels.length; c++) {
            if (c == 0) {
                // Pour le premier canal, on a dÃ©jÃ  les donnÃ©es
                mean_values[c] = parseFloat(values[2]);
                line = line + "," + values[2];
            } else {
                // Pour les autres canaux, il faut les charger
                chanResults = File.openAsString(dir + ImageName + "Measurements_" + channelNames[c] + ".csv");
                chanLines = split(chanResults, "\n");
                chanData = Array.slice(chanLines, 1);
                chanValues = split(chanData[i], ",");
                mean_values[c] = parseFloat(chanValues[2]);
                line = line + "," + chanValues[2];
            }
        }
        
        print(output, line);
    }
    File.close(output);
    
    // Supprimer les fichiers measurements
    for(i=0; i<channelNames.length; i++) {
        measurementFile = dir + ImageName + "Measurements_" + channelNames[i] + ".csv";
        File.delete(measurementFile);
}

	// Lire le fichier compilÃ©
	compiledResults = File.openAsString(dir + ImageName + "_Compiled_Results.csv");
	lines = split(compiledResults, "\n");
	header = lines[0];
	data = Array.slice(lines, 1); // Ignorer l'en-tÃªte
	
	// Trouver les indices des colonnes pour chaque type de fibre
	headers = split(header, ",");
	IIbIndex = -1;
	IIxIndex = -1;
	IIaIndex = -1;
	IIndex = -1;
	customIndex = -1;
	
	// Identifier les colonnes pour chaque type de fibre
	for (i = 0; i < headers.length; i++) {
	    
	    if (indexOf(headers[i], "Mean_IIb") >= 0) {
	        IIbIndex = i;
	    }
	    if (indexOf(headers[i], "Mean_IIx") >= 0) {
	        IIxIndex = i;
	    }
	    if (indexOf(headers[i], "Mean_IIa") >= 0) {
	        IIaIndex = i;
	    }
	    if (indexOf(headers[i], "Mean_I") >= 0) {
	        IIndex = i;
	    }
	    // VÃ©rifier d'abord si un canal custom est demandÃ©
	    if (customChannel > 0 && customChannelName != "" && indexOf(headers[i], customChannelName) >= 0) {
	        customIndex = i;
	    }
	}
	// Initialiser les tableaux pour les valeurs
	numRows = data.length;
	IIbValues = newArray(numRows);
	IIxValues = newArray(numRows);
	IIaValues = newArray(numRows);
	IValues = newArray(numRows);
	customValues = newArray(numRows);
	roiValues = newArray(numRows);
	
	// Initialiser les seuils
	IIbThreshold = 0;
	IIxThreshold = 0;
	IIaThreshold = 0;
	IThreshold = 0;
	customThreshold = 0;

	channelColors = newArray(totalChannels * 3);
if (useChannelColors) {
    // VÃ©rifier que l'image originale est ouverte
    if (isOpen("Original_For_Analysis")) {
        selectWindow("Original_For_Analysis");
        channelColors = extractChannelColors();
    } else {
        // Si l'image n'est pas disponible, utiliser des couleurs par défaut
        for (c = 0; c < totalChannels; c++) {
            if (c == 0) { // Rouge
                channelColors[c*3] = 255; channelColors[c*3+1] = 0; channelColors[c*3+2] = 0; 
            } else if (c == 1) { // Vert
                channelColors[c*3] = 0; channelColors[c*3+1] = 255; channelColors[c*3+2] = 0;
            } else if (c == 2) { // Bleu
                channelColors[c*3] = 0; channelColors[c*3+1] = 0; channelColors[c*3+2] = 255;
            } else if (c == 3) { // Magenta
                channelColors[c*3] = 255; channelColors[c*3+1] = 0; channelColors[c*3+2] = 255;
            } else { // Autres canaux
                channelColors[c*3] = 255; channelColors[c*3+1] = 255; channelColors[c*3+2] = 0;
            }
        }
    }
}

smallImageProgress(k, nbFichiers, 6, 10, "Calculating thresholds");	
	
	// Extraire les valeurs et calculer les seuils
	for (i = 0; i < numRows; i++) {
		
	    values = split(data[i], ",");
	    roiValues[i] = values[0];
	    
	    if (IIbIndex > -1) {
	        IIbValues[i] = parseFloat(values[IIbIndex]);
	    }
	    if (IIxIndex > -1) {
	        IIxValues[i] = parseFloat(values[IIxIndex]);
	    }
	    if (IIaIndex > -1) {
	        IIaValues[i] = parseFloat(values[IIaIndex]);
	    }
	    if (IIndex > -1) {
	        IValues[i] = parseFloat(values[IIndex]);
	    }
	    if (customIndex > -1) {
	        customValues[i] = parseFloat(values[customIndex]);
	    }
	}
	
	// Ajouter un tableau pour les indices de ROI
	ROIArr = newArray(numRows);
	for (i = 0; i < numRows; i++) {
	    ROIArr[i] = i;
	}
	
							// ============= 4. Classification des fibres ==================
						
		// Réouverture de l'image source
	    dir = getPlatformSafePath(dir);
	    open(dir+ImageName);
	    rename("Original_For_Analysis");
	    
	    // Importer ROIs si nÃ©cessaire
	    if (roiManager("count") == 0) {
		    roiManager("reset");
		    roiManager("Open", dir+ImageName+"_ROI_Set.zip");
		}
	    
	    if (IIbIndex > -1) {
	        selectWindow("Original_For_Analysis");
	        IIbThreshold = enhancedAdaptiveThreshold(IIbValues, getImageID(), "roiManager", ROIArr, IIbChannel);
	    }
	    if (IIxIndex > -1) {
	        selectWindow("Original_For_Analysis");
	        IIxThreshold = enhancedAdaptiveThreshold(IIxValues, getImageID(), "roiManager", ROIArr, IIxChannel);
	    }
	    if (IIaIndex > -1) {
	        selectWindow("Original_For_Analysis");
	        IIaThreshold = enhancedAdaptiveThreshold(IIaValues, getImageID(), "roiManager", ROIArr, IIaChannel);
	    }
	    if (IIndex > -1) {
	        selectWindow("Original_For_Analysis");
	        IThreshold = enhancedAdaptiveThreshold(IValues, getImageID(), "roiManager", ROIArr, IIndex);
	    }
	    if (customIndex > -1) {
	        selectWindow("Original_For_Analysis");
	        customThreshold = enhancedAdaptiveThreshold(customValues, getImageID(), "roiManager", ROIArr, customChannel);
	    }
	
	// CrÃ©er le fichier de sortie avec la classification
	outputFile = File.open(dir + ImageName + "_Classified_Results.csv");
	
	// Construire l'en-tÃªte avec point-virgule comme sÃ©parateur
	if (useCSA) {
    headerString = "ROI;CSA";
	} else {
	headerString = "ROI;MinFeret";
	}
	
	// N'ajouter que les colonnes pour les canaux actifs
	if (IIbChannel > 0) {
	    headerString = headerString + ";IIb";
	}
	if (IIxChannel > 0) {
	    headerString = headerString + ";IIx";
	}
	if (IIaChannel > 0) {
	    headerString = headerString + ";IIa";
	}
	if (IChannel > 0) {
	    headerString = headerString + ";I";
	}
	if (customChannel > 0) {
	    headerString = headerString + ";" + customChannelName;
	}
	
	// Ajouter la colonne de classification Ã  la fin
	headerString = headerString + ";Classification";
	print(outputFile, headerString);
	
	// Lire le fichier compilÃ© pour obtenir les donnÃ©es d'aire
	compiledResults = File.openAsString(dir + ImageName + "_Compiled_Results.csv");
	lines = split(compiledResults, "\n");
	header = lines[0];
	data = Array.slice(lines, 1);
	
	headers = split(header, ","); 
	classificationIndex = headers.length - 1; // La classification est toujours la derniÃ¨re colonne
	
	roiManager("reset");
	roiManager("Open", dir+ImageName+"_ROI_Set.zip");
	selectWindow("Original_For_Analysis");

smallImageProgress(k, nbFichiers, 7, 10, "Classifying fibers");

	// Classifier chaque fibre avec les nouvelles caractéristiques
	for (i = 0; i < numRows; i++) {
	    
	    // Nettoyage mémoire tous les 100 ROIs
	    if (i > 0 && i % 100 == 0) {
	        run("Collect Garbage");
	    }
	    
    // Extraire les valeurs Ã  partir du tableau data
    if (i >= data.length) {
        print("Warning: index i=" + i + " out of bounds for data (length=" + data.length + ")");
        continue; // Passer Ã  l'itÃ©ration suivante
    }
    values = split(data[i], ",");
    
	// RÃ©cupÃ©rer le numÃ©ro de ROI et la taille
	roiID = values[0];
	sizeValueNumeric = parseFloat(values[1]); // Valeur numÃ©rique pour les calculs
	
	// Pour l'affichage CSV (formatÃ©)
	sizeValueFormatted = replace(d2s(sizeValueNumeric, 2), ".", ",");
    
	// ===== OPTIMISATION: UTILISER LE CACHE =====
	    if (i < roiManager("count")) {
	        perimeter = 0;  // Non utilisé dans la classification
	        sizeValueNumeric = getCachedArea(i);  // Récupéré du cache
	        eccentricity = 0.5;  // Valeur par défaut
	        solidity = 0.8;      // Valeur par défaut
	    } else {
	        perimeter = 0;
	        eccentricity = 0;
	        solidity = 0;
	    }
	    
	    // Valeurs de chaque canal
	    value_IIb = 0;
	    value_IIx = 0;
	    value_IIa = 0;
	    value_I = 0;
	    value_custom = 0;
    
    // RÃ©cupÃ©rer les valeurs de chaque canal avec vÃ©rification de sÃ©curitÃ©
    if (IIbIndex > -1 && IIbIndex < values.length) {
        value_IIb = parseFloat(values[IIbIndex]);
    }
    if (IIxIndex > -1 && IIxIndex < values.length) {
        value_IIx = parseFloat(values[IIxIndex]);
    }
    if (IIaIndex > -1 && IIaIndex < values.length) {
        value_IIa = parseFloat(values[IIaIndex]);
    }
    if (IIndex > -1 && IIndex < values.length) {
        value_I = parseFloat(values[IIndex]);
    }
    if (customIndex > -1 && customIndex < values.length) {
        value_custom = parseFloat(values[customIndex]);
    }
    
    // Calculer les facteurs d'homogÃ©nÃ©itÃ©
    homogeneityFactor_IIb = 1.0;
    homogeneityFactor_IIx = 1.0;
    homogeneityFactor_IIa = 1.0;
    homogeneityFactor_I = 1.0;
    homogeneityFactor_custom = 1.0;
    
// Calculer les facteurs d'homogénéité seulement si i est dans les limites du ROI Manager
if (i < roiManager("count")) {
    roiManager("select", i);
    
    if (IIbIndex > -1 && IIbChannel > 0) {
        homogeneityFactor_IIb = calculateHomogeneity(newArray(value_IIb), i);
    }
    if (IIxIndex > -1 && IIxChannel > 0) {
        homogeneityFactor_IIx = calculateHomogeneity(newArray(value_IIx), i);
    }
    if (IIaIndex > -1 && IIaChannel > 0) {
        homogeneityFactor_IIa = calculateHomogeneity(newArray(value_IIa), i);
    }
    if (IIndex > -1 && IChannel > 0) {
        homogeneityFactor_I = calculateHomogeneity(newArray(value_I), i);
        if (solidity > 0.75) homogeneityFactor_I *= 1.25;
    }
    if (customIndex > -1 && customChannel > 0) {
        homogeneityFactor_custom = calculateHomogeneity(newArray(value_custom), i);
    }
}
      // DÃ©terminer si chaque type est positif
    isIIb = 0;
    isIIx = 0;
    isIIa = 0;
    isI = 0;
    iscustom = 0;
    
    // DÃ©terminer les positifs en comparant avec les seuils
	if (customIndex > -1 && customChannel > 0 && value_custom > customThreshold) {
    iscustom = 1;
	}
	
	adjustedHomogeneityFactor_IIb = 1.0 + (homogeneityFactor_IIb - 1.0) * 0.9; 
	if (IIbIndex > -1 && IIbChannel > 0 && value_IIb > IIbThreshold * adjustedHomogeneityFactor_IIb) {
	    isIIb = 1;
	}
	
	adjustedHomogeneityFactor_IIx = 1.0 + (homogeneityFactor_IIx - 1.0) * 0.9;
	if (IIxIndex > -1 && IIxChannel > 0 && value_IIx > IIxThreshold * adjustedHomogeneityFactor_IIx) {
	    isIIx = 1;
	}
	
	adjustedHomogeneityFactor_IIa = 1.0 + (homogeneityFactor_IIa - 1.0) * 0.9;
	if (IIaIndex > -1 && IIaChannel > 0 && value_IIa > IIaThreshold * adjustedHomogeneityFactor_IIa) {
	    isIIa = 1;
	}
	
	adjustedHomogeneityFactor_I = 1.0 + (homogeneityFactor_I - 1.0) * 0.9;
	if (IIndex > -1 && IChannel > 0 && value_I > IThreshold * adjustedHomogeneityFactor_I) {
	    isI = 1;
	}
    
    // PrÃ©paration pour la classification
    classification = "O"; // Par dÃ©faut non-classÃ©
    
    // PrÃ©paration des tableaux d'intensitÃ©s et seuils pour la classification amÃ©liorÃ©e
    intensities = newArray();
    thresholds = newArray();
    typeNames = newArray();
    
    // Ajouter les types qui dÃ©passent les seuils
    if (isIIb == 1) {
        intensities = Array.concat(intensities, value_IIb);
        thresholds = Array.concat(thresholds, IIbThreshold);
        typeNames = Array.concat(typeNames, "IIb");
    }
    if (isIIx == 1) {
        intensities = Array.concat(intensities, value_IIx);
        thresholds = Array.concat(thresholds, IIxThreshold);
        typeNames = Array.concat(typeNames, "IIx");
    }
    if (isIIa == 1) {
        intensities = Array.concat(intensities, value_IIa);
        thresholds = Array.concat(thresholds, IIaThreshold);
        typeNames = Array.concat(typeNames, "IIa");
    }
    if (isI == 1) {
        intensities = Array.concat(intensities, value_I);
        thresholds = Array.concat(thresholds, IThreshold);
        typeNames = Array.concat(typeNames, "I");
    }
    if (iscustom == 1) {
        intensities = Array.concat(intensities, value_custom);
        thresholds = Array.concat(thresholds, customThreshold);
        typeNames = Array.concat(typeNames, customChannelName);
    }
    
// Variables prÃ©calculÃ©es pour Ã©viter les recalculs
totalPositives = isIIb + isIIx + isIIa + isI;
baseClassification = "O";

// ===== CAS 1 TYPE POSITIF =====
if (totalPositives == 1) {
    if (isIIb == 1) {
        baseClassification = "IIb";
    } else if (isIIx == 1) {
        baseClassification = "IIx";
    } else if (isIIa == 1) {
        baseClassification = "IIa";
    } else {
        baseClassification = "I";
    }
}

// ===== CAS DE 2 TYPES POSITIFS =====
else if (totalPositives == 2) {
    
    // IIb + IIa : PrivilÃ©gier dominance
    if (isIIb == 1 && isIIa == 1) {
    	ratio = value_IIb / value_IIa;
    	if (ratio > 1.25) {
            baseClassification = "IIb";
        } else if (ratio < 0.875) {
            baseClassification = "IIa";
        } else {
            baseClassification = "IIb-IIa";
        }
    }

	// IIx + I : PrivilÃ©gier dominance
	else if (isIIx == 1 && isI == 1) {
    	ratio = value_IIx / value_I;
    	if (ratio > 1.25) {
            baseClassification = "IIx";
        } else if (ratio < 0.875) {
            baseClassification = "I";
        } else {
            baseClassification = "IIx-I";
        }
    }

	// IIb + I : PrivilÃ©gier dominance
	else if (isIIb == 1 && isI == 1) {
   		ratio = value_IIb / value_I;
    	if (ratio > 1.25) {
            baseClassification = "IIb";
        } else if (ratio < 0.875) {
            baseClassification = "I";
        } else {
            baseClassification = "IIb-I";
        }
    }
	
	// Cas hybrides autorisÃ©s
	else if (isIIb == 1 && isIIx == 1) {
        ratio = value_IIb / value_IIx;
        if (ratio > 2.5) {
            baseClassification = "IIb";
        } else if (ratio < 0.35) {
            baseClassification = "IIx";
        } else {
            baseClassification = "IIb-IIx";
        }
    }
    
    // IIx + IIa : hybride autorisÃ©
    else if (isIIx == 1 && isIIa == 1) {
        ratio = value_IIx / value_IIa;
        if (ratio > 2.5) {
            baseClassification = "IIx";
        } else if (ratio < 0.35) {
            baseClassification = "IIa";
        } else {
            baseClassification = "IIx-IIa";
        }
    }
    
    // IIa + I : hybride autorisÃ©
    else if (isIIa == 1 && isI == 1) {
        ratio = value_IIa / value_I;
        if (ratio > 2.5) {
            baseClassification = "IIa";
        } else if (ratio < 0.35) {
            baseClassification = "I";
        } else {
            baseClassification = "IIa-I";
        }
    }
}

// ===== CAS DE 3 TYPES POSITIFS =====
else if (totalPositives == 3) {
    
    // IIb + IIa + I : dominance entre IIa et I
    if (isIIb == 1 && isIIa == 1 && isI == 1) {
        ratio = value_IIa / value_I;
        if (ratio > 1.5) {
            baseClassification = "IIa";
        } else if (ratio < 0.67) {
            baseClassification = "I";
        } else {
            baseClassification = "IIa-I";
        }
    }
    
    // IIb + IIx + I : dominance entre IIb et IIx
    else if (isIIb == 1 && isIIx == 1 && isI == 1) {
        ratio = value_IIb / value_IIx;
        if (ratio > 1.5) {
            baseClassification = "IIb";
        } else if (ratio < 0.67) {
            baseClassification = "IIx";
        } else {
            baseClassification = "IIb-IIx";
        }
    }
    
    // IIx + IIa + I : prendre les 2 plus forts
    else if (isIIx == 1 && isIIa == 1 && isI == 1) {
        // DÃ©terminer directement les 2 plus forts sans tri
        if (value_IIx >= value_IIa && value_IIx >= value_I) {
            // IIx est le plus fort
            if (value_IIa >= value_I) {
                // IIx > IIa > I
                ratio = value_IIx / value_IIa;
                if (ratio > 1.5) {
                    baseClassification = "IIx";
                } else {
                    baseClassification = "IIx-IIa";
                }
            } else {
                // IIx > I > IIa
                ratio = value_IIx / value_I;
                if (ratio > 1.5) {
                    baseClassification = "IIx";
                } else {
                    baseClassification = "IIx-I";
                }
            }
        } else if (value_IIa >= value_IIx && value_IIa >= value_I) {
            // IIa est le plus fort
            if (value_IIx >= value_I) {
                // IIa > IIx > I
                ratio = value_IIa / value_IIx;
                if (ratio > 1.5) {
                    baseClassification = "IIa";
                } else {
                    baseClassification = "IIx-IIa";
                }
            } else {
                // IIa > I > IIx
                ratio = value_IIa / value_I;
                if (ratio > 1.5) {
                    baseClassification = "IIa";
                } else {
                    baseClassification = "IIa-I";
                }
            }
        } else {
            // I est le plus fort
            if (value_IIx >= value_IIa) {
                // I > IIx > IIa
                ratio = value_I / value_IIx;
                if (ratio > 1.5) {
                    baseClassification = "I";
                } else {
                    baseClassification = "IIx-I";
                }
            } else {
                // I > IIa > IIx
                ratio = value_I / value_IIa;
                if (ratio > 1.5) {
                    baseClassification = "I";
                } else {
                    baseClassification = "IIa-I";
                }
            }
        }
    }
        // IIx + IIa + IIb : prendre les 2 plus forts
    else if (isIIx == 1 && isIIa == 1 && isIIb == 1) {
        // DÃ©terminer directement les 2 plus forts sans tri
        if (value_IIx >= value_IIa && value_IIx >= value_IIb) {
            // IIx est le plus fort
            if (value_IIa >= value_IIb) {
                // IIx > IIa > IIb
                ratio = value_IIx / value_IIa;
                if (ratio > 1.5) {
                    baseClassification = "IIx";
                } else {
                    baseClassification = "IIx-IIa";
                }
            } else {
                // IIx > IIb > IIa
                ratio = value_IIx / value_IIb;
                if (ratio > 1.5) {
                    baseClassification = "IIx";
                } else {
                    baseClassification = "IIx-IIb";
                }
            }
        } else if (value_IIa >= value_IIx && value_IIa >= value_IIb) {
            // IIa est le plus fort
            if (value_IIx >= value_IIb) {
                // IIa > IIx > IIb
                ratio = value_IIa / value_IIx;
                if (ratio > 1.5) {
                    baseClassification = "IIa";
                } else {
                    baseClassification = "IIx-IIa";
                }
            } else {
                // IIa > IIb > IIx
                ratio = value_IIa / value_IIb;
                if (ratio > 1.5) {
                    baseClassification = "IIa";
                } else {
                    baseClassification = "IIa-IIb";
                }
            }
        } else {
            // IIb est le plus fort
            if (value_IIx >= value_IIa) {
                // IIb > IIx > IIa
                ratio = value_IIb / value_IIx;
                if (ratio > 1.5) {
                    baseClassification = "IIb";
                } else {
                    baseClassification = "IIx-IIb";
                }
            } else {
                // IIb > IIa > IIx
                ratio = value_IIb / value_IIa;
                if (ratio > 1.5) {
                    baseClassification = "IIb";
                } else {
                    baseClassification = "IIa-IIb";
                }
            }
        }
    }
}

// ===== CAS 4+ TYPES POSITIFS =====
else if (totalPositives >= 4) {
    // Trouver directement le maximum sans boucle
    maxValue = value_IIb;
    baseClassification = "IIb";
    
    if (value_IIx > maxValue) {
        maxValue = value_IIx;
        baseClassification = "IIx";
    }
    if (value_IIa > maxValue) {
        maxValue = value_IIa;
        baseClassification = "IIa";
    }
    if (value_I > maxValue) {
        maxValue = value_I;
        baseClassification = "I";
    }
}

// ===== AUCUN TYPE POSITIF =====
// baseClassification reste "O"

// ===== INTEGRATION CUSTOM =====
if (iscustom == 1) {
    if (baseClassification == "O") {
        classification = customChannelName;
    } else {
        classification = baseClassification + "-" + customChannelName;
    }
} else {
    classification = baseClassification;
}
    
    // Construire la ligne de rÃ©sultat
    resultLine = roiID + ";" + sizeValueFormatted;
    
    // Ajouter les valeurs des canaux de maniÃ¨re sÃ©curisÃ©e
    if (IIbChannel > 0) {
        resultLine = resultLine + ";" + replace(d2s(value_IIb, 2), ".", ",");
    }
    if (IIxChannel > 0) {
        resultLine = resultLine + ";" + replace(d2s(value_IIx, 2), ".", ",");
    }
    if (IIaChannel > 0) {
        resultLine = resultLine + ";" + replace(d2s(value_IIa, 2), ".", ",");
    }
    if (IChannel > 0) {
        resultLine = resultLine + ";" + replace(d2s(value_I, 2), ".", ",");
    }
    if (customChannel > 0) {
        resultLine = resultLine + ";" + replace(d2s(value_custom, 2), ".", ",");
    }
    
    // Ajouter la classification Ã  la fin
    resultLine = resultLine + ";" + classification;
    
    // Ã‰crire la ligne dans le fichier
    print(outputFile, resultLine);
}
File.close(outputFile);

	// Supprimer le fichier compilÃ© aprÃ¨s utilisation
	File.delete(dir + ImageName + "_Compiled_Results.csv");
	
	resultsFile = File.openAsString(dir + ImageName + "_Classified_Results.csv");
	lines = split(resultsFile, "\n");
	headers = split(lines[0], ";");
	
	// Trouver l'index de la colonne Classification
	classIndex = -1;
	for (i = 0; i < headers.length; i++) {
	    if (headers[i] == "Classification") {
	        classIndex = i;
	        break;
	    }
	}
	
	if (classIndex == -1) {
	    exit("Error: Classification column not found");
	}
	
	// Modifier la partie qui crÃ©e le fichier de sortie avec les statistiques
	outputModified = File.open(dir + ImageName + "_Classified_Results.csv");
	
	// Ã‰crire l'en-tÃªte avec les colonnes supplÃ©mentaires
	if (useCSA) {
	    headerString = "ROI;CSA";
	} else {
	    headerString = "ROI;MinFeret";
	}
	
	// Ajouter uniquement les canaux actifs avec vÃ©rification de leur utilisation
	if (IIbChannel > 0) {
	    headerString = headerString + ";IIb";
	}
	if (IIxChannel > 0) {
	    headerString = headerString + ";IIx";
	}
	if (IIaChannel > 0) {
	    headerString = headerString + ";IIa";
	}
	if (IChannel > 0) {
	    headerString = headerString + ";I";
	}
	if (customChannel > 0) {
	    headerString = headerString + ";" + customChannelName;
	}
	headerString = headerString + ";Classification;;Fiber type;Number;Percentage;Area mean";
	print(outputModified, headerString);
	
	// DÃ©terminer la premiÃ¨re ligne de donnÃ©es
	firstDataRow = 2;
	
	// Identifier les classifications uniques prÃ©sentes dans les donnÃ©es
	uniqueClassifications = newArray();
	for (i = 1; i < lines.length; i++) {
	    values = split(lines[i], ";");
	    if (values.length > classIndex) {
	        currentClass = values[classIndex];
	        
	        found = false;
	        for (j = 0; j < uniqueClassifications.length; j++) {
	            if (uniqueClassifications[j] == currentClass) {
	                found = true;
	                break;
	            }
	        }
	        if (!found && currentClass != "") {
	            uniqueClassifications = Array.concat(uniqueClassifications, currentClass);
	        }
	    }
	}
	Array.sort(uniqueClassifications);
	
	// Ã‰crire les donnÃ©es
	for (i = 1; i < lines.length; i++) {
	    values = split(lines[i], ";");
	    resultLine = values[0] + ";" + values[1];  // ROI et Area
	    
	    colIndex = 2; // Commencer aprÃ¨s ROI et Area
	    
    // Ajouter les valeurs des canaux dans l'ordre original
	if (IIbChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + ";" + values[colIndex];
	    colIndex++;}
		}
	if (IIxChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + ";" + values[colIndex];
	    colIndex++;}
		}
	if (IIaChannel > 0) {
	    if (colIndex < values.length) {
	        resultLine = resultLine + ";" + values[colIndex];
	        colIndex++;}
		}
	if (IChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + ";" + values[colIndex];
	    colIndex++;}
		}
	if (customChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + ";" + values[colIndex];
	    colIndex++;}
		}
    // Ajouter la classification Ã  la fin
	if (colIndex < values.length) {
	    resultLine = resultLine + ";" + values[colIndex];
	}
    // Ajouter les formules pour les statistiques
	baseColumns = 2; // ROI et Area
	activeChannels = 0;
	
	if (IIbChannel > 0) {activeChannels++;}
	if (IIxChannel > 0) {activeChannels++;}
	if (IIaChannel > 0) {activeChannels++;}
	if (IChannel > 0) {activeChannels++;}
	if (customChannel > 0) {activeChannels++;}
	
	// Obtenir les rÃ©fÃ©rences des colonnes
	classificationCol = getColumnLetter(baseColumns + activeChannels);
	areaCol = "B"; // La colonne Area est toujours B
	
	// GÃ©nÃ©rer les formules
	if (i <= uniqueClassifications.length) {
	    currentClass = uniqueClassifications[i-1];
	    	
    // Type de fibre
    resultLine = resultLine + ";;\"" + currentClass + "\";";
    
    // Index de la colonne de classification
    classColIndex = baseColumns + activeChannels;
    classificationCol = getColumnLetter(classColIndex);
    
    // Nombre (COUNT.IF)
    resultLine = resultLine + "\"=NB.SI(" + classificationCol + ":" + classificationCol + 
                ";\"\"" + currentClass + "\"\")\";";
    
    // Pourcentage
    countColIndex = getClassificationColumnIndex(baseColumns, activeChannels) + 4;
    countCol = getColumnLetter(countColIndex);
    resultLine = resultLine + "\"=" + countCol + (firstDataRow + i - 1) + 
                "/NB(A:A)*100\";";
    
    // Moyenne des aires (AVERAGE.IF)
    resultLine = resultLine + "\"=MOYENNE.SI(" + classificationCol + ":" + classificationCol + 
                ";\"\"" + currentClass + "\"\";" + areaCol + ":" + areaCol + ")\";";
	}
	
	else if (i == uniqueClassifications.length + 1) { // Ligne des totaux
	    resultLine += ";;\"Total\";"; // Type de fibre
	    resultLine += "\"=NB(A:A)\";"; // Nombre total
	    resultLine += "100;"; // Pourcentage total
	    resultLine += "\"=MOYENNE(B:B)\";"; // Moyenne gÃ©nÃ©rale des aires
	}   
	    print(outputModified, resultLine);
	}

File.close(outputModified);

File.rename(dir + ImageName + "_Classified_Results_Modified.csv", 
           dir + ImageName + "_Classified_Results.csv");

							// ============= 5. CrÃ©ation des visualisations ==================
						
	selectWindow("Original_For_Analysis");
	getDimensions(width, height, channels, slices, frames);

smallImageProgress(k, nbFichiers, 8, 10, "Creating visualization");

	// CrÃ©er l'overlay avec les dimensions exactes
	newImage("Base_Overlay", "RGB white", width, height, 1);
	run("Select None");
	
	// Charger les ROIs et les rÃ©sultats classifiÃ©s
	roiManager("reset");
	roiManager("Open", dir+ImageName+"_ROI_Set.zip");
	classifiedResults = File.openAsString(dir + ImageName + "_Classified_Results.csv");
	classLines = split(classifiedResults, "\n");
	
	// Trouver l'index de la colonne Classification
	classHeaders = split(classLines[0], ";");
	classIndex = -1;
	for (i = 0; i < classHeaders.length; i++) {
	    if (classHeaders[i] == "Classification") {
	        classIndex = i;
	        break;
	    }
	}
	
	// Appliquer les couleurs aux ROIs
	nRois = roiManager("count");
	for (i = 0; i < nRois; i++) {
	    if (i + 1 >= classLines.length) continue;
	    
	    classValues = split(classLines[i + 1], ";");
	    if (classValues.length <= classIndex) continue;
	    classification = classValues[classIndex];
	    
	    color = getClassificationColor(classification, channelColors, selectedChannels);
	    selectWindow("Base_Overlay");
	    roiManager("select", i);
	    setForegroundColor(color[0], color[1], color[2]);
	    run("Fill", "slice");
	}

	// Sauvegarder l'overlay
	selectWindow("Base_Overlay");
	saveAs("PNG", dir+ImageName+"_temp_overlay.png");
	close();
	
							// ============ 6. Sauvegarde des rÃ©sultats ===============
					
smallImageProgress(k, nbFichiers, 9, 10, "Saving results");

	// S'assurer que les bonnes images sont ouvertes dans le bon ordre
	// D'abord ouvrir l'overlay
	dir = getPlatformSafePath(dir);
	open(dir+ImageName+"_temp_overlay.png");
	rename("Overlay");
	
	// Ensuite, sélectionner l'image originale en dernier (important pour Add Image)
	selectWindow("Original_For_Analysis");
	
	// Ajouter l'overlay avec la mÃ©thode native d'ImageJ
	run("Add Image...", "image=Overlay x=0 y=0 opacity=" + overlayOpacity);
	
	// Sauvegarder l'image finale
	saveAs("Tiff", dir+ImageName+"_Final.tif");

smallImageProgress(k, nbFichiers, 10, 10, "Completed analysis");


 // =============================== NETTOYAGE ET PREPARATION POUR L'IMAGE SUIVANTE =============================
 
 
	close("*");
	File.delete(dir+ImageName+"_temp_overlay.png");


GLOBAL_LAST_DIR = getPlatformSafePath(dir);
GLOBAL_LAST_IMAGE = ImageName;

GLOBAL_FINAL_PATH = GLOBAL_LAST_DIR + GLOBAL_LAST_IMAGE + "_Final.tif";
}

if (isOpen("Log")) {
    selectWindow("Log");
    run("Close");
}
run("Close All");
if (isOpen("ROI Manager")) {
    selectWindow("ROI Manager");
    run("Close");
}
if (isOpen("Results")) {
    selectWindow("Results");
    run("Close");
}
showMessage("Et Merci Bonsoir !");

exit();