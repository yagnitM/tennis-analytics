CREATE DATABASE IF NOT EXISTS tennis_db;
USE tennis_db;

CREATE TABLE fact_matches (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    tourney_year INT,
    surface VARCHAR(20),
    best_of INT,
    winner_id INT,
    loser_id INT,
    winner_name VARCHAR(100),
    loser_name VARCHAR(100),
    w_ace INT,
    l_ace INT,
    w_svpt INT,
    l_svpt INT,
    w_df INT,
    l_df INT,
    score VARCHAR(100),
    sets_played INT,
    winner_sets INT,
    loser_sets INT,
    total_games_winner INT,
    total_games_loser INT,
    had_tiebreak VARCHAR(5),
    score_closeness DECIMAL(4,1)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/matches_bo3_filled.csv'
INTO TABLE fact_matches
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(tourney_year, surface, best_of, winner_id, loser_id, winner_name, loser_name,
w_ace, l_ace, w_svpt, l_svpt, w_df, l_df, score, sets_played, winner_sets,
loser_sets, total_games_winner, total_games_loser, had_tiebreak, score_closeness);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/matches_bo5_filled.csv'
INTO TABLE fact_matches
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(tourney_year, surface, best_of, winner_id, loser_id, winner_name, loser_name,
w_ace, l_ace, w_svpt, l_svpt, w_df, l_df, score, sets_played, winner_sets,
loser_sets, total_games_winner, total_games_loser, had_tiebreak, score_closeness);

select count(*) from fact_matches;

CREATE VIEW dim_players AS
SELECT winner_id AS player_id, winner_name AS player_name FROM fact_matches
UNION
SELECT loser_id, loser_name FROM fact_matches;

-- WIN PERCENT BY PLAYER
SELECT 
    p.player_name,
    COUNT(DISTINCT CASE WHEN f.winner_id = p.player_id THEN f.match_id END) AS wins,
    COUNT(f.match_id) AS total_matches,
    ROUND(COUNT(DISTINCT CASE WHEN f.winner_id = p.player_id THEN f.match_id END) * 100.0 / COUNT(f.match_id), 2) AS win_pct
FROM dim_players p
JOIN fact_matches f ON p.player_id = f.winner_id OR p.player_id = f.loser_id
GROUP BY p.player_id, p.player_name
HAVING total_matches >= 50
ORDER BY win_pct DESC;

-- WIN PERCENT BY PLAYER BY SURFACE
SELECT 
	p.player_name, f.surface, 
	COUNT(DISTINCT CASE WHEN f.winner_id = p.player_id THEN f.match_id END) AS wins,
	COUNT(f.match_id) AS total_matches,
	ROUND(COUNT(DISTINCT CASE WHEN f.winner_id = p.player_id THEN f.match_id END) * 100.0 / COUNT(f.match_id), 2) AS win_pct
FROM dim_players p
JOIN fact_matches f ON p.player_id = f.winner_id OR p.player_id = f.loser_id
GROUP BY p.player_id, p.player_name, f.surface
HAVING total_matches >= 20
ORDER BY win_pct DESC;

-- ACE RATE BY SURFACE PER PLAYER
WITH aces AS (
	SELECT 
		p.player_name, f.surface,
		SUM(CASE WHEN f.winner_id = p.player_id THEN w_ace ELSE l_ace END) AS total_aces,
		SUM(CASE WHEN f.winner_id = p.player_id THEN w_svpt ELSE l_svpt END) AS total_svpt
	FROM dim_players p
	JOIN fact_matches f ON p.player_id = f.winner_id OR p.player_id = f.loser_id
	GROUP BY p.player_id, p.player_name, f.surface
    HAVING total_svpt >= 500
) SELECT *, (total_aces/total_svpt) * 100 AS ACE_RATE FROM aces ORDER BY ACE_RATE DESC;

-- SURFACE ACE RATE
WITH ace_total AS (
	SELECT surface, SUM(w_ace + l_ace) AS ACES, SUM(w_svpt + l_svpt) AS TOTAL_SVPT
    FROM fact_matches
    WHERE surface IS NOT NULL
    GROUP BY surface
) SELECT *, ROUND((ACES/TOTAL_SVPT * 100.0),2) AS ACE_RATE FROM ace_total;

-- MATCH CLOSENESS BY SURFACE (PER PLAYER)
SELECT p.player_name, f.surface, AVG(f.score_closeness) AS MATCH_CLOSENESS, COUNT(f.match_id) AS TOTAL_MATCHES
FROM dim_players p
JOIN fact_matches f 
ON p.player_id = f.winner_id OR p.player_id = f.loser_id
GROUP BY p.player_id, p.player_name, f.surface
HAVING TOTAL_MATCHES >= 20
ORDER BY MATCH_CLOSENESS DESC;

-- SURFACE BY CLOSENESS	
SELECT surface, AVG(score_closeness) AS avg_closeness, COUNT(*) AS total_matches
FROM fact_matches
GROUP BY surface
ORDER BY avg_closeness DESC;

-- TOP ACE HITTERS OF ALL TIME
SELECT 
	p.player_name, 
    SUM(CASE WHEN f.winner_id = p.player_id THEN w_ace ELSE l_ace END) AS TOTAL_ACES
FROM dim_players p
JOIN fact_matches f
ON p.player_id = f.winner_id OR p.player_id = f.loser_id
GROUP BY p.player_id, p.player_name
ORDER BY TOTAL_ACES DESC;

-- DF LEADERS
SELECT 
	p.player_name,
    SUM(CASE WHEN f.winner_id = p.player_id THEN w_df ELSE l_df END) AS TOTAL_DF
FROM dim_players p
JOIN fact_matches f
ON p.player_id = f.winner_id OR p.player_id = f.loser_id
GROUP BY p.player_id, p.player_name
ORDER BY TOTAL_DF DESC;

-- DF per SERVE POINT
WITH df_svpt AS (
	SELECT p.player_name,
		SUM(CASE WHEN f.winner_id = p.player_id THEN w_df ELSE l_df END) AS TOTAL_DF,
		SUM(CASE WHEN f.winner_id = p.player_id THEN w_svpt ELSE l_svpt END) AS TOTAL_SVPT
	FROM dim_players p
	JOIN fact_matches f
	ON p.player_id = f.winner_id OR p.player_id = f.loser_id
	GROUP BY p.player_id, p.player_name
    HAVING TOTAL_SVPT >= 500
) SELECT *, 
ROUND((TOTAL_DF/TOTAL_SVPT * 100.0),2) AS DF_PER_SVPT 
FROM df_svpt
ORDER BY DF_PER_SVPT DESC;

-- TIEBREAK BY YEAR
SELECT 
    tourney_year,
    COUNT(*) AS total_matches,
    SUM(had_tiebreak = 'TRUE') AS tiebreak_matches,
    ROUND(SUM(had_tiebreak = 'TRUE') / COUNT(*) * 100, 2) AS tiebreak_pct
FROM fact_matches
GROUP BY tourney_year
ORDER BY tourney_year;

-- TIEBREAK BY SURFACE
SELECT
	surface,
    COUNT(*) AS total_matches,
    SUM(had_tiebreak = 'TRUE') AS tiebreak_matches,
    ROUND(SUM(had_tiebreak = 'TRUE') / COUNT(*) * 100, 2) AS tiebreak_pct
FROM fact_matches
WHERE surface IS NOT NULL
GROUP BY surface;

-- AVG CLOSENESS BY YEAR
SELECT
	tourney_year,
    AVG(score_closeness)
FROM fact_matches
GROUP BY tourney_year;

-- H2H
SELECT 
    winner_name,
    loser_name,
    COUNT(*) AS wins
FROM fact_matches
GROUP BY winner_name, loser_name
ORDER BY wins DESC;

-- H2H by surface
SELECT 
    winner_name,
    loser_name,
    surface,
    COUNT(*) AS wins
FROM fact_matches
WHERE surface IS NOT NULL
GROUP BY winner_name, loser_name, surface
ORDER BY wins DESC;

-- Win rate trend by year for a specific player
WITH player_year AS (
	SELECT
		p.player_name, f.tourney_year, 
		COUNT(DISTINCT CASE WHEN f.winner_id = p.player_id THEN f.match_id END) AS wins,
		COUNT(f.match_id) AS total_matches
        FROM dim_players p
        JOIN fact_matches f
        ON p.player_id = f.winner_id OR p.player_id = f.loser_id
        GROUP BY p.player_id, p.player_name, f.tourney_year
) SELECT *, (wins/total_matches * 100.0) AS win_pct 
FROM player_year
ORDER BY player_name, tourney_year ASC;

-- Avg aces per match trend by year 
SELECT 
	tourney_year,
    ROUND(AVG(w_ace + l_ace),2) AS AVG_ACE_PER_MATCH
FROM fact_matches
GROUP BY tourney_year;

-- FIVE MATCHES FREQUENCY
SELECT 
	tourney_year, 
    COUNT(*) AS TOTAL_FIVE_SET_MATCHES,
    SUM(sets_played = 5) AS five_set_matches,
    ROUND(SUM(sets_played = 5) / COUNT(*) * 100, 2) AS five_set_pct
FROM fact_matches
WHERE best_of = 5
GROUP BY tourney_year
ORDER BY tourney_year;

-- Top 5 players in each decade
WITH decade_wins AS (
    SELECT 
        winner_name,
        CASE 
            WHEN tourney_year BETWEEN 2000 AND 2009 THEN '2000s'
            WHEN tourney_year BETWEEN 2010 AND 2019 THEN '2010s'
            ELSE '2020s'
        END AS decade,
        COUNT(*) AS wins
    FROM fact_matches
    GROUP BY winner_name, decade
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY decade ORDER BY wins DESC) AS rnk
    FROM decade_wins
)
SELECT * FROM ranked
WHERE rnk <= 5;

