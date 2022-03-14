# Set Env. ----------------------------------------------------------------
library(tidyverse) # CRAN v1.3.1
library(Rlabkey)   # CRAN v2.8.2

# LabKey Config. ----------------------------------------------------------
labkey.setDefaults(baseUrl = "https://labkey-embassy.gel.zone/labkey")
lk_version <- "/main-programme/main-programme_v14_2022-01-27"

fetch_lk <- function(sql) {
  labkey.executeSql(
    folderPath = lk_version,
    schemaName = "lists",
    maxRows = 10000000,
    colNameOpt = "rname",
    sql = sql) %>%
    mutate(across(everything(), as.character))
}

# ICD10 Code Look-up ------------------------------------------------------
coding <- read_tsv("coding19.tsv", col_names = T) %>% 
  select(icd10 = coding, icd10_description = meaning)

# Fetch ICD10 entries from all tables -------------------------------------
icd10_full <- bind_rows(
  
  hes_apc = fetch_lk(paste("SELECT participant_id, 
                      epistart AS start,", 
                      paste("diag_", sprintf("%02d", seq(1:20)), sep = "", collapse = ","),
                      "FROM hes_apc")),
  
  hes_op = fetch_lk(paste("SELECT participant_id, 
                      apptdate AS start,", 
                      paste("diag_", sprintf("%02d", seq(1:12)), sep = "", collapse = ","),
                      "FROM hes_op")),
  
  hes_ae = fetch_lk(paste("SELECT participant_id, 
                      arrivaldate AS start,", 
                      paste("diag_", sprintf("%02d", seq(1:12)), sep = "", collapse = ","),
                      "FROM hes_ae
                      WHERE diagscheme = '02'")),
  
  mortality = fetch_lk(paste("SELECT participant_id, 
                        date_of_death,
                        icd10_underlying_cause,",
                        paste("icd10_multiple_cause_", seq(1:15), sep = "", collapse = ","),
                        "FROM mortality")) %>% 
    setNames(c("participant_id", "start", paste("diag_", sprintf("%02d", seq(1:16)), sep = ""))), .id = "origin")


# Clean ICD10 entries and pivot into long format --------------------------
icd10_clean <- icd10_full %>%  
  filter(!is.na(start)) %>%                               # remove empty start dates
  mutate(start = as.Date(str_sub(start, 1, 10))) %>%      # convert to date format
  filter(start >= "1995-01-01") %>%                       # dates before this are ICD-9
  pivot_longer(cols = starts_with("diag"),                # pivot to long format
               names_to = "diag", 
               values_to = "icd10", 
               values_drop_na = TRUE) %>%
  mutate(icd10 = case_when(                               # clean ICD10 codes
    str_detect(icd10, "R69X3|R69X6|R69X8") ~ icd10,       # reserved codes
    TRUE ~ str_extract(icd10, "([A-Z][0-9]+)"))) %>%      # clean to ICD10 format
  filter(!is.na(icd10)) %>%                               # remove null codes after clean
  select(participant_id, origin, start, diag, icd10) %>%  
  arrange(participant_id, origin, start, diag, icd10)

# Extract unique ICD10 codes per participant ------------------------------
icd10_unique <- icd10_clean %>% 
  distinct(participant_id, icd10)

# ICD10 code count and description ----------------------------------------
icd10_count <- icd10_unique %>% 
  count(icd10, sort = TRUE, name = "n_participants") %>% 
  left_join(coding, by = "icd10") %>%
  mutate(icd10_description = case_when(
    icd10 == "R69X6" ~ "Null (Primary diagnosis)",
    icd10 == "R69X8" ~ "Invalid",
    icd10 == "R69X3" ~ "Invalid (Exter l Cause code entered as Primary Diagnosis)",
    is.na(icd10_description) ~ "No description found", 
    TRUE ~ icd10_description)) %>% 
  select(icd10, icd10_description, n_participants)

# Save outputs ------------------------------------------------------------
save(icd10_full, file = "icd10_full.RData")
save(icd10_clean, file = "icd10_clean.RData")
save(icd10_unique, file = "icd10_unique.RData")
save(icd10_count, file = "icd10_count.RData")

write_tsv(icd10_full, file = "icd10_full.tsv", col_names = TRUE)
write_tsv(icd10_clean, file = "icd10_clean.tsv", col_names = TRUE)
write_tsv(icd10_unique, file = "icd10_unique.tsv", col_names = TRUE)
write_tsv(icd10_count, file = "icd10_count.tsv", col_names = TRUE)
