library(shiny)
library(shinymaterial)
library(dplyr)
library(readr)
library(ggplot2)
library(sf)
library(terra)
library(viridis)
library(leaflet)

# === Data Utils ===
# Normalize les codes des départements (ex: 1 -> 01, 75 -> 75)
# Ça permet de bien les matcher avec les fichiers géométriques
normalize_dept_code <- function(x) {
	x <- toupper(trimws(as.character(x)))
	idx_num <- grepl("^[0-9]+$", x)  # Trouve les nombres
	if (any(idx_num)) {
		num <- suppressWarnings(as.integer(x[idx_num]))
		# Ajoute un 0 devant si le nombre est < 100 (ex: 1 devient 01)
		x[idx_num] <- ifelse(num < 100, sprintf("%02d", num), as.character(num))
	}
	x
}

read_health_csv <- function(path) {
	# Définit les types des colonnes pour bien lire le CSV
	cols_def <- cols(
		quantite = col_character(),
		departement_code = col_character(),
		departement_nom = col_character(),
		effectif = col_number(),
		population_ref = col_number(),
		densite_per_100k = col_number()
	)
	
	# Essaie de lire avec read_csv2 (pour les CSV français avec ;)
	# Si ça marche pas, essaie avec read_csv
	d <- tryCatch({
		read_csv2(path, col_types = cols_def, show_col_types = FALSE)
	}, error = function(e) {
		read_csv(path, delim = ";", col_types = cols_def, show_col_types = FALSE)
	})
	
	# Nettoie et prépare les données
	d %>%
		mutate(
			departement_code = normalize_dept_code(departement_code),
			departement_nom = as.character(departement_nom),
			across(c(effectif, population_ref, densite_per_100k), ~na_if(., NA))
		)
}

data_professionnels <- read_health_csv("Donnees/donnees_professionnels.csv")
data_maladies <- read_health_csv("Donnees/donnees_maladies.csv")

# Groupe les professionnels en catégories plus larges
# (pour faire des analyses plus lisibles au lieu d'avoir 100 spécialités différentes)
add_professionnel_group <- function(d) {
	# Groupe les professionnels en catégories plus larges
	# Ça permet de faire des analyses lisibles au lieu d'avoir 100 spécialités différentes
	d %>%
		mutate(
			groupe_prof = dplyr::case_when(
				# 1. Médecine Générale et Omnipraticiens
				quantite %in% c(
					"Médecine générale",
					"Acupuncture et Médecine Générale",
					"Allergologie et Médecine Générale",
					"Angiologie et Médecine Générale",
					"Echotomographie et Médecine Générale",
					"Homéopathie et Médecine Générale",
					"Médecine d'urgence et Médecine Générale",
					"Médecine physique et Médecine Générale",
					"Phoniatrie et Médecine Générale",
					"Thermalisme et Médecine Générale",
					"SOS Médecins"
				) ~ "Médecine Générale et Omnipraticiens",

				# 2. Spécialités Chirurgicales
				quantite %in% c(
					"Chirurgie générale",
					"Chirurgie infantile",
					"Chirurgie viscérale et digestive",
					"Chirurgie orthopédique et traumatologie",
					"Chirurgie plastique reconstructrice et esthétique",
					"Chirurgie esthétique",
					"Chirurgie thoracique et cardio-vasculaire",
					"Chirurgie vasculaire",
					"Chirurgie urologique",
					"Chirurgie maxillo-faciale",
					"Chirurgie maxillo-faciale et stomatologie",
					"Neurochirurgie",
					"Anesthésie-réanimation",
					"Anesthésie-réanimation chirurgicale"
				) ~ "Spécialités Chirurgicales",

				# 3. Santé Buccodentaire
				quantite %in% c(
					"Chirurgie dentaire",
					"Chirurgiens-dentistes",
					"Chirurgiens-dentistes, spécialistes O.D.F.",
					"Orthodontie",
					"Orthopédie dento-faciale exclusive",
					"Médecine bucco-dentaire",
					"Chirurgie orale",
					"Stomatologie"
				) ~ "Santé Buccodentaire",

				# 4. Spécialités Médicales Organiques
				quantite %in% c(
					"Cardiologie",
					"Pathologie cardio-vasculaire",
					"Angiologie",
					"Phlébologie",
					"Médecine vasculaire",
					"Gastro-entérologie",
					"Gastro-entérologie et hépatologie",
					"Proctologie",
					"Pneumologie",
					"Pneumo-phtisiologie",
					"Neurologie",
					"Electroencéphalographie et électromyographie",
					"Néphrologie",
					"Endocrinologie et métabolisme",
					"Maladie du diabète et de la nutrition, diététique",
					"Dermato-vénéréologie",
					"Dermatologie et maladies vénériennes",
					"Rhumatologie",
					"Orthopédie"
				) ~ "Spécialités Médicales Organiques",

				# 5. Santé des Femmes, des Enfants et Reproduction
				quantite %in% c(
					"Gynécologie",
					"Gynécologie médicale",
					"Gynécologie obstétrique",
					"Gynécologie obstétrique et gynécologie médicale",
					"Obstétrique",
					"Sages-femmes",
					"Pédiatrie",
					"Stérilité",
					"Sexologie"
				) ~ "Santé des Femmes, des Enfants et Reproduction",

				# 6. Oncologie et Pathologie
				quantite %in% c(
					"Oncologie médicale",
					"Oncologie radiothérapique",
					"Radiothérapie",
					"Carcinologie",
					"Anatomo-cyto-pathologie"
				) ~ "Oncologie et Pathologie",

				# 7. Imagerie et Diagnostic Biologique
				quantite %in% c(
					"Radiodiagnostic et imagerie médicale",
					"Electroradiologie",
					"Echotomographie",
					"Médecine nucléaire",
					"Biologie",
					"Médecins biologistes",
					"Laboratoires",
					"Laboratoires polyvalents",
					"Laboratoires d'anatomo-cyto-pathologie"
				) ~ "Imagerie et Diagnostic Biologique",

				# 8. Rééducation et Paramédical
				quantite %in% c(
					"Masseurs-kinésithérapeutes-rééducateurs",
					"Médecine Physique et de Réadaptation",
					"Médecine physique",
					"Infirmiers",
					"Infirmiers de pratiques avancées",
					"Orthophonistes",
					"Orthoptistes",
					"Audiométrie",
					"Phoniatrie",
					"Pédicures",
					"Podologie",
					"Réanimation médicale"
				) ~ "Rééducation et Paramédical",

				# 9. Santé Mentale
				quantite %in% c(
					"Psychiatrie",
					"Psychothérapie",
					"Psychanalyse",
					"Médecine psychosomatique"
				) ~ "Santé Mentale",

				# 10. Autres Orientations et Médecines Spécialisées
				quantite %in% c(
					"Acupuncture",
					"Homéopathie",
					"Thermalisme (hydrologie, cures climatiques)",
					"Vertébrothérapie, chiropraxie",
					"Médecine légale et expertises médicales",
					"Médecine Légale",
					"Médecine génétique",
					"Immunologie",
					"Hématologie",
					"Maladies infectieuses et tropicales",
					"Médecine exotique",
					"Médecine d'urgence",
					"Gériatrie",
					"Médecine interne",
					"Allergologie",
					"M.E.P."
				) ~ "Autres Orientations et Médecines Spécialisées",

				TRUE ~ "Autres"
			)
		)
}