-- Year wise top performer using window functions (RANK) 
WITH year_win AS (
	SELECT
		winner_name, tourney_year, COUNT(*) AS wins
	FROM fact_matches
    GROUP BY winner_name, tourney_year
), ranked AS (
	SELECT *, DENSE_RANK() OVER(PARTITION BY tourney_year ORDER BY wins DESC) AS rnk
    FROM year_win
) SELECT * FROM ranked 
WHERE rnk <= 5;

-- WIN RATE IN TB MATCHES vs NON-TB MATCHES
WITH type_matches AS (
	SELECT p.player_name, 
		COUNT(CASE WHEN f.winner_id = p.player_id AND had_tiebreak = 'TRUE' THEN f.match_id END) AS TB_WINS,
        COUNT(CASE WHEN had_tiebreak = 'TRUE' THEN f.match_id END) AS MATCHES_HAVING_TB,
        COUNT(CASE WHEN f.winner_id = p.player_id AND had_tiebreak = 'FALSE' THEN f.match_id END) AS NON_TB_WINS,
        COUNT(CASE WHEN had_tiebreak = 'FALSE' THEN f.match_id END) AS MATCHES_WITHOUT_TB
	FROM dim_players p
    JOIN fact_matches f
    ON p.player_id = f.winner_id OR p.player_id = f.loser_id
    GROUP BY p.player_id, p.player_name
) SELECT *,
	(TB_WINS/MATCHES_HAVING_TB * 100.0) AS TB_MATCH_WIN_RATE,
    (NON_TB_WINS/MATCHES_WITHOUT_TB * 100.0) AS NON_TB_MATCH_WIN_RATE
FROM type_matches	
WHERE TB_WINS >=5 AND NON_TB_WINS >= 10
ORDER BY TB_MATCH_WIN_RATE DESC, NON_TB_MATCH_WIN_RATE;

SELECT COUNT(DISTINCT loser_id) FROM fact_matches;