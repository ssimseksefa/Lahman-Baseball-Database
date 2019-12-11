/* 1. What range of years does the provided database cover?*/
/* 1871	2016 */

select min(year), max(year)
from homegames;

/* 2. Find the name and height of the shortest player in the database. 
How many games did he play in? What is the name of the team for which he played? */
/* "Eddie Gaedel"	"43"	"1"	"St. Louis Browns" */
select distinct namefirst || ' ' || namelast as fullname, height, total_games, teams.name
from people
left join (select playerid, sum(g_all) as total_games, string_agg(teamid,'/') as teamid
		   from appearances
		   group by playerid) as appearances
using(playerid)  
left join teams
using(teamid)
where height=(select min(height) from people);

/* 3. Find all players in the database who played at Vanderbilt University. 
Create a list showing each player’s first and last names as well as the total 
salary they earned in the major leagues. Sort this list in descending order by 
the total salary earned. Which Vanderbilt player earned the most money in the majors? */
/* "David"	"Price"	"81,851,296" */
select namefirst, namelast, total_salary
from people
inner join (select playerid, sum(salary)::numeric::money as total_salary
		   from salaries
		   where playerid in (select distinct playerid
							  from collegeplaying
							  where schoolid = (select schoolid
												from schools
												where schoolname ilike '%vanderbilt%')
							 )
		   group by playerid) as salaries
using(playerid)
order by total_salary desc;

/* 4. Using the fielding table, group players into three groups based on their position:
label players with position OF as "Outfield", those with position "SS", "1B", "2B", 
and "3B" as "Infield", and those with position "P" or "C" as "Battery". 
Determine the number of putouts made by each of these three groups in 2016. */
/* "Battery"	"41424"
"Infield"	"58934"
"Outfield"	"29560" */
select (case when pos='OF' then 'Outfield'
			when pos='P' or pos='C' then 'Battery'
			else 'Infield' end) as position, sum(po) as total_putouts			 
from fielding
where yearid=2016
group by position;

/* 5. Find the average number of strikeouts per game by decade since 1920. 
Round the numbers you report to 2 decimal places. Do the same for home runs per game. 
Do you see any trends? */
/* Yes, it is increasing by time for both */
select yearid/10 * 10 as decades, sum(g)/2 as game_count, sum(so) as so_count,
		round(sum(so)/cast(sum(g)/2 as numeric), 2) as so_per_game,
		sum(hr) as hr_count,
		round(sum(hr)/cast(sum(g)/2 as numeric), 2) as hr_per_game
from batting
where yearid/10 * 10 >=1920
group by decades
order by decades;

/* 6. Find the player who had the most success stealing bases in 2016, where success is 
measured as the percentage of stolen base attempts which are successful. (A stolen base
attempt results either in a stolen base or being caught stealing.) Consider only players
who attempted at least 20 stolen bases. */
/* "Chris"	"Owings"	"21"	"2"	"91" */
with succes_sb as (select playerid, sum(sb) as sb, sum(cs) as cs, 
				   100*sum(sb)/( sum(sb)+sum(cs) ) as success
from batting
where yearid=2016
group by playerid
having sum(sb)+sum(cs)>=20)
select namefirst, namelast, sb, cs, success from succes_sb																							 
inner join people using(playerid)																		
order by success desc;

/* 7. From 1970 – 2016, what is the largest number of wins for a team that did not win 
the world series? What is the smallest number of wins for a team that did win the world 
series? Doing this will probably result in an unusually small number of wins for a world 
series champion – determine why this is the case. Then redo your query, excluding the 
problem year. How often from 1970 – 2016 was it the case that a team with the most wins 
also won the world series? What percentage of the time? */
/* "a team with the most wins also won the world series?" "percentage"
"Y"	"26.67"
"N"	"73.33" */
with mw_vs_champ as (
	with champ_and_nonchamp_mw as (
		with seconds as (
			select *, max(w) over(partition by yearid) as second_max
			from teams
			where yearid>=1970 and w>80 and wswin='N'
		)
		select distinct t.yearid, t.teamid, t.name, t.w, t.wswin 
		from seconds as s
		right join teams as t 
		using(teamid, yearid)
		where t.yearid>=1970 and t.w>80 and ((t.w=second_max and t.wswin='N') or t.wswin='Y')
		order by yearid,wswin desc
		)
	select *, case when wswin='Y' and w=max(w) over(partition by yearid) then 'Y' else 'N' end as is_champ_and_mw
	from champ_and_nonchamp_mw
	)
