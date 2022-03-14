# Overview
Extract and parse ICD-10 entries from Electronic Health Records in the Genomics England 100K and COVID-19 secondary datasets.

Uses a single R script and assumes connection and access to LabKey. 

GitHub Repo: https://github.com/genomicsengland/BRS_ICD10_parser

Confluence Page: https://cnfl.extge.co.uk/display/REBS/ICD-10%3A+Parse+and+Extract

# Important
- Must be run on Helix (HPC) / Cloud-RE as not all rows will be fetched locally on VPN or RE1.0 Desktop Environment (Rlabkey issue)
- Always run a manual check that number of rows is correct per table

# Explanation of Script
1. Set connection to LabKey
2. Extract participant_id, start date, and all ICD-10 containing columns from LabKey tables:
    - hes_apc (Admitted Patient Care records - Hospital Episode Statistics)
    - hes_op (Outpatient records - Hospital Episode Statistics)
    - hes_ae (Accident and Emergency records - Hospital Episode Statistics)
    - mortality (Mortality records - Office of National Statistics)
3. The episode start per table is taken from the following columns:
    - hes_apc = epistart
    - hes_op = apptdate
    - hes_ae = arrivaldate
    - mortality = date_of_death
4. ICD-10 information are taken from the following columns:
    - hes_apc = diag01 - diag20
    - hes_op = diag_01 - diag12
    - hes_ae = diag_01 - diag12 (note 'diagscheme' is filtered for '02' signifying ICD10 encoding)
    - mortality = icd10_underlying_cause & icd10_multiple_cause_01 - icd10_multiple_cause_15
5. All start dates are labelled as 'start' and all ICD-10 containing columns are labelled as diag_01, diag_02...
6. The tables are merged together and a column 'origin' is created - specifying the source of the table (hes_op, hes_apc...)
7. This table is saved (icd10_full)
8. These codes are then cleaned and pivoted into long format:
    - Empty start dates are removed
    - Dates are convert to date format
    - Dates before 01/01/1995 are removed as these contain ICD-9 codes as well as null / invalid dates (e.g. 01/01/1800)
    - Table pivoted to long format (one unique participant_id, table id, start, diag, icd10 per row)
    - Trailing characters are stripped from ICD-10 codes, including (X, D, A, S, -, ~). See 'Special Characters' below
    - R69X3, R69X6, R69X8 are preserved as they represent reserved codes
    - This table is saved (icd10_clean)
9. The unique observations of participant_id and icd10 with description are taken from icd10_clean. This table is saved (icd10_unique)
10. Each unique ICD10 per participant is tallyed across all participants. This table is saved (icd10_count)

# Outputs
- **icd10_full**: all pre-cleaned ICD-10 entries in a wide-format table containing: participant_id, origin, start, diag_01 - diag_20
- **icd10_clean**: cleaned ICD-10 entries in a long-format table containing: participant_id, table id, start, diag, icd10 per row (unique combination per row)
- **icd10_unique**: a three-column table containing: participant_id and icd10 with description where every row is unique
- **icd10_count**: a three-column table containing: icd10, icd10_description, n_participants (number of participants with term)


Note as reference the number of rows in the original raw data (MPV14): 
- hes_apc = 1,176,349
- hes_op = 6,050,176
- hes_ae = 6,372
- mortality = 6,127
- total = 7,239,024

# Data Dictionary
## Start Dates
The following columns are used per table for the date of ICD10 entry (the 'start' variable as above).

### Admitted Patient Care (epistart)
This field contains the date on which a patient was under the care of a particular consultant. If a patient has more than one episode in a spell, for each new episode there is a new value of epistart. However, the admission date which is copied to each new episode in a spell will remain unchanged and will be equal to the episode start date of the first episode in hospital.

2012/13 onwards:
01/01/1800 - Null date submitted
01/01/1801 - Invalid date submitted

1989/90 to 2011/12:
01/01/1600 ‚ Null date submitted
15/10/1582 ‚ Invalid date submitted

### Outpatient (apptdate)
The date when an appointment was scheduled.

dd/mm/yyyy = Date of Outpatient Appointment
18000101 - Blank arrival date submitted.
18010101 = arrival date is invalid or before period start date or after period end date.

### Accident and Emergency (arrivaldate)
The arrival date of a patient in the A&E department.
ddmmyyyy = The arrival date of a patient in the A&E department
18000101 - Blank arrival date submitted.
18010101 = arrival date is invalid or before period start date or after period end date.

### Mortality (date_of_death)
Date of the participant's death.

