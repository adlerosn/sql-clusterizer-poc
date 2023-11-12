WITH RECURSIVE src AS ( -- BigOh: O(lines)
	select distinct -- This subquery fetches the row with its ID and numeric values that will be clustered
		ROW_NUMBER() OVER(ORDER BY [index] DESC) as id,
		Age as age,
		Height as height,
		Weight as weight,
		Year as year
	from athlete_events
	where Age is not NULL and Height is not NULL and Weight is not NULL and Year is not NULL
	limit 1024
), stdsclaux AS ( -- BigOh: O(lines)
	SELECT -- This subquery gets the MAX and MIN for each column in order to apply standard scale
		max(age) AS maxage,
		min(age) AS minage,
		max(height) AS maxheight,
		min(height) AS minheight,
		max(weight) AS maxweight,
		min(weight) AS minweight,
		max(year) AS maxyear,
		min(year) AS minyear
	from src
), scrstdscl AS ( -- BigOh: O(lines)
	SELECT -- This subquery applies standard scale
		src.id,
		(0.0 + src.age - stdsclaux.minage) / (stdsclaux.maxage - stdsclaux.minage) AS stdsclage,
		(0.0 + src.height - stdsclaux.minheight) / (stdsclaux.maxheight - stdsclaux.minheight) AS stdsclheight,
		(0.0 + src.weight - stdsclaux.minweight) / (stdsclaux.maxweight - stdsclaux.minweight) AS stdsclweight,
		(0.0 + src.year - stdsclaux.minyear) / (stdsclaux.maxyear - stdsclaux.minyear) AS stdsclyear
	FROM src JOIN stdsclaux ON (1=1)
), scrstdscllin AS ( -- BigOh: O(lines*attributes)
	SELECT -- This subquery transforms each column value into a virtual vector
		id,
		1 as attr,
		stdsclage as val
	FROM scrstdscl
	UNION ALL
	SELECT
		id,
		2 as attr,
		stdsclheight as val
	FROM scrstdscl
	UNION ALL
	SELECT
		id,
		3 as attr,
		stdsclweight as val
	FROM scrstdscl
	UNION ALL
	SELECT
		id,
		4 as attr,
		stdsclyear as val
	FROM scrstdscl
), scrstdscldst AS ( -- BigOh: O(POW(lines*attributes, 2))
	SELECT -- This subquery calculates the distance between each distinct element
		c.ida,
		c.idb,
		SQRT(SUM(c.dif2)) AS dist
	FROM (
		SELECT
			a.id AS ida,
			b.id AS idb,
			a.attr AS attr,
			POW(a.val-b.val, 2) AS dif2
		FROM scrstdscllin AS a
		INNER JOIN scrstdscllin AS b
		ON (a.id <> b.id AND a.attr = b.attr)
	) AS c
	GROUP BY c.ida, c.idb
), scrstdsclgp1 AS ( -- BigOh: O(POW(lines, POW(2, desired_clusters))) ??
	SELECT -- This SLOW subquery tries to solve the combinatory problem of getting the N points that are farthest away between themselves
		t1.ida as id1,
		t2.ida as id2,
		t1.dist + t2.dist as dist
	FROM scrstdscldst AS t1
	INNER JOIN scrstdscldst AS t2
	ON (t1.idb = t2.ida AND t2.idb = t1.ida) -- t(n-1).b = t(n).a; if last, also t(n).b = t(first).a
	WHERE t1.ida <> t2.ida -- ensuring output idX will be distinct
	ORDER BY dist DESC LIMIT 1 -- only the largest distance
), scrstdsclgrv AS ( -- BigOh(desired_clusters)
	SELECT -- this subquery transforms each group representative back into virtual vector form
		1 as cl,
		v.id,
		v.attr,
		v.val
	FROM scrstdsclgp1 AS g
	INNER JOIN scrstdscllin AS v
	ON (v.id = g.id1)
	UNION ALL
	SELECT
		2 as cl,
		v.id,
		v.attr,
		v.val
	FROM scrstdsclgp1 AS g
	INNER JOIN scrstdscllin AS v
	ON (v.id = g.id2)
), scrstdsclgrpdst AS ( -- BigOh(line*desired_clusters*attributes)
	SELECT -- This subquery calculates the distance between each distinct element
		c.id,
		c.cl,
		SQRT(SUM(c.dif2)) AS dist
	FROM (
		SELECT
			a.id,
			b.cl,
			a.attr AS attr,
			POW(a.val-b.val, 2) AS dif2
		FROM scrstdscllin AS a
		INNER JOIN scrstdsclgrv AS b
		ON (a.attr = b.attr)
	) AS c
	GROUP BY c.id, c.cl
), scrstdsclgrpclf AS ( -- BigOh(lines*desired_clusters)
	SELECT -- This subquery calculates the distance between each distinct element
		src.*,
		(SELECT cl FROM scrstdsclgrpdst AS g WHERE g.id = src.id ORDER BY dist ASC LIMIT 1) AS clf
	FROM src
)
SELECT * FROM scrstdsclgrpclf
