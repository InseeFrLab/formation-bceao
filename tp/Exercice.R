library(aws.s3)
library(readr)
library(dplyr)
library(arrow)

aws.s3::get_bucket("projet-formation", region = "", prefix = "diffusion/bceao")

############################################################
# Importer des données avec Arrow
############################################################

df_sample2 <- s3read_using(
  FUN = arrow::read_csv_arrow,
  as_data_frame = FALSE,
  object = "diffusion/bceao/donnees_caisse_sample.csv",
  bucket = "projet-formation",
  opts = list("region" = "")
)

# Toutes les données
df_full <- s3read_using(
  FUN = arrow::read_csv_arrow,
  as_data_frame = FALSE,
  object = "diffusion/bceao/donnees_caisse.csv",
  bucket = "projet-formation",
  opts = list("region" = "")
)

# Prendre un extrait des données
df_full2 <- df_full |> head(5000000) |> compute()


# ############################################################
# # Sauvegarder des données en Parquet sur S3
# ############################################################
# 
# # Comment écrire un Parquet partitionné sur S3
# minio <- S3FileSystem$create(
#   access_key = Sys.getenv("AWS_ACCESS_KEY_ID"),
#   secret_key = Sys.getenv("AWS_SECRET_ACCESS_KEY"),
#   session_token = Sys.getenv("AWS_SESSION_TOKEN"),
#   scheme = "https",
#   endpoint_override = Sys.getenv("AWS_S3_ENDPOINT")
# )
# 
# arrow::write_dataset(
#   df_full2,
#   path = minio$path("oliviermeslin/bceao_parquet/donnees_caisses/"),
#   partitioning = c("code_reg"),
#   hive_style = TRUE,
#   existing_data_behavior = "overwrite"
# )

############################################################
# Sauvegarder des données en Parquet en local
############################################################

# Comment écrire un Parquet en local
arrow::write_parquet(
  df_full2,
  sink = "donnees_caisse.parquet"
)

# Comment écrire un Parquet partitionné en local
arrow::write_dataset(
  df_full2,
  path = "donnees_caisse/",
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
# Manipuler des données parquet en méthode lazy
############################################################

# Comment lire un fichier Parquet partitionné
data2 <- arrow::open_dataset(
  source = "donnees_caisse/",
  partitioning = schema(code_reg = arrow::utf8())
)

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


