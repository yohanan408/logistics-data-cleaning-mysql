Logistics Data Cleaning: Dirty Shipments Portfolio

This project demonstrates advanced MySQL data engineering techniques used to transform a "dirty" logistics dataset into a high-quality, analysis-ready table.

📌 Project Overview

The shipment.dirty_shipments table contained several data integrity issues common in real-world pipelines:
Formatting Inconsistency: Mixed casing (UPPER, lower, Proper) and redundant prefixes.
Structural Noise: Leading/trailing whitespaces and literal "NULL" strings.
Duplicate Records: Multiple entries for identical shipments.
Logical Errors: Shipments delivered before they were sent.
Statistical Outliers: Extreme freight costs that skew averages.

🛠️ Cleaning Steps & Logic

1. Text Standardisation & String Manipulation

Trimming: Removed all leading/trailing whitespace using TRIM().
Warehouse Normalisation: Used REPLACE and UPPER to standardise warehouse IDs (e.g., stripping "Warehouse" prefix and fixing redundant characters).
Smart Proper Case: Implemented a complex CONCAT/LOCATE logic to ensure cities with spaces (e.g., "New York") are correctly capitalised at each word boundary.

2. Handling Missing Values

Converted literal string "NULL" values into actual SQL NULL.
Used COALESCE(NULLIF(val, '')) to provide descriptive placeholders:
Missing Cities 
 "Unknown"
Missing Delivery Dates 
 "Not Yet Delivered"

3. Deduplication

Utilised Common Table Expressions (CTEs) and the ROW_NUMBER() window function to partition data by core shipment attributes. Only the first occurrence (row_num = 1) is retained, effectively removing exact and near-exact duplicates.

4. Mathematical & Logical Validation

Absolute Value Correction: Applied ABS() to negative weights, costs, and item counts, assuming negative signs were entry errors.
Multi-Format Date Parsing: Used STR_TO_DATE with COALESCE to handle three distinct date formats (YYYY-MM-DD, MM/DD/YYYY, and Feb 15 2024) in a single column.
Transit Logic: Created a data_quality_flag to identify shipments where the delivery date precedes the shipping date.

5. Advanced Outlier Detection (Tukey’s Fences)

Instead of using hard-coded limits, this script uses a dynamic statistical approach:
Calculates Q1 (25th percentile) and Q3 (75th percentile) using PERCENT_RANK().
Determines the Interquartile Range (IQR).
Sets Lower/Upper Bounds (


).
Caps extreme values at the bounds and flags them with a was_outlier boolean.

🚀 How to Use

Ensure you are using MySQL 8.0 or higher (required for Window Functions and PERCENT_RANK).
Run the script sections sequentially to view the transformation stages.
The final output provides a "Cleaned View" ready for export to BI tools like Tableau or Power BI.
