**Synthetic Control Method for Employment Analysis**

This project includes STATA code for running the Synthetic Control Method (SCM) to estimate the divergence of artist employment after the emergence of ChatGPT. The dataset is accessed from IPUMS CPS and consists of panel data on monthly employment across all occupations in the USA. The code utilizes the _synth_ and _synth_runner_ commands for estimating SCM, as well as data preprocessing and post-analysis.

These codes can be used as a baseline for other projects using SCM to estimate causality in data.

**Installation**
To run the code in this project, you need to install the synth and synth_runner packages in STATA. You can install these packages by running the following commands in your STATA command window:
_ssc install synth_
_ssc install synth_runner_

**Usage**
1) Clone this repository.
2) Load the dataset accesed from IPUMS CPS. Obliagory variables(CPS NAMES): year serial month hwtfinl cpsid gqtype metfips cpsidp age sex race marst occ uhrsworkt educ 
3) Run the STATA code using the provided scripts. Make sure to provide proper folder directories in the begginng at the beggining of the code file.

**License**
This project is licensed under the MIT License. You are free to use, modify, and distribute this software. See the LICENSE file for more details.