data_professionnels <- add_professionnel_group(data_professionnels)

add_maladie_group <- function(d) {
	# Groupe aussi les maladies pour simplifier la visualisation
	d %>%
		mutate(
			groupe = dplyr::case_when(
				# Cardio-vasculaire
				quantite %in% c(
					"Accident vasculaire cérébral invalidant (ALD1)",
					"Artériopathies chroniques avec manifestations ischémiques (ALD3)",
					"Insuffisance cardiaque grave, troubles du rythme graves, cardiopathies valvulaires graves, cardiopathies congénitales graves (ALD5)",
					"Hypertension artérielle sévère (ALD12)",
					"Maladie coronaire (ALD13)"
				) ~ "Cardio-vasculaire",

				# Neurologie
				quantite %in% c(
					"Formes graves des affections neurologiques et musculaires (dont myopathie), épilepsie grave (ALD9)",
					"Maladie d'Alzheimer et autres démences (ALD15)",
					"Maladie de Parkinson (ALD16)",
					"Paraplégie (ALD20)",
					"Sclérose en plaques (ALD25)"
				) ~ "Neurologie",

				# Psychiatrique
				quantite %in% c(
					"Affections psychiatriques de longue durée (ALD23)"
				) ~ "Psychiatrie",

				# Endocrino / métabolique
				quantite %in% c(
					"Diabète de type 1 et diabète de type 2 (ALD8)",
					"Maladies métaboliques héréditaires nécessitant un traitement prolongé spécialisé (ALD17)"
				) ~ "Endocrinologie et Métabolisme",

				# Respiratoire
				quantite %in% c(
					"Insuffisance respiratoire chronique grave (ALD14)",
					"Mucoviscidose (ALD18)"
				) ~ "Pneumologie",

				# Digestif
				quantite %in% c(
					"Maladies chroniques actives du foie et cirrhoses (ALD6)",
					"Rectocolite hémorragique et maladie de Crohn évolutives (ALD24)"
				) ~ "Gastro-entérologie",

				# Néphro
				quantite %in% c(
					"Néphropathie chronique grave et syndrome néphrotique primitif (ALD19)"
				) ~ "Néphrologie",

				# Hématologie
				quantite %in% c(
					"Insuffisances médullaires et autres cytopénies chroniques (ALD2)",
					"Hémoglobinopathies, hémolyses, chroniques constitutionnelles et acquises sévères (ALD10)",
					"Hémophilies et affections constitutionnelles de l'hémostase graves (ALD11)"
				) ~ "Hématologie",

				# Rhumato / auto-immun
				quantite %in% c(
					"Vascularites, lupus érythémateux systémique, sclérodermie systémique (ALD21)",
					"Polyarthrite rhumatoïde évolutive (ALD22)",
					"Spondylarthrite grave (ALD27)"
				) ~ "Rhumatologie et maladies auto-immunes",

				# Infectieux
				quantite %in% c(
					"Bilharziose compliquée (ALD4)",
					"Déficit immunitaire primitif grave nécessitant un traitement prolongé, infection par le virus de l'immuno-déficience humaine (VIH) (ALD7)",
					"Tuberculose active, lèpre (ALD29)"
				) ~ "Maladies infectieuses",

				# Orthopédie / rachis
				quantite %in% c(
					"Scoliose idiopathique structurale évolutive (dont l'angle est égal ou supérieur à 25 degrés) jusqu'à maturation rachidienne (ALD26)"
				) ~ "Orthopédie",

				# Transplantation
				quantite %in% c(
					"Suites de transplantation d'organe (ALD28)"
				) ~ "Transplantation",

				# Cancer
				quantite %in% c(
					"Tumeur maligne, affection maligne du tissu lymphatique ou hématopoïétique (ALD30)"
				) ~ "Oncologie",

				TRUE ~ "Autres"
			)
		)
}

