WITH RECURSIVE src AS ( -- BigOh: O(lines)
	select distinct -- This subquery fetches the row with its ID and numeric values that will be clustered
		ROW_NUMBER() OVER(ORDER BY [index] DESC) as id,
		Age as age,
		Height as height,
		Weight as weight,
		Year as year
	from athlete_events
	where Age is not NULL and Height is not NULL and Weight is not NULL and Year is not NULL
	limit 64
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
	    -- Think on how to select 1 2 4 3 from the X Y below without taking taking 5 6 7 8 9 as shortcuts
	    --  1          2
		--   5      6
		--               9
		--     7
		--             8
		--  3           4
		-- This means discovering from the full cartesian distance graph K_9 the
		-- 4 nodes in which the sum maximizes the sum, without having other intermediaty
		-- point selected, such as in 1 4 2 3, as it's closer for 1 to go to 3 than to 4.
		-- Also, 1 8 5 4 loop must be an invalid sequence as 1 to 5 is smaller than 1 to 8 to 5.
		t1.ida as id1,
		t2.ida as id2,
		t3.ida as id3,
		t4.ida as id4,
		t1.dist + t2.dist + t3.dist + t4.dist + t12.dist + t23.dist as dist,
		t1.dist + t2.dist + t3.dist + t4.dist as peri
	FROM scrstdscldst AS t1
	INNER JOIN scrstdscldst AS t2
	ON (t1.idb = t2.ida) -- t(n-1).b = t(n).a
	INNER JOIN scrstdscldst AS t3
	ON (t2.idb = t3.ida) -- t(n-1).b = t(n).a
	INNER JOIN scrstdscldst AS t4
	ON (t3.idb = t4.ida AND t4.idb = t1.ida) -- t(n-1).b = t(n).a; if last, also t(n).b = t(first).a
	INNER JOIN scrstdscldst AS t12 -- non-perimeter k graph component
	ON (t12.ida = t1.ida AND t12.idb = t2.idb)
	INNER JOIN scrstdscldst AS t23  -- non-perimeter k graph component
	ON (t23.ida = t2.ida AND t23.idb = t3.idb)
	WHERE 1=1
		AND t1.ida <> t2.ida -- ensuring output idX will be distinct
		AND t1.ida <> t3.ida -- ensuring output idX will be distinct
		AND t1.ida <> t4.ida -- ensuring output idX will be distinct
		AND t2.ida <> t3.ida -- ensuring output idX will be distinct
		AND t2.ida <> t4.ida -- ensuring output idX will be distinct
		AND t3.ida <> t4.ida -- ensuring output idX will be distinct
	ORDER BY dist DESC, peri ASC LIMIT 1 -- only the largest distance with smallest perimeter
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
	UNION ALL
	SELECT
		3 as cl,
		v.id,
		v.attr,
		v.val
	FROM scrstdsclgp1 AS g
	INNER JOIN scrstdscllin AS v
	ON (v.id = g.id3)
	UNION ALL
	SELECT
		4 as cl,
		v.id,
		v.attr,
		v.val
	FROM scrstdsclgp1 AS g
	INNER JOIN scrstdscllin AS v
	ON (v.id = g.id4)
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
