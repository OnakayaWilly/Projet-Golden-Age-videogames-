-- Top  10 ventes
SELECT
*
FROM game_sales
ORDER BY games_sold DESC
LIMIT 10;

-- nb total de vente par platformes 
SELECT
	platform,
	SUM(games_sold) as somme_ventes
FROM game_sales
GROUP BY platform
ORDER BY somme_ventes DESC

-- vérifications
SELECT
*
FROM game_sales
WHERE developer IS NULL

-- 
UPDATE game_sales 
SET developer = COALESCE(developer,'Unknown')
WHERE developer IS NULL;


-- Quels sont les jeux sortis après 2015 avec une note critique supérieure à 9 ?
SELECT
	g.game,
	g.year,
	CASE WHEN r.critic_score IS NULL THEN 0 
	ELSE r.critic_score END as crictic_score
FROM game_sales g
JOIN reviews r ON r.game = g.game
WHERE g.year > 2015 AND r.critic_score >= 9


-- Combien de jeux chaque plateforme (PS4, PC, etc.) possède-t-elle dans ce dataset
SELECT
	platform,
	COUNT(*) as count_games
FROM game_sales
GROUP BY platform
ORDER BY count_games DESC

-- une requête qui affiche tous les jeux de l'éditeur "Ubisoft" sortis sur la plateforme "PS4
SELECT
	*
FROM game_sales
WHERE publisher = 'Ubisoft' AND platform = 'PS4'

-- Est-ce que les jeux sans score sont des jeux très anciens ou des petits jeux peu vendus 
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
--


-- Quelles sont les 3 plateformes ayant généré le plus gros volume de ventes cumulé pour chaque année ? L'objectif est de voir si une plateforme (ex: PS4 vs Xbox One) a réussi à détrôner les autres sur la durée."
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


