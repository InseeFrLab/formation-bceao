library(readr)
library(dplyr)
library(arrow)

# Installer le package doremifasol
remotes::install_github("InseeFrLab/doremifasol", build_vignettes = TRUE)

library(doremifasol)

############################################################
# Télécharger des données brutes
############################################################

# Créer un dossier temporaire pour accueillir les données brutes
dir.create("rawdata")

# Télécharger les données du RP (cela peut prendre plusieurs minutes)
doremifasol::telechargerFichier(
  donnees = "RP_LOGEMENT",
  date = "dernier",
  telDir = "rawdata"
)

# Dézipper les données
unzip("rawdata/RP2017_LOGEMT_csv.zip", exdir = "rawdata/")

############################################################
# Importer des données avec data.table
############################################################

# Importer avec data.table
data <- data.table::fread(
  "rawdata/FD_LOGEMT_2017.csv",
  sep = ";",
  colClasses = c(
    COMMUNE = "character"
  ),
  nrows = 1e6
)

############################################################
# Sauvegarder des données en Parquet
############################################################

# Comment écrire un Parquet en local
arrow::write_parquet(
  data,
  sink = "logements_RP2017.parquet"
)

# Comment écrire un Parquet partitionné en local
arrow::write_dataset(
  data,
  path = "logements_RP2017/",
  partitioning = c("code_reg"),
  hive_style = TRUE,
  existing_data_behavior = "overwrite"
)


############################################################
# Manipuler des données parquet en mémoire
############################################################

# Comment importer un fichier Parquet en mémoire
data <- arrow::read_parquet(
  file = "logements_RP2017.parquet"
)

# Apprendre à se servir de select et filter
extrait_data <- data |> 
  select(prix, code_reg, variete) |>
  filter(code_reg %in% c(11, 28, 75))

# Apprendre à faire group_by et summarise  
resultat <- extrait_data |> 
  group_by(code_reg, variete) |>
  summarise(
    prix_moyen = mean(prix, na.rm = TRUE)
  )


############################################################
# Manipuler des données parquet en mode lazy
############################################################

# Se connecter un fichier Parquet partitionné
data2 <- arrow::open_dataset(
  source = "donnees_caisse/",
  partitioning = schema(code_reg = arrow::utf8())
)

# Afficher les informations sur le fichier partitionné
data2$schema
dim(data2)
names(data2)

# Apprendre à se servir de select et filter
# Apprendre à faire group_by et summarise
resultats <- data2 |> 
  group_by(
    code_reg, variete
  ) |>
  filter(code_reg %in% c(11, 28, 75)) |>
  summarise(
    prix_moyen = mean(prix, na.rm = TRUE)
  ) |> 
  compute()





# Comment écrire un Parquet partitionné en local
arrow::write_dataset(
  data,
  path = "logements_RP2017/",
  partitioning = c("code_reg"),
  hive_style = TRUE,
  existing_data_behavior = "overwrite"
)


############################################################
# Manipuler des données parquet en mémoire
############################################################

# Comment importer un fichier Parquet en mémoire
data <- arrow::read_parquet(
  file = "donnees_caisse.parquet"
)

# Apprendre à se servir de select et filter
extrait_data <- data |> 
  select(prix, code_reg, variete) |>
  filter(code_reg %in% c(11, 28, 75))

# Apprendre à faire group_by et summarise  
resultat <- extrait_data |> 
  group_by(code_reg, variete) |>
  summarise(
    prix_moyen = mean(prix, na.rm = TRUE)
  )


############################################################
# Manipuler des données parquet en mode lazy
############################################################

# Se connecter un fichier Parquet partitionné
data2 <- arrow::open_dataset(
  source = "donnees_caisse/",
  partitioning = schema(code_reg = arrow::utf8())
)

# Afficher les informations sur le fichier partitionné
data2$schema
dim(data2)
names(data2)

# Apprendre à se servir de select et filter
# Apprendre à faire group_by et summarise
resultats <- data2 |> 
  group_by(
    code_reg, variete
  ) |>
  filter(code_reg %in% c(11, 28, 75)) |>
  summarise(
    prix_moyen = mean(prix, na.rm = TRUE)
  ) |> 
  compute()