data_maladies <- add_maladie_group(data_maladies)

order_ald <- function(labels) {
	ald_num <- suppressWarnings(as.integer(sub(".*\\(ALD([0-9]+)\\).*", "\\1", labels)))
	labels[order(ald_num, labels, na.last = TRUE)]
}

# ---------- Geometries ----------
load_gadm_sf <- function(path) {
	x <- readRDS(path)
	if (!inherits(x, "SpatVector")) {
		x <- terra::unwrap(x)
	}
	st_as_sf(x)
}

place_geometry <- function(geometry, position, scale = 1) {
	centroid <- st_centroid(geometry)
	out <- (geometry - centroid) * scale + centroid + position
	st_crs(out) <- st_crs(geometry)
	out
}

fra <- load_gadm_sf("gadm_cache/gadm/gadm41_FRA_2_pk.rds") %>%
	transmute(
		departement_code = as.character(CC_2),
		departement_nom = as.character(NAME_2),
		geometry = geometry
	)

dom_specs <- tibble::tribble(
	~code, ~nom, ~file,
	"971", "Guadeloupe", "gadm_cache/gadm/gadm41_GLP_0_pk.rds",
	"972", "Martinique", "gadm_cache/gadm/gadm41_MTQ_0_pk.rds",
	"973", "Guyane", "gadm_cache/gadm/gadm41_GUF_0_pk.rds",
	"974", "Réunion", "gadm_cache/gadm/gadm41_REU_0_pk.rds",
	"976", "Mayotte", "gadm_cache/gadm/gadm41_MYT_0_pk.rds"
)

dom_list <- lapply(seq_len(nrow(dom_specs)), function(i) {
	x <- load_gadm_sf(dom_specs$file[i])
	x %>%
		transmute(
			departement_code = dom_specs$code[i],
			departement_nom = dom_specs$nom[i],
			geometry = geometry
		)
})
names(dom_list) <- c("glp", "mtq", "guy", "reu", "myt")

# Projection commune pour la carte
fra <- st_transform(fra, 3857)
dom_list <- lapply(dom_list, st_transform, crs = 3857)

# Repositionnement DOM (methode inspirée de l'exemple partage)
fra_bbox <- st_bbox(fra)

mtq_pos <- c(fra_bbox["xmin"] - st_bbox(dom_list$mtq)["xmin"] - 170000,
						 fra_bbox["ymin"] - st_bbox(dom_list$mtq)["ymin"] + 120000)
dom_list$mtq$geometry <- place_geometry(st_geometry(dom_list$mtq), mtq_pos, scale = 2.3)

glp_pos <- c(fra_bbox["xmin"] - st_bbox(dom_list$glp)["xmin"] - 170000,
						 st_bbox(dom_list$mtq)["ymax"] - st_bbox(dom_list$glp)["ymin"] + 180000)
dom_list$glp$geometry <- place_geometry(st_geometry(dom_list$glp), glp_pos, scale = 2.3)

reu_pos <- c(fra_bbox["xmin"] - st_bbox(dom_list$reu)["xmin"] - 170000,
						 st_bbox(dom_list$glp)["ymax"] - st_bbox(dom_list$reu)["ymin"] + 180000)
dom_list$reu$geometry <- place_geometry(st_geometry(dom_list$reu), reu_pos, scale = 2.3)

myt_pos <- c(fra_bbox["xmin"] - st_bbox(dom_list$myt)["xmin"] - 170000,
						 st_bbox(dom_list$reu)["ymax"] - st_bbox(dom_list$myt)["ymin"] + 180000)
dom_list$myt$geometry <- place_geometry(st_geometry(dom_list$myt), myt_pos, scale = 2.5)

guy_pos <- c(fra_bbox["xmin"] - st_bbox(dom_list$guy)["xmin"] - 280000,
						 st_bbox(dom_list$myt)["ymax"] - st_bbox(dom_list$guy)["ymin"] + 90000)
dom_list$guy$geometry <- place_geometry(st_geometry(dom_list$guy), guy_pos, scale = 0.5)

map_sf <- bind_rows(fra, dom_list$mtq, dom_list$glp, dom_list$reu, dom_list$myt, dom_list$guy)
map_sf_leaflet <- st_transform(map_sf, 4326)
dom_codes <- c("971", "972", "973", "974", "976")

pro_quantites <- sort(unique(data_professionnels$quantite))
pro_groupes <- sort(unique(data_professionnels$groupe_prof))
maladie_quantites <- order_ald(unique(data_maladies$quantite))
maladie_groupes <- sort(unique(data_maladies$groupe))

quality_df <- dplyr::bind_rows(
	tibble::tibble(
		source = "Professionnels",
		n_lignes = nrow(data_professionnels),
		n_variables = dplyr::n_distinct(data_professionnels$quantite),
		n_departements = dplyr::n_distinct(data_professionnels$departement_code),
		missing_effectif = sum(is.na(data_professionnels$effectif)),
		missing_population = sum(is.na(data_professionnels$population_ref)),
		doublons_quantite_dept = data_professionnels %>% count(quantite, departement_code) %>% filter(n > 1) %>% nrow()
	),
	tibble::tibble(
		source = "Maladies",
		n_lignes = nrow(data_maladies),
		n_variables = dplyr::n_distinct(data_maladies$quantite),
		n_departements = dplyr::n_distinct(data_maladies$departement_code),
		missing_effectif = sum(is.na(data_maladies$effectif)),
		missing_population = sum(is.na(data_maladies$population_ref)),
		doublons_quantite_dept = data_maladies %>% count(quantite, departement_code) %>% filter(n > 1) %>% nrow()
	)
)

