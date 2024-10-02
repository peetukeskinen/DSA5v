# Debt Sustainability Analysis (DSA) Tool - Version 5

## Overview
The Debt Sustainability Analysis (DSA) tool, now in its fifth version, is used for debt ratio projections. An enhancement from version 4, this version incorporates all criteria from the reformed EU Fiscal Rules. It improves the analysis of debt sustainability, including new fiscal safeguards, as outlined by the European Commission. For context on the importance of these debt rules, see this [blog post](https://www.vtv.fi/en/blog/the-length-of-the-adjustment-plan-in-the-reformed-eu-debt-rules-is-of-great-importance-to-finland/).

### Compatibility
The tool is compatible with Windows 10 (64-bit) and MATLAB R2020b.

### Components Required
To execute this MATLAB code, you'll need:

1. **Main Function:** `runDsaModel5.m`
2. **Helper Functions:**
   - `project_debt5v.m` - Projects debt paths considering yearly adjustments.
   - `sumq2y.m` - Converts quarterly shocks to yearly data.
   - `formatWithSpaces.m` - Ensures numbers in figures are formatted for readability.
3. **Data File:** `ECdataFinland.xlsx`

### Criteria
The current version 5 includes all criteria from the reformed EU fiscal rules, including:

- **Debt Sustainability Criteria:** Both deterministic and stochastic scenarios.
- **Debt Sustainability Safeguard**
- **Deficit Resilience Safeguard**
- **Deficit Benchmark**

These criteria ensure that the analysis aligns with updated EU regulations and is more comprehensive than previous versions.

### Scenarios and Customization
The tool facilitates debt projections following the guidelines of the European Commission's [Debt Sustainability Monitor 2023](https://economy-finance.ec.europa.eu/publications/debt-sustainability-monitor-2023_en). Users can run simulations under different assumptions and fiscal conditions, with flexibility in selecting methods and parameters for more customized results.

The use of the tool is done by running a separate file, `defineDsaModel5.m`, where all required parameters and options are selected. The defined `param` structure is then passed to the `DSA5v.m` function to run the analysis.

### Data and Adjustments
The file `ECdataFinland.xlsx` contains all necessary data for the tool. Users can modify parameters for sensitivity analysis and select options for plotting, language preference, and saving.

### Example

To execute the tool with selected configurations, modify the parameters in the `defineDsaModel5.m` file as needed and run the file. The selected parameter structure is passed to the `DSA5v.m` function for analysis.

### Contact
For any inquiries or feedback, please contact peetu.keskinen@vtv.fi.
