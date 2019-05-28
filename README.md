# floc_scanner_bundle

This repo contains the Matlab PsychToolbox code to run and analyze the visual/auditory 2-back/passive WM task that we've been using to localize sensory-biased frontal regions in individual subjects.

**floc_scanner.m** is the main task control function, and runs a modality-specific (auditory or visual) 2-back working memory task, and its passive-viewing equivalent, in alternating blocks. It can run either as a practice session (on a laptop) or as the task control for the scanner. You may need to add additional device cases to account for specific environments (e.g. a different laptop, or different scanner button box). 

## Usage
<pre>floc_scanner(subID, blockorder, device)</pre>

subID: Subject identifier (string)

whichorder: 1, 2, 3, or 4. Selects one of 4 pre-determined orders (stored in **blockorder**) the 8 blocks occur in.

device: Environment specifier (string, e.g. 'scanner', or 'laptop').

## Organization
**animal-sounds/** and **faces/** contain the auditory (cat and dog vocalizations) and visual (black and white face photos) stimuli for the task. **results/** is where .mat output files from **floc_scanner.m** will be saved. **analysis scripts/** contains scripts for assessing performance on the task.

## Citation
If you use these tasks, please cite Noyce, A. L., Cestero, N., Michalka, S. W., Shinn-Cunningham, B. G., & Somers, D. C. (2017). Sensory-biased and multiple-demand processing in human lateral frontal cortex. *Journal of Neuroscience, 37(36)*, 8755-8766. doi:10.1523/JNEUROSCI.0660-17.2017
