# mc cp s3/projet-formation/diffusion/bceao/data_recensement_2017.csv formation-bceao/tp/data/data_recensement_2017.csv

library(ggplot2)
library(dplyr)
# Nous avons mis à votre disposition un jeu de données de 4Go provenant du recensement de la population. 
# Il ne s'agit pas à proprement parler de données massives, mais l'objectif est de retracer les différentes 
# étapes, souvent indispensables, lorsque l'on travaille avec des données massives en R.

############################################################
# Importation des données csv
############################################################

# Importation avec readr
t <- Sys.time()
df_readr <- readr::read_delim(
  "tp/data/data_recensement_2017.csv",
  delim = ";",
  col_types = readr::cols(COMMUNE = readr::col_character())
)
elapsed_readr <- as.numeric(difftime(Sys.time(), t, units = "secs"))

# Importation avec data.table
t <- Sys.time()
df_datatable <- data.table::fread(
  "tp/data/data_recensement_2017.csv",
  sep = ";",
  colClasses = c(
    COMMUNE = "character"
  ),
  data.table = FALSE
)
elapsed_datatable <- as.numeric(difftime(Sys.time(), t, units = "secs"))

# Importer avec arrow
t <- Sys.time()
df_arrow <- arrow::read_delim_arrow(
  "tp/data/data_recensement_2017.csv",
  delim = ";",
  col_types = arrow::schema(COMMUNE = arrow::utf8()),
  as_data_frame = TRUE
)
elapsed_arrow <- as.numeric(difftime(Sys.time(), t, units = "secs"))


performance <- dplyr::tibble(format_text = c("readr", "data.table", "arrow"),
                             elapse_time = round(c(elapsed_readr, elapsed_datatable, elapsed_arrow),3))


performance |> 
  dplyr::mutate(format_text = forcats::fct_reorder(format_text, elapse_time)) |> 
  ggplot(aes(format_text, elapse_time))+
  geom_col(fill = "lightblue", width=0.6)+
  geom_text(aes(label = glue::glue("{elapse_time} sec")), hjust = 1, nudge_x = 0.4, size = 4, fontface = "bold") +
  coord_flip()+
  labs(title = "Performances de l'importation d'un fichier CSV",
       subtitle ="entre readr, data.table et arrow",
       x = "",
       y = "Temps d'import en secondes")+
  theme_light()

############################################################
# Convertir des fichiers CSV en fichier Parquet
############################################################

# Ecriture d'un fichier parquet unique
arrow::write_parquet(df_arrow,
                    "tp/data/data_recensement_2017.parquet")

# Ecriture d'un dossier contenant des fichiers parquet partitionnés par la Région
arrow::write_dataset(df_arrow,
                     "tp/data/data_partitioned", 
                     format = "parquet",
                     partitioning = c("REGION"))

# Ecriture d'une base de données DuckDB à partir du parquet partitionné
data_arrow <- arrow::open_dataset("tp/data/data_partitioned")
con <- dbConnect(duckdb::duckdb(), dbdir="tp/data/data_recensement_2017.duckdb", read_only=FALSE)
arrow::to_duckdb(df_arrow, table_name = "RP2017", con = con)
dbSendQuery(con, "CREATE TABLE dataset AS SELECT * FROM RP2017")


disk_size <- fs::dir_info(here::here("tp", "data"), recurse = TRUE) |>
  filter(type == "file") |>
  mutate(name = basename(path)) |> 
  arrange(name) |>
  group_by(name) |> 
  summarise(total = sum(size)) |> 
  ungroup() |>
  mutate(name = case_when(
                          startsWith(name, "part-0") ~ "parquet partitionné",
                          TRUE ~ tools::file_ext(name)
                ),
  name = forcats::fct_reorder(name, total)
  ) 

disk_size |> 
  ggplot(aes(name, total)) +
  geom_col(fill = "lightblue", width=0.6)+
  geom_text(aes(label = glue::glue("{total}B")), hjust = 1, nudge_x = 0.4, size = 3.5, fontface = "bold") +
  coord_flip()+
  scale_y_continuous(labels = scales::label_bytes(units = "auto_si", accuracy = 1))+
  labs(title = "Taille sur le",
       subtitle ="entre CSV, Parquet, Parquet partitionné et DuckDB",
       x = "Format",
       y = "Size")+
  theme_light()

############################################################
# Manipulation des données parquet en mémoire
############################################################

# Importation du fichier parquet en mémoire 
data <- arrow::read_parquet(
  file = "tp/data/data_recensement_2017.parquet"
)