-- Identifiez les éditeurs (Publishers) dont les jeux reçoivent systématiquement une note des utilisateurs 
--supérieure à la note des critiques (avec un écart d'au moins 1 point en moyenne). C
--es éditeurs ont-ils une base de fans plus engagée malgré des critiques presse moyennes ?"

with cte as (
SELECT
	publisher, 
	critic_score,
	user_score
FROM game_sales gs 
JOIN reviews r ON r.game = gs.game
WHERE r.critic_score IS NOT  NULL and r.user_score IS NOT NULL 
)
SELECT
	publisher,
	ROUND(AVG(user_score), 2)  as avg_user_score,
	ROUND(AVG(critic_score), 2)  as avg_critic_score,
	ROUND(AVG(user_score) - AVG(critic_score), 2) as ecart_avg
FROM cte
GROUP BY publisher
HAVING AVG(user_score) - AVG(critic_score) >= 1 AND COUNT(*) >= 2
ORDER BY ecart_avg DESC


/* 
En supposant que chaque développeur appartient à une catégorie de taille, 
calculez la contribution de chaque développeur aux ventes totales de leur éditeur respectif. 
Quel développeur est le 'moteur' principal de chaque grand éditeur 
*/



/*
Quels sont les éditeurs qui ont la plus grande variance (écart-type) dans leurs notes critiques ?
Nous voulons distinguer les éditeurs 'stables' (qui sortent toujours des jeux corrects) des éditeurs 'risqués'
(qui alternent entre chefs-d'œuvre et échecs totaux)."
*/ 
with cte as (
SELECT
	gs.publisher,
	r.critic_score
FROM game_sales gs
JOIN reviews r ON r.game = gs.game
WHERE r.critic_score IS NOT NULL
)
SELECT
	publisher,
	COUNT(*) as nb_games,
	ROUND(AVG(critic_score),2) as avg_critic_score,
	ROUND(STDDEV(critic_score),2) as sttdev_critic_score,
	MAX(critic_score) as max_score,
	MIN(critic_score) as min_score
FROM cte
GROUP BY publisher
HAVING COUNT(*) > 1
ORDER BY sttdev_critic_score DESC
LIMIT 10

/*
Identification des "Sleeping Giants" (Succès Critiques Oubliés)
Trouvez les jeux qui font partie du top 5% des meilleures notes critiques, 
mais qui sont dans les derniers 25% en termes de ventes. L'idée est d'identifier des propriétés intellectuelles (IP) 
de haute qualité qui ont manqué leur marketing et pourraient être relancées."
•	Indice : Utilise des sous-requêtes ou NTILE() pour segmenter par quartiles/percentiles.

*/
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



-----------------------------------------
/*
Quelles plateformes ont la durée de vie la plus saine ? Calculez l'écart entre le premier et le dernier jeu sorti sur chaque plateforme,
ainsi que la tendance des notes critiques sur cette période."
*/

with cycle_date as (
SELECT
	platform,
	MIN(year) as min_year,
	MAX(year) as max_year,
	MAX(year) - MIN(year) as difference
FROM game_sales 
GROUP BY platform
),
quality_trend as (
SELECT
	gs.platform,
	AVG(CASE WHEN gs.year <= c.min_year + 1 THEN COALESCE (r.critic_score,0) END) as early_score,
	AVG(CASE WHEN gs.year >= c.max_year - 1 THEN COALESCE (r.critic_score,0) END) as late_score
FROM cycle_date c
JOIN game_sales gs ON gs.platform = c.platform
JOIN reviews r ON r.game = gs.game
GROUP BY gs.platform
),
score as (
SELECT
	c.platform,
	c.difference,
	c.max_year,
	c.min_year,
	ROUND(q.early_score,2) as early_score,
	ROUND(q.late_score,2) as late_score,
	ROUND(q.late_score - q.early_score, 2) as evolution_quality
FROM cycle_date c 
JOIN quality_trend q ON q.platform = c.platform
WHERE c.difference > 0
ORDER BY c.difference DESC
LIMIT 10
)
SELECT
	platform,
	max_year,
	min_year,
	difference,
	evolution_quality,
	CASE WHEN evolution_quality > 0.5 THEN 'Maitrîse croissante '
		WHEN evolution_quality BETWEEN -0.5 AND 0.5 THEN 'Stable'
		WHEN evolution_quality < 0.5 THEN 'Déclin'
	END AS evolution
FROM score
ORDER BY evolution_quality DESC


/*
4. 
Question Business : "Si l'on segmente les plateformes par type (Portable vs Salon, ex: 3DS/DS vs PS4/XOne), 
comment les parts de marché ont-elles évolué entre 2010 et 2020 ?"
*/
with cte as (
SELECT 
	game,
    CASE 
        WHEN platform IN ('PS4', 'XOne', 'PS3', 'X360', 'Wii', 'PS2', 'XB', 'GC', 'N64', 'NES', 'SNES') THEN 'Salon'
        WHEN platform IN ('PSP', 'PSV', '3DS', 'DS', 'GBA', 'GB', 'GBC') THEN 'Portable'
        WHEN platform = 'NS' THEN 'Hybride'
        WHEN platform = 'PC' THEN 'PC'
        ELSE 'Autre/Digital'
    END AS category,
    games_sold,
	year
FROM game_sales
WHERE year BETWEEN 2010 AND 2020
)
SELECT
	category,
	ROUND(100.0 * SUM(games_sold) / (SELECT SUM(games_sold) FROM game_sales WHERE year BETWEEN 2010 AND 2020),2) as percentage_part
FROM cte
GROUP BY category
ORDER BY percentage_part DESC

-----
/*
Quels sont les jeux qui ont vendu plus de 2 fois la moyenne de leur propre éditeur ?
Ce sont les 'piliers' financiers qui portent l'entreprise."
*/
with cte as (
SELECT
	game,
	publisher,
	games_sold,
	AVG(games_sold) OVER(PARTITION BY publisher) as avg_sold_per_publish
FROM game_sales
)
SELECT
	game,
	publisher,
	games_sold,
	ROUND(avg_sold_per_publish,2) as avg_sold_per_publish,
	ROUND(games_sold / avg_sold_per_publish, 2) as ratio
FROM cte
WHERE games_sold >= avg_sold_per_publish * 2 AND avg_sold_per_publish > 0
ORDER BY ratio DESC

/* 
Quels éditeurs sont les plus diversifiés en termes de plateformes ?
Un éditeur présent sur 5 plateformes est-il plus rentable qu'un éditeur exclusif à une seule (ex: Nintendo) ?
*/
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


-- More you are on platform, more in average you sell more 