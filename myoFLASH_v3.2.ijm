// Maxime Di Gallo & Thomas Guilbert & Raphael Braud-Mussi
// 2025/07/24
//
// myoFLASH_v3.1.ijm
//
// myoFLASH: A general muscle fibers intensity quantification macro for FiJi 
// This macro works by selecting a folder containing only .tif files with multiple channels, including one delineating the outline of the muscle fibres (laminin).
//
// The operation of this macro has been validated with version 3.1.1.2 of Cellpose. To switch to the CellposeSAM version, simply set the ‘Auto-calibrate diameter’ 
// parameter to false and set the ‘FibreDiameter’ variable to 60 by default.
//
// Keywords: muscle fibers, muscle metabolism, fiber typing, immunofluorescence, myosin, cellpose, automated analysis
//
// This macro refers to DOI article ##############
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
    Dialog.create("Muscle Fiber Analyzer");
    Dialog.addMessage("Channel Configuration", 18, "#8a7cc2");
    Dialog.addNumber("Total number of channels:", 4, 0, 2, "");
    Dialog.addNumber("Laminin channel:", 2, 0, 2, "(delineates fibers)");
	Dialog.addCheckbox("Auto-calibrate diameter", true);
	Dialog.addNumber("Manual fiber diameter:", 60, 0, 3, "pixels (ignored if auto-calibrate is checked)");
    Dialog.addMessage("Fiber size measurement", 14, "#8a7cc2");
	Dialog.addChoice("Size measurement method:", newArray("Cross Sectional Area (CSA)", "Minimum Feret Diameter"), "Cross Sectional Area (CSA)");
    
    Dialog.addMessage("Fiber types to analyze", 18, "#8a7cc2");
    Dialog.addNumber("Type IIb channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addNumber("Type IIx channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addNumber("Type IIa channel:", 0, 0, 2, "(0 = Off)");
    Dialog.addNumber("Type I channel:", 0, 0, 2, "(0 = Off)");
    
    Dialog.addMessage("Custom channel (optional)", 14, "#c1666b");
    Dialog.addNumber("Channel number:", 0, 0, 2, "(0 = Off)");
    Dialog.addString("Channel name:", "", 10);
    
    // Advanced options in a collapsible panel
    Dialog.addCheckbox("Show advanced options", false);

    Dialog.show();
    
    // Récupérer les valeurs de base
    totalChannels = Dialog.getNumber();
    LaminineCannal = Dialog.getNumber();
    autoCalibrate = Dialog.getCheckbox();
	manualDiameter = Dialog.getNumber();
	// Déterminer le diamètre final
	if (autoCalibrate) {
	    FibreDiameter = 0;  // Active la calibration automatique
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
    
    // Afficher les options avancées si demandé
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
        
        // Récupérer les paramètres avancés
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
        // Valeurs par défaut
        cellposeSensitivity = 1.0;
        exclusionThreshold = 200;
        adaptiveThresholdFactor = 0.3;
        filterNonHomogeneous = true;
        useGPU = isWindowsOrLinux;
        useChannelColors = true;
        overlayOpacity = 30;
    }
    
    // Retourner tous les paramètres dans un tableau
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
    
    // Create or update the progress display - make it significantly larger
    if (!isOpen("Progress")) {
        newImage("Progress", "RGB", 450, 120, 1);
        setLocation(screenWidth-470, 10);  // Position in upper right
    }
    
    // Select progress image and update
    selectWindow("Progress");
    
    // Clear the image with a light gray background
    run("Select All");
    setBackgroundColor(240, 240, 240);
    run("Clear", "slice");
    
    // Draw decorative top bar with steel blue color
    setColor(70, 130, 180);
    fillRect(0, 0, 450, 20);
    
    // Draw title in top bar
    setColor(255, 255, 255);  // White text
    setFont("SansSerif", 18, "bold");
    drawString("MUSCLE FIBER ANALYZER", 150, 15);
    
    // Set color for main text
    setColor(0, 0, 0);  // Black
    setFont("SansSerif", 16, "bold");
    
    // Get timestamp
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    hourStr = "" + hour; if (hour < 10) hourStr = "0" + hour;
    minuteStr = "" + minute; if (minute < 10) minuteStr = "0" + minute;
    secondStr = "" + second; if (second < 10) secondStr = "0" + second;
    timestamp = hourStr + ":" + minuteStr + ":" + secondStr;
    
    // Draw text info
    drawString("File: " + (currentFile+1) + "/" + totalFiles, 20, 45);
    drawString("Step: " + getTaskName(step), 20, 70);
    drawString(timestamp + " - " + Math.round(progress) + "%", 20, 95);
    
    // Draw progress bar background
    setColor(220, 220, 220);
    fillRect(20, 100, 410, 15);
    
    // Color varies with progress - using more prominent blues
    if (progress < 33) {
        setColor(100, 150, 255);  // Light blue
    } else if (progress < 66) {
        setColor(70, 130, 180);   // Steel blue
    } else {
        setColor(0, 120, 215);    // Windows blue
    }
    
    // Fill progress bar - only the completed portion
    fillRect(20, 100, Math.round(410 * progress/100), 15);
    
    // Add border to progress bar
    setColor(100, 100, 100);
    drawRect(20, 100, 410, 15);
    
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
    // Definir les chemins potentiels pour différents systèmes d'exploitation
    function getPotentialCellposePaths() {
    os = getInfo("os.name");
    osLower = toLowerCase(os);
    homeDir = getDirectory("home");
    
    potentialPaths = newArray();
    
    // Chemins génériques Windows
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
        
        // Remplacer %USERPROFILE% de manière sécurisée
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
        
        // Vérifier l'existence du chemin
        if (File.exists(expandedPath)) {
            return expandedPath;
        }
    }
    return "";
}
    
    // Récupérer les chemins potentiels
    potentialPaths = getPotentialCellposePaths();
    
    // Trouver l'environnement Cellpose
    condaPath = findCellposeEnvironment(potentialPaths);
    
    // Vérifier si un environnement a été trouvé
    if (condaPath == "") {
        exit("Unable to find Cellpose environment. Please check your installation.");
    }
    
    // Préparer les paramètres de base Cellpose
    cellposeParams = "model=cyto2 diameter=" + FibreDiameter + " ch1=" + LaminineCannal + " ch2=0";
    cellposeParams = "env_path=" + condaPath + " env_type=conda " + cellposeParams;
    
    cellposeParams = cellposeParams + " additional_flags=--verbose";
    cellposeParams = cellposeParams + " no_dialog=true";
    cellposeParams = cellposeParams + " batch_mode=true";
    
    // Configuration GPU
    os = getInfo("os.name");
    osLower = toLowerCase(os);
    gpuAvailable = false;
    
    // Tester la disponibilité du GPU selon le système d'exploitation
    if (indexOf(osLower, "windows") >= 0 || indexOf(osLower, "linux") >= 0) {
    // Essayer de vérifier la présence de CUDA/GPU
    cudaPath = "C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA";
    gpuAvailable = File.exists(cudaPath);
}
    
    // Activer le GPU si disponible et demandé
    if (useGPU && gpuAvailable) {
        cellposeParams += " additional_flags=--use_gpu";
    } else if (useGPU && !gpuAvailable) {
        print("GPU not available. Using CPU.");
    }
    
    return cellposeParams;
}