# On va calculer la part de logement de fortune pour chaque commune d'une région donnée
# Un logement de de fortune est caractérisé par la modalité 5 de la variable TYPL
t <- Sys.time()
data |> 
  # filter(REGION == "76") |>
  select(REGION, COMMUNE, TYPL) |> 
  group_by(COMMUNE) |>
  summarise(
    nb_logements_fortune = sum(TYPL == "5"),
    nb_logements_commune = n()
  ) |>
  mutate(
    part_logements_fortune = nb_logements_fortune / nb_logements_commune
  ) |>
  arrange(-part_logements_fortune)
elapsed_in_memory <- as.numeric(difftime(Sys.time(), t, units = "secs"))

############################################################
# Manipulation des données parquet en évalutaion "Lazy"
############################################################

# On importe le dataset en mode lazy
data_lazy <- arrow::open_dataset(
  source = "tp/data/data_partitioned",
  partitioning = arrow::schema(REGION = arrow::utf8()))

# Si les données ne sont pas directement accessible comme précédemment, certaines informations utiles peuvent
# toutefois être récupérées comme le schéma des données, la taille de la base de données et le nom des colonnes

data_lazy$schema
dim(data_lazy)
names(data_lazy)

# On reproduit le même calcul que précedemment. Pour cela on définit dans un premier temps la requête.
# L'execution est instantanée puisqu'aucun calcul n'a encore été réalisé
query <- data_lazy |> 
  # filter(REGION == "76") |>
  select(REGION, COMMUNE, TYPL) |> 
  group_by(COMMUNE) |>
  summarise(
    nb_logements_fortune = sum(TYPL %in% "5"),
    nb_logements_commune = n()
  ) |>
  mutate(
    part_logements_fortune = nb_logements_fortune / nb_logements_commune
  ) |> 
  arrange(-part_logements_fortune)


# Une fois la requête créée, il existe deux méthodes pour évaluer la requête (i.e. réaliser le calcul).

# La première est la méthode compute()
# Cette méthode execute la requête et renvoie les données au format d'objet Arrow
query |> compute()

# La seconde est la fonction collect()
# Cette méthode execute la requête et renvoie les données au format tibble
t <- Sys.time()
query |> collect()
elapsed_lazy <- as.numeric(difftime(Sys.time(), t, units = "secs"))


############################################################
# Manipulation depuis la base de données DuckDB
############################################################

con <- dbConnect(duckdb::duckdb(), dbdir="tp/data/data_recensement_2017.duckdb", read_only=TRUE)
dbListTables(con)
query_sql <- "SELECT
                COMMUNE,
                SUM(CASE WHEN TYPL = '5' THEN 1 ELSE 0 END) AS nb_logements_fortune,
                COUNT(*) AS nb_logements_commune,
                SUM(CASE WHEN TYPL = '5' THEN 1 ELSE 0 END) / COUNT(*) AS part_logements_fortune
              FROM
                dataset
              GROUP BY
                COMMUNE
              ORDER BY
                part_logements_fortune DESC;"

t <- Sys.time()
dbGetQuery(con, query_sql) |> as_tibble()
elapsed_duckdb <- as.numeric(difftime(Sys.time(), t, units = "secs"))
duckdb::dbDisconnect(con)

############################################################
# Evaluation de la performance
############################################################

performance <- dplyr::tibble(format_text = c("in memory", "arrow lazy", "duckDB"),
                             elapse_time = round(c(elapsed_in_memory, elapsed_lazy, elapsed_duckdb),3))


performance |> 
  dplyr::mutate(format_text = forcats::fct_reorder(format_text, elapse_time)) |> 
  ggplot(aes(format_text, elapse_time))+
  geom_col(fill = "lightblue", width=0.6)+
  geom_text(aes(label = glue::glue("{elapse_time} sec")), hjust = 1, nudge_x = 0.4, size = 4, fontface = "bold") +
  coord_flip()+
  labs(title = "Performances des requêtes",
       x = "",
       y = "Temps de calcul en secondes")+
  theme_light()


############################################################
# Accès au données depuis le Cloud
############################################################
# mc cp -r formation-bceao/tp/data/data_partitioned/ s3/projet-formation/diffusion/bceao/data_partitioned/


# On peut lister les fichiers présent dans le bucket
aws.s3::get_bucket("projet-formation", prefix = "diffusion/bceao", region = "")

# Lecture du dataset parquet directement depuis le cloud
data_cloud <- arrow::open_dataset(
  source = "tp/data/data_partitioned",
  partitioning = arrow::schema(REGION = arrow::utf8()))






