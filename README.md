# Projet-Golden-Age-videogames


## Objectifs
Ce projet consiste en une analyse approfondie d'un ensemble de données regroupant les ventes de jeux vidéo et les avis des critiques/utilisateurs. L'objectif est d'identifier les tendances du marché, l'évolution des plateformes et la performance des éditeurs à travers des requêtes SQL complexes. 
(Top des ventes, parts de marché par type de console, Mesure de la longévité et de l'évolution de la qualité sur chaque plateforme, etc...)

Un projet effectué en SQL, plus précisément sur pgAdmin.

# Dataset
 - **Dataset Link:** [Golden age Dataset](https://www.kaggle.com/datasets/holmjason2/videogamedata)

# Table 

Création des tables games_sales et reviews respectivemennt sur pgAdmin

<img width="1103" height="381" alt="image" src="https://github.com/user-attachments/assets/ef21cebf-d008-4485-a0ff-93d1f2025cef" />
<img width="1102" height="242" alt="image" src="https://github.com/user-attachments/assets/ffe1eda5-b4ed-4872-9dc2-451e8091f0e2" />

# Exemple de certaines requêtes 
Voici un extrait du code entier, sinon se référer au fichier .sql.

### Quels sont les jeux sortis après 2015 avec une note critique supérieure à 9 ?
``` sql 
SELECT
	g.game,
	g.year,
	CASE WHEN r.critic_score IS NULL THEN 0 
	ELSE r.critic_score END as crictic_score
FROM game_sales g
JOIN reviews r ON r.game = g.game
WHERE g.year > 2015 AND r.critic_score >= 9
```

### Quelles sont les 3 plateformes ayant généré le plus gros volume de ventes cumulé pour chaque année ?
``` sql
with sale_by_year_platoforms as (
SELECT
	year,
	platform,
	SUM(games_sold) as total_sold
FROM game_sales
GROUP BY year, platform
),
ranked as (
SELECT
	year,
	platform,
	DENSE_RANK() OVER(PARTITION BY year ORDER BY total_sold DESC) as rk
FROM sale_by_year_platoforms
)
SELECT
	year,
	platform,
	rk as rang
FROM ranked
WHERE rk <= 3 
ORDER BY year DESC, rk ASC
```

### Trouvez les jeux qui font partie du top 5% des meilleures notes critiques, mais qui sont dans les derniers 25% en termes de ventes. 
``` sql
with cte as (
SELECT
	r.game,
	r.critic_score,
	gs.games_sold,
	NTILE(20) OVER(ORDER BY critic_score DESC) as tile_5_percent,
	NTILE(4) OVER(ORDER BY games_sold ASC)  as sales_tiles
FROM reviews r
JOIN game_sales gs ON gs.game = r.game
WHERE r.critic_score IS NOT NULL
)
SELECT
	game,
	critic_score,
	games_sold
FROM cte 
WHERE tile_5_percent = 1 AND sales_tiles = 1
ORDER BY critic_score DESC
```

### Quels éditeurs sont les plus diversifiés en termes de plateformes ?Un éditeur présent sur 5 plateformes est-il plus rentable qu'un éditeur exclusif à une
seule ?
``` sql
with publisher_info as (
SELECT
	publisher,
	COUNT (DISTINCT platform) as cnt,
	SUM(games_sold) as total_sold,
	SUM(games_sold) / COUNT (DISTINCT platform) as sales_by_platform
FROM game_sales 
GROUP BY publisher
)
SELECT
	CASE WHEN cnt = 1 THEN 'Exclusif'
		WHEN cnt BETWEEN 2 AND 5 THEN 'Hybride'
		WHEN cnt > 5 THEN '+5 platforms'
	END as type,
	COUNT(*) nb_publisher,
	ROUND(AVG(total_sold), 2) as avg_total_sold,
	ROUND(AVG(sales_by_platform),2) as avg_sales_by_platform
	
FROM publisher_info
GROUP BY 1
ORDER BY 1
```

###  Est-ce que les jeux sans score sont des jeux très anciens ou des petits jeux peu vendus 
```sql

SELECT
	CASE WHEN r.critic_score IS NULL THEN 'Sans Score'
		ELSE 'Avec Score'
		END as categorie_score,
		COUNT(*) as nb_jeux,
		ROUND(AVG(gs.year),0) avg_year,
		ROUND(AVG(gs.games_sold)::numeric,2) as avg_games_sold
FROM game_sales gs 
LEFT JOIN reviews r ON gs.game = r.game
GROUP BY 1
```
