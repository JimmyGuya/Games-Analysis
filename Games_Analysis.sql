USE Game_Analysis;


-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players at level 0
SELECT 
	pd.P_ID AS Player_ID,
	ld.Dev_ID AS Device_ID,
	pd.PName AS Player_Name,
	ld.Difficulty AS Diffficulty_level
FROM player_details AS pd
JOIN level_details2 AS ld
ON pd.P_ID = ld.P_ID
WHERE ld.level = 0;

-- Q2) Find Level1_code wise Avg_Kill_Count where Lives_earned is 2 and atleast 3 stages are crossed
SELECT 
	pd.L1_code AS Level1_code,
	AVG(ld.Kill_Count) AS Avg_Kill_Count
FROM level_details2 AS ld
JOIN player_details AS pd
ON pd.P_ID = ld.P_ID
WHERE ld.Lives_Earned = 2 AND ld.Stages_crossed >= 3
GROUP BY pd.L1_Code;

-- Q3) Find the total number of stages crossed at each difficulty level where for Level2 with players use zm_series devices. Arrange the result in decreasing order of total number of stages crossed.
SELECT 
	Difficulty AS Difficulty_level,
	SUM(Stages_crossed) AS Total_Stages_Crossed
FROM level_details2
WHERE Level = 2 AND Dev_ID LIKE 'zm%'
GROUP BY Difficulty
ORDER BY Total_Stages_Crossed DESC;

-- Q4) Extract P_ID and the total number of unique dates for those players who have played games on multiple days.
SELECT 
	P_ID,
	COUNT(DISTINCT CAST(Timestamp AS Date)) AS Total_Unique_Dates
FROM level_details2
GROUP BY P_ID
HAVING COUNT(DISTINCT CAST(Timestamp AS Date)) > 1;

-- Q5) Find P_ID and level wise sum of kill_counts where kill_count is greater than avg kill count for the medium difficulty.
SELECT 
	P_ID,
	level,
	SUM(Kill_Count) AS Total_Kill_Counts
FROM level_details2
WHERE Difficulty = 'Medium'
AND Kill_Count > (
	SELECT
		AVG(Kill_Count) AS Avg_Kill_Count
FROM level_details2
WHERE Difficulty = 'Medium')
GROUP BY P_ID, Level;

-- Q6) Find Level and its corresponding Level code wise sum of lives earned excluding level 0. Arrange in ascending order of level.
SELECT 
	ld.Level AS Level,
	pd.L1_Code AS Level1_Code,
	pd.L2_Code AS Level2_Code,
	SUM(ld.Lives_Earned) AS Total_Lives_Eaarned
FROM player_details AS pd
JOIN level_details2 AS ld
ON pd.P_ID = ld.p_ID
WHERE Level > 0
GROUP BY ld.Level, pd.L1_Code, pd.L2_Code
ORDER BY Level ASC;

--Q7) Find Top 3 score based on each dev_id and Rank them in increasing order using Row_Number. Display difficulty as well.
WITH Top_3_Score AS (
SELECT
	Dev_ID,
	Score,
	Difficulty,
	ROW_NUMBER() OVER(PARTITION BY Dev_ID ORDER BY Score ASC) AS Row_Num
FROM level_details2
)
SELECT
	Dev_ID,
	Score,
	Difficulty,
	Row_Num
FROM Top_3_Score
WHERE Row_Num <= 3
ORDER BY Dev_ID, Row_Num;

--Q8) Find first_login datetime for each device id
SELECT
	Dev_ID,
	MIN(Timestamp) AS First_Login
FROM level_details2
GROUP BY Dev_ID;

--Q9) Find Top 5 score based on each difficulty level and Rank them in increasing order using Rank. Display dev_id as well.
WITH Top_5_score AS(
SELECT
	Dev_ID,
	Score,
	Difficulty,
	RANK() OVER(PARTITION BY Difficulty ORDER BY Score) AS Rank
FROM level_details2
)
SELECT 
	Dev_ID,
	Score,
	Difficulty,
	Rank
FROM Top_5_score
WHERE Rank <= 5
ORDER BY Difficulty, Rank;

--Q10) Find the device ID that is first logged in(based on start_datetime) for each player(p_id). Output should contain player id, device id and first login datetime.
WITH RankedLogins AS (
SELECT 
	P_ID,
	Dev_ID,
	Timestamp AS First_Login_Datetime,
	ROW_NUMBER() OVER(PARTITION BY P_ID ORDER BY Timestamp) AS login_rank
FROM level_details2
)
SELECT
	P_ID,
	Dev_ID,
	First_Login_Datetime
