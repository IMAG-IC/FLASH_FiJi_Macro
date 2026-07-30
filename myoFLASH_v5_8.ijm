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
	Dialog.addChoice("Formula language (spreadsheet):", newArray("Français", "English"), "Français");
    
    Dialog.addMessage("Fiber types to analyze", 18, "#8a7cc2");
    Dialog.addNumber("Type IIb channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addString("Type IIb name:", "IIb", 8);
    Dialog.addNumber("Type IIx channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addString("Type IIx name:", "IIx", 8);
    Dialog.addNumber("Type IIa channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addString("Type IIa name:", "IIa", 8);
    Dialog.addNumber("Type I channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addString("Type I name:", "I", 8);
    
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
    // Noms d'affichage personnalisés (file des String : IIb, IIx, IIa, I, puis custom)
    typeName_IIb = Dialog.getString();
    typeName_IIx = Dialog.getString();
    typeName_IIa = Dialog.getString();
    typeName_I = Dialog.getString();
    customChannel = Dialog.getNumber();
    customChannelName = Dialog.getString();
    sizeMeasurementMethod = Dialog.getChoice();
    spreadsheetLang = Dialog.getChoice();
    showAdvanced = Dialog.getCheckbox();
    
    // Show advanced parameters
    if (showAdvanced) {
        Dialog.create("Advanced Options");
        
        Dialog.addMessage("Segmentation parameters", 14, "#4285F4");
        Dialog.addSlider("Cellpose sensitivity:", 0.1, 2.0, 1.0);
        Dialog.addSlider("Small fiber exclusion threshold:", 50, 500, 200);
        
        Dialog.addMessage("Classification parameters", 14, "#0F9D58");
        Dialog.addSlider("Adaptive threshold factor:", 0.1, 0.6, 0.3);
        Dialog.addSlider("Positivity fraction (display range):", 0.01, 0.5, 0.15);
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
        positivityFraction = Dialog.getNumber();
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
        positivityFraction = 0.15;
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
	               filterNonHomogeneous, useGPU, useChannelColors, overlayOpacity, positivityFraction,
	               typeName_IIb, typeName_IIx, typeName_IIa, typeName_I, spreadsheetLang);
    
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

// Seuil de positivité basé sur le display range ajusté par l'utilisateur
// channelIndex  : numéro de canal 1-indexé (tel que IIbChannel, IChannel, etc.)
// positivityFraction : fraction du display range au-dessus de displayMin (ex: 0.15)
// Retourne le seuil de niveaux de gris brut correspondant
function getDisplayRangeThreshold(channelIndex, positivityFraction) {
    
    // Vérifications de sécurité
    if (channelIndex <= 0) {
        print("Warning: getDisplayRangeThreshold appelé avec channelIndex=" + channelIndex);
        return 0;
    }
    if (!isOpen("Original_For_Analysis")) {
        print("Warning: Original_For_Analysis n'est pas ouverte");
        return 0;
    }
    
    selectWindow("Original_For_Analysis");
    
    // Vérifier que le canal demandé existe dans l'image
    getDimensions(w, h, nCh, sl, fr);
    if (channelIndex > nCh) {
        print("Warning: canal " + channelIndex + " demandé mais l'image n'a que " + nCh + " canaux");
        return 0;
    }
    
    // Lire le display range du canal
    Stack.setChannel(channelIndex);
    getMinAndMax(displayMin, displayMax);
    
    // Vérifier que le display range est cohérent
    if (displayMax <= displayMin) {
        print("Warning: display range incohérent pour canal " + channelIndex + 
              " (min=" + displayMin + ", max=" + displayMax + "). Seuil fixé à displayMin.");
        return displayMin;
    }
    
    // Calculer et retourner le seuil
    threshold = displayMin + positivityFraction * (displayMax - displayMin);
    
    return threshold;
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
            
            // Trouver le canal correspondant au type (comparaison sur les noms d'affichage)
            for (i = 0; i < fiberTypeChannels.length; i++) {
                if (types[t] == channelDisplayNames[i]) {
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
        
        // Trouver le canal correspondant au type (comparaison sur les noms d'affichage)
        for (i = 0; i < channelDisplayNames.length; i++) {
            if (classification == channelDisplayNames[i]) {
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

// Formate un nombre à 2 décimales avec le séparateur décimal de la langue choisie.
// FR : virgule (decimalIsComma=true) ; EN : point.
function fmt2(x) {
    s = d2s(x, 2);
    if (decimalIsComma) {
        s = replace(s, ".", ",");
    }
    return s;
}

// Traduit une classification en codes internes ("I","IIa","IIb","IIx",...) vers les noms
// d'affichage personnalisés. Gère les hybrides ("IIb-IIa") en traduisant chaque token.
// S'appuie sur les tableaux globaux channelNames (interne) / channelDisplayNames (affichage).
function remapClassificationToDisplay(internalClass) {
    // "O" (non classé) et chaîne vide restent inchangés
    if (internalClass == "O" || internalClass == "") {
        return internalClass;
    }
    tokens = split(internalClass, "-");
    result = "";
    for (tk = 0; tk < tokens.length; tk++) {
        displayTok = tokens[tk]; // par défaut inchangé (ex. canal custom déjà en nom d'affichage)
        for (mp = 0; mp < channelNames.length; mp++) {
            if (tokens[tk] == channelNames[mp]) {
                displayTok = channelDisplayNames[mp];
                break;
            }
        }
        if (tk == 0) {
            result = displayTok;
        } else {
            result = result + "-" + displayTok;
        }
    }
    return result;
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
exclusionThreshold = params[12];
adaptiveThresholdFactor = params[13];
filterNonHomogeneous = params[14];
useGPU = params[15];
useChannelColors = params[16];
overlayOpacity = params[17];
positivityFraction = params[18];
// Noms d'affichage personnalisés des types de fibres
typeName_IIb = params[19];
typeName_IIx = params[20];
typeName_IIa = params[21];
typeName_I = params[22];
spreadsheetLang = params[23];

// ===== TOKENS DE FORMULE SELON LA LANGUE DU TABLEUR =====
// Permet des formules VIVANTES (recalcul automatique) adaptées à la locale choisie.
// Le fichier reste au format CSV « français » (séparateur de champ ; et décimale ,).
if (spreadsheetLang == "English") {
    // Excel en anglais mais réglages régionaux européens (cas le plus fréquent hors USA) :
    // séparateur de liste = ";" et décimale = "," → MÊME structure que le français.
    // Seuls les NOMS DE FONCTIONS changent (interface Excel anglaise).
    fnCountIf = "COUNTIF";   // NB.SI
    fnCount   = "COUNT";     // NB
    fnAvgIf   = "AVERAGEIF"; // MOYENNE.SI
    fnAvg     = "AVERAGE";   // MOYENNE
    argSep    = ";";         // séparateur d'arguments = séparateur de liste régional (;)
    // Format TSV : séparateur de colonnes = TABULATION. Elle n'entre en conflit ni avec la
    // décimale "," ni avec le ";" des formules. La ligne "sep=<tab>" écrite en tête du fichier
    // fait découper les colonnes automatiquement au double-clic.
    fieldSep  = "\t";
    // On GARDE la décimale "," : un Excel à réglages régionaux européens ne reconnaît
    // "3537,59" comme un NOMBRE que si la décimale est une virgule.
    // Indispensable pour que AVERAGEIF / AVERAGE fonctionnent sur la colonne B.
    decimalIsComma = true;
} else {
    fnCountIf = "NB.SI";
    fnCount   = "NB";
    fnAvgIf   = "MOYENNE.SI";
    fnAvg     = "MOYENNE";
    argSep    = ";";         // séparateur d'arguments français
    fieldSep  = ";";         // séparateur de colonnes CSV français
    decimalIsComma = true;   // décimale = virgule
}

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
// channelNames        = codes internes ("IIb","IIx","IIa","I",custom) → sert à la détection des
//                       colonnes du fichier compilé et à toute la logique interne (INCHANGÉ).
// channelDisplayNames = noms d'affichage personnalisés → sert uniquement aux sorties (CSV, overlay).
selectedChannels = newArray();
channelNames = newArray();
channelDisplayNames = newArray();

if (IIbChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IIbChannel);
    channelNames = Array.concat(channelNames, "IIb");
    channelDisplayNames = Array.concat(channelDisplayNames, typeName_IIb);
}
if (IIxChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IIxChannel);
    channelNames = Array.concat(channelNames, "IIx");
    channelDisplayNames = Array.concat(channelDisplayNames, typeName_IIx);
}
if (IIaChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IIaChannel);
    channelNames = Array.concat(channelNames, "IIa");
    channelDisplayNames = Array.concat(channelDisplayNames, typeName_IIa);
}
if (IChannel > 0) {
    selectedChannels = Array.concat(selectedChannels, IChannel);
    channelNames = Array.concat(channelNames, "I");
    channelDisplayNames = Array.concat(channelDisplayNames, typeName_I);
}
if (customChannel > 0 
//&& lengthOf(customChannelName) > 0
) {
    selectedChannels = Array.concat(selectedChannels, customChannel);
    channelNames = Array.concat(channelNames, customChannelName);
    channelDisplayNames = Array.concat(channelDisplayNames, customChannelName);
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
	run("Select None");

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
    print("Warning: No ROIs to set properties for. You may have an active selection on your image. Clear it and restart the analysis");
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
    numRows = firstData.length;

    // Préchargement de tous les canaux supplémentaires (C lectures au lieu de N×C)
    // Tableau plat : preloadedMeans[c * numRows + i] = valeur Mean ROI i canal c
    preloadedMeans = newArray(selectedChannels.length * numRows);
    for (c = 0; c < selectedChannels.length; c++) {
        cRaw = File.openAsString(dir + ImageName + "Measurements_" + channelNames[c] + ".csv");
        cLines = split(cRaw, "\n");
        for (ri = 0; ri < numRows && (ri + 1) < cLines.length; ri++) {
            cVals = split(cLines[ri + 1], ",");
            preloadedMeans[c * numRows + ri] = parseFloat(cVals[2]);
        }
    }

	// Charger les ROIs pour MinFeret si nécessaire
	if (!useCSA) {
	    roiManager("reset");
	    roiManager("Open", dir+ImageName+"_ROI_Set.zip");
	}

	// Écrire les données — aucune lecture de fichier dans la boucle
	for (i = 0; i < firstData.length; i++) {
	    values = split(firstData[i], ",");
	    if (useCSA) {
	        sizeValue = values[1];
	    } else {
	        roiManager("select", i);
	        run("Set Measurements...", "feret's redirect=None decimal=3");
	        run("Measure");
	        sizeValue = getResult("MinFeret", nResults-1);
	        run("Clear Results");
	    }
        line = values[0] + "," + sizeValue;

        for (c = 0; c < selectedChannels.length; c++) {
            line = line + "," + d2s(preloadedMeans[c * numRows + i], 6);
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
	    
    if (headers[i] == "Mean_IIb") {
        IIbIndex = i;
    }
    if (headers[i] == "Mean_IIx") {
        IIxIndex = i;
    }
    if (headers[i] == "Mean_IIa") {
        IIaIndex = i;
    }
    if (headers[i] == "Mean_I") {
        IIndex = i;
    }
    // Vérifier d'abord si un canal custom est demandé
    if (customChannel > 0 && customChannelName != "" && headers[i] == "Mean_" + customChannelName) {
        customIndex = i;
    }
}
	numRows = data.length;
	
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
	
							// ============= 4. Classification des fibres ==================
						
		selectWindow("Original_For_Analysis");
	    
	    // Importer ROIs si nÃ©cessaire
	    if (roiManager("count") == 0) {
		    roiManager("reset");
		    roiManager("Open", dir+ImageName+"_ROI_Set.zip");
		}
	    
	    if (IIbIndex > -1) {
	        IIbThreshold = getDisplayRangeThreshold(IIbChannel, positivityFraction);
	    }
	    if (IIxIndex > -1) {
	        IIxThreshold = getDisplayRangeThreshold(IIxChannel, positivityFraction);
	    }
	    if (IIaIndex > -1) {
	        IIaThreshold = getDisplayRangeThreshold(IIaChannel, positivityFraction);
	    }
	    if (IIndex > -1) {
	        IThreshold = getDisplayRangeThreshold(IChannel, positivityFraction);
	    }
	    if (customIndex > -1) {
	        customThreshold = getDisplayRangeThreshold(customChannel, positivityFraction);
	    }
	
	// Créer le fichier de sortie avec la classification
	outputFile = File.open(dir + ImageName + "_Classified_Results.csv");
	
	// Construire l'en-tÃªte avec le séparateur de colonnes de la langue choisie
	if (useCSA) {
    headerString = "ROI" + fieldSep + "CSA";
	} else {
	headerString = "ROI" + fieldSep + "MinFeret";
	}
	
	// N'ajouter que les colonnes pour les canaux actifs (noms d'affichage personnalisés)
	if (IIbChannel > 0) {
	    headerString = headerString + fieldSep + typeName_IIb;
	}
	if (IIxChannel > 0) {
	    headerString = headerString + fieldSep + typeName_IIx;
	}
	if (IIaChannel > 0) {
	    headerString = headerString + fieldSep + typeName_IIa;
	}
	if (IChannel > 0) {
	    headerString = headerString + fieldSep + typeName_I;
	}
	if (customChannel > 0) {
	    headerString = headerString + fieldSep + customChannelName;
	}
	
	// Ajouter la colonne de classification Ã  la fin
	headerString = headerString + fieldSep + "Classification";
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

		// Mettre en cache le nombre de ROIs avant la boucle (valeur invariante)
	nRoisClass = roiManager("count");
	
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
	
	// Pour l'affichage CSV (formatÃ© selon la langue)
	sizeValueFormatted = fmt2(sizeValueNumeric);
    
	// ===== OPTIMISATION: UTILISER LE CACHE =====
	if (i < nRoisClass) {
	    sizeValueNumeric = getCachedArea(i);
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
    
homogeneityFactor_IIb    = 1.0;
homogeneityFactor_IIx    = 1.0;
homogeneityFactor_IIa    = 1.0;
homogeneityFactor_I      = 1.0;
homogeneityFactor_custom = 1.0;

// Calculer les facteurs d'homogénéité seulement si i est dans les limites du ROI Manager
// Pénalité de surface uniquement — calculateHomogeneity ne peut pas fonctionner
// avec une seule valeur par ROI (division par zéro dans calculateStd, n-1=0)
if (i < nRoisClass) {
    area_roi = getCachedArea(i);
    penaliteAire = 1.0;
    if (area_roi < 200) {
        penaliteAire = 1.0 + (1.0 - area_roi / 200.0) * 0.8;
    }
    homogeneityFactor_IIb    = penaliteAire;
    homogeneityFactor_IIx    = penaliteAire;
    homogeneityFactor_IIa    = penaliteAire;
    homogeneityFactor_I      = penaliteAire;
    homogeneityFactor_custom = penaliteAire;
}
      // Déterminer si chaque type est positif
    isIIb = 0;
    isIIx = 0;
    isIIa = 0;
    isI = 0;
    iscustom = 0;
    
 // Score normalisé = (valeur - seuil) / seuil
	// Mesure à quel point chaque canal dépasse son propre seuil, indépendamment de son échelle d'intensité.
	// Score > 0 = positif, score <= 0 = négatif.
	// Ce score est comparable entre canaux même si leurs intensités absolues sont très différentes.
	score_IIb    = 0;
	score_IIx    = 0;
	score_IIa    = 0;
	score_I      = 0;
	score_custom = 0;

	adjustedHomogeneityFactor_IIb = 1.0 + (homogeneityFactor_IIb - 1.0) * 0.9;
	if (IIbIndex > -1 && IIbChannel > 0 && IIbThreshold > 0) {
	    effectiveThreshold_IIb = IIbThreshold * adjustedHomogeneityFactor_IIb;
	    if (value_IIb > effectiveThreshold_IIb) {
	        isIIb = 1;
	        score_IIb = (value_IIb - effectiveThreshold_IIb) / effectiveThreshold_IIb;
	    }
	}

	adjustedHomogeneityFactor_IIx = 1.0 + (homogeneityFactor_IIx - 1.0) * 0.9;
	if (IIxIndex > -1 && IIxChannel > 0 && IIxThreshold > 0) {
	    effectiveThreshold_IIx = IIxThreshold * adjustedHomogeneityFactor_IIx;
	    if (value_IIx > effectiveThreshold_IIx) {
	        isIIx = 1;
	        score_IIx = (value_IIx - effectiveThreshold_IIx) / effectiveThreshold_IIx;
	    }
	}

	adjustedHomogeneityFactor_IIa = 1.0 + (homogeneityFactor_IIa - 1.0) * 0.9;
	if (IIaIndex > -1 && IIaChannel > 0 && IIaThreshold > 0) {
	    effectiveThreshold_IIa = IIaThreshold * adjustedHomogeneityFactor_IIa;
	    if (value_IIa > effectiveThreshold_IIa) {
	        isIIa = 1;
	        score_IIa = (value_IIa - effectiveThreshold_IIa) / effectiveThreshold_IIa;
	    }
	}

	adjustedHomogeneityFactor_I = 1.0 + (homogeneityFactor_I - 1.0) * 0.9;
	if (IIndex > -1 && IChannel > 0 && IThreshold > 0) {
	    effectiveThreshold_I = IThreshold * adjustedHomogeneityFactor_I;
	    if (value_I > effectiveThreshold_I) {
	        isI = 1;
	        score_I = (value_I - effectiveThreshold_I) / effectiveThreshold_I;
	    }
	}

	adjustedHomogeneityFactor_custom = 1.0 + (homogeneityFactor_custom - 1.0) * 0.9;
	if (customIndex > -1 && customChannel > 0 && customThreshold > 0) {
	    effectiveThreshold_custom = customThreshold * adjustedHomogeneityFactor_custom;
	    if (value_custom > effectiveThreshold_custom) {
	        iscustom = 1;
	        score_custom = (value_custom - effectiveThreshold_custom) / effectiveThreshold_custom;
	    }
	}
	
    // PrÃ©paration pour la classification
    classification = "O"; // Par dÃ©faut non-classÃ©
    
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

    // IIb + IIx
    if (isIIb == 1 && isIIx == 1) {
        if (score_IIx > 0) { ratio = score_IIb / score_IIx; } else { ratio = 999; }
        if (ratio > 50.0) { baseClassification = "IIb"; }
        else if (ratio < 0.010) { baseClassification = "IIx"; }
        else { baseClassification = "IIb-IIx"; }
    }

    // IIx + IIa
    else if (isIIx == 1 && isIIa == 1) {
        if (score_IIa > 0) { ratio = score_IIx / score_IIa; } else { ratio = 999; }
        if (ratio > 50.0) { baseClassification = "IIx"; }
        else if (ratio < 0.010) { baseClassification = "IIa"; }
        else { baseClassification = "IIx-IIa"; }
    }

    // IIa + I
    else if (isIIa == 1 && isI == 1) {
        if (score_I > 0) { ratio = score_IIa / score_I; } else { ratio = 999; }
        if (ratio > 50.0) { baseClassification = "IIa"; }
        else if (ratio < 0.01) { baseClassification = "I"; }
        else { baseClassification = "IIa-I"; }
    }

    // IIb + IIa
    else if (isIIb == 1 && isIIa == 1) {
        if (score_IIa > 0) { ratio = score_IIb / score_IIa; } else { ratio = 999; }
        if (ratio > 2.0) { baseClassification = "IIb"; }
        else if (ratio < 0.5) { baseClassification = "IIa"; }
        else { baseClassification = "IIb-IIa"; }
    }

    // IIx + I
    else if (isIIx == 1 && isI == 1) {
        if (score_I > 0) { ratio = score_IIx / score_I; } else { ratio = 999; }
        if (ratio > 2.0) { baseClassification = "IIx"; }
        else if (ratio < 0.5) { baseClassification = "I"; }
        else { baseClassification = "IIx-I"; }
    }

    // IIb + I
    else if (isIIb == 1 && isI == 1) {
        if (score_I > 0) { ratio = score_IIb / score_I; } else { ratio = 999; }
        if (ratio > 2.0) { baseClassification = "IIb"; }
        else if (ratio < 0.5) { baseClassification = "I"; }
        else { baseClassification = "IIb-I"; }
    }
}

// ===== CAS DE 3 TYPES POSITIFS =====
else if (totalPositives == 3) {

    // IIb + IIx + IIa
    if (isIIb == 1 && isIIx == 1 && isIIa == 1) {
        if (score_IIb >= score_IIx && score_IIb >= score_IIa) {
            if (score_IIx > 0) { ratio = score_IIb / score_IIx; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIb"; }
            else { baseClassification = "IIb-IIx"; }
        } else if (score_IIx >= score_IIb && score_IIx >= score_IIa) {
            if (score_IIa > 0) { ratio = score_IIx / score_IIa; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIx"; }
            else { baseClassification = "IIx-IIa"; }
        } else {
            if (score_IIx > 0) { ratio = score_IIa / score_IIx; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIa"; }
            else { baseClassification = "IIx-IIa"; }
        }
    }

    // IIb + IIx + I
    else if (isIIb == 1 && isIIx == 1 && isI == 1) {
        if (score_IIb >= score_IIx && score_IIb >= score_I) {
            if (score_IIx > 0) { ratio = score_IIb / score_IIx; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIb"; }
            else { baseClassification = "IIb-IIx"; }
        } else if (score_IIx >= score_IIb && score_IIx >= score_I) {
            if (score_IIb > 0) { ratio = score_IIx / score_IIb; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIx"; }
            else { baseClassification = "IIb-IIx"; }
        } else {
            if (score_IIx > 0) { ratio = score_I / score_IIx; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "I"; }
            else { baseClassification = "IIx-I"; }
        }
    }

    // IIb + IIa + I
    else if (isIIb == 1 && isIIa == 1 && isI == 1) {
        if (score_IIb >= score_IIa && score_IIb >= score_I) {
            if (score_IIa > 0) { ratio = score_IIb / score_IIa; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIb"; }
            else { baseClassification = "IIb-IIa"; }
        } else if (score_IIa >= score_IIb && score_IIa >= score_I) {
            if (score_IIb > 0) { ratio = score_IIa / score_IIb; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIa"; }
            else { baseClassification = "IIb-IIa"; }
        } else {
            if (score_IIa > 0) { ratio = score_I / score_IIa; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "I"; }
            else { baseClassification = "IIa-I"; }
        }
    }

    // IIx + IIa + I
    else if (isIIx == 1 && isIIa == 1 && isI == 1) {
        if (score_IIx >= score_IIa && score_IIx >= score_I) {
            if (score_IIa > 0) { ratio = score_IIx / score_IIa; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIx"; }
            else { baseClassification = "IIx-IIa"; }
        } else if (score_IIa >= score_IIx && score_IIa >= score_I) {
            if (score_IIx > 0) { ratio = score_IIa / score_IIx; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "IIa"; }
            else { baseClassification = "IIx-IIa"; }
        } else {
            if (score_IIa > 0) { ratio = score_I / score_IIa; } else { ratio = 999; }
            if (ratio > 2.0) { baseClassification = "I"; }
            else { baseClassification = "IIa-I"; }
        }
    }
}

// ===== CAS 4+ TYPES POSITIFS =====
else if (totalPositives >= 4) {

    maxScore1 = score_IIb; maxType1 = "IIb";
    if (score_IIx > maxScore1) { maxScore1 = score_IIx; maxType1 = "IIx"; }
    if (score_IIa > maxScore1) { maxScore1 = score_IIa; maxType1 = "IIa"; }
    if (score_I   > maxScore1) { maxScore1 = score_I;   maxType1 = "I";   }

    maxScore2 = 0; maxType2 = "O";
    if (maxType1 != "IIb" && score_IIb > maxScore2) { maxScore2 = score_IIb; maxType2 = "IIb"; }
    if (maxType1 != "IIx" && score_IIx > maxScore2) { maxScore2 = score_IIx; maxType2 = "IIx"; }
    if (maxType1 != "IIa" && score_IIa > maxScore2) { maxScore2 = score_IIa; maxType2 = "IIa"; }
    if (maxType1 != "I"   && score_I   > maxScore2) { maxScore2 = score_I;   maxType2 = "I";   }

    if (maxScore2 > 0) { ratio = maxScore1 / maxScore2; } else { ratio = 999; }
    if (ratio > 2.0) {
        baseClassification = maxType1;
    } else {
        ordreType1 = 99; ordreType2 = 99;
        if (maxType1 == "IIb") { ordreType1 = 1; }
        if (maxType1 == "IIx") { ordreType1 = 2; }
        if (maxType1 == "IIa") { ordreType1 = 3; }
        if (maxType1 == "I")   { ordreType1 = 4; }
        if (maxType2 == "IIb") { ordreType2 = 1; }
        if (maxType2 == "IIx") { ordreType2 = 2; }
        if (maxType2 == "IIa") { ordreType2 = 3; }
        if (maxType2 == "I")   { ordreType2 = 4; }
        if (ordreType1 < ordreType2) {
            baseClassification = maxType1 + "-" + maxType2;
        } else {
            baseClassification = maxType2 + "-" + maxType1;
        }
    }
}

// ===== AUCUN TYPE POSITIF =====
// baseClassification reste "O"

// ===== TRADUCTION VERS LES NOMS D'AFFICHAGE + INTEGRATION CUSTOM =====
// La logique de classification reste en codes internes ; on ne traduit qu'ici, à la sortie.
displayBase = remapClassificationToDisplay(baseClassification);
if (iscustom == 1) {
    if (baseClassification == "O") {
        classification = customChannelName;
    } else {
        classification = displayBase + "-" + customChannelName;
    }
} else {
    classification = displayBase;
}
    
    // Construire la ligne de rÃ©sultat
    resultLine = roiID + fieldSep + sizeValueFormatted;
    
    // Ajouter les valeurs des canaux de maniÃ¨re sÃ©curisÃ©e
    if (IIbChannel > 0) {
        resultLine = resultLine + fieldSep + fmt2(value_IIb);
    }
    if (IIxChannel > 0) {
        resultLine = resultLine + fieldSep + fmt2(value_IIx);
    }
    if (IIaChannel > 0) {
        resultLine = resultLine + fieldSep + fmt2(value_IIa);
    }
    if (IChannel > 0) {
        resultLine = resultLine + fieldSep + fmt2(value_I);
    }
    if (customChannel > 0) {
        resultLine = resultLine + fieldSep + fmt2(value_custom);
    }
    
    // Ajouter la classification Ã  la fin
    resultLine = resultLine + fieldSep + classification;
    
    // Ã‰crire la ligne dans le fichier
    print(outputFile, resultLine);
}
File.close(outputFile);

	// Supprimer le fichier compilÃ© aprÃ¨s utilisation
	File.delete(dir + ImageName + "_Compiled_Results.csv");
	
	resultsFile = File.openAsString(dir + ImageName + "_Classified_Results.csv");
	lines = split(resultsFile, "\n");
	headers = split(lines[0], fieldSep);
	
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
	    headerString = "ROI" + fieldSep + "CSA";
	} else {
	    headerString = "ROI" + fieldSep + "MinFeret";
	}
	
	// Ajouter uniquement les canaux actifs (noms d'affichage personnalisés)
	if (IIbChannel > 0) {
	    headerString = headerString + fieldSep + typeName_IIb;
	}
	if (IIxChannel > 0) {
	    headerString = headerString + fieldSep + typeName_IIx;
	}
	if (IIaChannel > 0) {
	    headerString = headerString + fieldSep + typeName_IIa;
	}
	if (IChannel > 0) {
	    headerString = headerString + fieldSep + typeName_I;
	}
	if (customChannel > 0) {
	    headerString = headerString + fieldSep + customChannelName;
	}
	headerString = headerString + fieldSep + "Classification" + fieldSep + fieldSep + "Fiber type" + fieldSep + "Number" + fieldSep + "Percentage" + fieldSep + "Area mean";
	// Ligne d'indication du séparateur : Excel la consomme au double-clic et découpe
	// automatiquement les colonnes selon fieldSep (,-anglais / ;-français), quels que
	// soient les réglages régionaux. Elle n'apparaît PAS comme une ligne de données dans Excel.
	print(outputModified, "sep=" + fieldSep);
	print(outputModified, headerString);
	
	// Identifier les classifications uniques prÃ©sentes dans les donnÃ©es
	uniqueClassifications = newArray();
	for (i = 1; i < lines.length; i++) {
	    values = split(lines[i], fieldSep);
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

	// ===== RÉFÉRENCES DE COLONNES POUR LES FORMULES VIVANTES =====
	// baseColumns = ROI + taille (2). activeChannels = nb de canaux actifs (custom inclus).
	baseColumns = 2;
	activeChannels = 0;
	if (IIbChannel > 0) { activeChannels++; }
	if (IIxChannel > 0) { activeChannels++; }
	if (IIaChannel > 0) { activeChannels++; }
	if (IChannel > 0) { activeChannels++; }
	if (customChannel > 0) { activeChannels++; }
	classificationCol = getColumnLetter(baseColumns + activeChannels);   // colonne "Classification"
	numberCol = getColumnLetter(baseColumns + activeChannels + 3);       // colonne "Number" du résumé
	areaCol = "B";                                                       // la taille est toujours en colonne B

	// Ã‰crire les donnÃ©es
	for (i = 1; i < lines.length; i++) {
	    values = split(lines[i], fieldSep);
	    resultLine = values[0] + fieldSep + values[1];  // ROI et Area
	    
	    colIndex = 2; // Commencer aprÃ¨s ROI et Area
	    
    // Ajouter les valeurs des canaux dans l'ordre original
	if (IIbChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + fieldSep + values[colIndex];
	    colIndex++;}
		}
	if (IIxChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + fieldSep + values[colIndex];
	    colIndex++;}
		}
	if (IIaChannel > 0) {
	    if (colIndex < values.length) {
	        resultLine = resultLine + fieldSep + values[colIndex];
	        colIndex++;}
		}
	if (IChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + fieldSep + values[colIndex];
	    colIndex++;}
		}
	if (customChannel > 0) {
	    if (colIndex < values.length) {
	    resultLine = resultLine + fieldSep + values[colIndex];
	    colIndex++;}
		}
    // Ajouter la classification Ã  la fin
	if (colIndex < values.length) {
	    resultLine = resultLine + fieldSep + values[colIndex];
	}
    // ===== RÉSUMÉ INTERLIGNÉ AVEC FORMULES VIVANTES (placement d'origine, à droite) =====
	// Les formules se recalculent automatiquement si l'utilisateur réédite les classifications.
	// Champ formule entre guillemets pour protéger le séparateur d'arguments ; séparateur de
	// colonnes = fieldSep (; en FR, , en EN) ; séparateur d'arguments = argSep.
	if (i <= uniqueClassifications.length) {
	    currentClass = uniqueClassifications[i-1];
	    ssRow = i + 1; // ligne tableur correspondante (1 = en-tête)
	    // Colonne vide + type de fibre
	    resultLine = resultLine + fieldSep + fieldSep + "\"" + currentClass + "\"" + fieldSep;
	    // Number : comptage vivant de la classe
	    resultLine = resultLine + "\"=" + fnCountIf + "(" + classificationCol + ":" + classificationCol + argSep + "\"\"" + currentClass + "\"\")\"" + fieldSep;
	    // Percentage : arithmétique vivante (référence la case Number de la même ligne)
	    resultLine = resultLine + "\"=" + numberCol + ssRow + "/" + fnCount + "(A:A)*100\"" + fieldSep;
	    // Area mean : moyenne conditionnelle vivante
	    resultLine = resultLine + "\"=" + fnAvgIf + "(" + classificationCol + ":" + classificationCol + argSep + "\"\"" + currentClass + "\"\"" + argSep + areaCol + ":" + areaCol + ")\"" + fieldSep;
	}
	else if (i == uniqueClassifications.length + 1) { // Ligne Total
	    resultLine = resultLine + fieldSep + fieldSep + "\"Total\"" + fieldSep;
	    resultLine = resultLine + "\"=" + fnCount + "(A:A)\"" + fieldSep;                 // nombre total
	    resultLine = resultLine + "100" + fieldSep;                                       // pourcentage total
	    resultLine = resultLine + "\"=" + fnAvg + "(" + areaCol + ":" + areaCol + ")\"" + fieldSep; // moyenne générale
	}
	    print(outputModified, resultLine);
	}

File.close(outputModified);

							// ============= 5. Création des visualisations ==================
						
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

	// Ignorer l'éventuelle ligne "sep=..." écrite en tête (pour le double-clic Excel)
	headerOffset = 0;
	if (classLines.length > 0 && startsWith(classLines[0], "sep=")) {
	    headerOffset = 1;
	}

	// Trouver l'index de la colonne Classification
	classHeaders = split(classLines[headerOffset], fieldSep);
	classIndex = -1;
	for (i = 0; i < classHeaders.length; i++) {
	    if (classHeaders[i] == "Classification") {
	        classIndex = i;
	        break;
	    }
	}
	
	// Appliquer les couleurs aux ROIs
	nRois = roiManager("count");
	selectWindow("Base_Overlay");
	for (i = 0; i < nRois; i++) {
	    if (headerOffset + 1 + i >= classLines.length) continue;
	    
	    classValues = split(classLines[headerOffset + 1 + i], fieldSep);
	    if (classValues.length <= classIndex) continue;
	    classification = classValues[classIndex];
	    
	    color = getClassificationColor(classification, channelColors, selectedChannels);
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