select yearid, split_part(string_agg(is_champ_and_mw,'/'),'/',1) as mw_is_also_champ, round(100.0*(
	count(*) over(partition by split_part(string_agg(is_champ_and_mw,'/'),'/',1) ) ) / (
		count(*) over(partition by split_part(string_agg(is_champ_and_mw,'/'),'/',2) ) ),2) as percentage
from mw_vs_champ
group by yearid
order by yearid;

/* 8. Using the attendance figures from the homegames table, find the teams and parks 
which had the top 5 average attendance per game in 2016 (where average attendance is 
defined as total attendance divided by number of games). Only consider parks where there 
were at least 10 games played. Report the park name, team name, and average attendance. 
Repeat for the lowest 5 average attendance. */
/* highest "Dodger Stadium"	"Los Angeles Dodgers"	45719 */
/* lowest "Tropicana Field"	"Tampa Bay Rays"	15878 */
select park_name, t.name, h.attendance/h.games as att_per_game
from homegames as h
inner join parks as p using(park)
inner join (select teamid as team, name from teams where yearid=2016) as t using(team)
where year=2016 and games>=10
order by h.attendance/h.games desc
limit 5;

select park_name, t.name, h.attendance/h.games as att_per_game
from homegames as h
inner join parks as p using(park)
inner join (select teamid as team, name from teams where yearid=2016) as t using(team)
where year=2016 and games>=10
order by h.attendance/h.games
limit 5;

/* 9. Which managers have won the TSN Manager of the Year award in both the National 
League (NL) and the American League (AL)? Give their full name and the teams that they 
were managing when they won the award. */
/* "Davey Johnson"	"Baltimore Orioles"	"AL"
"Davey Johnson"	"Washington Nationals"	"NL"
"Jim Leyland"	"Detroit Tigers"	"AL"
"Jim Leyland"	"Pittsburgh Pirates"	"NL" */
with both_winner as (
	with nl_al_counts as (	
		select playerid, lgid, count(*) as win_time 
		from awardsmanagers
		where awardid like 'TSN Manager of the Year' and (lgid='NL' or lgid='AL')
		group by playerid,lgid
		order by playerid,lgid
	)
	select playerid
	from nl_al_counts
	group by playerid
	having string_agg(lgid, ' & ')='AL & NL'
)
select distinct (namefirst || ' ' || namelast) as manager, name as team, lgid
from awardsmanagers
inner join both_winner using(playerid)
inner join people using(playerid)
inner join managers using(playerid, yearid, lgid)
inner join teams using(yearid, lgid, teamid);

/* 10. Analyze all the colleges in the state of Tennessee. Which college has had 
the most success in the major leagues. Use whatever metric for success you like 
- number of players, number of games, salaries, world series wins, etc. */

with tn_players as (
	select distinct playerid, schoolname 
	from collegeplaying 
	inner join (select * from schools where schoolstate='TN') as tn_schools
	using(schoolid)
	order by playerid
)
select playerid, yearid, birthyear, deathyear, debut, finalgame, schoolname, teamid, rank, g, w, l, divwin, wcwin, lgwin, wswin, g_all, gs, salary from people
inner join tn_players using(playerid)
left join appearances as ap using(playerid)
left join teams using(teamid, yearid, lgid)
left join salaries using(playerid, yearid, teamid)
order by playerid, yearid, teamid;

with tn_players as (
	select distinct playerid, schoolname 
	from collegeplaying 
	inner join (select * from schools where schoolstate='TN') as tn_schools
	using(schoolid)
	order by playerid
)
select playerid, yearid, schoolname, teamid, gamenum, gp from people
inner join tn_players using(playerid)
left join appearances as ap using(playerid)
inner join allstarfull using(playerid, teamid, yearid)
where gp=1
order by playerid, yearid, teamid;

with tn_players as (
	select distinct playerid, schoolname 
	from collegeplaying 
	inner join (select * from schools where schoolstate='TN') as tn_schools
	using(schoolid)
	order by playerid
)
select playerid, yearid, schoolname, teamid, awardid from people
inner join tn_players using(playerid)
left join appearances as ap using(playerid)
inner join awardsplayers using(playerid, yearid)
order by playerid, yearid, teamid; 