FROM RankedLogins
WHERE login_rank = 1;

--Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played by the player until that date.
--a) Window Function
WITH Player_Game_Summary AS (
SELECT 
	P_ID,
	CAST(TimeStamp AS date) AS game_date,
	SUM(Kill_Count) AS Kill_Count
FROM level_details2
GROUP BY P_ID, CAST(TimeStamp AS date)
),
Player_Total_Game_Summary AS(
SELECT
	P_ID,
	game_date,
	Kill_Count,
	SUM(Kill_Count) OVER(PARTITION BY P_ID ORDER BY game_date) AS Total_Kill_Count_So_Far,
	SUM(1) OVER(PARTITION BY P_ID ORDER BY game_date) AS Total_Game_Played
FROM Player_Game_Summary
)
SELECT 
	P_ID,
	game_date,
	Kill_Count,
	Total_Kill_Count_So_Far,
	Total_Game_Played
FROM Player_Total_Game_Summary
ORDER BY P_ID, game_date;

--b) Without window function
SELECT 
	ld.P_ID,
	convert(date, ld.TimeStamp) AS game_date,
	SUM(Kill_Count) AS Kill_Count,
	(
		SELECT SUM(ld2.Kill_Count)
		FROM level_details2 AS ld2
		WHERE ld2.P_ID = ld.P_ID
		AND CONVERT(Date, ld2.TimeStamp) <= CONVERT(Date, ld.TimeStamp)
	) AS Total_Kill_Count_So_far
FROM
	level_details2 AS ld
GROUP BY
	ld.P_ID,
	CONVERT(Date, ld.TimeStamp)
ORDER BY
	ld.P_ID,
	game_date;

--Q12) Find the cumulative sum of stages crossed over a start_datetime
SELECT
	TimeStamp,
	Stages_crossed,
	SUM(Stages_crossed) OVER(ORDER BY TimeStamp) AS Cumulative_Stages_Crossed
FROM level_details2;

--Q13) Find the cumulutive sum of stages crossed over a start_datetime for each player id but exclude the most recent start_datetime
SELECT
	ld.P_ID,
	MAX(ld.TimeStamp) AS TimeStamp,
	SUM(ld.stages_crossed) AS Cumulative_stages
FROM level_details2 AS ld
WHERE ld.TimeStamp < 
	(SELECT MAX(TimeStamp)
FROM level_details2
WHERE P_ID = ld.P_ID)
GROUP BY ld.P_ID;

--Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id
WITH Top_3_score AS (
SELECT
	Dev_ID,
	P_ID,
	SUM(Score) AS Total_Score,
	ROW_NUMBER() OVER(PARTITION BY Dev_ID ORDER BY SUM(Score) DESC) AS Row_Num
FROM level_details2
GROUP BY Dev_ID, P_ID
)
SELECT
	Dev_ID,
	P_ID,
	Total_Score
FROM Top_3_score
WHERE Row_Num <= 3
ORDER BY Dev_ID, Total_Score DESC;

--Q15) Find players who scored more than 50% of the avg score scored by sum of scores for each player_id
WITH PlayerTotalScore AS (
	SELECT
	P_ID,
	SUM(Score) AS Total_Score
	FROM level_details2
	GROUP BY P_ID
)
SELECT
	P_ID
FROM PlayerTotalScore
WHERE Total_Score > 
(Select AVG(Total_Score) * 0.5 
FROM PlayerTotalScore);

--Q16)Create a stored procedure to find n headshots_count based on each dev_id and Rank them in increasing order using Row_Number
CREATE PROCEDURE TopNHeadshotsCount (@N int)
AS
BEGIN
	SET NOCOUNT ON;
	WITH RankedHeadshots AS(
		SELECT
			P_ID,
			Dev_ID,
			headshots_count,
			difficulty,
			ROW_NUMBER() OVER(PARTITION BY Dev_ID ORDER BY headshots_count ASC) AS HeadshotsRank
		FROM level_details2
	)
	SELECT
		HeadshotsRank,
		p_ID,
		Dev_ID,
		headshots_count,
		difficulty
	FROM RankedHeadshots
	WHERE HeadshotsRank <= @N;
END;

--run this following to execute procedure
EXEC TopNHeadshotsCount @N = 5;