# Crée une matrice pour les analyses (AFC/CAH)
# Chaque ligne = un département, chaque colonne = un groupe
# Les valeurs = somme des effectifs
build_analysis_matrix <- function(d, group_col) {
	agg <- d %>%
		group_by(departement_code, .data[[group_col]]) %>%
		summarise(effectif = sum(effectif, na.rm = TRUE), .groups = "drop")

	agg$groupe_tmp <- agg[[group_col]]
	# xtabs crée une tableau de contingence (c'est une matrice)
	mat <- xtabs(effectif ~ departement_code + groupe_tmp, data = agg)
	as.matrix(mat)
}

# Affiche un message quand y'a pas de données à tracer
plot_empty <- function(msg) {
	plot.new()
	text(0.5, 0.5, msg, cex = 1.1)
}

ui <- material_page(
	title = "SAE Reporting - Application",
	nav_bar_fixed = TRUE,
	include_icons = TRUE,
	tags$head(tags$style(HTML("
		.side-nav li > a {
			color: #ffffff !important;
		}
		.side-nav li.active > a {
			color: #ffffff !important;
			font-weight: 600 !important;
			border-left: 3px solid #ffcdd2;
		}
		.side-nav li > a i.material-icons {
			color: rgba(255,255,255,0.8) !important;
		}
		.side-nav li.active > a i.material-icons {
			color: #ffcdd2 !important;
		}
	"))),
	material_side_nav(
		fixed = TRUE,
		background_color = "#fa4b4b",
		material_side_nav_tabs(
			side_nav_tabs = c(
				"Professionnels" = "tab_prof",
				"Maladies"       = "tab_mal",
				"Analyse"        = "tab_analyse",
				"Synth\u00e8se"  = "tab_synth",
				"Qualit\u00e9"   = "tab_qual"
			),
			icons = c("local_hospital", "healing", "analytics", "bar_chart", "rule"),
			color = "red lighten-4"
		)
	),

	material_side_nav_tab_content(
		side_nav_tab_id = "tab_prof",
		material_row(
			material_column(
				width = 3,
				material_card(
					title = "Filtres Professionnels",
					uiOutput("quantite_ui"),
					material_radio_button("mode_prof", "Niveau de lecture", choices = c("Détail" = "detail", "Groupe" = "groupe"), selected = "detail"),
					material_radio_button("metric", "Indicateur", choices = c("Effectif" = "effectif", "Densité / 100k" = "densite_per_100k"), selected = "effectif"),
					br()
				)
			),
			material_column(
				width = 9,
				material_card(
					title = "Carte Professionnels",
					leafletOutput("map_leaflet", height = "700px")
				),
				material_card(
					title = "Tableau",
					div(
						style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
						h5("Données filtrées"),
						downloadButton("download_data_prof", "Télécharger CSV", class = "btn-sm")
					),
					tableOutput("data_table")
				)
			)
		)
	),

	material_side_nav_tab_content(
		side_nav_tab_id = "tab_mal",
		material_row(
			material_column(
				width = 3,
				material_card(
					title = "Filtres Maladies",
					uiOutput("quantite_maladie_ui"),
					material_radio_button("mode_maladie", "Niveau de lecture", choices = c("ALD" = "ald", "Groupe" = "groupe"), selected = "ald"),
					material_radio_button("metric_maladie", "Indicateur", choices = c("Effectif" = "effectif", "Densité / 100k" = "densite_per_100k"), selected = "effectif"),
					br()
				)
			),
			material_column(
				width = 9,
				material_card(
					title = "Carte Maladies",
					verbatimTextOutput("maladies_info"),
					leafletOutput("map_maladies", height = "700px")
				),
				material_card(
					title = "Tableau",
					div(
						style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
						h5("Données filtrées"),
						downloadButton("download_data_mal", "Télécharger CSV", class = "btn-sm")
					),
					tableOutput("table_maladies")
				)
			)
		)
	),

	material_side_nav_tab_content(
		side_nav_tab_id = "tab_analyse",
		material_row(
			material_column(
				width = 3,
				material_card(
					title = "Paramètres Analyse",
					material_dropdown(
						"analyse_source",
						"Source",
						choices = c("Professionnels" = "prof", "Maladies" = "mal"),
						selected = "prof"
					),
					material_radio_button(
						"analyse_methode",
						"Méthode",
						choices = c("AFC" = "afc", "CAH" = "cah"),
						selected = "afc"
					),
					material_slider(
						"analyse_k",
						"Nombre de classes (CAH)",
						min_value = 2,
						max_value = 8,
						initial_value = 4,
						step_size = 1
					),
					br()
				)
			),
			material_column(
				width = 9,
				material_card(
					title = "Résumé méthode",
					verbatimTextOutput("analyse_info")
				),
				material_card(
					title = "Graphique principal",
					plotOutput("analyse_plot_main", height = "350px")
				),
				material_card(
					title = "Graphique secondaire",
					plotOutput("analyse_plot_secondary", height = "350px")
				),
				material_card(
					title = "Profils de classes",
					tableOutput("analyse_table")
				)
			)
		)
	),

	material_side_nav_tab_content(
		side_nav_tab_id = "tab_synth",
		material_row(
			material_column(
				width = 3,
				material_card(
					title = "Paramètres Synthèse",
					material_dropdown("synth_source", "Source", choices = c("Professionnels" = "prof", "Maladies" = "mal"), selected = "prof"),
					uiOutput("synth_variable_ui"),
					material_radio_button("synth_metric", "Indicateur", choices = c("Effectif" = "effectif", "Densité / 100k" = "densite_per_100k"), selected = "effectif"),
					material_radio_button("synth_individus", "Individus", choices = c("Tous les départements" = "all", "Hexagone" = "hex", "DOM uniquement" = "dom"), selected = "all"),
					material_slider("synth_top_n", "Top N", min_value = 3, max_value = 20, initial_value = 10, step_size = 1),
					checkboxGroupInput(
						"synth_graphs",
						"Graphiques à afficher",
						choices = c(
							"Top catégories" = "top",
							"Top départements" = "dept"
						),
						selected = c("top", "dept")
					)
				)
			),
			material_column(
				width = 9,
				material_card(
					title = "Aide à la lecture",
					verbatimTextOutput("synth_help")
				),
				material_card(
					title = "Top catégories",
					plotOutput("plot_top_categories", height = "300px")
				),
				material_card(
					title = "Top départements",
					plotOutput("plot_top_departements", height = "300px")
				)
			)
		)
	),

	material_side_nav_tab_content(
		side_nav_tab_id = "tab_qual",
		material_card(
			title = "Panneau Qualité des données",
			p("Contrôle rapide des sources chargées dans l'application."),
			tableOutput("quality_table")
		)
	)
)

server <- function(input, output, session) {
	# ====== PARTIE ANALYSE ======
	# Choisit la source données selon ce que l'user sélectionne
	analyse_input <- reactive({
		if (identical(input$analyse_source, "mal")) {
			list(d = data_maladies, group_col = "groupe", source_label = "Maladies")
		} else {
			list(d = data_professionnels, group_col = "groupe_prof", source_label = "Professionnels")
		}
	})

	# Crée la matrice pour l'analyse (département x groupe)
	analyse_matrix <- reactive({
		x <- analyse_input()
		build_analysis_matrix(x$d, x$group_col)
	})

	# AFC = Analyse Factorielle des Correspondances
	# C'est une methode pour explorer les relations entre lignes et colonnes
	analyse_afc <- reactive({
		if (!requireNamespace("FactoMineR", quietly = TRUE)) {
			return(NULL)
		}
		mat <- analyse_matrix()
		if (nrow(mat) < 2 || ncol(mat) < 2) {
			return(NULL)
		}
		# Divise par le total pour avoir des proportions (normée de 0 à 1)
		prop <- prop.table(mat, margin = 1)
		# Fait l'AFC sur les proportions
		FactoMineR::CA(prop, graph = FALSE)
	})

	# CAH = Classification Ascendante Hierarchique (clustering)
	# Regroupe les départements qui se ressemblent  
	analyse_cah <- reactive({
		mat <- analyse_matrix()
		if (nrow(mat) < 3 || ncol(mat) < 2) {
			return(NULL)
		}
		# Scale = centre et réduit les données (les met à l'échelle)
		X <- scale(mat)
		X[is.na(X)] <- 0
		# Calcule la distance entre tous les départements
		d <- dist(X)
		# Regroupe les plus proches (méthode Ward)
		hc <- hclust(d, method = "ward.D2")
		# Coupe l'arbre pour avoir k classes
		k <- max(2, min(input$analyse_k, nrow(mat) - 1))
		cl <- cutree(hc, k = k)
		list(hc = hc, cl = cl, mat = mat, X = X)
	})

	output$analyse_info <- renderText({
		x <- analyse_input()
		if (identical(input$analyse_methode, "afc")) {
			if (!requireNamespace("FactoMineR", quietly = TRUE)) {
				return("AFC indisponible: package FactoMineR non installé.")
			}
			res <- analyse_afc()
			if (is.null(res)) {
				return("AFC indisponible: matrice insuffisante (au moins 2 départements x 2 groupes).")
			}
			paste0(
				"Source: ", x$source_label,
				" | Méthode: AFC (sur profils lignes)\n",
				"Dimensions: ", nrow(analyse_matrix()), " départements x ", ncol(analyse_matrix()), " groupes\n",
				"Inertie axe 1: ", round(res$eig[1, 2], 2), "% | axe 2: ", round(res$eig[2, 2], 2), "%"
			)
		} else {
			res <- analyse_cah()
			if (is.null(res)) {
				return("CAH indisponible: matrice insuffisante pour classifier.")
			}
			tab_cl <- table(res$cl)
			paste0(
				"Source: ", x$source_label,
				" | Méthode: CAH (Ward sur données centrées-réduites)\n",
				"Nombre de classes: ", length(tab_cl),
				" | Tailles: ", paste(tab_cl, collapse = " / ")
			)
		}
	})

	output$analyse_plot_main <- renderPlot({
		if (identical(input$analyse_methode, "afc")) {
			res <- analyse_afc()
			if (is.null(res)) {
				plot_empty("AFC non disponible")
				return(invisible())
			}
			barplot(
				res$eig[, 2],
				main = "AFC - Inertie par axe",
				ylab = "Inertie (%)",
				col = "#ef5350",
				border = NA
			)
		} else {
			res <- analyse_cah()
			if (is.null(res)) {
				plot_empty("CAH non disponible")
				return(invisible())
			}
			plot(
				res$hc,
				labels = FALSE,
				hang = -1,
				main = "CAH - Dendrogramme (Ward)",
				xlab = "Départements",
				sub = ""
			)
			rect.hclust(res$hc, k = length(unique(res$cl)), border = "#1e88e5")
		}
	})

	output$analyse_plot_secondary <- renderPlot({
		if (identical(input$analyse_methode, "afc")) {
			res <- analyse_afc()
			if (is.null(res)) {
				plot_empty("AFC non disponible")
				return(invisible())
			}
			plot(
				res$row$coord[, 1],
				res$row$coord[, 2],
				pch = 16,
				col = "#1565c0",
				xlab = "Axe 1",
				ylab = "Axe 2",
				main = "AFC - Carte des départements"
			)
			abline(h = 0, v = 0, col = "grey70", lty = 2)
			text(
				res$row$coord[, 1],
				res$row$coord[, 2],
				labels = rownames(res$row$coord),
				cex = 0.65,
				adj = c(-0.3, -0.3),
				col = "#1565c0"
			)
		} else {
			res <- analyse_cah()
			if (is.null(res)) {
				plot_empty("CAH non disponible")
				return(invisible())
			}
			pc <- prcomp(res$X, center = FALSE, scale. = FALSE)
			plot(
				pc$x[, 1],
				pc$x[, 2],
				col = res$cl,
				pch = 16,
				xlab = "Composante 1",
				ylab = "Composante 2",
				main = "CAH - Projection PCA colorée par classe"
			)
			legend("topright", legend = paste("Classe", sort(unique(res$cl))), col = sort(unique(res$cl)), pch = 16, cex = 0.85)
		}
	})

	output$analyse_table <- renderTable({
		if (!identical(input$analyse_methode, "cah")) {
			return(data.frame(Message = "Le tableau des profils est disponible en mode CAH."))
		}
		res <- analyse_cah()
		if (is.null(res)) {
			return(data.frame(Message = "CAH non disponible avec les données actuelles."))
		}

		mat_df <- as.data.frame(res$mat)
		mat_df$classe <- as.factor(res$cl[rownames(mat_df)])
		profils <- mat_df %>%
			group_by(classe) %>%
			summarise(across(where(is.numeric), ~ round(mean(.x, na.rm = TRUE), 1)), .groups = "drop")

		profils
	}, striped = TRUE, bordered = TRUE, hover = TRUE)

	output$quantite_ui <- renderUI({
		# Crée un dropdown qui change selon le mode (détail ou groupe)
		if (identical(input$mode_prof, "groupe")) {
			selectInput("quantite", "Groupe", choices = pro_groupes, selected = pro_groupes[1])
		} else {
			selectInput("quantite", "Spécialité", choices = pro_quantites, selected = pro_quantites[1])
		}
	})

	output$quantite_maladie_ui <- renderUI({
		# Même chose pour les maladies
		if (identical(input$mode_maladie, "groupe")) {
			selectInput("quantite_maladie", "Groupe", choices = maladie_groupes, selected = maladie_groupes[1])
		} else {
			selectInput("quantite_maladie", "ALD", choices = maladie_quantites, selected = maladie_quantites[1])
		}
	})

	output$synth_variable_ui <- renderUI({
		# Liste des variables disponibles pour faire le top
		if (identical(input$synth_source, "mal")) {
			selectInput("synth_variable", "Variable", choices = c("ALD" = "quantite", "Groupe" = "groupe"), selected = "quantite")
		} else {
			selectInput("synth_variable", "Variable", choices = c("Profession" = "quantite", "Groupe" = "groupe_prof"), selected = "quantite")
		}
	})

	# Affiche un résumé de ce qu'on affiche (juste pour info)
	output$synth_help <- renderText({
		req(input$synth_source, input$synth_variable, input$synth_metric, input$synth_individus)
		source_label <- if (identical(input$synth_source, "mal")) "Maladies" else "Professionnels"
		variable_label <- if (identical(input$synth_variable, "quantite")) {
			if (identical(input$synth_source, "mal")) "ALD" else "Profession"
		} else {
			"Groupe"
		}
		paste0(
			"Source: ", source_label,
			" | Variable: ", variable_label,
			" | Indicateur: ", ifelse(input$synth_metric == "effectif", "Effectif", "Densité / 100k"),
			" | Individus: ",
			ifelse(input$synth_individus == "all", "Tous", ifelse(input$synth_individus == "hex", "Hexagone", "DOM"))
		)
	})

	# Filtre les données selon ce que l'utilisateur a choisi
	# req() vérifie que les inputs sont disponibles avant de continuer
	synth_data <- reactive({
		req(input$synth_source, input$synth_individus)
		d <- if (identical(input$synth_source, "mal")) data_maladies else data_professionnels
		
		# Filtre par région si l'utilisateur demande hexagone ou DOM uniquement
		if (identical(input$synth_individus, "hex")) {
			d <- d %>% filter(!departement_code %in% DOM_CODES)
		} else if (identical(input$synth_individus, "dom")) {
			d <- d %>% filter(departement_code %in% DOM_CODES)
		}
		d
	})

	# Calcule les top catégories (un réactive = plus rapide)
	# Regroupe par catégorie, fait la somme, trie et prend les N premiers
	top_categories_data <- reactive({
		req(input$synth_variable, input$synth_metric, input$synth_top_n)
		synth_data() %>%
			group_by(.data[[input$synth_variable]]) %>%
			summarise(valeur = sum(.data[[input$synth_metric]], na.rm = TRUE), .groups = "drop") %>%
			arrange(desc(valeur)) %>%
			head(input$synth_top_n) %>%
			mutate(libelle = .data[[input$synth_variable]])
	})

	# Même chose mais pour les départements
	top_departements_data <- reactive({
		req(input$synth_metric, input$synth_top_n)
		synth_data() %>%
			group_by(departement_code, departement_nom) %>%
			summarise(valeur = sum(.data[[input$synth_metric]], na.rm = TRUE), .groups = "drop") %>%
			arrange(desc(valeur)) %>%
			head(input$synth_top_n) %>%
			mutate(libelle = paste0(departement_code, " - ", departement_nom))
	})

	# Affiche les top catégories en barres horizontales
	output$plot_top_categories <- renderPlot({
		req(input$synth_graphs, "top" %in% input$synth_graphs)  # Affiche que si coché
		top_df <- top_categories_data()
		if (nrow(top_df) == 0) {
			plot_empty("Aucune donnée disponible")
			return(invisible())
		}

		ggplot(top_df, aes(x = reorder(libelle, valeur), y = valeur, fill = valeur)) +
			geom_col() +
			scale_fill_viridis_c(option = "plasma", guide = "none") +
			coord_flip() +
			labs(
				title = "Top catégories",
				x = "Catégorie",
				y = ifelse(input$synth_metric == "effectif", "Effectif", "Densité / 100k"),
				caption = "Source: Données"
			) +
			theme_light(base_size = 11) +
			theme(
				plot.title = element_text(face = "bold", size = 12),
				panel.grid.major.y = element_blank(),
				panel.grid.minor = element_blank()
			)
	})

	output$plot_top_departements <- renderPlot({
		req(input$synth_graphs, "dept" %in% input$synth_graphs)
		
		dept_df <- top_departements_data()
		if (nrow(dept_df) == 0) {
			plot_empty("Aucune donnée disponible")
			return(invisible())
		}

		ggplot(dept_df, aes(x = reorder(libelle, valeur), y = valeur, fill = valeur)) +
			geom_col() +
			scale_fill_viridis_c(option = "magma", guide = "none") +
			coord_flip() +
			labs(
				title = "Top départements",
				x = "Département",
				y = ifelse(input$synth_metric == "effectif", "Effectif", "Densité / 100k"),
				caption = "Source: Données"
			) +
			theme_light(base_size = 11) +
			theme(
				plot.title = element_text(face = "bold", size = 12),
				panel.grid.major.y = element_blank(),
				panel.grid.minor = element_blank()
			)
	})

	# Filtre les données pros selon ce que l'user sélectionne
	filtered <- reactive({
		req(input$quantite)  # Attend que l'user choisisse quelque chose
		if (identical(input$mode_prof, "groupe")) {
			# Mode groupe: regroupe tous les détails d'un groupe par département
			data_professionnels %>%
				filter(groupe_prof == input$quantite) %>%
				group_by(departement_code, departement_nom, groupe_prof) %>%
				summarise(
					effectif = sum(effectif, na.rm = TRUE),
					population_ref = max(population_ref, na.rm = TRUE),
					quantite = first(groupe_prof),
					.groups = "drop"
				) %>%
				mutate(densite_per_100k = ifelse(population_ref > 0, effectif / population_ref * 100000, NA_real_))
		} else {
			# Mode détail: montre chaque type exactement comme dans les données
			data_professionnels %>%
				filter(quantite == input$quantite)
		}
	})

	# Joint les données filtrées avec la géométrie pour la carte
	# left_join garde tous les départements, même s'il y a pas de données
	map_data_leaflet <- reactive({
		map_sf_leaflet %>%
			left_join(
				filtered() %>% select(departement_code, quantite, effectif, population_ref, densite_per_100k),
				by = "departement_code"
			)
	})

	# Filtre les données maladies (même logique que filtered())
	filtered_maladies <- reactive({
		req(input$quantite_maladie)
		if (identical(input$mode_maladie, "groupe")) {
			# Regroupe par groupe de maladie
			data_maladies %>%
				filter(groupe == input$quantite_maladie) %>%
				group_by(departement_code, departement_nom, groupe) %>%
				summarise(
					effectif = sum(effectif, na.rm = TRUE),
					population_ref = max(population_ref, na.rm = TRUE),
					quantite = first(groupe),
					.groups = "drop"
				) %>%
				mutate(densite_per_100k = ifelse(population_ref > 0, effectif / population_ref * 100000, NA_real_))
		} else {
			# Mode ALD: montre les ALD en détail
			data_maladies %>%
				filter(quantite == input$quantite_maladie)
		}
	})

	# Joint les données maladies filtrées avec la géométrie
	map_data_maladies <- reactive({
		dat <- map_sf_leaflet
		fm <- filtered_maladies()

		dat %>%
			left_join(
				fm %>% select(departement_code, quantite, effectif, population_ref, densite_per_100k),
				by = "departement_code"
			)
	})

	# Crée la carte interactive des professionnels
	output$map_leaflet <- renderLeaflet({
		metric_col <- input$metric  # L'indicateur choisi (effectif ou densité)
		dat <- map_data_leaflet()
		dat$map_value <- dat[[metric_col]]  # Ajoute une colonne avec la valeur
		vals <- dat$map_value

		# Crée l'échelle de couleurs (gradient)
		pal <- colorNumeric(
			palette = viridisLite::viridis(8, option = "C"),
			domain = vals,
			na.color = "#d9d9d9"
		)

		m <- leaflet(dat) %>%
			addProviderTiles(providers$CartoDB.Positron) %>%
			addPolygons(
				fillColor = ~pal(map_value),
				fillOpacity = 0.85,
				color = "white",
				weight = 1,
				opacity = 1,
				highlightOptions = highlightOptions(weight = 2, color = "#333", bringToFront = TRUE),
				popup = ~paste0(
					"<b>", departement_nom, " (", departement_code, ")</b><br/>",
					"Specialite: ", quantite, "<br/>",
					"Effectif: ", effectif, "<br/>",
					"Densite / 100k: ", round(densite_per_100k, 2)
				)
			) %>%
			addLegend(
				pal = pal,
				values = vals,
				title = ifelse(metric_col == "effectif", "Effectif", "Densite / 100k"),
				opacity = 0.9,
				position = "bottomright"
			)

		dom_labels <- dat %>%
			filter(departement_code %in% dom_codes) %>%
			st_point_on_surface() %>%
			st_coordinates() %>%
			as.data.frame() %>%
			bind_cols(dat %>% filter(departement_code %in% dom_codes) %>% st_drop_geometry())

		m <- m %>%
			addLabelOnlyMarkers(
				lng = dom_labels$X,
				lat = dom_labels$Y,
				label = dom_labels$departement_nom,
				labelOptions = labelOptions(noHide = TRUE, textOnly = TRUE, direction = "right", style = list("font-size" = "11px", "font-weight" = "bold"))
			)

		m
	})

	output$maladies_info <- renderText({
		if (identical(input$mode_maladie, "groupe")) {
			paste("Mode groupe | groupes disponibles:", length(maladie_groupes), "| groupe selectionne:", input$quantite_maladie)
		} else {
			paste("Mode ALD | ALD disponibles:", length(maladie_quantites), "| ALD selectionnee:", input$quantite_maladie)
		}
	})

	output$map_maladies <- renderLeaflet({
		metric_col <- input$metric_maladie
		dat <- map_data_maladies()
		dat$map_value <- dat[[metric_col]]
		vals <- dat$map_value

		pal <- colorNumeric(
			palette = viridisLite::viridis(8, option = "B"),
			domain = vals,
			na.color = "#e5e5e5"
		)

		m <- leaflet(dat) %>%
			addProviderTiles(providers$CartoDB.Positron) %>%
			addPolygons(
				fillColor = ~pal(map_value),
				fillOpacity = 0.85,
				color = "white",
				weight = 1,
				opacity = 1,
				highlightOptions = highlightOptions(weight = 2, color = "#333", bringToFront = TRUE),
				popup = ~paste0(
					"<b>", departement_nom, " (", departement_code, ")</b><br/>",
					"Variable: ", ifelse(is.na(quantite), "non disponible", quantite), "<br/>",
					"Effectif: ", ifelse(is.na(effectif), "NA", effectif), "<br/>",
					"Densite / 100k: ", ifelse(is.na(densite_per_100k), "NA", round(densite_per_100k, 2))
				)
			)

		if (any(!is.na(vals))) {
			m <- m %>%
				addLegend(
					pal = pal,
					values = vals,
					title = ifelse(metric_col == "effectif", "Effectif", "Densite / 100k"),
					opacity = 0.9,
					position = "bottomright"
				)
		}

		m
	})

	# Affiche les données du tableau professionnel
	output$data_table <- renderTable({
		req(input$quantite)  # Attends que l'user choisisse quelque chose
		filtered() %>%
			select(quantite, departement_code, departement_nom, effectif, population_ref, densite_per_100k) %>%
			arrange(departement_code)
	}, striped = TRUE, bordered = TRUE, hover = TRUE)

	# Affiche les données du tableau maladies (même structure que professionnels)
	output$table_maladies <- renderTable({
		fm <- filtered_maladies()
		if (identical(input$mode_maladie, "groupe")) {
			return(
				fm %>%
					select(quantite, departement_code, departement_nom, effectif, population_ref, densite_per_100k) %>%
					arrange(departement_code)
			)
		}

		fm %>%
			select(quantite, departement_code, departement_nom, effectif, population_ref, densite_per_100k) %>%
			arrange(departement_code)
	}, striped = TRUE, bordered = TRUE, hover = TRUE)

	# Affiche les stats de qualité des données (nbre lignes, missing, doublons, etc.)
	output$quality_table <- renderTable({
		quality_df
	}, striped = TRUE, bordered = TRUE, hover = TRUE)

	# Télécharge les données professionnelles filtrées
	output$download_data_prof <- downloadHandler(
		filename = function() {
			paste0("donnees_professionnels_", Sys.Date(), ".csv")
		},
		content = function(file) {
			readr::write_csv2(
				filtered() %>% arrange(departement_code),
				file
			)
		}
	)

	# Télécharge les données maladies filtrées
	output$download_data_mal <- downloadHandler(
		filename = function() {
			paste0("donnees_maladies_", Sys.Date(), ".csv")
		},
		content = function(file) {
			readr::write_csv2(
				filtered_maladies() %>% arrange(departement_code),
				file
			)
		}
	)
}

shinyApp(ui = ui, server = server)