function testGPUAvailability() {
    // Récupérer le nom du système d'exploitation
    os = getInfo("os.name");
    osLower = toLowerCase(os);
    
    // Vérification spécifique pour Windows et Linux
    if (indexOf(osLower, "windows") >= 0 || indexOf(osLower, "linux") >= 0) {
        // Chemins potentiels pour l'installation CUDA
        cudaPaths = newArray(
            "C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA",
            "C:\\Program Files\\NVIDIA Corporation\\CUDA",
            "/usr/local/cuda"
        );
        
        // Vérifier l'existence des chemins CUDA
        gpuFound = false;
        for (i = 0; i < cudaPaths.length; i++) {
            if (File.exists(cudaPaths[i])) {
                gpuFound = true;
                break;
            }
        }
        
        // Si CUDA est trouvé, supposer que le GPU est disponible sans exécuter nvidia-smi
        if (gpuFound) {
            return true;
        }
    }
    
    // Par défaut, retourner false
    return false;
}

function getPlatformSafePath(path) {
    // Standardiser la gestion des séparateurs de chemin
    os = getInfo("os.name");
    if (indexOf(toLowerCase(os), "windows") >= 0) {
        // Windows - s'assurer que les chemins utilisent backslash
        path = replace(path, "/", "\\");
        // S'assurer qu'il y a un backslash à la fin si nécessaire
        if (!endsWith(path, "\\")) {
            path = path + "\\";
        }
    } else {
        // Mac/Linux - s'assurer que les chemins utilisent slash
        path = replace(path, "\\", "/");
        // S'assurer qu'il y a un slash à la fin si nécessaire
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
	
// Fonction pour calculer l'écart-type
function calculateStd(values, mean) {
	    sumSquares = 0;
	    n = values.length;
	    for (i = 0; i < n; i++) {
	        diff = values[i] - mean;
	        sumSquares += diff * diff;
	    }
	    return sqrt(sumSquares / (n - 1));
}

// Fonction pour calculer la médiane
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

// Fonction pour calculer les artios inter-canaux
function calculateRatios(intensityValues, selectedChannels) {
    // Initialiser les ratios
    ratio_1_3 = 0; ratio_1_4 = 0; ratio_3_4 = 0;
    
    // Trouver les indices correspondant aux canaux
    ch1_idx = -1; ch3_idx = -1; ch4_idx = -1;
    for (c = 0; c < selectedChannels.length; c++) {
        if (selectedChannels[c] == 1) ch1_idx = c;
        if (selectedChannels[c] == 3) ch3_idx = c;
        if (selectedChannels[c] == 4) ch4_idx = c;
    }
    
    // Calculer les ratios uniquement si les indices sont valides
    epsilon = 1e-10; // Petit nombre pour éviter division par 0
    
    if (ch1_idx >= 0 && ch3_idx >= 0) {
        ratio_1_3 = intensityValues[ch1_idx] / (intensityValues[ch3_idx] + epsilon);
    }
    
    if (ch1_idx >= 0 && ch4_idx >= 0) {
        ratio_1_4 = intensityValues[ch1_idx] / (intensityValues[ch4_idx] + epsilon);
    }
    
    if (ch3_idx >= 0 && ch4_idx >= 0) {
        ratio_3_4 = intensityValues[ch3_idx] / (intensityValues[ch4_idx] + epsilon);
    }
    
	return newArray(ratio_1_3, ratio_1_4, ratio_3_4);
}

// Fonction pour calculer la moyenne mobile
function calculateRollingMean(values, window) {
	    means = newArray(values.length);
	    for (i = 0; i < values.length; i++) {
	        start = maxOf(0, i - floor(window/2));
	        end = minOf(values.length, i + floor(window/2) + 1);
	        sum = 0;
	        count = 0;
	        for (j = start; j < end; j++) {
	            sum += values[j];
	            count++;
	        }
	        means[i] = sum / count;
	    }
	    return means;
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
    // Utilise la méthode d'Ashman D (plus robuste que la simple détection de pic)
    ashmanD = 0;
    if (values.length >= 20) {
        // Tentative de détection de deux populations
        bimodalParams = detectBimodalDistribution(values);
        isBimodal = bimodalParams[0];
        
        if (isBimodal) {
            mu1 = bimodalParams[1];
            sigma1 = bimodalParams[2];
            mu2 = bimodalParams[3];
            sigma2 = bimodalParams[4];
            
            // Coefficient D d'Ashman: |µ1-µ2|/√(σ1²+σ2²)
            ashmanD = abs(mu1 - mu2) / sqrt(sigma1*sigma1 + sigma2*sigma2);
        }
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
        // Distribution clairement bimodale - utiliser la méthode des deux gaussiennes
        // Retourne la vallée entre les deux pics
        threshold = (mu1 + mu2) / 2;
        // Ajustement en fonction de la texture
        threshold = adjustThresholdByTexture(threshold, textureScores);
        return threshold;
    } 
    else {
        // Distribution unimodale
	    // Facteur de base
	    baseFactor = 0.18; 
	    
	    // Calcul de proportion pour calibration
	    initialThreshold = median + (baseFactor * std);
	    positiveCount = 0;
	    for (i = 0; i < values.length; i++) {
	        if (values[i] > initialThreshold) positiveCount++;
	    }
	    proportion = positiveCount / values.length;
	    
	    // Ajustement du facteur selon la proportion - moins agressif
	    if (proportion < 0.25) { // Augmenté pour être plus tolérant
	    // Faible proportion - être encore plus sensible
	    if (proportion < 0.05) { // Seuil plus élevé
	        baseFactor = 0.06; // Encore plus réduit
	    } else if (proportion < 0.10) { // Seuil plus élevé
	        baseFactor = 0.10; // Encore plus réduit
	    } else {
	        baseFactor = 0.15; // Encore plus réduit
	    }
	} else if (proportion > 0.45) { // Seuil plus élevé pour être plus tolérant
	        // Forte proportion - être moins strict
	        if (proportion > 0.65) { // Réduit de 0.7 à 0.65
	            baseFactor = 0.5; // Réduit de 0.6 à 0.5
	        } else if (proportion > 0.5) { // Réduit de 0.55 à 0.5
	            baseFactor = 0.4; // Réduit de 0.5 à 0.4
	        } else {
	            baseFactor = 0.35; // Réduit de 0.4 à 0.35
	        }
	    }
    }
	    
	    // Calculer le seuil final
	    threshold = median + (baseFactor * std);
	    
	    // Ajustement en fonction de la texture
	    threshold = adjustThresholdByTexture(threshold, textureScores);
	    
	    // Limites de sécurité moins strictes
	    minThreshold = q1 * 0.8;  // 20% en dessous de Q1 (plus permissif)
		maxThreshold = q3 + (1.5 * iqr);  // Encore plus élevé pour accepter plus de valeurs
	    
	    // Garantir que le seuil reste dans des limites raisonnables
	    threshold = maxOf(threshold, minThreshold);
	    threshold = minOf(threshold, maxThreshold);
	    
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
    if (cv > 0.25) {
        // Pénalité graduelle commençant à CV 0.25 au lieu de 0.3
        homogeneityScore *= (1.0 / (1.0 + 0.75 * (cv - 0.25)));
    }
    
    // Pénaliser forte asymétrie
    if (abs(skewness) > 0.9) { // Seuil réduit de 1.0 à 0.9
        homogeneityScore *= (1.0 / (1.0 + 0.14 * (abs(skewness) - 0.9))); // Facteur légèrement ajusté
    }
    
    // Pénaliser une distribution non normale (pics ou queues lourdes)
    kurtosisNormal = 3.0; // Valeur pour distribution normale
    if (abs(kurtosis - kurtosisNormal) > 1.4) { // Seuil réduit de 1.5 à 1.4
        homogeneityScore *= (1.0 / (1.0 + 0.11 * (abs(kurtosis - kurtosisNormal) - 1.4)));
    }
    
    // Pénaliser un fort écart entre moyenne et médiane (indicateur d'asymétrie)
    if (mean > 0 && abs(mean - median) / mean > 0.18) { // Seuil réduit de 0.2 à 0.18
        homogeneityScore *= (1.0 / (1.0 + 0.48 * (abs(mean - median) / mean - 0.18)));
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
    
    // Ajuster le seuil en fonction de l'homogénéité moyenne
    // Si texture très hétérogène (score bas), on augmente le seuil pour être plus strict
    // Si texture très homogène (score élevé), on peut baisser légèrement le seuil
    
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

// Ajustement du facteur en fonction de la densité d'histogramme
function adjustFactorByHistogramDensity(values, median, std, baseFactor) {
    // Estimer la densité de l'histogramme autour du seuil potentiel
    potentialThreshold = median + (baseFactor * std);
    thresholdRange = std * 0.2; // Plage autour du seuil pour évaluer la densité
    
    countInRange = 0;
    for (i = 0; i < values.length; i++) {
        if (abs(values[i] - potentialThreshold) <= thresholdRange) {
            countInRange++;
        }
    }
    
    // Calculer la densité normalisée
    normDensity = countInRange / (values.length * 2 * thresholdRange);
    
    // Ajuster le facteur en fonction de la densité
    // Haute densité = incertitude élevée, on augmente le facteur pour être plus strict
    if (normDensity > 0.1) {
        // Densité élevée autour du seuil - augmenter le facteur (jusqu'à +25%)
        adjustment = 1.0 + (normDensity - 0.1) * 2.5; // max +25% quand densité = 0.2
        return baseFactor * minOf(1.25, adjustment);
    } else {
        // Faible densité - pas d'ajustement
        return baseFactor;
    }
}

// Fonction pour trouver la vallée entre deux pics (pour distributions bimodales)
function findValleyBetweenPeaks(sortedValues, histArray, minVal, binSize) {
    // Trouver les deux pics principaux
    peak1 = 0; peak1Value = 0;
    peak2 = 0; peak2Value = 0;
    
    for (i = 1; i < histArray.length-1; i++) {
        if (histArray[i] > histArray[i-1] && histArray[i] > histArray[i+1]) {
            if (histArray[i] > peak1Value) {
                peak2 = peak1;
                peak2Value = peak1Value;
                peak1 = i;
                peak1Value = histArray[i];
            } else if (histArray[i] > peak2Value) {
                peak2 = i;
                peak2Value = histArray[i];
            }
        }
    }
    
    // Assurer que peak1 < peak2
    if (peak1 > peak2 && peak2 != 0) {
        temp = peak1; peak1 = peak2; peak2 = temp;
    }
    
    // Si deux pics sont identifiés, chercher la vallée entre eux
    if (peak1 != 0 && peak2 != 0 && peak1 != peak2) {
        valley = peak1;
        valleyValue = histArray[peak1];
        
        for (i = peak1+1; i < peak2; i++) {
            if (histArray[i] < valleyValue) {
                valley = i;
                valleyValue = histArray[i];
            }
        }
        
        // Convertir l'index de bin en valeur réelle
        return minVal + (valley * binSize) + (binSize/2);
    }
    
    return -1; // Pas de vallée trouvée
}

function detectPeripheralStaining(roiIndex) {
    // Sélectionner la ROI
    roiManager("select", roiIndex);
    
    // Obtenir les dimensions de la ROI
    Roi.getBounds(x, y, width, height);
    
    // Créer une ROI intérieure (réduite de 25%)
    innerWidth = width * 0.75;
    innerHeight = height * 0.75;
    innerX = x + (width - innerWidth) / 2;
    innerY = y + (height - innerHeight) / 2;
    
    // Mesurer l'intensité sur toute la ROI
    run("Measure");
    fullMean = getResult("Mean", nResults-1);
    fullStd = getResult("StdDev", nResults-1);
    run("Clear Results");
    
    // Créer une sélection pour la zone intérieure
    makeRectangle(innerX, innerY, innerWidth, innerHeight);
    
    // Mesurer l'intensité dans la zone intérieure
    run("Measure");
    innerMean = getResult("Mean", nResults-1);
    innerStd = getResult("StdDev", nResults-1);
    run("Clear Results");
    
    // Revenir à la ROI originale
    roiManager("select", roiIndex);
    
    // Calculer le ratio périphérie/intérieur avec nouveau critère
    peripheralRatio = 0;
    if (innerMean > 0) {
        peripheralRatio = fullMean / innerMean;
        
        // Ajouter analyse du coefficient de variation
        cv_inner = innerStd / innerMean;
        cv_full = fullStd / fullMean;
        
        // Si le coefficient de variation de la ROI complète est beaucoup plus grand
        // que celui de la zone intérieure, c'est un indice supplémentaire de marquage périphérique
        if (cv_full > cv_inner * 1.5) {
            peripheralRatio *= 1.2; // Augmenter le ratio si fort contraste entre bord et centre
        }
    }
    
    // Retourner true si le marquage est principalement périphérique (utiliser une comparaison explicite)
    return peripheralRatio > 1.3; // Seuil plus sensible
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
    
    // Obtenir les propriétés de la ROI
    Roi.getBounds(x, y, width, height);
    
    // Mesurer l'aire et l'intensité de la ROI entière
    run("Set Measurements...", "area mean standard integrated redirect=None decimal=3");
    run("Measure");
    area = getResult("Area", nResults-1);
    fullRoiMean = getResult("Mean", nResults-1);
    fullRoiStd = getResult("StdDev", nResults-1);
    run("Clear Results");
    
    // 1. Pénaliser les très petites ROI (probablement du bruit)
    if (area < 200) {
        penaltyFactors *= (1 + (1 - area/200) * 0.8);
    }
    
    // 2. Pénaliser les ROI très hétérogènes
    if (cv > 0.25) {  // Seuil réduit de 0.3 à 0.25
        penaltyFactors *= (1 + (cv - 0.25) * 1.0);  // Pénalité augmentée de 0.8 à 1.0
    }
    
    // 3. Analyse centre-périphérie simplifiée
    if (fullRoiStd/fullRoiMean > 0.45) {  // Seuil réduit de 0.5 à 0.45
        penaltyFactors *= (1 + 0.3 * (fullRoiStd/fullRoiMean - 0.45));  // Pénalité augmentée
    }
    
    // 4. Détecter spécifiquement les marquages périphériques
    isPeripheral = detectPeripheralStaining(roiIndex);
    if (isPeripheral == true) {  // Ajout d'une comparaison explicite avec true pour éviter l'erreur
        penaltyFactors *= 1.4;  // Forte pénalité pour les marquages périphériques
    }
    
    // 5. Ajustement en fonction de la valeur moyenne relative
    allValues = Array.copy(values);
    Array.sort(allValues);
    globalMedian = calculateMedian(allValues);
    
    if (valueMean < 0.3 * globalMedian) {
        penaltyFactors *= (1 + 0.3 * (1 - (valueMean/(0.3*globalMedian))));  // Augmenté de 0.25 à 0.3
    }
    
    // Limiter le facteur de pénalité maximum
    penaltyFactors = minOf(3.0, penaltyFactors);  // Augmenté de 2.5 à 3.0
    
    // S'assurer que la ROI originale est toujours sélectionnée à la fin
    roiManager("select", roiIndex);
    
    return penaltyFactors;
}


// ============================================ CLASSIFICATION DES FIBRES ====================================================


function classifyHybridFiber(intensities, thresholds, typeNames, sizeValue, perimeter, eccentricity, solidity, ratios) {
    // Normaliser les intensités par rapport à leurs seuils
    normalizedIntensities = newArray(intensities.length);
    for (i = 0; i < intensities.length; i++) {
        normalizedIntensities[i] = intensities[i] / thresholds[i];
    }
    
    // Caractéristiques morphologiques normalisées
	if (useCSA) {
	    normalizedSize = sizeValue / 1000;
	} else {
	    normalizedSize = sizeValue / 50; // Ajustement pour MinFeret (valeurs plus petites)
	}
    normalizedPerimeter = perimeter / 100;
    
    // Scores de base pour chaque type
    scores = newArray(typeNames.length);
    minPositiveScore = 0.2;
    
    // Vérifier si un canal custom est présent
	hasCustom = false;
	customIndex = -1;
	for (i = 0; i < typeNames.length; i++) {
	    if (typeNames[i] == customChannelName && customChannelName != "") {
	        hasCustom = true;
	        customIndex = i;
	        break;
	    }
	}
	
	// Si custom est présent, modifier la logique de dominance
	if (hasCustom) {
	    // Pour les customs, pas de dominance - directement hybride si plusieurs types
	    if (typeNames.length >= 2) {
	        // Trier les types pour un ordre cohérent
	        sortedTypes = newArray();
	        
	        // Ordre de priorité : IIb > IIx > IIa > I > custom
	        typeOrder = newArray("IIb", "IIx", "IIa", "I", customChannelName);
	        
	        for (j = 0; j < typeOrder.length; j++) {
	            for (i = 0; i < typeNames.length; i++) {
	                if (typeNames[i] == typeOrder[j] && scores[i] > 0) {
	                    sortedTypes = Array.concat(sortedTypes, typeNames[i]);
	                }
	            }
	        }
	        
	        // Retourner le premier type + custom (ou custom + premier type selon l'ordre)
	        if (sortedTypes.length >= 2) {
	            if (sortedTypes[0] == customChannelName) {
	                return sortedTypes[1] + "-" + customChannelName;
	            } else {
	                return sortedTypes[0] + "-" + customChannelName;
	            }
	        }
	    }
	}
    
    for (i = 0; i < typeNames.length; i++) {
        // Score initial basé sur l'intensité - plus permissif
        if (normalizedIntensities[i] > 1.0) {
            scores[i] = pow(maxOf(0, normalizedIntensities[i] - 1.0), 1.1); // Exposant réduit pour plus de sensibilité
        } else {
            scores[i] = 0;
        }
        
        // Règles spécifiques par type de fibre 
        if (typeNames[i] == "I") {
            // Type I - généralement plus petit, ratio_3_4 élevé
            if (normalizedSize < 1.0) scores[i] *= 1.35; // Augmenté
            if (ratios[2] > 1.2) scores[i] *= 1.45; // Augmenté et seuil réduit
            // Bonus supplémentaire pour la forte homogénéité
            if (solidity > 0.75) scores[i] *= 1.25;
            
            // Pénalité pour hétérogénéité périphérique
            if (eccentricity > 0.5 && solidity < 0.8) {
                scores[i] *= 0.65; // Pénalité pour les signaux périphériques
            }
        }
        else if (typeNames[i] == "IIa") {
            // Type IIa - taille moyenne, ratio_1_3 moyen
            if (normalizedSize > 0.35 && normalizedSize < 2.8) scores[i] *= 1.35; // Plage élargie
            if (ratios[0] > 0.65 && ratios[0] < 2.4) scores[i] *= 1.35; // Plage élargie
            if (solidity > 0.75) scores[i] *= 1.25; 
            
            // Pénalité pour hétérogénéité périphérique
            if (eccentricity > 0.5 && solidity < 0.8) {
                scores[i] *= 0.65; // Pénalité pour les signaux périphériques
            }
        }
        
        else if (typeNames[i] == "IIb") {
            // Type IIb - généralement plus grand, ratio_1_4 élevé
            if (normalizedSize > 0.6) scores[i] *= 1.45; // Augmenté et seuil réduit
            if (eccentricity < 0.75) scores[i] *= 1.25; // Plage élargie
            if (ratios[1] > 0.8) scores[i] *= 1.35; // Seuil réduit
            
            // Pénalité pour hétérogénéité périphérique
            if (eccentricity > 0.5 && solidity < 0.8) {
                scores[i] *= 0.65; // Pénalité pour les signaux périphériques
            }
        }
        else if (typeNames[i] == "IIx") {
            // Règles spécifiques aux fibres IIx
            if (normalizedSize > 0.5 && normalizedSize < 2.0) scores[i] *= 1.3;
            if (ratios[0] > 0.8 && ratios[0] < 1.8) scores[i] *= 1.3;
            if (solidity > 0.78) scores[i] *= 1.22;
            
            // Pénalité pour hétérogénéité périphérique
            if (eccentricity > 0.5 && solidity < 0.8) {
                scores[i] *= 0.65; // Pénalité pour les signaux périphériques
            }
        }
     	 
        // Ajustement morphologique général
        if (solidity > 0.85) scores[i] *= 1.5;
    }
    
    // Vérifier d'abord la présence de custom
	hasCustom = false;
	customIndex = -1;
	for (i = 0; i < typeNames.length; i++) {
	    if (typeNames[i] == customChannelName && customChannelName != "") {
	        hasCustom = true;
	        customIndex = i;
	        break;
	    }
	}
	
	// Identifier les deux types avec les scores les plus élevés
	maxScore = -1;
	dominantTypeIndex = -1;
	secondScore = -1;
	secondTypeIndex = -1;
	
	for (i = 0; i < scores.length; i++) {
	    if (scores[i] > maxScore) {
	        secondScore = maxScore;
	        secondTypeIndex = dominantTypeIndex;
	        maxScore = scores[i];
	        dominantTypeIndex = i;
	    } else if (scores[i] > secondScore) {
	        secondScore = scores[i];
	        secondTypeIndex = i;
	    }
	}
	
	// Si aucun signal positif significatif, retourner "O"
	if (maxScore <= minPositiveScore) {
	    return "O";
	}
	
	// LOGIQUE SPÉCIALE POUR CUSTOM : Pas de dominance si custom est présent
	if (hasCustom && typeNames.length >= 2) {
	    // Si custom est présent avec d'autres types, forcer hybride
	    positiveTypes = newArray();
	    
	    // Collecter tous les types avec scores > minPositiveScore
	    for (i = 0; i < typeNames.length; i++) {
	        if (scores[i] > minPositiveScore) {
	            positiveTypes = Array.concat(positiveTypes, typeNames[i]);
	        }
	    }
	    
	    // Si custom + au moins un autre type, créer hybride
	    if (positiveTypes.length >= 2) {
	        // Trier selon l'ordre naturel : IIb > IIx > IIa > I > custom
	        sortedTypes = newArray();
	        typeOrder = newArray("IIb", "IIx", "IIa", "I", customChannelName);
	        
	        for (j = 0; j < typeOrder.length; j++) {
	            for (i = 0; i < positiveTypes.length; i++) {
	                if (positiveTypes[i] == typeOrder[j]) {
	                    sortedTypes = Array.concat(sortedTypes, positiveTypes[i]);
	                }
	            }
	        }
	        
	        // Retourner hybride custom
	        if (sortedTypes.length >= 2) {
	            if (sortedTypes[0] == customChannelName) {
	                return sortedTypes[1] + "-" + customChannelName;
	            } else {
	                return sortedTypes[0] + "-" + customChannelName;
	            }
	        }
	    }
	}
	
	// LOGIQUE NORMALE (sans custom) : Test de dominance
	if (secondScore <= 0 || maxScore > 3 * secondScore) {
	    return typeNames[dominantTypeIndex];
	}
	
	// Seuil hybride augmenté pour détecter plus de fibres hybrides (plus permissif)
	if (!hasCustom && maxScore < 4 * secondScore) { // Augmenté de 2.2 à 2.5
	
	// Par des valeurs encore plus permissives :
	if (secondScore <= 0 || maxScore > 3.5 * secondScore) {  // Encore plus réduit
	    return typeNames[dominantTypeIndex];
	}
	
        // Vérification spéciale pour IIa-I
        if ((typeNames[dominantTypeIndex] == "IIa" && typeNames[secondTypeIndex] == "I") ||
            (typeNames[dominantTypeIndex] == "I" && typeNames[secondTypeIndex] == "IIa")) {
            // Être plus permissif pour la combinaison IIa-I
            return "IIa-I";  // Toujours retourner dans l'ordre correct
        }
        
        // Vérifier la compatibilité biologique pour les autres combinaisons
        hybridClassification = typeNames[dominantTypeIndex] + "-" + typeNames[secondTypeIndex];
        reversedHybrid = typeNames[secondTypeIndex] + "-" + typeNames[dominantTypeIndex];
        
        // Vérifier les combinaisons biologiquement plausibles
        validHybrids = newArray("IIb-IIx", "IIx-IIa", "IIa-I", "IIb-IIa", "IIx-I");
        isValid = false;
        
        for (i = 0; i < validHybrids.length; i++) {
            if (hybridClassification == validHybrids[i] || reversedHybrid == validHybrids[i]) {
                isValid = true;
                break;
            }
        }
        
        if (isValid) {
            // Vérifier l'ordre naturel (IIb > IIx > IIa > I)
            if ((typeNames[dominantTypeIndex] == "IIx" && typeNames[secondTypeIndex] == "IIb") ||
                (typeNames[dominantTypeIndex] == "IIa" && typeNames[secondTypeIndex] == "IIx") ||
                (typeNames[dominantTypeIndex] == "I" && typeNames[secondTypeIndex] == "IIa")) {
                // Inverser l'ordre si nécessaire
                return typeNames[secondTypeIndex] + "-" + typeNames[dominantTypeIndex];
            }
            return hybridClassification;
        }
    }
    
    if (hasCustom && maxScore < 4 * secondScore) { // Plus permissif pour custom
	    // Si custom est l'un des deux types principaux, forcer hybride
	    if (typeNames[dominantTypeIndex] == customChannelName || typeNames[secondTypeIndex] == customChannelName) {
	        if (typeNames[dominantTypeIndex] == customChannelName) {
	            return typeNames[secondTypeIndex] + "-" + customChannelName;
	        } else {
	            return typeNames[dominantTypeIndex] + "-" + customChannelName;
	        }
	    }
	}
	    
    // Cas par défaut - retourner le type dominant
    return typeNames[dominantTypeIndex];
}

// Fonction pour appliquer des règles spéciales aux classifications hybrides
function applyHybridRules(intensities, thresholds, typeNames, sizeValue, perimeter, eccentricity, solidity, ratios) {
    // Version originale de la fonction classifyHybridFiber
    classificationResult = classifyHybridFiber(intensities, thresholds, typeNames, sizeValue, perimeter, eccentricity, solidity, ratios);
    return classificationResult;
}

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
    r = 128; g = 128; b = 128; // Couleur grise par défaut
    
    // Si c'est une classification simple "O"
    if (classification == "O") {
        return newArray(128, 128, 128); // Gris pour négatif
    }
    
    // Vérifier si c'est une fibre hybride (contient un tiret)
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
                    typeChannel = fiberTypeChannels[i] - 1; // -1 car les indices commencent à 0
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
        
        // Calculer la moyenne si des types valides ont été trouvés
        if (validTypeCount > 0) {
            // Mélange logarithmique pour accentuer les couleurs combinées
            r = pow(rTotal/validTypeCount, 0.8);
            g = pow(gTotal/validTypeCount, 0.8);
            b = pow(bTotal/validTypeCount, 0.8);
            
            // Normalisation pour accentuer la visibilité
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
                typeChannel = selectedChannels[i] - 1; // -1 car les indices commencent à 0
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
    
    // Créer un tableau pour stocker les couleurs extraites
    channelColors = newArray(channels * 3); // R,G,B pour chaque canal
    
    // Pour chaque canal, extraire la couleur dominante
    for (c = 1; c <= channels; c++) {
        // Créer une copie temporaire du canal
        selectImage(origID);
        Stack.setChannel(c);
        run("Duplicate...", "title=temp_channel");
        tempID = getImageID();
        
        // Définir un seuil pour extraire les pixels les plus brillants (signal)
        setAutoThreshold("Default dark");
        getThreshold(lower, upper);
        
        // Définir un seuil élevé pour ne garder que le signal fort
        setThreshold(maxOf(lower, (lower+upper)*0.6), upper);
        run("Create Selection");
        
        // Si la sélection est vide (pas de pixels au-dessus du seuil), utiliser toute l'image
        if (selectionType() == -1) {
            run("Select All");
        }
        
        // Mesurer la couleur moyenne dans la sélection
        run("Measure");
        meanIntensity = getResult("Mean", nResults-1);
        
        // Normaliser la couleur pour qu'elle soit vive mais pas trop saturée
        normalizationFactor = 230 / maxOf(1, meanIntensity);
        
        // Déterminer la couleur en fonction du canal
        if (c == 1) { // Premier canal souvent en rouge
            channelColors[(c-1)*3] = minOf(255, meanIntensity * normalizationFactor);
            channelColors[(c-1)*3+1] = 0;
            channelColors[(c-1)*3+2] = 0;
        } 
        else if (c == 2) { // Deuxième canal souvent en vert
            channelColors[(c-1)*3] = 0;
            channelColors[(c-1)*3+1] = minOf(255, meanIntensity * normalizationFactor);
            channelColors[(c-1)*3+2] = 0;
        }
        else if (c == 3) { // Troisième canal souvent en bleu
            channelColors[(c-1)*3] = 0;
            channelColors[(c-1)*3+1] = 0;
            channelColors[(c-1)*3+2] = minOf(255, meanIntensity * normalizationFactor);
        }
        else if (c == 4) { // Quatrième canal souvent en magenta
            channelColors[(c-1)*3] = minOf(255, meanIntensity * normalizationFactor);
            channelColors[(c-1)*3+1] = 0;
            channelColors[(c-1)*3+2] = minOf(255, meanIntensity * normalizationFactor);
        }
        else { // Canaux supplémentaires
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
    
    // Revenir à l'image originale
    selectImage(origID);
    
    return channelColors;
}


// Fonction pour obtenir la lettre de colonne à partir d'un index (0-based)
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
    // Convertir une chaîne de numéros de ROI en tableau d'indices
    // Format supporté: "1,3,5-10,15"
    
    if (roiString == "") return newArray(0);
    
    // Traiter les éléments séparés par des virgules
    elements = split(roiString, ",");
    roiIndices = newArray(0);
    
    for (i = 0; i < elements.length; i++) {
        element = elements[i];
        element = replace(element, " ", ""); // Supprimer les espaces
        
        // Vérifier si c'est une plage (ex: "5-10")
        if (indexOf(element, "-") > 0) {
            rangeParts = split(element, "-");
            if (rangeParts.length == 2) {
                start = parseInt(rangeParts[0]);
                end = parseInt(rangeParts[1]);
                
                // Validation des nombres
                if (!isNaN(start) && !isNaN(end)) {
                    // Convertir de numéros de ROI (1-based) à indices (0-based)
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
                // Convertir de numéro de ROI (1-based) à indice (0-based)
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


// 5. Ajout d'une fonction de debug pour vérifier les chemins et les fichiers
function debugCheckPaths() {
    print("=== DEBUG INFO ===");
    print("Current directory: " + dir);
    print("Current image: " + ImageName);
    print("GLOBAL_LAST_DIR: " + GLOBAL_LAST_DIR);
    print("GLOBAL_LAST_IMAGE: " + GLOBAL_LAST_IMAGE);
    print("Path exists? " + File.exists(dir + ImageName));
    print("Normalized path exists? " + File.exists(dir + normalizeFileName(ImageName)));
    print("==================");
}



// ===================================================================================================================
// ================================================== WORKFLOW =======================================================
// ===================================================================================================================



// =============================================== INITIALISATION ====================================================


// Déterminer l'os
os = getInfo("os.name");
isWindowsOrLinux = indexOf(toLowerCase(os), "windows") >= 0 || indexOf(toLowerCase(os), "linux") >= 0;

// Initialiser useGPU par défaut
useGPU = isWindowsOrLinux;

// Obtenir tous les paramètres depuis la boîte de dialogue améliorée
params = showEnhancedDialog();

// Extraire les paramètres
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

// Vérification que les canaux sélectionnés ne dépassent pas le nombre total de canaux
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

// Mise à jour des variables globales
var GLOBAL_LAST_DIR = "";
var GLOBAL_LAST_IMAGE = "";

// =============================================== PREPARATION =================================================


// Créer un tableau des canaux à mesurer
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

// Choix du dossier des images à analyser
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

	// Appel à Cellpose
	fijiPath = getDirectory("imagej");
	userHome = getDirectory("home");
	cellposeCommand = configureCellpose();
	condaPath = substring(cellposeCommand, indexOf(cellposeCommand, "env_path=") + 9, indexOf(cellposeCommand, " ", indexOf(cellposeCommand, "env_path=")));

smallImageProgress(k, nbFichiers, 2, 10, "Configuring Cellpose");
	
	
cellposeCommand = "env_path="+condaPath+" env_type=conda model=cyto3 model_path="+fijiPath+" diameter="+FibreDiameter+" ch1="+LaminineCannal+" ch2=0";

	// Ajout de l'option GPU si sélectionnée et disponible
	if (isWindowsOrLinux && useGPU) {
	    cellposeCommand = cellposeCommand + " additional_flags=--use_gpu";
	}
	
							// ========== 2. Segmentation avec Cellpose ==========
							
smallImageProgress(k, nbFichiers, 3, 10, "Running Cellpose");

	cellposeCommand = cellposeCommand + " additional_flags=--verbose";
    cellposeCommand = cellposeCommand + " no_dialog=true";
    cellposeCommand = cellposeCommand + " batch_mode=true";

	run("Cellpose ...", cellposeCommand);
	
	// Sauvegarder l'image Masque avec le paramètre "nom de l'image"

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

	//Lancer la macro 02_Macro_Analyse_MAIRE.ijm conditionnée aux canaux ALL - paramètre canal laminine
	if (useCSA) {
	    run("Set Measurements...", "area mean");
	} else {
	    run("Set Measurements...", "area mean feret's");
	}
	nROIs = roiManager("count");
	getDimensions(w, h, channels, slices, frames);
	
	// Mesurer uniquement les canaux sélectionnés
	for(i=0; i<selectedChannels.length; i++) {
		
	    setSlice(selectedChannels[i]);
	    
	    for(j=0; j<nROIs; j++) {
	        roiManager("select", j);
	        run("Measure");
	    }
	    selectWindow("Results");
	    saveAs("Results", dir + ImageName + "Measurements_" + channelNames[i] + ".csv");
	    selectWindow("Results");
	    run("Close");
	}

	roiManager('reset');
	run("Select None");
	selectImage("Originale");
	close();
	
	// Création et remplissage du fichier compilé après les mesures de tous les canaux
	output = File.open(dir + ImageName + "_Compiled_Results.csv");
	
	// Écrire les en-têtes
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
	
	// Écrire les données du premier canal avec Area
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
    
    // Écrire les en-têtes avec ajout des ratios
    if (useCSA) {
	    headers = "ROI,Size_CSA";
	} else {
	    headers = "ROI,Size_MinFeret";
	}
    for(i=0; i<channelNames.length; i++) {
        headers = headers + ",Mean_" + channelNames[i];
    }
    // Ajouter les ratios aux en-têtes
    headers = headers + ",Ratio_1_3,Ratio_1_4,Ratio_3_4";
    print(output, headers);
    
    // Premier canal : Label, Area, Mean
    firstResults = File.openAsString(dir + ImageName + "Measurements_" + channelNames[0] + ".csv");
    firstLines = split(firstResults, "\n");
    firstData = Array.slice(firstLines, 1);
    
	// Charger les ROIs pour MinFeret si nécessaire
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
                // Pour le premier canal, on a déjà les données
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
        
        // Calculer les ratios
        ratios = calculateRatios(mean_values, selectedChannels);
		ratio_1_3 = ratios[0];
		ratio_1_4 = ratios[1]; 
		ratio_3_4 = ratios[2];
		
		// Ajouter les ratios à la ligne
		line = line + "," + ratio_1_3 + "," + ratio_1_4 + "," + ratio_3_4;
        
        print(output, line);
    }
    File.close(output);
    
    // Supprimer les fichiers measurements
    for(i=0; i<channelNames.length; i++) {
        measurementFile = dir + ImageName + "Measurements_" + channelNames[i] + ".csv";
        File.delete(measurementFile);
}

	// Lire le fichier compilé
	compiledResults = File.openAsString(dir + ImageName + "_Compiled_Results.csv");
	lines = split(compiledResults, "\n");
	header = lines[0];
	data = Array.slice(lines, 1); // Ignorer l'en-tête
	
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
	    // Vérifier d'abord si un canal custom est demandé
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
    // Vérifier que l'image originale est ouverte
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
	    
	    // Importer ROIs si nécessaire
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
	
	// Créer le fichier de sortie avec la classification
	outputFile = File.open(dir + ImageName + "_Classified_Results.csv");
	
	// Construire l'en-tête avec point-virgule comme séparateur
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
	
	// Ajouter la colonne de classification à la fin
	headerString = headerString + ";Classification";
	print(outputFile, headerString);
	
	// Lire le fichier compilé pour obtenir les données d'aire
	compiledResults = File.openAsString(dir + ImageName + "_Compiled_Results.csv");
	lines = split(compiledResults, "\n");
	header = lines[0];
	data = Array.slice(lines, 1);
	
	headers = split(header, ","); 
	classificationIndex = headers.length - 1; // La classification est toujours la dernière colonne
	
	roiManager("reset");
	roiManager("Open", dir+ImageName+"_ROI_Set.zip");
	dir = getPlatformSafePath(dir);
	open(dir+ListeFichier[k]);
	rename("Original_For_Analysis");

smallImageProgress(k, nbFichiers, 7, 10, "Classifying fibers");

	// Classifier chaque fibre avec les nouvelles caractéristiques
	for (i = 0; i < numRows; i++) {
    // Extraire les valeurs à partir du tableau data
    if (i >= data.length) {
        print("Warning: index i=" + i + " out of bounds for data (length=" + data.length + ")");
        continue; // Passer à l'itération suivante
    }
    values = split(data[i], ",");
    
	// Récupérer le numéro de ROI et la taille
	roiID = values[0];
	sizeValueNumeric = parseFloat(values[1]); // Valeur numérique pour les calculs
	
	// Pour l'affichage CSV (formaté)
	sizeValueFormatted = replace(d2s(sizeValueNumeric, 2), ".", ",");
    
    // Extraire les caractéristiques morphologiques
    if (i < roiManager("count")) {
        roiManager("select", i);
        run("Set Measurements...", "area perimeter shape redirect=None decimal=3");
        run("Measure");
        perimeter = getResult("Perim.", nResults-1);
        eccentricity = 1 - getResult("Circ.", nResults-1); // Approximation de l'eccentricity
        solidity = getResult("Solidity", nResults-1);
        run("Clear Results");
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
    
    // Récupérer les valeurs de chaque canal avec vérification de sécurité
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
    
    // Extraire les ratios (les 3 dernières colonnes sont les ratios)
    ratio_idx = headers.length - 3;
    ratio_1_3 = 0; ratio_1_4 = 0; ratio_3_4 = 0;
    
    if (ratio_idx > 0 && ratio_idx < values.length) {
        ratio_1_3 = parseFloat(values[ratio_idx]);
        if (ratio_idx + 1 < values.length) ratio_1_4 = parseFloat(values[ratio_idx + 1]);
        if (ratio_idx + 2 < values.length) ratio_3_4 = parseFloat(values[ratio_idx + 2]);
    }
    
    ratios = newArray(ratio_1_3, ratio_1_4, ratio_3_4);
    
    // Calculer les facteurs d'homogénéité
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
    
      // Déterminer si chaque type est positif
    isIIb = 0;
    isIIx = 0;
    isIIa = 0;
    isI = 0;
    iscustom = 0;
    
    // Déterminer les positifs en comparant avec les seuils
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
    
    // Préparation pour la classification
    classification = "O"; // Par défaut non-classé
    
    // Préparation des tableaux d'intensités et seuils pour la classification améliorée
    intensities = newArray();
    thresholds = newArray();
    typeNames = newArray();
    
    // Ajouter les types qui dépassent les seuils
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
    
// Variables précalculées pour éviter les recalculs
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
    
    // IIb + IIa : Privilégier dominance
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

	// IIx + I : Privilégier dominance
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

	// IIb + I : Privilégier dominance
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
	
	// Cas hybrides autorisés
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
    
    // IIx + IIa : hybride autorisé
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
    
    // IIa + I : hybride autorisé
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
        // Déterminer directement les 2 plus forts sans tri
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
        // Déterminer directement les 2 plus forts sans tri
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

// ===== INTÉGRATION CUSTOM =====
if (iscustom == 1) {
    if (baseClassification == "O") {
        classification = customChannelName;
    } else {
        classification = baseClassification + "-" + customChannelName;
    }
} else {
    classification = baseClassification;
}
    
    // Construire la ligne de résultat
    resultLine = roiID + ";" + sizeValueFormatted;
    
    // Ajouter les valeurs des canaux de manière sécurisée
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
    
    // Ajouter la classification à la fin
    resultLine = resultLine + ";" + classification;
    
    // Écrire la ligne dans le fichier
    print(outputFile, resultLine);
}
File.close(outputFile);

	// Supprimer le fichier compilé après utilisation
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
	
	// Modifier la partie qui crée le fichier de sortie avec les statistiques
	outputModified = File.open(dir + ImageName + "_Classified_Results.csv");
	
	// Écrire l'en-tête avec les colonnes supplémentaires
	if (useCSA) {
	    headerString = "ROI;CSA";
	} else {
	    headerString = "ROI;MinFeret";
	}
	
	// Ajouter uniquement les canaux actifs avec vérification de leur utilisation
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
	
	// Déterminer la première ligne de données
	firstDataRow = 2;
	
	// Identifier les classifications uniques présentes dans les données
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
	
	// Écrire les données
	for (i = 1; i < lines.length; i++) {
	    values = split(lines[i], ";");
	    resultLine = values[0] + ";" + values[1];  // ROI et Area
	    
	    colIndex = 2; // Commencer après ROI et Area
	    
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
    // Ajouter la classification à la fin
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
	
	// Obtenir les références des colonnes
	classificationCol = getColumnLetter(baseColumns + activeChannels);
	areaCol = "B"; // La colonne Area est toujours B
	
	// Générer les formules
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
	    resultLine += "\"=MOYENNE(B:B)\";"; // Moyenne générale des aires
	}   
	    print(outputModified, resultLine);
	}

File.close(outputModified);

File.rename(dir + ImageName + "_Classified_Results_Modified.csv", 
           dir + ImageName + "_Classified_Results.csv");

							// ============= 5. Création des visualisations ==================
						
	// Ouvrir l'image originale pour récupérer les dimensions
	dir = getPlatformSafePath(dir);
	open(dir+ListeFichier[k]);
	rename("Original_For_Analysis");
	getDimensions(width, height, channels, slices, frames);

smallImageProgress(k, nbFichiers, 8, 10, "Creating visualization");

	// Créer l'overlay avec les dimensions exactes
	newImage("Base_Overlay", "RGB white", width, height, 1);
	run("Select None");
	
	// Charger les ROIs et les résultats classifiés
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
	
							// ============ 6. Sauvegarde des résultats ===============
					
smallImageProgress(k, nbFichiers, 9, 10, "Saving results");

	// S'assurer que les bonnes images sont ouvertes dans le bon ordre
	// D'abord ouvrir l'overlay
	dir = getPlatformSafePath(dir);
	open(dir+ImageName+"_temp_overlay.png");
	rename("Overlay");
	
	// Ensuite, sélectionner l'image originale en dernier (important pour Add Image)
	selectWindow("Original_For_Analysis");
	
	// Ajouter l'overlay avec la méthode native d'ImageJ
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