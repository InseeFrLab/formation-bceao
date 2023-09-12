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

# Question: importer le fichier du RP avec data.table. 
# Conseil: commencer par importer quelques lignes et bien vérifier le type des variables!

# Importer avec data.table
input <- data.table::fread(
  "rawdata/FD_LOGEMT_2017.csv",
  sep = ";",
  colClasses = c(
    COMMUNE = "character"
  ),
  data.table = FALSE
)

############################################################
# Sauvegarder des données en Parquet
############################################################

# Question: écrire les données dans un parquet nommé "logements_RP2017.parquet"

# Comment écrire un Parquet en local
arrow::write_parquet(
  input,
  sink = "logements_RP2017.parquet"
)

# Question: écrire les données dans un parquet partitionné par la variable "REGION"

# Comment écrire un Parquet partitionné en local
dir.create("logements_RP2017")
arrow::write_dataset(
  input,
  path = "logements_RP2017/",
  partitioning = c("REGION"),
  hive_style = TRUE,
  existing_data_behavior = "overwrite"
)


############################################################
# Manipuler des données parquet en mémoire
############################################################

# Question: importer le fichier "logements_RP2017.parquet" sous forme d'un data.frame

# Comment importer un fichier Parquet en mémoire
data <- arrow::read_parquet(
  file = "logements_RP2017.parquet"
)

# Question: Extraire des données les observations
# correspondant à la région Auvergne-Rhône-Alpes (REGION == "84")
# Conserver uniquement les variables suivantes: COMMUNE, TYPL

extrait_data <- data |> 
  filter(REGION == "84") |>
  select(REGION, COMMUNE, TYPL)

# Question: Calculer la part d'habitations de fortune dans chaque commune

resultat <- extrait_data |> 
  group_by(COMMUNE) |>
  summarise(
    nb_logements_fortune = sum(TYPL == "5"),
    nb_logements_commune = n()
  ) |>
  mutate(
    part_logements_fortune = nb_logements_fortune / nb_logements_commune
  ) |>
  arrange(-part_logements_fortune)


############################################################
# Manipuler des données parquet en mode lazy
############################################################

# Question: Se connecter au fichier Parquet partitionné SANS importer les données en mémoire

# Se connecter un fichier Parquet partitionné
data2 <- arrow::open_dataset(
  source = "donnees_caisse/",
  partitioning = schema(code_reg = arrow::utf8())
)

# Question: Afficher les informations sur le fichier partitionné: le chema des données, leur dimension et le nom des variables
data2$schema
dim(data2)
names(data2)

# Question: Extraire des données les observations
# correspondant à la région Auvergne-Rhône-Alpes (REGION == "84")
# Conserver uniquement les variables suivantes: COMMUNE, TYPL
# Calculer la part d'habitations de fortune dans chaque commune

resultats <- data2 |> 
  filter(REGION == "84") |>
  select(REGION, COMMUNE, TYPL) |> 
  group_by(COMMUNE) |>
  summarise(
    nb_logements_fortune = sum(TYPL == "5"),
    nb_logements_commune = n()
  ) |>
  mutate(
    part_logements_fortune = nb_logements_fortune / nb_logements_commune
  ) |> 
  compute()
