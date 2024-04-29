-- Create view for batsman stats
CREATE VIEW batsman_stats AS
SELECT
	batsman_name,
    SUM(runs) as total_runs,
    SUM(balls) AS total_balls_faced,
    ROUND(SUM(balls)/SUM(4s)) AS balls_per_fours,
    ROUND(SUM(balls)/SUM(6s)) AS balls_per_sixes,
    SUM(4s) AS total_fours,
    SUM(6s) AS total_sixes,
    ROUND(COUNT(CASE WHEN out_or_not = 'not_out' THEN 1 ELSE NULL END)*100/ count(out_or_not)) AS not_out_pct,
    SUM(runs)*100/SUM(balls) AS avg_SR
FROM fact_batting
GROUP BY batsman_name;


-- 1. Top 10 batsman based on past 3 years total runs scored.
SELECT * FROM batsman_stats
ORDER BY total_runs DESC
LIMIT 10;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 2. Top 10 batsmen based on past 3 years batting average.(min 60 balls faced in each season)
CREATE TEMPORARY TABLE batting_stats_per_season
	SELECT 
		b.batsman_name,
		get_season(m.match_date) AS season,
		SUM(b.runs) AS total_runs,
		SUM(b.balls) AS total_balls,
        SUM(CASE WHEN b.out_or_not = "out" THEN 1 ELSE 0 END) AS times_out,
        SUM(4s) AS total_fours,
        SUM(6s) AS total_sixes
	FROM fact_batting AS b
	JOIN dim_match AS m
	USING(match_id)
	GROUP BY b.batsman_name, get_season(m.match_date)
	ORDER BY b.batsman_name, season;

SELECT * FROM batting_stats_per_season;

SELECT 
	batsman_name,
    SUM(total_runs) AS total_runs,
    SUM(times_out) AS times_out,
    SUM(total_runs)/SUM(times_out) AS batting_avg
FROM batting_stats_per_season
GROUP BY batsman_name
HAVING COUNT(DISTINCT season) = 3
AND SUM(CASE WHEN total_balls >= 60 THEN 1 ELSE 0 END) = 3
ORDER BY batting_avg DESC
LIMIT 10;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 3. Top 10 batsmen based on past 3 years strike rate (min 60 balls faced in each season)
SELECT 
	batsman_name,
    SUM(total_runs) AS total_runs,
    SUM(total_balls) AS total_balls,
    SUM(total_runs)*100/SUM(total_balls) AS strike_rate
FROM batting_stats_per_season
GROUP BY batsman_name
HAVING COUNT(DISTINCT season) = 3
AND SUM(CASE WHEN total_balls >= 60 THEN 1 ELSE 0 END) = 3
ORDER BY strike_rate DESC
LIMIT 10;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 4. Top 10 bowlers based on past 3 years total wickets taken.
SELECT
	bowler_name,
    SUM(wickets) AS total_wickets
FROM fact_bowling
GROUP BY bowler_name
ORDER BY total_wickets DESC
LIMIT 10;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 5. Top 10 bowlers based on past 3 years bowling average. (min 60 balls bowled in each season)
CREATE TEMPORARY TABLE bowlers_stats
SELECT 
	bowler_name,
    get_season(m.match_date) AS season,
    SUM(balls_bowled) AS total_balls_bowled,
    SUM(runs) AS total_runs_conceded,
    SUM(wickets) AS total_wickets
FROM fact_bowling AS b
JOIN dim_match AS m
USING(match_id)
GROUP BY bowler_name, season
ORDER BY bowler_name, season;

SELECT * FROM bowlers_stats;

SELECT 
	bowler_name,
    SUM(total_runs_conceded) AS total_runs_conceded,
    SUM(total_wickets) AS total_wickets,
    SUM(total_runs_conceded)/ SUM(total_wickets) AS bowling_avg
FROM bowlers_stats
GROUP BY bowler_name
HAVING SUM(CASE WHEN total_balls_bowled >= 60 THEN 1 ELSE 0 END) = 3
ORDER BY bowling_avg
LIMIT 10;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 6. Top 10 bowlers based on past 3 years economy rate. (min 60 balls bowled in each season)
SELECT 
	bowler_name,
    SUM(total_runs_conceded) AS total_runs_conceded,
    SUM(total_balls_bowled) AS total_balls_bowled,
    (SUM(total_runs_conceded)/SUM(total_balls_bowled))*6 AS economy_rate
FROM bowlers_stats
GROUP BY bowler_name
HAVING SUM(CASE WHEN total_balls_bowled >= 60 THEN 1 ELSE 0 END) = 3
ORDER BY economy_rate
LIMIT 10;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 7. Top 5 batsmen based on past 3 years boundary % (fours and sixes)
-- Minimun 700 runs scored
SELECT 
	batsman_name,
    SUM(runs) AS total_runs,
    SUM(4s) AS total_fours,
    SUM(6s) AS total_sixes,
    ((SUM(4s)*4) + (SUM(6s)*6))*100/SUM(runs) AS boundary_pct
FROM fact_batting
GROUP BY batsman_name
HAVING SUM(runs) > 700
ORDER BY boundary_pct DESC
LIMIT 5;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 8. Top 5 bowlers based on past 3 years dot ball %.
SELECT 
	bowler_name,
    SUM(balls_bowled) AS balls_bowled,
    SUM(0s) AS dot_balls_bowled,
    SUM(0s)*100/SUM(balls_bowled) AS dot_ball_pct
FROM fact_bowling
GROUP BY bowler_name
HAVING SUM(balls_bowled) > 500
ORDER BY dot_ball_pct DESC
LIMIT 5;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 9. Top 4 teams based on past 3 years winning %

CREATE VIEW result_summary AS 
WITH
	match_summary AS
		(SELECT team1 AS team_name, dim_match.*, get_season(match_date) AS season from dim_match
		UNION
		SELECT team2 AS team_name, dim_match.*, get_season(match_date) AS season from dim_match
		ORDER BY match_id),
    
	result_table AS
		(SELECT  
			team_name,
            season,
			SUM(CASE WHEN team1 = team_name THEN 1 ELSE 0 END) AS match_played_as_team1,
			SUM(CASE WHEN team2 = team_name THEN 1 ELSE 0 END) AS match_played_as_team2,
			SUM(CASE WHEN team1 = team_name AND winner = team_name THEN 1 ELSE 0 END) AS winner_as_team1,
			SUM(CASE WHEN team2 = team_name AND winner = team_name THEN 1 ELSE 0 END) AS winner_as_team2
		FROM match_summary
		GROUP BY team_name,season)
    
SELECT 
	team_name,season, match_played_as_team1, match_played_as_team2,
	(match_played_as_team1 + match_played_as_team2) AS total_match_played,
    winner_as_team1, winner_as_team2,
    (winner_as_team1 + winner_as_team2) AS total_win
    FROM result_table;


-- Top 4 teams based on past 3 years winning %
SELECT
	team_name,
    ROUND(SUM(total_win)*100/SUM(total_match_played)) AS pct_win
FROM result_summary
GROUP BY team_name
ORDER BY pct_win DESC
LIMIT 4;

-- ----------------------------------------------------------------------------------------------------------------------------

-- 10.Top 2 teams with the highest number of wins achieved by chasing targets over the past 3 years.
SELECT
	team_name,
    ROUND(SUM(winner_as_team2)*100/SUM(match_played_as_team2),1) AS pct_win_while_chasing
FROM result_summary
GROUP BY team_name
ORDER BY pct_win_while_chasing DESC
LIMIT 2;