## ICD-10
The following columns are used to etract all ICD-10 entries. 

### Admitted Patient Care (diag_01 to diag_20)
There are twenty fields (fourteen before April 2007 and seven before April 2002), diag_01 to diag_20, which contain information about a patient's illness or condition. The field diag_01 contains the primary diagnosis. The other fields contain secondary/subsidiary diagnoses. The codes are defined in the International Statistical Classification of Diseases, Injuries and Causes of Death. HES records currently use the tenth revision (ICD-10). Prior to April 1995, the ninth revision was used (ICD-9). Diagnosis codes start with a letter and are followed by two or three digits. The third digit identifies variations on a main diagnosis code containing two digits. The third digit is preceded by a full stop in ICD-10, but this is not stored in the field.

annn = A valid ICD-9 or ICD-10 diagnosis code.

annnnn = A valid ICD-9 or ICD-10 diagnosis code.

Null = Not applicable

R96X - Not known

R69X6 - Null (Primary diagnosis)

R69X8 - Invalid

R69X3 - Invalid (Exter l Cause code entered as Primary Diagnosis)

### Outpatient (diag_01 to diag_12)
There are twenty fields (fourteen before April 2007 and seven before April 2002), diag_01 to diag_12, which contain information about a patient's illness or condition. The field diag_01 contains the primary diagnosis. The other fields contain secondary/subsidiary diagnoses. The codes are defined in the International Statistical Classification of Diseases, Injuries and Causes of Death. HES records currently use the tenth revision (ICD-10). Prior to April 1995, the ninth revision was used (ICD-9). Diagnosis codes start with a letter and are followed by two or three digits. The third digit identifies variations on a main diagnosis code containing two digits. The third digit is preceded by a full stop in ICD-10, but this is not stored in the field.

annn = A valid ICD-9 or ICD-10 diagnosis code.

annnnn = A valid ICD-9 or ICD-10 diagnosis code.

Null = Not applicable

R96X - Not known

R69X6 - Null (Primary diagnosis)

R69X8 - Invalid

R69X3 - Invalid (Exter l Cause code entered as Primary Diagnosis)

### Accident and Emergency (diag_01 to diag_12): 
The A&E diagnosis code recorded for an A&E attendance. The CDS allows an unlimited number of diagnoses to be submitted, however, only the first 12 diagnoses are available within HES. The A&E diagnosis is a six character code made up of, diagnosis condition (n2), sub-analysis (n1), anatomical area (n2) and anatomical side (an1). Only certain diagnoses contain a sub-analysis. 6an = An A&E diagnosis classification code

### Mortality (icd10_underlying_cause & icd10_multiple_cause_01 to icd10_multiple_cause_15)
ICD10 coded causes of death

## Special Characters
The ICD-10 utilises a placeholder character “X”. The “X” is used as a placeholder at certain codes to allow for future expansion. An example of this is at the poisoning, adverse effect and under-dosing codes, categories T36-T50. ICD-10-CM Official Guidelines for Coding and Reporting FY 2019 Page 8 of 120 Where a placeholder exists, the X must be used in order for the code to be considered a valid code.

The extension character must always be in the seventh position. So, if a code has fewer than six characters and requires a seventh character extension, you must fill in all of the empty character spaces with a placeholder “X.” 

Seventh character extensions for injuries (not including fractures) include:

- "A" (Initial encounter) - Initial encounter is defined as the period when the patient is receiving active treatment for the injury, poisoning, or other consequences of an external cause.  An "A" may be assigned on more than one claim
- "D" (Subsequent encounter) - An encounter after the active phase of treatment and when the patient is receiving routine care for the injury during the period of healing or recovery.
- "S" (Sequela) - Complications that arise as a direct result of a condition.

The hyphen or dash (-) at the end of an ICD-10 code indicates that additional characters are required on the code (it is not complete). To find the most specific code with additional characters, the coder would look up the more specific complete Alphabetic Index code in the Tabular Listing.

# ICD10 Lookup Table
To map ICD10 codes to descriptions, the UK Biobank ICD10 lookup table is used (https://biobank.ndph.ox.ac.uk/ukb/coding.cgi?id=19). Description: ICD10 - WHO International Classification of Diseases. ICD-10 codes, terms and text used by permission of WHO, from: International Statistical Classification of Diseases and Related Health Problems, Tenth Revision (ICD-10). Vols 1-3. Geneva, World Health Organization, 1992-2016. This is a hierarchical tree-structured dictionary which uses strings (character sequences) to represent categories or special values
